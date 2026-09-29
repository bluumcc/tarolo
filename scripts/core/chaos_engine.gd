class_name ChaosEngine
extends RefCounted
## Estado puro de uma partida de Tarot Caos: vários níveis curtos (8 cartas, sem
## licitação nem talão — todo mundo joga pra si), cada uma com um modificador sorteado
## e um bônus de "Fôlego" pra quem estiver por baixo, garantindo chance de virada até
## o fim. Vence quem somar mais pontos no total dos níveis.

signal trick_resolved(result: Dictionary)
signal round_finished(result: Dictionary)
signal match_finished(result: Dictionary)

const HAND_SIZE := 8
const ROUNDS := 5
const FOLEGO_MULT := 1.5   # bônus de pontos pra quem tá em último ANTES do nível começar
const ARRISCAR_MULT := 2.0  # poder Arriscar: rodada vencida vale ×2
const ARRISCAR_LOSS := 2.0  # ...e se perder, −2
# Aposta em fichas (estilo poker): antes do nível você crava quantas rodadas vai ganhar
# (palpite exato) e quanto aposta. Todas as apostas vão pro pote do nível; quem acerta o
# número exato divide o pote pelo peso (aposta × dificuldade × combos). Errou por 1 recebe
# metade da aposta de volta; errou por mais perde tudo. Sem vencedor, o pote acumula.
const STAKES := [10, 25, 50]
const DOUBLE_FROM_TRICK := 3        # DOBRAR liberado a partir da 4ª rodada (índice 3)
const NEAR_REFUND := 0.5            # errou por 1: devolve metade da aposta
const COMBO_WEIGHT := 0.25          # cada combo feito no nível: +25% no peso
const COMBO_WEIGHT_MAX := 1.0       # ...até +100% (peso ×2)
const BUY_IN := 100.0
const GOLD_MULT := 3.0      # Rodada Dourada
const FINAL_MULT := 2.0     # todos os pontos do último nível
const KING_CUT_BONUS := 3.0 # Corte de Rei
const BREAK_BONUS := 2.0    # Cortado: quebrar a sequência de 2+ vitórias de alguém
const SAQUE_AMOUNT := 2.0   # pontos roubados de cada rival no Saque
const ASSALTO_AMOUNT := 4.0 # pontos roubados do líder no Assalto ao Líder
const CURSE_PENALTY := 3.0  # pontos perdidos por quem vence a Rodada Maldita
const FORTE_MULT := 1.5     # Naipe Forte
const VAZA_PLUS := 1.0      # bônus fixo de Cada Rodada Vale +1
const NAIPE_CURSED_VALUE := -1.0  # valor de cada carta do Naipe Maldito
const PAYOUT_SHARES := [0.5, 0.3, 0.15, 0.05]  # fatia do pote por colocação (1º a 4º)

var num_players := 4
var rng := RandomNumberGenerator.new()

var totals: Array = []        # pontos acumulados no total da partida
var round_index := 0
var modifier_sequence: Array = []  # ordem embaralhada dos modificadores, sem repetir na partida
var modifier := -1
var weak_suit := -1
var modifier_trick := -1      # rodada (0..7) onde o modificador de escopo RODADA vale; -1 = nível inteiro
var streak: Array = []        # vitórias seguidas de cada jogador, dentro do nível
var last_winner := -1
var folego_player := -1       # quem recebe o bônus de virada nesse nível (-1 = ninguém)
var buy_in := BUY_IN
var pot := 0.0

var hands: Array = []
var plays: Array = []
var captured: Array = []
var round_points: Array = []  # pontos ganhos só nesse nível, por jogador
var player_items: Array = []  # item ativo de cada jogador nesse nível (ChaosItems.Item)
var power_used: Array = []    # se o jogador já usou o poder desse nível
var arriscar_on: Array = []   # Arriscar armado pra rodada atual
var bet_predict: Array = []   # palpite de cada jogador: nº de rodadas que vai ganhar (-1 = sem aposta)
var bet_stake: Array = []     # fichas apostadas no nível (dobram se doubled)
var bet_doubled: Array = []   # já usou DOBRAR nesse nível
var bet_carry := 0.0          # pote acumulado dos níveis em que ninguém acertou
var bet_chips: Array = []     # saldo líquido de fichas das apostas na partida, por jogador
var combo_count: Array = []   # combos feitos no nível (contam pro peso do palpite)
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
	bet_carry = 0.0
	bet_chips = []
	for p in range(num_players):
		bet_chips.append(0.0)
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
	power_used = []
	arriscar_on = []
	bet_predict = []
	bet_stake = []
	bet_doubled = []
	combo_count = []
	streak = []
	last_winner = -1
	for p in range(num_players):
		streak.append(0)
		captured.append([])
		round_points.append(0.0)
		player_items.append(ChaosItems.Item.NONE)
		power_used.append(false)
		arriscar_on.append(false)
		bet_predict.append(-1)
		bet_stake.append(0.0)
		bet_doubled.append(false)
		combo_count.append(0)
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


## Define o item escolhido por um jogador pro nível atual — chamado pela UI depois que
## humano/bots decidem, logo após advance_round() preparar o nível novo.
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
## deve ser tratado como um Trunfo fraco nas regras de rodada desse nível.
func louco_can_win() -> bool:
	return modifier == ChaosModifiers.Modifier.LOUCO_VENCE


## Modificador que vale na rodada que está sendo jogada agora (-1 se nenhum): os de nível
## inteira valem sempre; os de rodada só na rodada sorteada.
func active_modifier() -> int:
	if ChaosModifiers.scope_of(modifier) == ChaosModifiers.Scope.ROUND or trick_number == modifier_trick:
		return modifier
	return -1


## Verdadeiro se `mod` está valendo na rodada atual.
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
## o item pessoal dele (não considera Fôlego/item de nível — esses se aplicam à rodada
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
	return v


func is_final_round() -> bool:
	return round_index >= ROUNDS - 1


## Rodada Invertida: vence a MENOR carta do naipe líder (Trunfo que corta não vale nada).
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


## Se `card`, jogada por `player` agora, venceria a rodada como está (considera Rodada Invertida
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
	var streak_mult := ChaosCombos.streak_mult(int(streak[winner]))
	mult *= streak_mult
	if streak[winner] >= 3:
		combos.append("MAO_QUENTE")
	for cid in ChaosCombos.detect(plays):
		combos.append(cid)
		if cid == "CHUVA_TRUNFOS":
			mult *= ChaosCombos.CHUVA_MULT
		elif cid == "REALEZA":
			mult *= ChaosCombos.REALEZA_MULT
		elif cid == "ESCADA":
			bonus += ChaosCombos.ESCADA_BONUS
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
	combo_count[winner] += combos.size()
	var folego_applied := winner == folego_player
	if folego_applied:
		mult *= FOLEGO_MULT
	if arriscar_on[winner]:
		mult *= ARRISCAR_MULT
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
	var arriscar_loss := 0.0
	for q in range(num_players):
		if q != winner and arriscar_on[q]:
			arriscar_loss += ARRISCAR_LOSS
			totals[q] -= ARRISCAR_LOSS
			round_points[q] -= ARRISCAR_LOSS
	var arriscar_winner: bool = arriscar_on[winner]
	var arriscar_losers: Array = []
	for q in range(num_players):
		if q != winner and arriscar_on[q]:
			arriscar_losers.append(q)
		arriscar_on[q] = false
	var trick_result := {
		"winner": winner,
		"winning_index": idx,
		"plays": plays.duplicate(),
		"points": points,
		"base_points": base_points,
		"mult": mult,
		"folego_applied": folego_applied,
		"arriscar_winner": arriscar_winner,
		"arriscar_losers": arriscar_losers,
		"trick_number": trick_number,
		"modifier": ev,
		"combos": combos,
		"streak": int(streak[winner]),
		"streak_mult": streak_mult,
		"bonus": bonus,
		"saque_amount": saque_amount,
		"assalto_amount": assalto_amount,
		"final": is_final_round(),
	}
	history.append(trick_result)
	round_points[winner] += points + saque_amount + assalto_amount
	totals[winner] += points + saque_amount + assalto_amount
	plays = []
	trick_number += 1
	leader = winner
	current = winner
	trick_resolved.emit(trick_result)
	if is_round_over():
		var bet_results := _settle_bets()
		round_result = {
			"bets": bet_results["items"],
			"pot_info": bet_results,
			"tricks_won": _tricks_won(),
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


func _tricks_won() -> Array:
	var won: Array = []
	for p in range(num_players):
		won.append(0)
	for h in history:
		won[int(h["winner"])] += 1
	return won


## Dificuldade do palpite: prever muitas rodadas paga mais.
static func difficulty_of(predict: int) -> float:
	if predict <= 2:
		return 1.0
	if predict <= 4:
		return 1.5
	return 2.0


func tricks_left() -> int:
	return HAND_SIZE - trick_number


func tricks_won_by(player: int) -> int:
	return int(_tricks_won()[player])


## Pote do nível agora: acumulado dos níveis anteriores + todas as apostas.
func bet_pot() -> float:
	var total := bet_carry
	for p in range(num_players):
		if int(bet_predict[p]) >= 0:
			total += float(bet_stake[p])
	return total


## Menor erro ainda possível no palpite (0 = ainda dá pra acertar exato).
func bet_min_error(player: int) -> int:
	var predict: int = bet_predict[player]
	var won := tricks_won_by(player)
	if won > predict:
		return won - predict
	if won + tricks_left() < predict:
		return predict - (won + tricks_left())
	return 0


## Situação ao vivo do palpite: "none", "on" (no alvo), "chase" (falta ganhar mais),
## "near" (só dá pra errar por 1) ou "bust" (estourou).
func bet_status(player: int) -> String:
	if int(bet_predict[player]) < 0:
		return "none"
	var err := bet_min_error(player)
	if err >= 2:
		return "bust"
	if err == 1:
		return "near"
	return "on" if tricks_won_by(player) == int(bet_predict[player]) else "chase"


## Peso de um jogador na divisão do pote se acertar.
func bet_weight(player: int) -> float:
	var combo_bonus := minf(COMBO_WEIGHT * float(combo_count[player]), COMBO_WEIGHT_MAX)
	return float(bet_stake[player]) * difficulty_of(int(bet_predict[player])) * (1.0 + combo_bonus)


func set_bet(player: int, predict: int, stake: int = 0) -> void:
	if predict < 0 or stake <= 0:
		bet_predict[player] = -1
		bet_stake[player] = 0.0
		return
	bet_predict[player] = clampi(predict, 0, HAND_SIZE)
	bet_stake[player] = float(stake)
	bet_doubled[player] = false


func can_double(player: int) -> bool:
	return int(bet_predict[player]) >= 0 and not bet_doubled[player] \
		and trick_number >= DOUBLE_FROM_TRICK and not is_round_over() and bet_min_error(player) == 0


## Dobra a aposta (e o peso). Devolve as fichas extras que entraram no pote (0 = não deu).
func double_bet(player: int) -> float:
	if not can_double(player):
		return 0.0
	var extra: float = bet_stake[player]
	bet_stake[player] = extra * 2.0
	bet_doubled[player] = true
	return extra


## Acerta o pote ao fim do nível. Cada item: {predict, won, stake, doubled, err, hit,
## refund, share, delta, weight, combos}; `delta` = ganho líquido de fichas (share + refund − stake).
func _settle_bets() -> Dictionary:
	var won := _tricks_won()
	var carry_in := bet_carry
	var total_pot := bet_pot()
	var out: Array = []
	var refunds_total := 0.0
	var hitters: Array = []
	var weight_sum := 0.0
	var best_err := 99
	for p in range(num_players):
		var predict: int = bet_predict[p]
		if predict < 0:
			out.append({"predict": -1, "won": int(won[p]), "stake": 0.0, "doubled": false, "err": 0, "hit": false, "refund": 0.0, "share": 0.0, "delta": 0.0, "weight": 0.0, "combos": int(combo_count[p])})
			continue
		var err := absi(int(won[p]) - predict)
		var stake: float = bet_stake[p]
		var refund := 0.0
		var weight := 0.0
		if err == 0:
			hitters.append(p)
			weight = bet_weight(p)
			weight_sum += weight
		elif err == 1:
			refund = roundf(stake * NEAR_REFUND)
			refunds_total += refund
		best_err = mini(best_err, err)
		out.append({"predict": predict, "won": int(won[p]), "stake": stake, "doubled": bool(bet_doubled[p]), "err": err, "hit": err == 0, "refund": refund, "share": 0.0, "delta": 0.0, "weight": weight, "combos": int(combo_count[p])})
	var pool := total_pot - refunds_total
	var carry_out := 0.0
	var consolation := false
	if pool > 0.0:
		var takers := hitters
		if takers.is_empty() and is_final_round():
			# Último nível sem acerto: o pote vai pros que chegaram mais perto.
			consolation = true
			for p in range(num_players):
				if int(bet_predict[p]) >= 0 and int(out[p]["err"]) == best_err:
					takers.append(p)
					out[p]["weight"] = float(bet_stake[p])
					weight_sum += float(bet_stake[p])
		if takers.is_empty():
			carry_out = pool
		else:
			var paid := 0.0
			var top: int = takers[0]
			for p in takers:
				var sh := floorf(pool * float(out[p]["weight"]) / weight_sum)
				out[p]["share"] = sh
				paid += sh
				if float(out[p]["weight"]) > float(out[top]["weight"]):
					top = p
			out[top]["share"] = float(out[top]["share"]) + (pool - paid)
	for p in range(num_players):
		var o: Dictionary = out[p]
		if int(o["predict"]) < 0:
			continue
		o["delta"] = float(o["share"]) + float(o["refund"]) - float(o["stake"])
		bet_chips[p] += float(o["delta"])
	bet_carry = carry_out
	return {"items": out, "pot": total_pot, "carry_in": carry_in, "carry_out": carry_out, "jackpot": carry_out > 0.0, "consolation": consolation, "hitters": hitters}


## ---- Poderes ---------------------------------------------------------------

func can_use_power(player: int) -> bool:
	return player_items[player] != ChaosItems.Item.NONE and not power_used[player] \
		and current == player and not is_round_over()


## Roubar Trunfo: entrega a carta mais fraca e leva o melhor Trunfo do alvo (ou a melhor
## carta dele se não tiver Trunfo). Retorna {"given", "taken"}.
func use_troca(player: int, target: int) -> Dictionary:
	if not can_use_power(player) or player_items[player] != ChaosItems.Item.TROCA or target == player:
		return {}
	var mine: Array = hands[player]
	var theirs: Array = hands[target]
	var given: CardData = mine[0]
	for c in mine:
		if _swap_worth(c) < _swap_worth(given):
			given = c
	var taken: CardData = theirs[0]
	for c in theirs:
		if _swap_worth(c) > _swap_worth(taken):
			taken = c
	mine.erase(given)
	theirs.erase(taken)
	mine.append(taken)
	theirs.append(given)
	power_used[player] = true
	return {"given": given, "taken": taken}


func _swap_worth(c: CardData) -> float:
	if c.is_louco():
		return 5.0
	return float(c.rank) + (100.0 if c.is_trunfo() else 0.0) + (50.0 if c.is_bout() else 0.0)


func use_espiada(player: int, target: int) -> Array:
	if not can_use_power(player) or player_items[player] != ChaosItems.Item.ESPIADA or target == player:
		return []
	power_used[player] = true
	return (hands[target] as Array).duplicate()


func use_arriscar(player: int) -> bool:
	if not can_use_power(player) or player_items[player] != ChaosItems.Item.ARRISCAR:
		return false
	power_used[player] = true
	arriscar_on[player] = true
	return true


## Chamado pela UI depois de mostrar o resumo do nível, pra sortear/preparar a próxima.
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
