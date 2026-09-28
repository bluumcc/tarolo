class_name MatchEngine
extends RefCounted
## Estado puro de uma rodada de Tarot Vanilla (sem UI): licitação, talão, vazas e a
## pontuação final do tomador contra a defesa.

signal trick_resolved(result: Dictionary)
signal round_finished()

var num_players := 4
var hands: Array = []          # Array[Array[CardData]]
var chien: Array = []          # talão (6 cartas)
var plays: Array = []          # vaza atual: [{player, card}]
var captured: Array = []       # Array[Array[CardData]] capturado por cada jogador
var leader := -1
var current := -1
var trick_number := 0
var total_tricks := -1
var history: Array = []        # resultados das vazas
var result: Dictionary = {}    # preenchido quando a rodada acaba (round_finished)
var rng := RandomNumberGenerator.new()

# ------------------------------------------------------------------ licitação
var taker := -1
var contract := -1
var bid_turn := 0
var bid_active: Array = []     # ainda não passou
var highest_bid := -1
var highest_bidder := -1
var bidding_done := false
var bidding_void := false      # todos passaram (mão anulada — chamador deve refazer o setup)
var taker_trump_count := 0     # trunfos na mão do tomador já com o talão resolvido (Poignée)


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

	taker = -1
	contract = -1
	bid_turn = 0
	bid_active = []
	for p in range(num_players):
		bid_active.append(true)
	highest_bid = -1
	highest_bidder = -1
	bidding_done = false
	bidding_void = false

	leader = -1
	current = -1
	trick_number = 0
	total_tricks = -1
	plays = []
	history = []
	result = {}


# ------------------------------------------------------------------ licitação

## Contratos que `player` pode oferecer agora (estritamente acima do lance atual).
## Passar sempre é permitido à parte, exceto quando `is_bidding_forced`.
func bid_options(player: int) -> Array:
	var opts: Array = []
	for c in range(highest_bid + 1, Scoring.Contract.GARDE_CONTRE + 1):
		opts.append(c)
	return opts


## Verdadeiro quando `player` é o único que ainda não passou e ninguém deu lance —
## nesse caso, alguém precisa assumir (não pode passar), como no jogo real.
func is_bidding_forced(player: int) -> bool:
	if highest_bidder != -1 or not bid_active[player]:
		return false
	for p in range(num_players):
		if p != player and bid_active[p]:
			return false
	return true


## `choice` = -1 (passar) ou um valor de `Scoring.Contract`.
func place_bid(player: int, choice: int) -> Dictionary:
	if bidding_done or player != bid_turn or not bid_active[player]:
		return {"ok": false, "error": "fora de vez"}
	if choice == -1:
		if is_bidding_forced(player):
			return {"ok": false, "error": "obrigado a dar um lance"}
		bid_active[player] = false
	else:
		if choice <= highest_bid:
			return {"ok": false, "error": "lance muito baixo"}
		highest_bid = choice
		highest_bidder = player
	_advance_bidding()
	return {"ok": true, "done": bidding_done}


func _advance_bidding() -> void:
	var active_count := 0
	for a in bid_active:
		if a:
			active_count += 1
	if active_count == 0:
		bidding_done = true
		bidding_void = true
		return
	if active_count == 1 and highest_bidder != -1 and bid_active[highest_bidder]:
		bidding_done = true
		taker = highest_bidder
		contract = highest_bid
		_finalize_taker()
		return
	var attempts := 0
	while attempts < num_players:
		bid_turn = (bid_turn + 1) % num_players
		attempts += 1
		if bid_active[bid_turn] and bid_turn != highest_bidder:
			return


## Aplica as regras do contrato vencedor sobre o talão e prepara o início das vazas.
## Petite/Garde: o tomador vê o talão e descarta 6 cartas de volta (contam pra ele).
## Garde Sans: o tomador não vê o talão, mas ele conta pra ele mesmo assim.
## Garde Contre: o tomador não vê o talão, e ele NÃO conta pra ele (fica com a defesa).
func _finalize_taker() -> void:
	match contract:
		Scoring.Contract.PETITE, Scoring.Contract.GARDE:
			(hands[taker] as Array).append_array(chien)
			Deck.sort_hand(hands[taker])
			var discarded := _auto_discard(hands[taker], Deck.CHIEN_SIZE)
			for c in discarded:
				(hands[taker] as Array).erase(c)
			captured[taker].append_array(discarded)
		Scoring.Contract.GARDE_SANS:
			captured[taker].append_array(chien)
		Scoring.Contract.GARDE_CONTRE:
			pass  # talão não entra na jogada nem pontua pro tomador
	total_tricks = (hands[0] as Array).size()
	leader = (taker + 1) % num_players
	current = leader
	taker_trump_count = 0
	for c in hands[taker]:
		if (c as CardData).is_trunfo():
			taker_trump_count += 1


## Descarta as `n` cartas mais fracas (nunca um Bout) de `hand`, devolve as descartadas.
static func _auto_discard(hand: Array, n: int) -> Array:
	var pool: Array = hand.filter(func(c: CardData) -> bool: return not c.is_bout())
	pool.sort_custom(func(a: CardData, b: CardData) -> bool: return a.points() < b.points())
	return pool.slice(0, mini(n, pool.size()))


# ------------------------------------------------------------------ vazas

func legal_for(player: int) -> Array:
	return TrickRules.legal_cards(hands[player], plays)


func is_round_over() -> bool:
	return total_tricks > 0 and trick_number >= total_tricks


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
	# Garde Sans/Contre: o talão nunca entrou na mão do tomador (não é jogado em vaza
	# nenhuma), então ele só entra na conta final aqui — não nos dois casos acima.
	var bonuses := _round_bonuses()
	var r := Scoring.resolve(taker_points, bouts, contract, bonuses)
	r["taker"] = taker
	r["taker_points"] = taker_points
	r["bouts"] = bouts
	r["deltas"] = Scoring.distribute(r["score"], taker, num_players)
	return r


## Detecta Poignée (mão inicial do tomador), Chelem (tomador venceu todas as vazas) e
## Petit au bout (Le Petit na última vaza) — tudo automático, sem exigir declaração.
func _round_bonuses() -> Dictionary:
	var poignee := Scoring.poignee_bonus(taker_trump_count)
	var chelem := 0.0
	var taker_won_all := true
	for p in range(num_players):
		if p != taker and not (captured[p] as Array).is_empty():
			taker_won_all = false
			break
	if taker_won_all:
		chelem = Scoring.CHELEM_BONUS
	var petit_au_bout := 0.0
	if not history.is_empty():
		var last_trick: Dictionary = history[-1]
		var has_petit := false
		for entry in (last_trick["plays"] as Array):
			var card: CardData = entry["card"]
			if card.is_trunfo() and card.rank == CardData.PETIT:
				has_petit = true
				break
		if has_petit:
			var winner: int = last_trick["winner"]
			petit_au_bout = Scoring.PETIT_AU_BOUT_BONUS if winner == taker else -Scoring.PETIT_AU_BOUT_BONUS
	return {"poignee": poignee, "chelem": chelem, "petit_au_bout": petit_au_bout}


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
