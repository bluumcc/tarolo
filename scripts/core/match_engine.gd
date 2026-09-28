class_name MatchEngine
extends RefCounted
## Estado puro de uma partida de vazas (sem UI). A cena chama `play()` e anima o resultado.

signal trick_resolved(result: Dictionary)
signal round_finished()

var num_players := 4
var hands: Array = []          # Array[Array[CardData]]
var scores: Array = []         # int por jogador
var tricks_won: Array = []     # int por jogador
var plays: Array = []          # vaza atual: [{player, card}]
var jokers: Array = []         # curingas por jogador: Array[Array[String]]
var stage_mult: Array = []     # multiplicador de fase por jogador (bots do Arcade)
var leader := 0
var current := 0
var trick_number := 0
var total_tricks := 0
var gold_earned := 0           # ouro do jogador humano (índice 0) nesta partida
var history: Array = []        # resultados das vazas
var rng := RandomNumberGenerator.new()


## config: { seed, players, arcana_count, modifiers, upgrades, jokers (do jogador 0), stage_mult (Array) }
func setup(config: Dictionary) -> void:
	num_players = int(config.get("players", 4))
	if config.has("seed"):
		rng.seed = int(config["seed"])
	else:
		rng.randomize()
	var deck := Deck.build(rng, int(config.get("arcana_count", 4)), bool(config.get("modifiers", false)), config.get("upgrades", {}))
	hands = Deck.deal(deck, num_players)
	scores = []
	tricks_won = []
	jokers = []
	stage_mult = []
	for p in range(num_players):
		scores.append(0)
		tricks_won.append(0)
		jokers.append([])
		stage_mult.append(1.0)
	jokers[0] = (config.get("jokers", []) as Array).duplicate()
	var sm: Array = config.get("stage_mult", [])
	for p in range(mini(sm.size(), num_players)):
		stage_mult[p] = float(sm[p])
	total_tricks = (hands[0] as Array).size()
	leader = rng.randi_range(0, num_players - 1)
	current = leader
	trick_number = 0
	gold_earned = 0
	plays = []
	history = []


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
	var result := _resolve_trick()
	return {"ok": true, "trick_complete": true, "result": result}


func _resolve_trick() -> Dictionary:
	var idx := TrickRules.winning_index(plays)
	var winner: int = plays[idx]["player"]
	var cards: Array = plays.map(func(p): return p["card"])
	var ev := Scoring.evaluate(cards, plays[idx]["card"], jokers[winner], stage_mult[winner])
	scores[winner] += ev["total"]
	tricks_won[winner] += 1
	var gold := 0
	if winner == 0:
		gold = 1 + (2 if (jokers[0] as Array).has("ganancia") else 0)
		gold_earned += gold
	var result := {
		"winner": winner,
		"winning_index": idx,
		"plays": plays.duplicate(),
		"eval": ev,
		"gold": gold,
		"trick_number": trick_number,
	}
	history.append(result)
	plays = []
	trick_number += 1
	leader = winner
	current = winner
	trick_resolved.emit(result)
	if is_round_over():
		round_finished.emit()
	return result


## Índices dos jogadores do 1º ao último lugar (desempate por vazas vencidas).
func standings() -> Array:
	var order: Array = range(num_players)
	order.sort_custom(func(a: int, b: int) -> bool:
		if scores[a] != scores[b]:
			return scores[a] > scores[b]
		return tricks_won[a] > tricks_won[b])
	return order


func placement_of(player: int) -> int:
	return standings().find(player)
