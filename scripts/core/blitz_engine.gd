class_name BlitzEngine
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
const BUY_IN_BLINDS := BlitzEconomy.BUY_IN_BLINDS    # stack de entrada = 20 blinds
const PRIZE_PER_POINT := 0.25  # cada ponto das cartas vale 0,25 blind, pago pelos rivais
const GOLD_MULT := 3.0       # Transmutação (só no modo antigo de pontos)
const KING_CUT_BONUS := 3.0  # Corte de Rei (pontos)
const BREAK_BONUS := 2.0     # Cortado: quebrar a sequência de 2+ vitórias de alguém

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
var streak: Array = []
var last_winner := -1
var combo_count: Array = []
var hand_no := 0              # rodadas de aposta jogadas na mesa (roda o botão)
var button := 0               # "dealer": fala por último
var start_leader := 0         # quem abre a 1ª rodada (sorteado pela cena; 0 nos testes); as demais sorteiam de novo

# Aposta da rodada atual.
var pot := 0.0
## Pote da aposta por rodada — separado do `pot` acima de propósito: no Blitz os dois existem ao
## mesmo tempo (o `pot` é o do palpite do nível inteiro; este é só da rodada atual, zera a cada
## `begin_trick()`). Misturar os dois faria a conta do palpite vazar pra aposta da rodada.
var trick_pot := 0.0
var contrib: Array = []       # quanto cada um pôs nessa rodada
var folded: Array = []        # desistiu dessa rodada (não joga carta)
var busted: Array = []        # stack zerou: fora do jogo até o fim da mesa
var bet_level := 0.0          # valor que todos precisam igualar
var raises := 0
var last_pots: Array = []     # camadas do último pote da jogada: [{amount, winner, uncalled}] (a UI mostra quando há mais de uma)
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
## Dobrar/triplicar/cobrir o palpite no pote do nível: desligado por enquanto (mistura com as apostas
## da rodada). Os testes ligam pra manter a mecânica coberta.
var doubles_enabled := false
var carry := 0.0              # pote acumulado quando ninguém acerta
var bonus_on := true          # prêmio especial de sequência (desligável nos testes)
var hit_streak := 0           # acertos seguidos do jogador 0
var human_bonus := 0.0        # total de prêmios da casa recebidos pelo jogador 0
var blitz_result: Dictionary = {}
var point_factor := BLITZ_POINT_FACTOR   # ajustável (simulação)
var styles: Array = []                  # estilo de cada bot (BlitzBot.Style), fixo enquanto ele estiver na mesa
const BLITZ_DEAL_SIZE := 10             # recebe 10, descarta 2 (ver DISCARD_SIZE), fica com HAND_SIZE (8)
const BLITZ_DISCARD_SIZE := 2
## Aposta por rodada: cada uma das 8 rodadas tem sua própria mini-aposta (passar/apostar/
## aumentar/desistir), com pote próprio (`trick_pot`) pago a quem vence a rodada — por cima do
## palpite do nível. A ante (o "pontapé" que todo mundo paga só pra rodada acontecer) é uma
## fração do blind, não o blind inteiro: já existe a entrada do palpite pesando por rodada.
const BLITZ_TRICK_ANTE_FACTOR := 0.2

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
	start_leader = int(config.get("start_leader", 0)) % maxi(num_players, 1)
	blitz = str(config.get("mode", "chaos")) == "blitz"
	point_factor = float(config.get("point_factor", BLITZ_POINT_FACTOR))
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
	busted = []
	session_stats = []
	for p in range(num_players):
		stacks.append(float((config.get("stacks", []) as Array)[p]) if (config.get("stacks", []) as Array).size() > p else float(buy_in))
		busted.append(false)
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
	# Embaralha os modificadores: as 8 vazas do nível usam os 8 primeiros, sem repetir. Toda
	# mesa de Blitz tem modificador em toda jogada, sem exceção.
	modifier_sequence = (BlitzModifiers.blitz_pool() if blitz else BlitzModifiers.ALL).duplicate()
	Deck.shuffle(modifier_sequence, rng)
	modifier = -1
	# Dealer: sorteado só no começo da partida (1ª rodada, `start_leader`); depois é sempre o vencedor da
	# última jogada da rodada anterior. Se ele não está mais na mesa (eliminado), passa pro próximo vivo.
	if round_index == 0 or leader < 0:
		leader = start_leader
	else:
		var tries := 0
		while busted[leader] and tries < num_players:
			leader = (leader + 1) % num_players
			tries += 1
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
	return modifier == BlitzModifiers.Modifier.LOUCO_VENCE


## Sorteia o modificador dessa jogada (o próximo da ordem embaralhada do Ritual). Chamado uma vez
## no começo de cada jogada, antes de qualquer decisão (aposta ou profecia) que dependa dele.
func draw_trick_modifier() -> void:
	modifier = modifier_sequence[trick_number]


## Modificador da vaza atual (-1 antes de `draw_trick_modifier` ser chamado).
func active_modifier() -> int:
	return modifier


func is_active(mod: int) -> bool:
	return modifier == mod


func legal_for(player: int) -> Array:
	# Não existe a obrigação de cobrir: qualquer Trunfo serve. No Pitagórico, qualquer carta serve.
	return TrickRules.legal_cards_for(hands[player], plays, false, modifier)


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
		if not folded[p] and not busted[p]:
			out.append(p)
	return out


## Marca como busted todo jogador com stack ≤ 0. Retorna os índices recém-bustados.
## Persiste entre níveis — não é resetado por _setup_round().
## Quem zerou a stack é eliminado, e acabou: o palpite dele deixa de valer (a entrada fica no pote
## como dinheiro morto) — sem isso o eliminado "acertava" o palpite 0, recebia fichas e voltava.
## Quem pagou a entrada e ainda tem ao menos 1 ficha segue jogando em all-in (ante limitada ao que sobrou).
## Torneio, começo da rodada: quem não tem fichas pra pagar a entrada do palpite não pode jogar o nível
## — eliminado antes de pôr qualquer ficha no pote. Devolve quem caiu.
func bust_cant_enter(include_human := true) -> Array:
	var out: Array = []
	for p in range(0 if include_human else 1, num_players):
		if not busted[p] and stacks[p] < blitz_entry():
			busted[p] = true
			out.append(p)
	return out


func bust_broke(include_human := true) -> Array:
	var newly: Array = []
	for p in range(0 if include_human else 1, num_players):
		if not busted[p] and stacks[p] <= 0.0:
			busted[p] = true
			newly.append(p)
	return newly


func active_count() -> int:
	return active_players().size()


## Bots sem fichas pro blind saem e um novo jogador senta com 15 a 30 blinds (varia, como
## gente de verdade). Devolve os assentos trocados.
func refill_bots() -> Array:
	var swapped: Array = []
	for p in range(1, num_players):
		if stacks[p] < blind:
			var fresh := float(rng.randi_range(BlitzEconomy.BOT_STACK_BLINDS[0], BlitzEconomy.BOT_STACK_BLINDS[1]) * blind)
			stacks[p] = fresh
			level_start_stacks[p] = fresh
			streak[p] = 0
			busted[p] = false   # novo jogador senta no lugar do que quebrou
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
	# Todo mundo paga a ante E o blind inteiro antes das ações (torneio e rankeada): o blind é a
	# aposta mínima da jogada. No Blitz a ante é só uma fração do blind e vem somada a ele.
	var ante_size := float(blind) * ((BLITZ_TRICK_ANTE_FACTOR + 1.0) if blitz else 1.0)
	for p in range(num_players):
		folded[p] = busted[p]   # eliminado (torneio) fica fora da jogada: sem ante, sem fala e sem carta
		var ante := minf(ante_size, stacks[p])
		contrib[p] = ante
		stacks[p] -= ante
		trick_pot += ante
	bet_level = ante_size
	to_act = []
	for i in range(1, num_players + 1):
		var q := (button + i) % num_players
		if stacks[q] > 0.0:
			to_act.append(q)
	betting = true
	# Quase todo mundo all-in na ante: ninguém tem o que decidir.
	if to_act.size() <= 1 and _nobody_to_match():
		to_act = []
		betting = false
		_start_trick_play()


func bet_actor() -> int:
	return int(to_act[0]) if betting and not to_act.is_empty() else -1


## Aumentar só faz sentido se algum rival que não desistiu ainda tem fichas pra responder.
func _rival_can_respond(player: int) -> bool:
	for q in range(num_players):
		if q != player and not folded[q] and stacks[q] > 0.0:
			return true
	return false


## Verdadeiro se ninguém além do último que fala tem fichas pra igualar mais nada.
func _nobody_to_match() -> bool:
	var with_chips := 0
	for q in range(num_players):
		if not folded[q] and stacks[q] > 0.0:
			with_chips += 1
	return with_chips <= 1


func to_call(player: int) -> float:
	return minf(maxf(bet_level - contrib[player], 0.0), maxf(stacks[player], 0.0))


## Opções de quem está falando: {can_check, call, can_raise, min_to, max_to, pot, all_in_to}.
## O pagar é limitado à stack (pagar "tudo que tem" é all-in) e o aumento vai até o all-in
## pessoal, limitado só pelo que o rival mais forte ainda consegue cobrir.
func bet_options(player: int) -> Dictionary:
	# No-limit de verdade: dá pra aumentar até o próprio all-in, mesmo que passe do que qualquer rival
	# tem. O que ninguém cobre volta pra quem pôs (ver `_settle_side_pots`).
	var own_max: float = stacks[player] + contrib[player]
	var max_to := own_max
	var call_amt := to_call(player)
	var can_raise: bool = max_to > bet_level and stacks[player] > call_amt and _rival_can_respond(player)
	return {
		"can_check": bet_level - contrib[player] <= 0.0,
		"call": call_amt,
		"can_raise": can_raise,
		"min_to": minf(bet_level + float(blind), max_to),
		"max_to": max_to,
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
			if not folded[q] and stacks[q] > 0.0:
				to_act.append(q)
	if active_count() <= 1:
		to_act = []
	bet_log.append({"player": player, "action": action, "to": bet_level, "amount": amount})
	var done := to_act.is_empty()
	if done:
		betting = false
		_start_trick_play()
	return {"ok": true, "action": action, "to": bet_level, "amount": amount, "done": done}


## Potes paralelos (all-in), como no poker: o que cada um pôs na rodada é fatiado em camadas pelos
## valores de all-in dos que não desistiram. Cada camada (pote principal, depois os laterais) vai
## pro MELHOR jogador entre os que a cobriram (`contrib` ≥ topo da camada). O que ninguém cobriu
## volta pra quem pôs. A parte do `winner` (o melhor de todos) fica em `trick_pot`, que quem chama
## soma à stack dele; as camadas dos outros vencedores já são pagas aqui.
func _settle_side_pots(winner: int) -> void:
	var order := _trick_order(winner)
	var won := 0.0
	last_pots = []
	for layer in pot_layers():
		var taker := winner
		for q in order:
			if (layer["eligible"] as Array).has(q):
				taker = q
				break
		last_pots.append({"amount": float(layer["amount"]), "winner": taker, "uncalled": (layer["eligible"] as Array).size() == 1 and last_pots.size() > 0})
		if taker == winner:
			won += float(layer["amount"])
		else:
			stacks[taker] += float(layer["amount"])
	trick_pot = won


## Camadas do pote da jogada (principal + laterais) pelo que cada um pôs até agora: cada uma tem o
## valor e quem pode ganhá-la (não desistiu e cobriu a camada). Camada com 1 só elegível = sobra que
## ninguém cobriu (volta pra ele). A sobra de quem desistiu acima de todos os níveis entra na última.
func pot_layers() -> Array:
	var levels: Array = []
	for q in range(num_players):
		if not folded[q] and contrib[q] > 0.0 and not levels.has(contrib[q]):
			levels.append(contrib[q])
	levels.sort()
	var layers: Array = []
	var prev := 0.0
	var paid := 0.0
	var total := 0.0
	for q in range(num_players):
		total += contrib[q]
	for lv in levels:
		var slice := 0.0
		var elig: Array = []
		for q in range(num_players):
			slice += minf(contrib[q], lv) - minf(contrib[q], prev)
			if not folded[q] and contrib[q] >= lv:
				elig.append(q)
		layers.append({"amount": slice, "eligible": elig})
		paid += slice
		prev = lv
	if not layers.is_empty() and total - paid > 0.0:
		layers[layers.size() - 1]["amount"] = float(layers[layers.size() - 1]["amount"]) + (total - paid)
	return layers


## Jogadores do melhor pro pior na rodada de cartas, com `winner` sempre primeiro (os demais seguem
## a mesma regra de quem vence, pelo naipe líder; quem não jogou carta — desistiu — fica de fora).
func _trick_order(winner: int) -> Array:
	var out: Array = [winner]
	var rest: Array = plays.filter(func(pl: Dictionary) -> bool: return int(pl["player"]) != winner)
	while not rest.is_empty():
		var i := TrickRules.winning_index_mod(rest, active_modifier())
		if i == -1:
			i = 0   # só sobrou O Louco (sem poder): ordem irrelevante
		out.append(int(rest[i]["player"]))
		rest.remove_at(i)
	for q in range(num_players):   # quem ainda não jogou carta (ordem desconhecida) vem por último
		if not folded[q] and not out.has(q):
			out.append(q)
	return out


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


## Mesa desfeita no meio da rodada (torneio): as jogadas que faltam não são disputadas — não contam
## vitória pra ninguém — e o palpite é conferido com o que já foi jogado. Fecha a rodada na hora.
func void_remaining_tricks() -> void:
	if not blitz or is_round_over():
		return
	plays = []
	betting = false
	to_act = []
	trick_pot = 0.0
	if trick_number == 0:
		# Nenhuma jogada foi disputada: o nível não aconteceu — devolve as entradas do palpite.
		for p in range(num_players):
			stacks[p] += float(stakes[p])
			pot -= float(stakes[p])
			stakes[p] = 0.0
	trick_number = HAND_SIZE
	blitz_result = _settle_blitz()
	var deltas: Array = []
	for p in range(num_players):
		deltas.append(stacks[p] - level_start_stacks[p])
	round_result = {
		"round": round_index, "modifier": modifier,
		"stacks": stacks.duplicate(), "deltas": deltas,
		"tricks_won": tricks_won(), "wins": wins.duplicate(), "blitz": blitz_result,
	}
	round_finished.emit(round_result)
	if is_match_over():
		match_result = make_standings()
		match_finished.emit(match_result)


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
		var value := 2 if ev == BlitzModifiers.Modifier.VAZA_DOURADA else 1
		wins[winner] += value
		_settle_side_pots(winner)
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
			"gain": trick_gain, "pots": last_pots.duplicate(true),
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
	var is_legal := false
	for lc in legal_for(player):
		if (lc as CardData).equals(card):
			is_legal = true
			break
	if not is_legal:
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


## Valor de uma carta em pontos. Nenhum modificador mexe nele.
func card_value(c: CardData, _player: int = -1) -> float:
	return c.points()


## Se `card`, jogada por `player` agora, venceria a jogada como está.
func would_win(card: CardData, player: int) -> bool:
	return TrickRules.would_win_mod(card, player, plays, modifier)


## Pontos das cartas viram fichas (pagas pelos rivais): 1 ponto = PRIZE_PER_POINT blinds.
func chips_of(points: float) -> float:
	return roundf(points * PRIZE_PER_POINT * float(blind))


## Fichas que os modificadores Saque, Assalto e Maldição movem (sempre STEAL_BLINDS blinds no total,
## em qualquer mesa). Tira dos pagadores na hora, devolve o que o vencedor deve receber (Saque e
## Assalto) e já desconta do vencedor o que ele paga (Maldição). Ninguém paga mais do que tem.
func _modifier_chips(ev: int, winner: int, rivals: Array) -> Dictionary:
	var total := float(BlitzModifiers.STEAL_BLINDS * blind)
	var out := {"saque": 0.0, "assalto": 0.0, "assalto_from": -1, "curse": 0.0}
	if ev == BlitzModifiers.Modifier.ASSALTO_LIDER:
		var rich := _richest_rival(winner)
		if rich != -1:
			var take := minf(total, maxf(stacks[rich], 0.0))
			stacks[rich] -= take
			out["assalto"] = take
			out["assalto_from"] = rich
	elif ev == BlitzModifiers.Modifier.SAQUE and not rivals.is_empty():
		var share := ceilf(total / float(rivals.size()))
		for q in rivals:
			var take := minf(share, maxf(stacks[q], 0.0))
			stacks[q] -= take
			out["saque"] = float(out["saque"]) + take
	elif ev == BlitzModifiers.Modifier.VAZA_MALDITA and not rivals.is_empty():
		var cost := minf(total, maxf(stacks[winner], 0.0))
		var each := floorf(cost / float(rivals.size()))
		for q in rivals:
			stacks[q] += each
		out["curse"] = each * float(rivals.size())
		stacks[winner] -= float(out["curse"])
	return out


## Rival com mais fichas (o próprio vencedor não conta: se ele lidera, rouba do segundo). -1 = ninguém tem fichas.
func _richest_rival(winner: int) -> int:
	var best := -1
	for q in range(num_players):
		if q == winner or busted[q] or stacks[q] <= 0.0:
			continue
		if best == -1 or stacks[q] > stacks[best]:
			best = q
	return best


func _resolve_trick() -> Dictionary:
	var ev := active_modifier()
	var idx := TrickRules.winning_index_mod(plays, ev)
	var winner: int = plays[idx]["player"]
	var cards: Array = plays.map(func(p): return p["card"])
	captured[winner].append_array(cards)
	if blitz:
		return _resolve_trick_blitz(idx, winner, ev)
	var base_points := 0.0
	for c in cards:
		base_points += card_value(c, winner)
	var mult := 1.0
	if ev == BlitzModifiers.Modifier.VAZA_DOURADA:
		mult *= GOLD_MULT
	var combos: Array = []
	var bonus := 0.0
	var prev_streak: int = streak[last_winner] if last_winner != -1 else 0
	var broke := last_winner != -1 and last_winner != winner and prev_streak >= 2
	for q in range(num_players):
		streak[q] = streak[q] + 1 if q == winner else 0
	var streak_mult := BlitzCombos.streak_mult(int(streak[winner]))
	mult *= streak_mult
	if streak[winner] >= 3:
		combos.append("MAO_QUENTE")
	for cid in BlitzCombos.detect(plays):
		combos.append(cid)
		if cid == "CHUVA_TRUNFOS":
			mult *= BlitzCombos.CHUVA_MULT
		elif cid == "REALEZA":
			mult *= BlitzCombos.REALEZA_MULT
		elif cid == "ESCADA":
			bonus += BlitzCombos.ESCADA_BONUS
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
	# Prêmio das cartas: pago pelos rivais que jogaram a jogada (soma zero, a casa não cria fichas).
	var rivals: Array = []
	for pl in plays:
		if int(pl["player"]) != winner:
			rivals.append(int(pl["player"]))
	var chips := _modifier_chips(ev, winner, rivals)
	var saque_amount := float(chips["saque"])
	var assalto_amount := float(chips["assalto"])
	var prize := 0.0
	if raw_prize > 0.0 and not rivals.is_empty():
		var share := ceilf(raw_prize / float(rivals.size()))
		for q in rivals:
			var pay := minf(share, stacks[q])
			stacks[q] -= pay
			prize += pay
	var result := {
		"winner": winner, "winning_index": idx, "plays": plays.duplicate(), "points": points,
		"base_points": base_points, "mult": mult, "prize": prize, "pot": trick_pot, "combos": combos,
		"streak": int(streak[winner]), "streak_mult": streak_mult, "bonus": bonus,
		"saque_amount": saque_amount, "assalto_amount": assalto_amount, "curse_amount": float(chips["curse"]),
		"walkover": false, "trick_number": trick_number, "modifier": ev,
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
	_settle_side_pots(winner)
	# Taxa da casa: só quando as cartas foram jogadas (sem disputa, sem taxa).
	var rake := 0.0
	if rake_on and not bool(result.get("walkover", false)):
		rake = BlitzEconomy.rake_of(trick_pot, blind)
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
			"round": round_index, "modifier": modifier,
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
func clone_for_sim() -> BlitzEngine:
	var c := BlitzEngine.new()
	c.num_players = num_players
	c.blind = blind
	c.buy_in = buy_in
	c.levels = levels
	c.blitz = blitz
	c.point_factor = point_factor
	c.styles = styles.duplicate()
	c.rake_on = rake_on
	c.bonus_on = bonus_on
	c.stacks = stacks.duplicate()
	c.level_start_stacks = level_start_stacks.duplicate()
	c.round_index = round_index
	c.modifier_sequence = modifier_sequence.duplicate()
	c.modifier = modifier
	c.streak = streak.duplicate()
	c.last_winner = last_winner
	c.combo_count = combo_count.duplicate()
	c.hand_no = hand_no
	c.pot = pot
	c.trick_pot = trick_pot
	c.contrib = contrib.duplicate()
	c.folded = folded.duplicate()
	c.busted = busted.duplicate()
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
	if not blitz or predicts[player] != -1 or busted[player]:
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
	if not doubles_enabled or not blitz or is_round_over() or int(doubles[player]) >= BLITZ_MAX_DOUBLES:
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
	var value := 2 if ev == BlitzModifiers.Modifier.VAZA_DOURADA else 1
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
	var chips := _modifier_chips(ev, winner, rivals)
	var saque_amount := float(chips["saque"])
	var assalto_amount := float(chips["assalto"])
	var assalto_from := int(chips["assalto_from"])
	var curse_amount := float(chips["curse"])
	# Pote da aposta por rodada: paga pra quem venceu a rodada de cartas, por cima do tempero de
	# pontos acima — o ganho líquido desconta o que o próprio vencedor pôs nessa rodada.
	_settle_side_pots(winner)
	var trick_pot_total := trick_pot
	stacks[winner] += trick_pot_total
	var trick_gain: float = trick_pot_total - float(contrib[winner])
	trick_pot = 0.0
	stacks[winner] += prize + saque_amount + assalto_amount
	var result := {
		"winner": winner, "winning_index": idx, "plays": plays.duplicate(), "points": base_points,
		"base_points": base_points, "mult": 1.0, "prize": prize, "pot": pot, "combos": [], "streak": 0,
		"streak_mult": 1.0, "bonus": 0.0, "saque_amount": saque_amount, "assalto_amount": assalto_amount, "assalto_from": assalto_from,
		"curse_amount": curse_amount, "walkover": false, "trick_number": trick_number, "modifier": ev,
		"value": value, "wins": wins.duplicate(), "rake": 0.0, "trick_pot": trick_pot_total, "trick_gain": trick_gain,
		"gain": prize + saque_amount + assalto_amount - curse_amount + trick_gain, "pots": last_pots.duplicate(true),
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
			"round": round_index, "modifier": modifier,
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
		if busted[p]:
			continue   # eliminado: a entrada fica no pote (dinheiro morto) e o palpite não vale
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
			rake = BlitzEconomy.blitz_rake_of(pool, blind)
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
	# Última rodada da mesa (ex.: torneio, 1 nível por mesa): ninguém acertou e não há "próximo nível" pra
	# receber o acumulado — ele volta pra quem pôs, na proporção da entrada, em vez de sumir.
	var carry_returned := 0.0
	if is_final_round() and carry_out > 0.0:
		var total_in := 0.0
		var top_p := 0
		for p in range(num_players):
			total_in += float(stakes[p])
			if float(stakes[p]) > float(stakes[top_p]):
				top_p = p
		if total_in > 0.0:
			var given := 0.0
			for p in range(num_players):
				var share := floorf(carry_out * float(stakes[p]) / total_in)
				stacks[p] += share
				net[p] += share
				given += share
			stacks[top_p] += carry_out - given
			net[top_p] += carry_out - given
			carry_returned = carry_out
			carry_out = 0.0
	var res := {
		"predicts": predicts.duplicate(), "stakes": stakes.duplicate(), "wins": wins.duplicate(), "doubles": doubles.duplicate(),
		"hits": hits, "near": near, "payouts": payouts, "refunds": refunds, "net": net,
		"pool": pool, "rake": rake, "carry_in": carry, "carry_out": carry_out,
		"bonus": bonus, "streak": hit_streak, "carry_returned": carry_returned,
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
	if levels == 0 or round_index < levels:
		_setup_round()


func placement_of(player: int) -> int:
	var order: Array = make_standings()["standings"]
	return order.find(player)
