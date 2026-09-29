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
const ITEM_MULT := 1.25    # bônus do item Fôlego Pessoal
const ITEM_STEAL := 4.0    # pontos roubados pelo item Roubo de Vaza
const BUY_IN := 100.0
const GOLD_MULT := 3.0      # Vaza Dourada
const FINAL_MULT := 2.0     # todos os pontos da última rodada
const STREAK_MULT := 1.5    # Mão Quente: 3ª vitória seguida (e seguintes) na rodada
const KING_CUT_BONUS := 3.0 # Corte de Rei
const BREAK_BONUS := 2.0    # Cortado: quebrar a sequência de 2+ vitórias de alguém
const SAQUE_AMOUNT := 2.0   # pontos roubados de cada rival no Saque
const ASSALTO_AMOUNT := 4.0 # pontos roubados do líder no Assalto ao Líder
const CURSE_PENALTY := 3.0  # pontos perdidos por quem vence a Vaza Maldita
const FORTE_MULT := 1.5     # Naipe Forte
const VAZA_PLUS := 1.0      # bônus fixo de Cada Vaza Vale +1
const NAIPE_CURSED_VALUE := -1.0  # valor de cada carta do Naipe Maldito
const PAYOUT_SHARES := [0.5, 0.3, 0.15, 0.05]  # fatia do pote por colocação (1º a 4º)

var num_players := 4
var rng := RandomNumberGenerator.new()

var totals: Array = []        # pontos acumulados no total da partida
var round_index := 0
var modifier_sequence: Array = []  # ordem embaralhada dos modificadores, sem repetir na partida
var modifier := -1
var weak_suit := -1
var modifier_trick := -1      # vaza (0..7) onde o modificador de escopo VAZA vale; -1 = rodada inteira
var streak: Array = []        # vitórias seguidas de cada jogador, dentro da rodada
var last_winner := -1
var folego_player := -1       # quem recebe o bônus de virada nessa rodada (-1 = ninguém)
var buy_in := BUY_IN
var pot := 0.0

var hands: Array = []
var plays: Array = []
var captured: Array = []
var round_points: Array = []  # pontos ganhos só nessa rodada, por jogador
var player_items: Array = []  # item ativo de cada jogador nessa rodada (ChaosItems.Item)
var roubo_used: Array = []    # se o jogador já usou o Roubo de Vaza nessa rodada
var leader := -1
var current := -1
var trick_number := 0
var history: Array = []
var round_result: Dictionary = {}
var match_result: Dictionary = {}


## config: { players, seed, buy_in }
func setup_match(config: Dictionary) -> void:
	num_players = int(config.get("players", 4))
	buy_in = float(config.get("buy_in", BUY_IN))
	pot = buy_in * num_players
	if config.has("seed"):
		rng.seed = int(config["seed"])
	else:
		rng.randomize()
	totals = []
	for p in range(num_players):
		totals.append(0.0)
	round_index = 0
	match_result = {}
	modifier_sequence = ChaosModifiers.ALL.duplicate()
	Deck.shuffle(modifier_sequence, rng)
	_setup_round()


func _setup_round() -> void:
	var deck := Deck.build(rng)
	var dealt := Deck.deal(deck, num_players, HAND_SIZE)
	hands = dealt["hands"]
	captured = []
	round_points = []
	player_items = []
	roubo_used = []
	streak = []
	last_winner = -1
	for p in range(num_players):
		streak.append(0)
		captured.append([])
		round_points.append(0.0)
		player_items.append(ChaosItems.Item.NONE)
		roubo_used.append(false)
	modifier = modifier_sequence[round_index % modifier_sequence.size()]
	weak_suit = -1
	modifier_trick = -1
	if ChaosModifiers.scope_of(modifier) == ChaosModifiers.Scope.TRICK:
		if modifier == ChaosModifiers.Modifier.PRIMEIRA_DOBRO:
			modifier_trick = 0
		elif modifier == ChaosModifiers.Modifier.ULTIMA_TRIPLO:
			modifier_trick = HAND_SIZE - 1
		else:
			modifier_trick = rng.randi_range(1, HAND_SIZE - 2)
	if ChaosModifiers.has_suit(modifier):
		var suits := [CardData.Suit.OUROS, CardData.Suit.PAUS, CardData.Suit.COPAS, CardData.Suit.ESPADAS]
		weak_suit = suits[rng.randi_range(0, suits.size() - 1)]
	folego_player = _lowest_player() if round_index > 0 else -1
	leader = round_index % num_players
	current = leader
	trick_number = 0
	plays = []
	history = []
	round_result = {}


## Define o item escolhido por um jogador pra rodada atual — chamado pela UI depois que
## humano/bots decidem, logo após advance_round() preparar a rodada nova.
func set_item(player: int, item: int) -> void:
	player_items[player] = item


func payout_for(placement: int) -> float:
	return pot * PAYOUT_SHARES[clampi(placement, 0, PAYOUT_SHARES.size() - 1)]


func _lowest_player() -> int:
	var lowest := 0
	for p in range(1, num_players):
		if totals[p] < totals[lowest]:
			lowest = p
	return lowest


func _highest_player() -> int:
	var highest := 0
	for p in range(1, num_players):
		if totals[p] > totals[highest]:
			highest = p
	return highest


## Verdadeiro no modificador "O Louco Vence" — usado pela UI/bots pra saber se O Louco
## deve ser tratado como um Trunfo fraco nas regras de vaza dessa rodada.
func louco_can_win() -> bool:
	return modifier == ChaosModifiers.Modifier.LOUCO_VENCE


## Modificador que vale na vaza que está sendo jogada agora (-1 se nenhum): os de rodada
## inteira valem sempre; os de vaza só na vaza sorteada.
func active_modifier() -> int:
	if ChaosModifiers.scope_of(modifier) == ChaosModifiers.Scope.ROUND or trick_number == modifier_trick:
		return modifier
	return -1


## Verdadeiro se `mod` está valendo na vaza atual.
func is_active(mod: int) -> bool:
	return active_modifier() == mod


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


## Valor de uma carta já considerando o modificador ativo e, se um jogador for passado,
## o item pessoal dele (não considera Fôlego/item de rodada — esses se aplicam à vaza
## inteira, não carta a carta).
func card_value(c: CardData, player: int = -1) -> float:
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
		ChaosModifiers.Modifier.NAIPE_FORTE:
			if c.suit == weak_suit:
				v *= FORTE_MULT
		ChaosModifiers.Modifier.PEQUENAS_IMPORTAM:
			if is_equal_approx(c.points(), 0.5):
				v = 1.0
		ChaosModifiers.Modifier.NAIPE_MALDITO:
			if c.suit == weak_suit:
				v = NAIPE_CURSED_VALUE
	if player != -1 and player < player_items.size():
		var item: int = player_items[player]
		var shield_applies := (modifier == ChaosModifiers.Modifier.NAIPE_FRACO or modifier == ChaosModifiers.Modifier.NAIPE_MALDITO) and c.suit == weak_suit
		if item == ChaosItems.Item.ESCUDO_NAIPE and shield_applies:
			v = c.points()
		elif item == ChaosItems.Item.TRUNFO_AFIADO and c.is_trunfo():
			v += 1.0
	return v


func is_final_round() -> bool:
	return round_index >= ROUNDS - 1


## Vaza Invertida: vence a MENOR carta do naipe líder (Trunfo que corta não vale nada).
func _lowest_index(trick: Array = []) -> int:
	if trick.is_empty():
		trick = plays
	var ls := TrickRules.lead_suit(trick)
	var best := -1
	for i in range(trick.size()):
		var c: CardData = trick[i]["card"]
		if c.is_louco() or c.suit != ls:
			continue
		if best == -1 or c.rank < (trick[best]["card"] as CardData).rank:
			best = i
	return best if best != -1 else TrickRules.winning_index(trick, louco_can_win())


## Se `card`, jogada por `player` agora, venceria a vaza como está (considera Vaza Invertida
## / Mundo ao Contrário). Usado pelos bots.
func would_win(card: CardData, player: int) -> bool:
	var ev := active_modifier()
	if ev != ChaosModifiers.Modifier.MUNDO_CONTRARIO and ev != ChaosModifiers.Modifier.VAZA_INVERTIDA:
		return TrickRules.would_win(card, player, plays, louco_can_win())
	var trick := plays.duplicate()
	trick.append({"player": player, "card": card})
	return int(trick[_lowest_index(trick)]["player"]) == player


func _resolve_trick() -> Dictionary:
	var ev := active_modifier()
	var inverted := ev == ChaosModifiers.Modifier.MUNDO_CONTRARIO or ev == ChaosModifiers.Modifier.VAZA_INVERTIDA
	var idx := _lowest_index() if inverted else TrickRules.winning_index(plays, louco_can_win())
	var winner: int = plays[idx]["player"]
	var cards: Array = plays.map(func(p): return p["card"])
	captured[winner].append_array(cards)
	var base_points := 0.0
	for c in cards:
		base_points += card_value(c, winner)
	var mult := 1.0
	if ev == ChaosModifiers.Modifier.PRIMEIRA_DOBRO:
		mult *= 2.0
	if ev == ChaosModifiers.Modifier.ULTIMA_TRIPLO:
		mult *= 3.0
	if ev == ChaosModifiers.Modifier.VAZA_DOURADA:
		mult *= GOLD_MULT
	if is_final_round():
		mult *= FINAL_MULT
	# Combos: sequência, quebra de sequência e corte de Rei.
	var combos: Array = []
	var bonus := 0.0
	if ev == ChaosModifiers.Modifier.VAZA_MAIS_UM:
		bonus += VAZA_PLUS
	if ev == ChaosModifiers.Modifier.VAZA_MALDITA:
		bonus -= CURSE_PENALTY
	var prev_streak: int = streak[last_winner] if last_winner != -1 else 0
	var broke := last_winner != -1 and last_winner != winner and prev_streak >= 2
	for q in range(num_players):
		streak[q] = streak[q] + 1 if q == winner else 0
	if streak[winner] >= 3:
		mult *= STREAK_MULT
		combos.append("MAO_QUENTE")
	if broke:
		bonus += BREAK_BONUS
		combos.append("CORTADO")
	var wcard: CardData = plays[idx]["card"]
	var lead := TrickRules.lead_suit(plays)
	if wcard.is_trunfo() and lead != CardData.Suit.TRUNFO and lead != -1:
		for pl in plays:
			var pc: CardData = pl["card"]
			if pc.suit == lead and pc.rank == 14:
				bonus += KING_CUT_BONUS
				combos.append("CORTE_REI")
				break
	last_winner = winner
	var folego_applied := winner == folego_player
	if folego_applied:
		mult *= FOLEGO_MULT
	var item_folego: bool = winner < player_items.size() and player_items[winner] == ChaosItems.Item.FOLEGO_PESSOAL
	if item_folego:
		mult *= ITEM_MULT
	var points := base_points * mult + bonus
	var saque_amount := 0.0
	var assalto_amount := 0.0
	if ev == ChaosModifiers.Modifier.ASSALTO_LIDER:
		var lead_p := _highest_player()
		if lead_p != winner:
			assalto_amount = minf(ASSALTO_AMOUNT, totals[lead_p])
			totals[lead_p] -= assalto_amount
			round_points[lead_p] -= assalto_amount
	if ev == ChaosModifiers.Modifier.SAQUE:
		for q in range(num_players):
			if q == winner:
				continue
			var take := minf(SAQUE_AMOUNT, totals[q])
			totals[q] -= take
			round_points[q] -= take
			saque_amount += take
	var roubo_applied := false
	var roubo_amount := 0.0
	var roubo_target := -1
	if winner < player_items.size() and player_items[winner] == ChaosItems.Item.ROUBO_VAZA and not roubo_used[winner]:
		roubo_used[winner] = true
		var target := _highest_player()
		if target != winner:
			roubo_amount = minf(ITEM_STEAL, totals[target])
			totals[target] -= roubo_amount
			round_points[target] -= roubo_amount
			roubo_applied = roubo_amount > 0.0
			roubo_target = target
	var trick_result := {
		"winner": winner,
		"winning_index": idx,
		"plays": plays.duplicate(),
		"points": points,
		"base_points": base_points,
		"mult": mult,
		"folego_applied": folego_applied,
		"item_folego": item_folego,
		"roubo_applied": roubo_applied,
		"roubo_amount": roubo_amount,
		"roubo_target": roubo_target,
		"trick_number": trick_number,
		"modifier": ev,
		"combos": combos,
		"bonus": bonus,
		"saque_amount": saque_amount,
		"assalto_amount": assalto_amount,
		"final": is_final_round(),
	}
	history.append(trick_result)
	round_points[winner] += points + roubo_amount + saque_amount + assalto_amount
	totals[winner] += points + roubo_amount + saque_amount + assalto_amount
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
			"modifier_trick": modifier_trick,
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
		total += card_value(c, player)
	return total


func placement_of(player: int) -> int:
	var order: Array = match_result.get("standings", range(num_players))
	return order.find(player)
