class_name ChaosEngine
extends RefCounted
## Estado puro de uma partida de Tarot Caos: várias rodadas curtas (8 cartas, sem
## licitação nem talão — todo mundo joga pra si), cada uma com um modificador sorteado
## e um bônus de "Fôlego" pra quem estiver por baixo, garantindo chance de virada até
## o fim. Vence quem somar mais pontos no total das rodadas.

signal trick_resolved(result: Dictionary)
signal round_finished(result: Dictionary)
signal match_finished(result: Dictionary)

const HAND_SIZE := 8
const ROUNDS := 5
const FOLEGO_MULT := 1.5   # bônus de pontos pra quem tá em último ANTES da rodada começar

var num_players := 4
var rng := RandomNumberGenerator.new()

var totals: Array = []        # pontos acumulados no total da partida
var round_index := 0
var modifier := -1
var weak_suit := -1
var folego_player := -1       # quem recebe o bônus de virada nessa rodada (-1 = ninguém)

var hands: Array = []
var plays: Array = []
var captured: Array = []
var round_points: Array = []  # pontos ganhos só nessa rodada, por jogador
var leader := -1
var current := -1
var trick_number := 0
var history: Array = []
var round_result: Dictionary = {}
var match_result: Dictionary = {}


## config: { players, seed }
func setup_match(config: Dictionary) -> void:
	num_players = int(config.get("players", 4))
	if config.has("seed"):
		rng.seed = int(config["seed"])
	else:
		rng.randomize()
	totals = []
	for p in range(num_players):
		totals.append(0.0)
	round_index = 0
	match_result = {}
	_setup_round()


func _setup_round() -> void:
	var deck := Deck.build(rng)
	var dealt := Deck.deal(deck, num_players, HAND_SIZE)
	hands = dealt["hands"]
	captured = []
	round_points = []
	for p in range(num_players):
		captured.append([])
		round_points.append(0.0)
	modifier = ChaosModifiers.random_modifier(rng)
	weak_suit = -1
	if modifier == ChaosModifiers.Modifier.NAIPE_FRACO:
		var suits := [CardData.Suit.OUROS, CardData.Suit.PAUS, CardData.Suit.COPAS, CardData.Suit.ESPADAS]
		weak_suit = suits[rng.randi_range(0, suits.size() - 1)]
	folego_player = _lowest_player() if round_index > 0 else -1
	leader = round_index % num_players
	current = leader
	trick_number = 0
	plays = []
	history = []
	round_result = {}


func _lowest_player() -> int:
	var lowest := 0
	for p in range(1, num_players):
		if totals[p] < totals[lowest]:
			lowest = p
	return lowest


## Verdadeiro no modificador "O Louco Vence" — usado pela UI/bots pra saber se O Louco
## deve ser tratado como um Trunfo fraco nas regras de vaza dessa rodada.
func louco_can_win() -> bool:
	return modifier == ChaosModifiers.Modifier.LOUCO_VENCE


func legal_for(player: int) -> Array:
	return TrickRules.legal_cards(hands[player], plays)


func is_round_over() -> bool:
	return trick_number >= HAND_SIZE


func is_match_over() -> bool:
	return round_index >= ROUNDS - 1 and is_round_over()


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


## Valor de uma carta já considerando o modificador ativo (não considera Fôlego — esse
## se aplica à vaza inteira, não carta a carta).
func card_value(c: CardData) -> float:
	var v := c.points()
	match modifier:
		ChaosModifiers.Modifier.TRUNFO_DOBRO:
			if c.is_trunfo():
				v *= 2.0
		ChaosModifiers.Modifier.REIS_DOBRO:
			if c.rank == 14 and not c.is_trunfo():
				v *= 2.0
		ChaosModifiers.Modifier.NAIPE_FRACO:
			if c.suit == weak_suit:
				v *= 0.5
	return v


func _resolve_trick() -> Dictionary:
	var idx := TrickRules.winning_index(plays, louco_can_win())
	var winner: int = plays[idx]["player"]
	var cards: Array = plays.map(func(p): return p["card"])
	captured[winner].append_array(cards)
	var base_points := 0.0
	for c in cards:
		base_points += card_value(c)
	var mult := 1.0
	if modifier == ChaosModifiers.Modifier.PRIMEIRA_DOBRO and trick_number == 0:
		mult *= 2.0
	if modifier == ChaosModifiers.Modifier.ULTIMA_TRIPLO and trick_number == HAND_SIZE - 1:
		mult *= 3.0
	var folego_applied := winner == folego_player
	if folego_applied:
		mult *= FOLEGO_MULT
	var points := base_points * mult
	var trick_result := {
		"winner": winner,
		"winning_index": idx,
		"plays": plays.duplicate(),
		"points": points,
		"base_points": base_points,
		"mult": mult,
		"folego_applied": folego_applied,
		"trick_number": trick_number,
	}
	history.append(trick_result)
	round_points[winner] += points
	totals[winner] += points
	plays = []
	trick_number += 1
	leader = winner
	current = winner
	trick_resolved.emit(trick_result)
	if is_round_over():
		round_result = {
			"round": round_index,
			"modifier": modifier,
			"weak_suit": weak_suit,
			"folego_player": folego_player,
			"round_points": round_points.duplicate(),
			"totals": totals.duplicate(),
		}
		round_finished.emit(round_result)
		if round_index >= ROUNDS - 1:
			var order := range(num_players)
			order.sort_custom(func(a: int, b: int) -> bool: return totals[a] > totals[b])
			match_result = {"totals": totals.duplicate(), "standings": order}
			match_finished.emit(match_result)
	return trick_result


## Chamado pela UI depois de mostrar o resumo da rodada, pra sortear/preparar a próxima.
func advance_round() -> void:
	round_index += 1
	if round_index < ROUNDS:
		_setup_round()


func points_of(player: int) -> float:
	var total := 0.0
	for c in captured[player]:
		total += card_value(c)
	return total


func placement_of(player: int) -> int:
	var order: Array = match_result.get("standings", range(num_players))
	return order.find(player)
