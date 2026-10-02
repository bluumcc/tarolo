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
var modifier_sequence: Array = []  # ordem embaralhada dos 11 modificadores pra esse nível: 1 por vaza
var modifier := -1            # modificador da vaza atual (-1 = ainda não sorteado pra essa vaza)
var weak_suit := -1
var streak: Array = []
var last_winner := -1
var combo_count: Array = []
var hand_no := 0              # rodadas de aposta jogadas na mesa (roda o botão)
var button := 0               # "dealer": fala por último

# Aposta da rodada atual.
var pot := 0.0
## Pote da aposta por rodada — separado do `pot` acima de propósito: no Blitz os dois existem ao
## mesmo tempo (o `pot` é o do palpite do nível inteiro; este é só da rodada atual, zera a cada
## `begin_trick()`). Misturar os dois faria a conta do palpite vazar pra aposta da rodada.
var trick_pot := 0.0
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

# Modo Blitz: palpite de vitórias por nível (em vez de aposta por rodada).
const BLITZ_ENTRY_BLINDS := 8                      # entrada fixa de cada nível, em blinds (20% da stack)
const BLITZ_STREAK_BONUS_BLINDS := 3              # prêmio especial da casa: 3+ acertos seguidos (só você)
const BLITZ_BONUS_VAULT_SHARE := 0.5              # o prêmio só sai de até 50% da taxa que a casa já cobrou de você
const BLITZ_DOUBLE_FROM := 3                       # 1º dobrar a partir da 4ª rodada; o 2º, da 6ª
const BLITZ_MAX_DOUBLES := 2   # dobrar + triplicar (testado remover: derrubava a escada Difícil>Normal — era a maior fonte de vantagem do Difícil, não um enfeite)
const BLITZ_POINT_FACTOR := 0.5                    # pontos das cartas → fichas no Blitz, em relação ao Caos (1 pt = 0,25 blind × fator)
var blitz := false
var doubles: Array = []       # quantas vezes cada um dobrou a entrada nesse nível (0 a 2)
var predicts: Array = []      # palpite de cada um (-1 = ainda não fez)
var stakes: Array = []        # fichas que cada um pôs no pote do nível
var wins: Array = []          # vitórias contadas no nível (Rodada Dobrada conta 2)
var carry := 0.0              # pote acumulado quando ninguém acerta
var bonus_on := true          # prêmio especial de sequência (desligável nos testes)
var hit_streak := 0           # acertos seguidos do jogador 0
var human_bonus := 0.0        # total de prêmios da casa recebidos pelo jogador 0
var blitz_result: Dictionary = {}
var point_factor := BLITZ_POINT_FACTOR   # ajustável (simulação)
var styles: Array = []                  # estilo de cada bot (ChaosBot.Style), fixo enquanto ele estiver na mesa
var onboarding_levels := 0              # níveis restantes sem dobrar/cobrir (Blitz, contas novas — modificador sempre ativo)
const BLITZ_DEAL_SIZE := 10             # recebe 10, descarta 2 (ver DISCARD_SIZE), fica com HAND_SIZE (8)
const BLITZ_DISCARD_SIZE := 2
## Aposta por rodada: cada uma das 8 rodadas tem sua própria mini-aposta (passar/apostar/
## aumentar/desistir), com pote próprio (`trick_pot`) pago a quem vence a rodada — por cima do
## palpite do nível. A ante (o "pontapé" que todo mundo paga só pra rodada acontecer) é uma
## fração do blind, não o blind inteiro: já existe a entrada do palpite pesando por rodada.
const BLITZ_TRICK_ANTE_FACTOR := 0.25

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
	blitz = str(config.get("mode", "chaos")) == "blitz"
	point_factor = float(config.get("point_factor", BLITZ_POINT_FACTOR))
	onboarding_levels = int(config.get("onboarding_levels", 0))
	carry = 0.0
	hit_streak = 0
	human_bonus = 0.0
	if config.has("seed"):
		rng.seed = int(config["seed"])
	else:
		rng.randomize()
	styles = []
	var cfg_styles: Array = config.get("styles", [])
	for p in range(num_players):
		styles.append(int(cfg_styles[p]) if cfg_styles.size() > p else rng.randi_range(0, 2))
	stacks = []
	session_stats = []
	for p in range(num_players):
		stacks.append(float((config.get("stacks", []) as Array)[p]) if (config.get("stacks", []) as Array).size() > p else float(buy_in))
		session_stats.append({"pots": 0, "bluffs": 0, "folds": 0, "hits": 0, "near": 0, "levels": 0})
	round_index = 0
	hand_no = 0
	match_result = {}
	_setup_round()


func _setup_round() -> void:
	var deck := Deck.build(rng)
	# Blitz: recebe 10, descarta 2 antes de qualquer outra decisão (sempre, mesmo na conta nova) —
	# o nível continua tendo HAND_SIZE (8) rodadas, só a mão inicial nasce maior pra escolher.
	var deal_size := BLITZ_DEAL_SIZE if blitz else HAND_SIZE
	var dealt := Deck.deal(deck, num_players, deal_size)
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
	# Embaralha os modificadores: as 8 vazas do nível usam os 8 primeiros, sem repetir. Sempre
	# ativo, mesmo no onboarding — toda mesa de Blitz tem modificador em toda rodada, sem exceção.
	modifier_sequence = (ChaosModifiers.blitz_pool() if blitz else ChaosModifiers.ALL).duplicate()
	Deck.shuffle(modifier_sequence, rng)
	modifier = -1
	weak_suit = -1
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
	predicts = []
	stakes = []
	wins = []
	doubles = []
	blitz_result = {}
	for p in range(num_players):
		predicts.append(-1)
		stakes.append(0.0)
		wins.append(0)
		doubles.append(0)
	if blitz:
		pot = carry


func _highest_player() -> int:
	var highest := 0
	for p in range(1, num_players):
		if stacks[p] > stacks[highest]:
			highest = p
	return highest


## Verdadeiro no modificador "O Louco Vence".
func louco_can_win() -> bool:
	return modifier == ChaosModifiers.Modifier.LOUCO_VENCE


## Sorteia o modificador dessa vaza (o próximo da ordem embaralhada do nível) e, se ele tiver
## naipe-alvo, sorteia o naipe também. Chamado uma vez no começo de cada vaza, antes de
## qualquer decisão (aposta ou palpite) que dependa dele.
func draw_trick_modifier() -> void:
	modifier = modifier_sequence[trick_number]
	weak_suit = -1
	if ChaosModifiers.has_suit(modifier):
		var suits := [CardData.Suit.OUROS, CardData.Suit.PAUS, CardData.Suit.COPAS, CardData.Suit.ESPADAS]
		weak_suit = suits[rng.randi_range(0, suits.size() - 1)]


## Modificador da vaza atual (-1 antes de `draw_trick_modifier` ser chamado).
func active_modifier() -> int:
	return modifier


func is_active(mod: int) -> bool:
	return modifier == mod


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
			styles[p] = rng.randi_range(0, 2)   # jogador novo, estilo novo (sorteado, nunca mostrado)
			swapped.append(p)
	return swapped


## Abre a rodada de apostas: gira o botão, cobra a ante de todos (quem tem menos precisa ter
## sido trocado/recomprado antes) e monta a fila de fala. No Blitz a ante é uma fração do blind
## (a rodada já tem a entrada do palpite pesando; a ante daqui é só o pontapé de cada rodada,
## não outro custo do tamanho da entrada inteira) — escreve em `trick_pot`, separado do `pot`
## do palpite do nível (os dois existem ao mesmo tempo, não podem se misturar).
func begin_trick() -> void:
	trick_pot = 0.0
	raises = 0
	bet_log = []
	hand_no += 1
	button = leader  # aposta começa do jogador após o líder da vaza
	var ante_size := float(blind) * (BLITZ_TRICK_ANTE_FACTOR if blitz else 1.0)
	for p in range(num_players):
		folded[p] = false
		var ante := minf(ante_size, stacks[p])
		contrib[p] = ante
		stacks[p] -= ante
		trick_pot += ante
	bet_level = ante_size
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
		"pot": trick_pot,
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
				# No Blitz o descarte é aleatório (custo fixo, sem entregar qual carta era fraca);
				# no Caos (legado) continua a mais fraca virada.
				_discard_random(player) if blitz else _discard_weakest(player)
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
				trick_pot += amount
		"raise":
			if not opt["can_raise"]:
				return {"ok": false, "error": "sem aumento"}
			var target := clampf(to, float(opt["min_to"]), float(opt["max_to"]))
			amount = target - contrib[player]
			stacks[player] -= amount
			contrib[player] = target
			trick_pot += amount
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


## Blitz: desistir custa exatamente 1 carta aleatória (não a mais fraca) — o custo é o mesmo pra
## todo mundo, sem entregar qual carta era boa ou ruim. As mãos continuam do mesmo tamanho.
func _discard_random(player: int) -> CardData:
	var hand: Array = hands[player]
	if hand.is_empty():
		return null
	var picked: CardData = hand[rng.randi_range(0, hand.size() - 1)]
	hand.erase(picked)
	last_discard = {"player": player, "card": picked}
	return picked


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
	# Ninguém jogou carta: o vencedor também descarta pra todas as mãos ficarem iguais — aleatória
	# no Blitz (mesmo custo de quem desistiu), a mais fraca no Caos (legado).
	var dropped := _discard_random(winner) if blitz else _discard_weakest(winner)
	if blitz:
		var ev := active_modifier()
		var value := 2 if ev == ChaosModifiers.Modifier.VAZA_DOURADA else 1
		wins[winner] += value
		var trick_pot_total := trick_pot
		stacks[winner] += trick_pot_total
		var trick_gain: float = trick_pot_total - float(contrib[winner])
		trick_pot = 0.0
		var result := {
			"discarded": dropped,
			"winner": winner, "winning_index": -1, "plays": [], "points": 0.0, "base_points": 0.0,
			"mult": 1.0, "prize": 0.0, "pot": pot, "combos": [], "streak": 0, "streak_mult": 1.0,
			"bonus": 0.0, "saque_amount": 0.0, "assalto_amount": 0.0, "curse_amount": 0.0,
			"walkover": true, "trick_number": trick_number, "modifier": ev,
			"value": value, "wins": wins.duplicate(), "rake": 0.0, "trick_pot": trick_pot_total, "trick_gain": trick_gain,
			"gain": trick_gain,
		}
		return _finish_trick_blitz(result, winner)
	var result := {
		"discarded": dropped,
		"winner": winner, "winning_index": -1, "plays": [], "points": 0.0, "base_points": 0.0,
		"mult": 1.0, "prize": 0.0, "pot": trick_pot, "combos": [], "streak": 0, "streak_mult": 1.0,
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
		ChaosModifiers.Modifier.FIGURAS_DOBRO:
			if c.rank >= 11 and c.rank <= 14 and not c.is_trunfo():
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
	if ev != ChaosModifiers.Modifier.VAZA_INVERTIDA:
		return TrickRules.would_win(card, player, plays, louco_can_win())
	var trick := plays.duplicate()
	trick.append({"player": player, "card": card})
	return int(trick[_lowest_index(trick)]["player"]) == player


## Pontos das cartas viram fichas (pagas pelos rivais): 1 ponto = PRIZE_PER_POINT blinds.
func chips_of(points: float) -> float:
	return roundf(points * PRIZE_PER_POINT * float(blind))


func _resolve_trick() -> Dictionary:
	var ev := active_modifier()
	var inverted := ev == ChaosModifiers.Modifier.VAZA_INVERTIDA
	var idx := _lowest_index() if inverted else TrickRules.winning_index(plays, louco_can_win())
	var winner: int = plays[idx]["player"]
	var cards: Array = plays.map(func(p): return p["card"])
	captured[winner].append_array(cards)
	if blitz:
		return _resolve_trick_blitz(idx, winner, ev)
	var base_points := 0.0
	for c in cards:
		base_points += card_value(c, winner)
	var mult := 1.0
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
		var cost := minf(-raw_prize, trick_pot)
		var each := floorf(cost / float(rivals.size()))
		for q in rivals:
			stacks[q] += each
		prize = -each * float(rivals.size())
	var result := {
		"winner": winner, "winning_index": idx, "plays": plays.duplicate(), "points": points,
		"base_points": base_points, "mult": mult, "prize": prize, "pot": trick_pot, "combos": combos,
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
		rake = ChaosEconomy.rake_of(trick_pot, blind)
		house_rake += rake
		if contrib[0] > 0.0:
			human_rake += rake * contrib[0] / maxf(trick_pot, 1.0)
	result["rake"] = rake
	stacks[winner] += trick_pot - rake + float(result["prize"]) + float(result["saque_amount"]) + float(result["assalto_amount"])
	session_stats[winner]["pots"] += 1
	result["stacks"] = stacks.duplicate()
	result["gain"] = trick_pot - rake + float(result["prize"]) + float(result["saque_amount"]) + float(result["assalto_amount"]) - contrib[winner]
	trick_pot = 0.0
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
			"stacks": stacks.duplicate(), "deltas": deltas,
			"tricks_won": tricks_won(),
		}
		round_finished.emit(round_result)
		if is_match_over():
			match_result = make_standings()
			match_finished.emit(match_result)
	return result


## Cópia leve do estado do Blitz pra simulação (bots/Oráculo): sem histórico, rng novo.
## As cartas são compartilhadas (imutáveis); os arrays são copiados.
func clone_for_sim() -> ChaosEngine:
	var c := ChaosEngine.new()
	c.num_players = num_players
	c.blind = blind
	c.buy_in = buy_in
	c.levels = levels
	c.blitz = blitz
	c.point_factor = point_factor
	c.styles = styles.duplicate()
	c.onboarding_levels = onboarding_levels
	c.rake_on = rake_on
	c.bonus_on = bonus_on
	c.stacks = stacks.duplicate()
	c.level_start_stacks = level_start_stacks.duplicate()
	c.round_index = round_index
	c.modifier_sequence = modifier_sequence.duplicate()
	c.modifier = modifier
	c.weak_suit = weak_suit
	c.streak = streak.duplicate()
	c.last_winner = last_winner
	c.combo_count = combo_count.duplicate()
	c.hand_no = hand_no
	c.pot = pot
	c.trick_pot = trick_pot
	c.contrib = contrib.duplicate()
	c.folded = folded.duplicate()
	c.bet_level = bet_level
	c.raises = raises
	c.betting = betting
	c.to_act = to_act.duplicate()
	c.doubles = doubles.duplicate()
	c.predicts = predicts.duplicate()
	c.stakes = stakes.duplicate()
	c.wins = wins.duplicate()
	c.carry = carry
	c.hit_streak = hit_streak
	c.human_bonus = human_bonus
	c.house_rake = house_rake
	c.human_rake = human_rake
	c.hands = []
	for h in hands:
		c.hands.append((h as Array).duplicate())
	c.plays = plays.duplicate()
	c.captured = []
	for cp in captured:
		c.captured.append((cp as Array).duplicate())
	c.leader = leader
	c.current = current
	c.trick_number = trick_number
	c.session_stats = []
	for st in session_stats:
		c.session_stats.append((st as Dictionary).duplicate())
	c.rng.seed = rng.randi()
	return c


# ------------------------------------------------------------------ Blitz

## Peso do palpite no pote: palpites altos são mais difíceis e valem mais.
static func blitz_weight(predict: int) -> float:
	if predict >= 5:
		return 2.0
	if predict >= 3:
		return 1.5
	return 1.0


func blitz_entry() -> float:
	return float(BLITZ_ENTRY_BLINDS * blind)


## Palpite (0 a 8) de um jogador; a entrada sai da stack e vai pro pote do nível. Todos os
## palpites são revelados juntos depois.
func blitz_place(player: int, predict: int) -> bool:
	if not blitz or predicts[player] != -1:
		return false
	var amount := minf(blitz_entry(), stacks[player])
	stacks[player] -= amount
	stakes[player] = amount
	pot += amount
	predicts[player] = clampi(predict, 0, HAND_SIZE)
	return true


## Quantas vitórias ainda faltam pro palpite (negativo = já estourou).
func blitz_need(player: int) -> int:
	return int(predicts[player]) - int(wins[player])


## Dobrar: a partir da 4ª rodada (a 2ª vez, da 6ª), só se ainda dá pra acertar. Paga mais uma
## entrada (o peso no pote dobra/triplica junto). No máximo 2 vezes por nível.
func can_double(player: int) -> bool:
	if not can_cover(player):
		return false
	return trick_number >= BLITZ_DOUBLE_FROM + 2 * int(doubles[player])


## Cobrir a dobra/triplicada de um rival: mesmo efeito de `double_down`, mas sem a espera da
## rodada — é uma resposta imediata ao lance de outro jogador.
func can_cover(player: int) -> bool:
	if not blitz or is_round_over() or int(doubles[player]) >= BLITZ_MAX_DOUBLES or onboarding_levels > 0:
		return false
	var need := blitz_need(player)
	return need >= 0 and need <= tricks_left() and stacks[player] >= blitz_entry()


## Verdadeiro se a mão ainda tem cartas de sobra (recebeu 10, ainda não descartou até 8).
func can_discard(player: int) -> bool:
	return blitz and (hands[player] as Array).size() > HAND_SIZE


## Descarta exatamente BLITZ_DISCARD_SIZE cartas (precisam estar na mão, sem repetir). Sempre a
## primeira decisão do nível, antes do palpite e de qualquer modificador — todo mundo decide sem
## ver o que os outros descartaram. Devolve false e não muda nada se a lista for inválida.
func apply_discard(player: int, cards: Array) -> bool:
	if not can_discard(player) or cards.size() != BLITZ_DISCARD_SIZE:
		return false
	var hand: Array = hands[player]
	var idxs: Array = []
	for c in cards:
		var idx := -1
		for i in range(hand.size()):
			if idxs.has(i):
				continue
			if (hand[i] as CardData).equals(c):
				idx = i
				break
		if idx == -1:
			return false
		idxs.append(idx)
	idxs.sort()
	idxs.reverse()
	for i in idxs:
		hand.remove_at(i)
	return true


func _pay_double(player: int) -> void:
	stacks[player] -= blitz_entry()
	stakes[player] += blitz_entry()
	pot += blitz_entry()
	doubles[player] += 1


func double_down(player: int) -> bool:
	if not can_double(player):
		return false
	_pay_double(player)
	return true


func cover_double(player: int) -> bool:
	if not can_cover(player):
		return false
	_pay_double(player)
	return true


func blitz_ready() -> bool:
	for p in range(num_players):
		if predicts[p] == -1:
			return false
	return true


## Situação do palpite de alguém agora: "hit" (no alvo), "short" (falta), "over" (estourou).
func blitz_status(player: int) -> String:
	if wins[player] == predicts[player]:
		return "hit"
	return "short" if wins[player] < predicts[player] else "over"


## No Blitz, só o que muda QUEM vence (Louco Vence/Rodada Invertida, já aplicados antes de
## chegar aqui) e a contagem (Rodada Dourada→Dobrada) importam pro palpite. Saque, Assalto ao
## Líder e Rodada Maldita ainda mexem em fichas de verdade, à parte do palpite — os outros 5
## modificadores não têm efeito nenhum aqui (só valem no Caos).
func _resolve_trick_blitz(idx: int, winner: int, ev: int) -> Dictionary:
	# Rodada Dobrada (Dourada no Blitz) conta 2 vitórias; os pontos NÃO são multiplicados.
	var value := 2 if ev == ChaosModifiers.Modifier.VAZA_DOURADA else 1
	wins[winner] += value
	# Pontos das cartas (já com o modificador) viram fichas pagas pelos rivais, como no Caos, só
	# que num fator menor: o palpite continua sendo o prêmio principal, os pontos são o tempero.
	var base_points := 0.0
	for pl in plays:
		base_points += card_value(pl["card"], winner)
	var raw_prize := roundf(base_points * PRIZE_PER_POINT * float(blind) * point_factor)
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
	var curse_amount := 0.0
	if ev == ChaosModifiers.Modifier.VAZA_MALDITA:
		if not rivals.is_empty():
			var cost := minf(chips_of(CURSE_PENALTY), stacks[winner])
			var each := floorf(cost / float(rivals.size()))
			for q in rivals:
				stacks[q] += each
			curse_amount = each * float(rivals.size())
	# Pote da aposta por rodada: paga pra quem venceu a rodada de cartas, por cima do tempero de
	# pontos acima — o ganho líquido desconta o que o próprio vencedor pôs nessa rodada.
	var trick_pot_total := trick_pot
	stacks[winner] += trick_pot_total
	var trick_gain: float = trick_pot_total - float(contrib[winner])
	trick_pot = 0.0
	stacks[winner] += prize + saque_amount + assalto_amount - curse_amount
	var result := {
		"winner": winner, "winning_index": idx, "plays": plays.duplicate(), "points": base_points,
		"base_points": base_points, "mult": 1.0, "prize": prize, "pot": pot, "combos": [], "streak": 0,
		"streak_mult": 1.0, "bonus": 0.0, "saque_amount": saque_amount, "assalto_amount": assalto_amount,
		"curse_amount": curse_amount, "walkover": false, "trick_number": trick_number, "modifier": ev,
		"value": value, "wins": wins.duplicate(), "rake": 0.0, "trick_pot": trick_pot_total, "trick_gain": trick_gain,
		"gain": prize + saque_amount + assalto_amount - curse_amount + trick_gain,
	}
	return _finish_trick_blitz(result, winner)


func _finish_trick_blitz(result: Dictionary, winner: int) -> Dictionary:
	last_winner = winner
	result["stacks"] = stacks.duplicate()
	history.append(result)
	plays = []
	trick_number += 1
	hand_no += 1
	leader = winner
	current = winner
	if is_round_over():
		blitz_result = _settle_blitz()
		var deltas: Array = []
		for p in range(num_players):
			deltas.append(stacks[p] - level_start_stacks[p])
		round_result = {
			"round": round_index, "modifier": modifier, "weak_suit": weak_suit,
			"stacks": stacks.duplicate(), "deltas": deltas,
			"tricks_won": tricks_won(), "wins": wins.duplicate(), "blitz": blitz_result,
		}
	trick_resolved.emit(result)
	if is_round_over():
		round_finished.emit(round_result)
		if is_match_over():
			match_result = make_standings()
			match_finished.emit(match_result)
	return result


## Fim do nível: acertou o número exato leva o pote (dividido por entrada × dificuldade),
## errou por 1 recebe metade da entrada de volta, errou por 2 ou mais perde a entrada.
## Ninguém acertou: o pote inteiro acumula pro próximo nível.
func _settle_blitz() -> Dictionary:
	var payouts: Array = []
	var refunds: Array = []
	var hits: Array = []
	var near: Array = []
	var weights: Array = []
	var total_w := 0.0
	var pool := pot
	for p in range(num_players):
		payouts.append(0.0)
		refunds.append(0.0)
		weights.append(0.0)
		session_stats[p]["levels"] += 1
		var diff := absi(int(wins[p]) - int(predicts[p]))
		if diff == 0 and float(stakes[p]) > 0.0:
			# (Quem não pôs nada no pote — sem fichas na hora do palpite — não tem o que levar.)
			hits.append(p)
			weights[p] = float(stakes[p]) * blitz_weight(int(predicts[p]))
			total_w += float(weights[p])
			session_stats[p]["hits"] += 1
		elif diff == 1:
			near.append(p)
			refunds[p] = floorf(float(stakes[p]) / 2.0)
			pool -= float(refunds[p])
			session_stats[p]["near"] += 1
	var rake := 0.0
	var carry_out := 0.0
	if hits.is_empty():
		carry_out = pool
	else:
		if rake_on:
			rake = ChaosEconomy.blitz_rake_of(pool, blind)
		var dist := pool - rake
		var paid := 0.0
		var top: int = hits[0]
		for p in hits:
			payouts[p] = floorf(dist * float(weights[p]) / total_w)
			paid += float(payouts[p])
			if float(weights[p]) > float(weights[top]):
				top = p
		payouts[top] += dist - paid
		var total_stakes := 0.0
		for p in range(num_players):
			total_stakes += float(stakes[p])
		house_rake += rake
		human_rake += rake * float(stakes[0]) / maxf(total_stakes, 1.0)
	# Prêmio especial da casa: 3 ou mais acertos seguidos (só você). É pago com a taxa que a casa
	# já cobrou de você (no máximo metade dela), então a casa sempre sai no lucro.
	var bonus := 0.0
	if hits.has(0):
		hit_streak += 1
		if bonus_on and hit_streak >= 3:
			var vault := maxf(human_rake - human_bonus, 0.0) * BLITZ_BONUS_VAULT_SHARE
			bonus = floorf(minf(float(BLITZ_STREAK_BONUS_BLINDS * blind), vault))
			human_bonus += bonus
	else:
		hit_streak = 0
	var net: Array = []
	for p in range(num_players):
		stacks[p] += float(payouts[p]) + float(refunds[p])
		net.append(float(payouts[p]) + float(refunds[p]) - float(stakes[p]))
	stacks[0] += bonus
	net[0] += bonus
	# Multa por erro grosso (≥2 rodadas fora): 2 blinds extras vão pro carry do próximo nível.
	# Quem errou exato já perdeu toda a entrada; quem foi perto (diff=1) perdeu metade — só os
	# erros grandes pagam extra, pra tornar o acerto do palpite mais decisivo.
	var miss_penalty := 0.0
	for p in range(num_players):
		var diff := absi(int(wins[p]) - int(predicts[p]))
		if diff >= 2 and float(stakes[p]) > 0.0:
			var pen := minf(float(blind) * 2.0, stacks[p])
			stacks[p] -= pen
			net[p] -= pen
			miss_penalty += pen
	carry_out += miss_penalty
	var res := {
		"predicts": predicts.duplicate(), "stakes": stakes.duplicate(), "wins": wins.duplicate(), "doubles": doubles.duplicate(),
		"hits": hits, "near": near, "payouts": payouts, "refunds": refunds, "net": net,
		"pool": pool, "rake": rake, "carry_in": carry, "carry_out": carry_out,
		"bonus": bonus, "streak": hit_streak,
	}
	carry = carry_out
	pot = 0.0
	return res


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
	onboarding_levels = maxi(0, onboarding_levels - 1)
	if levels == 0 or round_index < levels:
		_setup_round()


func placement_of(player: int) -> int:
	var order: Array = make_standings()["standings"]
	return order.find(player)
