class_name ChaosEngine
extends RefCounted
## Estado puro da Mesa Caos: um "poker de rodadas". Cada nível distribui 8 cartas e sorteia
## um modificador. Cada rodada (4 cartas) é uma mão de aposta: todos pagam o blind (ante),
## falam na ordem do botão (passar, aumentar, pagar ou desistir) e só quem ficou joga carta.
## Quem leva a rodada leva o pote, mais um bônus pago pelos rivais pelas cartas, modificadores e
## combos. O placar é a stack de fichas de cada um. A mesa não tem fim: cada nível novo
## redistribui as cartas e sorteia outro modificador.

signal trick_resolved(result: Dictionary)
signal round_finished(result: Dictionary)
signal match_finished(result: Dictionary)

const HAND_SIZE := 8
const ROUNDS := 5            # níveis de uma partida com fim (config "levels"); 0 = mesa sem fim
const BLIND := 10
const BUY_IN_BLINDS := ChaosEconomy.BUY_IN_BLINDS    # stack de entrada = 20 blinds
const MAX_RAISES := 2        # aumentos por rodada
const PRIZE_PER_POINT := 0.25  # cada ponto das cartas vale 0,25 blind, pago pelos rivais
const GOLD_MULT := 3.0       # Rodada Dourada
const KING_CUT_BONUS := 3.0  # Corte de Rei (pontos)
const BREAK_BONUS := 2.0     # Cortado: quebrar a sequência de 2+ vitórias de alguém
const SAQUE_AMOUNT := 2.0    # pontos roubados de cada rival no Saque
const ASSALTO_AMOUNT := 4.0  # pontos roubados de quem tem a maior stack
const CURSE_PENALTY := 3.0   # pontos que quem vence a Rodada Maldita paga aos rivais
const FORTE_MULT := 1.5      # Naipe Forte
const VAZA_PLUS := 1.0       # bônus fixo de Cada Rodada Vale +1
const NAIPE_CURSED_VALUE := -1.0  # valor de cada carta do Naipe Maldito

var num_players := 4
var rng := RandomNumberGenerator.new()

var blind := BLIND
var buy_in := BLIND * BUY_IN_BLINDS
var levels := 0               # 0 = sem fim
var stacks: Array = []        # fichas de cada jogador na mesa
var level_start_stacks: Array = []
var round_index := 0          # nível atual (0-based)
var modifier_sequence: Array = []
var modifier := -1
var weak_suit := -1
var modifier_trick := -1
var streak: Array = []
var last_winner := -1
var combo_count: Array = []
var hand_no := 0              # rodadas de aposta jogadas na mesa (roda o botão)
var button := 0               # "dealer": fala por último

# Aposta da rodada atual.
var pot := 0.0
var contrib: Array = []       # quanto cada um pôs nessa rodada
var folded: Array = []        # desistiu dessa rodada (não joga carta)
var bet_level := 0.0          # valor que todos precisam igualar
var raises := 0
var to_act: Array = []        # fila de quem ainda precisa falar
var bet_log: Array = []       # [{player, action, to, amount}]
var betting := false
var last_discard: Dictionary = {}
var rake_on := true            # taxa da casa (desligável nos testes de lógica)
var house_rake := 0.0          # total cobrado pela casa na mesa
var human_rake := 0.0          # quanto do total saiu de fichas do jogador 0   # {player, card} do último descarte por desistência

var hands: Array = []
var plays: Array = []
var captured: Array = []
var leader := -1
var current := -1
var trick_number := 0
var history: Array = []
var round_result: Dictionary = {}
var match_result: Dictionary = {}
var session_stats: Array = []   # por jogador: {pots, bluffs, folds}


## config: { players, seed, blind, buy_in, levels, stacks }
func setup_match(config: Dictionary) -> void:
	num_players = int(config.get("players", 4))
	blind = int(config.get("blind", BLIND))
	buy_in = int(config.get("buy_in", blind * BUY_IN_BLINDS))
	levels = int(config.get("levels", 0))
	if config.has("seed"):
		rng.seed = int(config["seed"])
	else:
		rng.randomize()
	stacks = []
	session_stats = []
	for p in range(num_players):
		stacks.append(float((config.get("stacks", []) as Array)[p]) if (config.get("stacks", []) as Array).size() > p else float(buy_in))
		session_stats.append({"pots": 0, "bluffs": 0, "folds": 0})
	round_index = 0
	hand_no = 0
	match_result = {}
	modifier_sequence = ChaosModifiers.ALL.duplicate()
	Deck.shuffle(modifier_sequence, rng)
	_setup_round()


func _setup_round() -> void:
	var deck := Deck.build(rng)
	var dealt := Deck.deal(deck, num_players, HAND_SIZE)
	hands = dealt["hands"]
	captured = []
	combo_count = []
	streak = []
	last_winner = -1
	level_start_stacks = stacks.duplicate()
	for p in range(num_players):
		streak.append(0)
		captured.append([])
		combo_count.append(0)
	if round_index > 0 and round_index % modifier_sequence.size() == 0:
		Deck.shuffle(modifier_sequence, rng)
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
	leader = round_index % num_players
	current = leader
	trick_number = 0
	plays = []
	history = []
	round_result = {}
	pot = 0.0
	betting = false
	contrib = []
	folded = []
	for p in range(num_players):
		contrib.append(0.0)
		folded.append(false)


func _highest_player() -> int:
	var highest := 0
	for p in range(1, num_players):
		if stacks[p] > stacks[highest]:
			highest = p
	return highest


## Verdadeiro no modificador "O Louco Vence".
func louco_can_win() -> bool:
	return modifier == ChaosModifiers.Modifier.LOUCO_VENCE


## Modificador que vale na rodada que está sendo jogada agora (-1 se nenhum).
func active_modifier() -> int:
	if ChaosModifiers.scope_of(modifier) == ChaosModifiers.Scope.ROUND or trick_number == modifier_trick:
		return modifier
	return -1


func is_active(mod: int) -> bool:
	return active_modifier() == mod


func legal_for(player: int) -> Array:
	# No Caos não existe a obrigação de cobrir: qualquer Trunfo serve.
	return TrickRules.legal_cards(hands[player], plays, false)


func is_round_over() -> bool:
	return trick_number >= HAND_SIZE


func is_match_over() -> bool:
	return levels > 0 and round_index >= levels - 1 and is_round_over()


func is_final_round() -> bool:
	return levels > 0 and round_index >= levels - 1


# ------------------------------------------------------------------ aposta

func active_players() -> Array:
	var out: Array = []
	for p in range(num_players):
		if not folded[p]:
			out.append(p)
	return out


func active_count() -> int:
	return active_players().size()


## Bots sem fichas pro blind saem e um novo jogador senta com 15 a 30 blinds (varia, como
## gente de verdade). Devolve os assentos trocados.
func refill_bots() -> Array:
	var swapped: Array = []
	for p in range(1, num_players):
		if stacks[p] < blind:
			var fresh := float(rng.randi_range(ChaosEconomy.BOT_STACK_BLINDS[0], ChaosEconomy.BOT_STACK_BLINDS[1]) * blind)
			stacks[p] = fresh
			level_start_stacks[p] = fresh
			streak[p] = 0
			swapped.append(p)
	return swapped


## Abre a rodada de apostas: gira o botão, cobra o blind de todos (quem tem menos que o
## blind precisa ter sido trocado/recomprado antes) e monta a fila de fala.
func begin_trick() -> void:
	pot = 0.0
	raises = 0
	bet_log = []
	hand_no += 1
	button = hand_no % num_players
	for p in range(num_players):
		folded[p] = false
		var ante := minf(float(blind), stacks[p])
		contrib[p] = ante
		stacks[p] -= ante
		pot += ante
	bet_level = float(blind)
	to_act = []
	for i in range(1, num_players + 1):
		to_act.append((button + i) % num_players)
	betting = true


func bet_actor() -> int:
	return int(to_act[0]) if betting and not to_act.is_empty() else -1


## Máximo que todo mundo ainda na rodada consegue cobrir (sem potes paralelos).
func bet_cap() -> float:
	var cap := INF
	for p in range(num_players):
		if not folded[p]:
			cap = minf(cap, stacks[p] + contrib[p])
	return cap


func to_call(player: int) -> float:
	return maxf(bet_level - contrib[player], 0.0)


## Opções de quem está falando: {can_check, call, can_raise, min_to, max_to, pot}.
func bet_options(player: int) -> Dictionary:
	var cap := bet_cap()
	var call_amt := to_call(player)
	var can_raise := raises < MAX_RAISES and cap > bet_level
	return {
		"can_check": call_amt <= 0.0,
		"call": call_amt,
		"can_raise": can_raise,
		"min_to": minf(bet_level + float(blind), cap),
		"max_to": cap,
		"pot": pot,
	}


## Fala do jogador: action = "check" | "call" | "raise" | "fold". `to` = valor total da
## aposta dele na rodada quando aumenta. Devolve {ok, action, to, amount, done}.
func bet_act(player: int, action: String, to := 0.0) -> Dictionary:
	if not betting or bet_actor() != player:
		return {"ok": false, "error": "fora de turno"}
	var opt := bet_options(player)
	var amount := 0.0
	match action:
		"fold":
			if opt["can_check"]:
				# Desistir sem precisar não faz sentido: vira passar.
				action = "check"
			else:
				folded[player] = true
				session_stats[player]["folds"] += 1
				_discard_weakest(player)
		"check":
			if not opt["can_check"]:
				return {"ok": false, "error": "precisa pagar"}
		"call":
			if opt["can_check"]:
				action = "check"
			else:
				amount = float(opt["call"])
				stacks[player] -= amount
				contrib[player] += amount
				pot += amount
		"raise":
			if not opt["can_raise"]:
				return {"ok": false, "error": "sem aumento"}
			var target := clampf(to, float(opt["min_to"]), float(opt["max_to"]))
			amount = target - contrib[player]
			stacks[player] -= amount
			contrib[player] = target
			pot += amount
			bet_level = target
			raises += 1
			to = target
		_:
			return {"ok": false, "error": "ação inválida"}
	to_act.pop_front()
	if action == "raise":
		# Todo mundo ainda na rodada (menos quem aumentou) precisa responder.
		to_act = []
		for i in range(1, num_players):
			var q := (player + i) % num_players
			if not folded[q]:
				to_act.append(q)
	if active_count() <= 1:
		to_act = []
	bet_log.append({"player": player, "action": action, "to": bet_level, "amount": amount})
	var done := to_act.is_empty()
	if done:
		betting = false
		_start_trick_play()
	return {"ok": true, "action": action, "to": bet_level, "amount": amount, "done": done}


## Quem desiste descarta a carta mais fraca (virada): as mãos continuam do mesmo tamanho.
func _discard_weakest(player: int) -> CardData:
	var hand: Array = hands[player]
	if hand.is_empty():
		return null
	var worst: CardData = hand[0]
	for c in hand:
		if _card_worth(c) < _card_worth(worst):
			worst = c
	hand.erase(worst)
	last_discard = {"player": player, "card": worst}
	return worst


func _card_worth(c: CardData) -> float:
	if c.is_louco():
		return 60.0 if louco_can_win() else 5.0
	return float(c.rank) + (100.0 if c.is_trunfo() else 0.0) + (50.0 if c.is_bout() else 0.0)


## Depois da aposta: define quem abre as cartas (o vencedor anterior; se ele desistiu, o próximo).
func _start_trick_play() -> void:
	plays = []
	if active_count() <= 1:
		return
	var l := leader
	while folded[l]:
		l = (l + 1) % num_players
	current = l


## Sobrou só um na rodada: ele leva o pote sem jogar carta.
func walkover_player() -> int:
	if betting or active_count() != 1:
		return -1
	return int(active_players()[0])


func resolve_walkover() -> Dictionary:
	var winner := walkover_player()
	if winner == -1:
		return {}
	session_stats[winner]["bluffs"] += 1
	# Ninguém jogou carta: o vencedor também descarta a mais fraca pra todas as mãos ficarem iguais.
	var dropped := _discard_weakest(winner)
	var result := {
		"discarded": dropped,
		"winner": winner, "winning_index": -1, "plays": [], "points": 0.0, "base_points": 0.0,
		"mult": 1.0, "prize": 0.0, "pot": pot, "combos": [], "streak": 0, "streak_mult": 1.0,
		"bonus": 0.0, "saque_amount": 0.0, "assalto_amount": 0.0, "walkover": true,
		"trick_number": trick_number, "modifier": active_modifier(),
	}
	return _finish_trick(result, winner)


# ------------------------------------------------------------------ cartas

func play(player: int, card: CardData) -> Dictionary:
	if betting or player != current or is_round_over() or folded[player]:
		return {"ok": false, "error": "fora de turno"}
	var hand: Array = hands[player]
	if not TrickRules.is_legal(card, hand, plays, false):
		return {"ok": false, "error": "jogada ilegal"}
	hand.erase(card)
	plays.append({"player": player, "card": card})
	if plays.size() < active_count():
		var n := (current + 1) % num_players
		while folded[n]:
			n = (n + 1) % num_players
		current = n
		return {"ok": true, "trick_complete": false}
	return {"ok": true, "trick_complete": true, "result": _resolve_trick()}


## Valor de uma carta já considerando o modificador ativo.
func card_value(c: CardData, _player: int = -1) -> float:
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


## Se `card`, jogada por `player` agora, venceria a rodada como está.
func would_win(card: CardData, player: int) -> bool:
	var ev := active_modifier()
	if ev != ChaosModifiers.Modifier.MUNDO_CONTRARIO and ev != ChaosModifiers.Modifier.VAZA_INVERTIDA:
		return TrickRules.would_win(card, player, plays, louco_can_win())
	var trick := plays.duplicate()
	trick.append({"player": player, "card": card})
	return int(trick[_lowest_index(trick)]["player"]) == player


## Pontos das cartas viram fichas (pagas pelos rivais): 1 ponto = PRIZE_PER_POINT blinds.
func chips_of(points: float) -> float:
	return roundf(points * PRIZE_PER_POINT * float(blind))


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
	combo_count[winner] += combos.size()
	var points := base_points * mult + bonus
	var raw_prize := chips_of(points)
	var saque_amount := 0.0
	var assalto_amount := 0.0
	if ev == ChaosModifiers.Modifier.ASSALTO_LIDER:
		var rich := _highest_player()
		if rich != winner:
			assalto_amount = minf(chips_of(ASSALTO_AMOUNT), stacks[rich])
			stacks[rich] -= assalto_amount
	if ev == ChaosModifiers.Modifier.SAQUE:
		for pl in plays:
			var q: int = pl["player"]
			if q == winner:
				continue
			var take := minf(chips_of(SAQUE_AMOUNT), stacks[q])
			stacks[q] -= take
			saque_amount += take
	# Prêmio das cartas: pago pelos rivais que jogaram a rodada (soma zero, a casa não cria
	# fichas). Prêmio negativo (Rodada Maldita): o vencedor paga aos rivais, saindo do pote.
	var rivals: Array = []
	for pl in plays:
		if int(pl["player"]) != winner:
			rivals.append(int(pl["player"]))
	var prize := 0.0
	if raw_prize > 0.0 and not rivals.is_empty():
		var share := ceilf(raw_prize / float(rivals.size()))
		for q in rivals:
			var pay := minf(share, stacks[q])
			stacks[q] -= pay
			prize += pay
	elif raw_prize < 0.0 and not rivals.is_empty():
		var cost := minf(-raw_prize, pot)
		var each := floorf(cost / float(rivals.size()))
		for q in rivals:
			stacks[q] += each
		prize = -each * float(rivals.size())
	var result := {
		"winner": winner, "winning_index": idx, "plays": plays.duplicate(), "points": points,
		"base_points": base_points, "mult": mult, "prize": prize, "pot": pot, "combos": combos,
		"streak": int(streak[winner]), "streak_mult": streak_mult, "bonus": bonus,
		"saque_amount": saque_amount, "assalto_amount": assalto_amount, "walkover": false,
		"trick_number": trick_number, "modifier": ev,
	}
	return _finish_trick(result, winner)


## Paga o pote (menos a taxa da casa) e o bônus dos rivais ao vencedor, fecha a rodada e, no fim do nível, o resultado.
func _finish_trick(result: Dictionary, winner: int) -> Dictionary:
	if bool(result.get("walkover", false)):
		var prev_streak: int = streak[last_winner] if last_winner != -1 else 0
		for q in range(num_players):
			streak[q] = streak[q] + 1 if q == winner else 0
		result["streak"] = int(streak[winner])
		result["broke"] = last_winner != -1 and last_winner != winner and prev_streak >= 2
	last_winner = winner
	# Taxa da casa: só quando as cartas foram jogadas (sem disputa, sem taxa).
	var rake := 0.0
	if rake_on and not bool(result.get("walkover", false)):
		rake = ChaosEconomy.rake_of(pot, blind)
		house_rake += rake
		if contrib[0] > 0.0:
			human_rake += rake * contrib[0] / maxf(pot, 1.0)
	result["rake"] = rake
	stacks[winner] += pot - rake + float(result["prize"]) + float(result["saque_amount"]) + float(result["assalto_amount"])
	session_stats[winner]["pots"] += 1
	result["stacks"] = stacks.duplicate()
	result["gain"] = pot - rake + float(result["prize"]) + float(result["saque_amount"]) + float(result["assalto_amount"]) - contrib[winner]
	pot = 0.0
	history.append(result)
	plays = []
	trick_number += 1
	leader = winner
	current = winner
	trick_resolved.emit(result)
	if is_round_over():
		var deltas: Array = []
		for p in range(num_players):
			deltas.append(stacks[p] - level_start_stacks[p])
		round_result = {
			"round": round_index, "modifier": modifier, "weak_suit": weak_suit,
			"modifier_trick": modifier_trick, "stacks": stacks.duplicate(), "deltas": deltas,
			"tricks_won": tricks_won(),
		}
		round_finished.emit(round_result)
		if is_match_over():
			match_result = make_standings()
			match_finished.emit(match_result)
	return result


func make_standings() -> Dictionary:
	var order := range(num_players)
	order.sort_custom(func(a: int, b: int) -> bool: return stacks[a] > stacks[b])
	return {"stacks": stacks.duplicate(), "standings": order}


func tricks_won() -> Array:
	var won: Array = []
	for p in range(num_players):
		won.append(0)
	for h in history:
		won[int(h["winner"])] += 1
	return won


func tricks_left() -> int:
	return HAND_SIZE - trick_number


func tricks_won_by(player: int) -> int:
	return int(tricks_won()[player])


## Chamado pela UI depois do resumo do nível: distribui o próximo (a mesa não acaba).
func advance_round() -> void:
	round_index += 1
	if levels == 0 or round_index < levels:
		_setup_round()


func placement_of(player: int) -> int:
	var order: Array = make_standings()["standings"]
	return order.find(player)
