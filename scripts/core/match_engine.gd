class_name MatchEngine
extends RefCounted
## Estado puro de uma rodada de Tarot Vanilla (sem UI): licitação, talão, vazas e a
## pontuação final do tomador contra a defesa.

signal trick_resolved(result: Dictionary)
signal round_finished()

var num_players := 4
var hands: Array = []          # Array[Array[CardData]]
var chien: Array = []          # talão (6 cartas), incorporado à mão do tomador no setup
var taker := 0
var contract := 0              # Scoring.Contract — V1: escolhido automaticamente pela força da mão
var plays: Array = []          # vaza atual: [{player, card}]
var captured: Array = []       # Array[Array[CardData]] capturado por cada jogador (vazas + talão do tomador)
var leader := 0
var current := 0
var trick_number := 0
var total_tricks := 0
var history: Array = []        # resultados das vazas
var result: Dictionary = {}    # preenchido quando a rodada acaba (round_finished)
var rng := RandomNumberGenerator.new()


## config: { seed, players }
func setup(config: Dictionary) -> void:
	num_players = int(config.get("players", 4))
	if config.has("seed"):
		rng.seed = int(config["seed"])
	else:
		rng.randomize()
	var deck := Deck.build(rng)
	var dealt := Deck.deal(deck, num_players, 18)
	hands = dealt["hands"]
	chien = dealt["rest"]
	captured = []
	for p in range(num_players):
		captured.append([])

	taker = _pick_taker()
	contract = _contract_for(taker)
	# O tomador incorpora o talão e descarta 6 cartas de volta (sem Bouts, se possível) —
	# essas 6 já contam como capturadas por ele pra pontuação final.
	(hands[taker] as Array).append_array(chien)
	Deck.sort_hand(hands[taker])
	var discarded := _auto_discard(hands[taker], Deck.CHIEN_SIZE)
	for c in discarded:
		(hands[taker] as Array).erase(c)
	captured[taker].append_array(discarded)

	total_tricks = (hands[0] as Array).size()
	leader = (taker + 1) % num_players
	current = leader
	trick_number = 0
	plays = []
	history = []
	result = {}


## V1: sem licitação interativa — quem tem a mão mais forte assume como tomador.
## (a licitação de verdade — Passe/Petite/Garde/Garde Sans/Garde Contre, escolhida
## pelo jogador — entra numa próxima fase.)
func _pick_taker() -> int:
	var best := 0
	var best_strength := -1.0
	for p in range(num_players):
		var s := _hand_strength(hands[p])
		if s > best_strength:
			best_strength = s
			best = p
	return best


func _hand_strength(hand: Array) -> float:
	var s := 0.0
	for c in hand:
		var card: CardData = c
		if card.is_bout():
			s += 3.0
		elif card.is_trunfo():
			s += 1.0
		else:
			s += card.points()
	return s


func _contract_for(taker_seat: int) -> int:
	return Scoring.Contract.GARDE if _hand_strength(hands[taker_seat]) >= 26.0 else Scoring.Contract.PETITE


## Descarta as `n` cartas mais fracas (nunca um Bout) de `hand`, devolve as descartadas.
static func _auto_discard(hand: Array, n: int) -> Array:
	var pool: Array = hand.filter(func(c: CardData) -> bool: return not c.is_bout())
	pool.sort_custom(func(a: CardData, b: CardData) -> bool: return a.points() < b.points())
	return pool.slice(0, mini(n, pool.size()))


func legal_for(player: int) -> Array:
	return TrickRules.legal_cards(hands[player], plays)


func is_round_over() -> bool:
	return trick_number >= total_tricks


## Joga `card` pelo jogador da vez. Retorna { ok, trick_complete, result? }.
func play(player: int, card: CardData) -> Dictionary:
	if player != current or is_round_over():
		return {"ok": false, "error": "fora de turno"}
	var hand: Array = hands[player]
	if not TrickRules.is_legal(card, hand, plays):
		return {"ok": false, "error": "jogada ilegal"}
	hand.erase(card)
	plays.append({"player": player, "card": card})
	if plays.size() < num_players:
		current = (current + 1) % num_players
		return {"ok": true, "trick_complete": false}
	return {"ok": true, "trick_complete": true, "result": _resolve_trick()}


func _resolve_trick() -> Dictionary:
	var idx := TrickRules.winning_index(plays)
	var winner: int = plays[idx]["player"]
	var cards: Array = plays.map(func(p): return p["card"])
	captured[winner].append_array(cards)
	var points := 0.0
	for c in cards:
		points += (c as CardData).points()
	var trick_result := {
		"winner": winner,
		"winning_index": idx,
		"plays": plays.duplicate(),
		"points": points,
		"trick_number": trick_number,
	}
	history.append(trick_result)
	plays = []
	trick_number += 1
	leader = winner
	current = winner
	trick_resolved.emit(trick_result)
	if is_round_over():
		result = _finish()
		round_finished.emit()
	return trick_result


func _finish() -> Dictionary:
	var taker_points := 0.0
	var bouts := 0
	for c in captured[taker]:
		var card: CardData = c
		taker_points += card.points()
		if card.is_bout():
			bouts += 1
	var r := Scoring.resolve(taker_points, bouts, contract)
	r["taker"] = taker
	r["taker_points"] = taker_points
	r["bouts"] = bouts
	r["deltas"] = Scoring.distribute(r["score"], taker, num_players)
	return r


## Pontos capturados até agora por um jogador (visível durante a partida — o placar
## oficial só fecha no fim, como no Tarot de verdade).
func points_of(player: int) -> float:
	var total := 0.0
	for c in captured[player]:
		total += (c as CardData).points()
	return total


## Índices dos jogadores do melhor ao pior resultado da rodada (pelo delta de pontos).
func standings() -> Array:
	var deltas: Array = result.get("deltas", [])
	var order: Array = range(num_players)
	if deltas.is_empty():
		return order
	order.sort_custom(func(a: int, b: int) -> bool: return int(deltas[a]) > int(deltas[b]))
	return order


func placement_of(player: int) -> int:
	return standings().find(player)
