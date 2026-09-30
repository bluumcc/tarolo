class_name ChaosBot
extends RefCounted
## IA dos bots da Mesa Caos: escolhem a carta (ciente do modificador) e decidem as apostas
## (passar, aumentar, pagar, desistir) pela força da mão, com blefe nos níveis difíceis.


## Dificuldade só de simulação: o Difícil ANTIGO do Blitz (joga só pelo palpite, ignora os pontos
## das cartas) — serve de régua pra medir quanto jogar os pontos rende.
const LEGACY := 99
## Quanto vale, em blinds, fechar o palpite exato (aproximado: fatia esperada do pote).
const HIT_VALUE_BLINDS := 6.0
## Pontos médios de uma carta que ainda vai cair na mesa (pra estimar o tamanho do prêmio).
const AVG_CARD_POINTS := 1.4


static func choose(engine: ChaosEngine, player: int, difficulty: int, rng: RandomNumberGenerator) -> CardData:
	var legal: Array = engine.legal_for(player)
	if legal.size() == 1:
		return legal[0]
	if engine.blitz and difficulty != LEGACY:
		return _blitz_choose(engine, player, difficulty, rng)
	if difficulty == LEGACY:
		difficulty = BotAI.Difficulty.HARD
	if difficulty == BotAI.Difficulty.EASY:
		return legal[rng.randi_range(0, legal.size() - 1)]
	if difficulty == BotAI.Difficulty.NORMAL and rng.randf() < 0.15:
		return legal[rng.randi_range(0, legal.size() - 1)]

	var ev := engine.active_modifier()
	var inverted := ev == ChaosModifiers.Modifier.VAZA_INVERTIDA
	var mods := ChaosModifiers.Modifier
	# Quer perder a rodada? (Rodada Maldita, ou Assalto ao Líder sendo ele o líder não muda nada.)
	var want_lose := ev == mods.VAZA_MALDITA
	# Aposta alta: vale gastar a carta mais forte pra garantir.
	var high_stakes := ev in [mods.VAZA_DOURADA, mods.SAQUE] \
		or (ev == mods.ASSALTO_LIDER and player == engine._highest_player()) \
		or engine.pot > float(engine.blind) * 8.0
	var blitz_win := false
	if engine.blitz:
		# Blitz: joga pra fechar o palpite. Já no alvo (ou estourou) foge das rodadas; se falta,
		# tenta ganhar na proporção do que falta pelas rodadas que restam.
		high_stakes = false
		var need := int(engine.predicts[player]) - int(engine.wins[player])
		var left := engine.tricks_left()
		blitz_win = need > 0 and (need >= left or rng.randf() < float(need) / float(left))
		want_lose = not blitz_win
		high_stakes = blitz_win and need >= left

	var is_last := engine.plays.size() == engine.active_count() - 1
	var winners: Array = legal.filter(func(c: CardData) -> bool: return engine.would_win(c, player))
	var losers: Array = legal.filter(func(c: CardData) -> bool: return not engine.would_win(c, player))

	if want_lose:
		if not losers.is_empty():
			# Blitz: perder com a carta mais forte que ainda perde (descarta força embaixo de uma
			# carta maior) evita ser obrigado a vencer mais tarde.
			if engine.blitz and not engine.plays.is_empty() and (difficulty == BotAI.Difficulty.HARD or rng.randf() < 0.4):
				return _strongest_loser(losers)
			return _cheapest(engine, losers, player)
		return _cheapest(engine, winners, player)

	if not engine.plays.is_empty() and not winners.is_empty():
		# Cartas do naipe maldito somam negativo na própria rodada: evita usá-las pra vencer.
		var clean: Array = winners.filter(func(c: CardData) -> bool: return engine.card_value(c, player) >= 0.0)
		var pool: Array = clean if not clean.is_empty() else winners
		pool.sort_custom(func(a: CardData, b: CardData) -> bool: return a.rank < b.rank)
		# Invertido: o mais seguro é a menor carta; normal: a maior.
		if is_last or (not high_stakes and not inverted and pool.size() > 1 and _trick_value(engine) < 1.0):
			return pool[0]
		return pool[0] if inverted else pool[pool.size() - 1]

	if engine.blitz and blitz_win and engine.plays.is_empty() and not inverted:
		var strong: Array = legal.filter(func(c: CardData) -> bool: return not c.is_louco())
		if not strong.is_empty():
			strong.sort_custom(func(a: CardData, b: CardData) -> bool:
				if a.is_trunfo() != b.is_trunfo():
					return a.is_trunfo()
				return a.rank > b.rank)
			return strong[0]

	if not engine.blitz and engine.plays.is_empty() and not inverted and engine.pot > float(engine.blind) * float(engine.active_count()) * 1.2:
		# Rodada aumentada: abre com a carta mais forte pra defender o pote.
		var power: Array = legal.filter(func(c: CardData) -> bool: return not c.is_louco() and engine.card_value(c, player) >= 0.0)
		if not power.is_empty():
			power.sort_custom(func(a: CardData, b: CardData) -> bool:
				if a.is_trunfo() != b.is_trunfo():
					return a.is_trunfo()
				return a.rank > b.rank)
			return power[0]

	if engine.plays.is_empty():
		var lead_pool: Array = legal.filter(func(c: CardData) -> bool: return not c.is_louco() and not c.is_bout() and engine.card_value(c, player) >= 0.0)
		if lead_pool.is_empty():
			lead_pool = legal
		if inverted or ev == mods.VAZA_MALDITA:
			lead_pool.sort_custom(func(a: CardData, b: CardData) -> bool: return a.rank < b.rank)
			return lead_pool[0]
		var safe: Array = lead_pool.filter(func(c: CardData) -> bool: return not c.is_trunfo())
		if not safe.is_empty():
			lead_pool = safe
		lead_pool.sort_custom(func(a: CardData, b: CardData) -> bool: return a.rank < b.rank)
		return lead_pool[0]

	# Não dá pra vencer: descarta a carta menos valiosa (cartas amaldiçoadas primeiro).
	return _cheapest(engine, losers if not losers.is_empty() else legal, player)


static func _trick_value(engine: ChaosEngine) -> float:
	var v := 0.0
	for p in engine.plays:
		v += engine.card_value(p["card"])
	return v


static func _strongest_loser(cards: Array) -> CardData:
	var pool: Array = cards.filter(func(c: CardData) -> bool: return not c.is_louco())
	if pool.is_empty():
		pool = cards
	pool.sort_custom(func(a: CardData, b: CardData) -> bool:
		if a.is_trunfo() != b.is_trunfo():
			return a.is_trunfo()
		return a.rank > b.rank)
	return pool[0]


## Carta mais barata de perder: menor valor (naipe maldito = -1 sai primeiro), sem Bouts.
static func _cheapest(engine: ChaosEngine, cards: Array, player: int) -> CardData:
	var pool: Array = cards.filter(func(c: CardData) -> bool: return not c.is_bout())
	if pool.is_empty():
		pool = cards
	pool.sort_custom(func(a: CardData, b: CardData) -> bool:
		var va := engine.card_value(a, player)
		var vb := engine.card_value(b, player)
		if not is_equal_approx(va, vb):
			return va < vb
		return a.rank < b.rank)
	return pool[0]


## Força da mão pra essa rodada, de 0 a 1 (mistura as duas melhores cartas: o naipe que abre
## a rodada pode obrigar a jogar uma carta menor).
static func hand_strength(engine: ChaosEngine, player: int) -> float:
	var ev := engine.active_modifier()
	var inverted := ev == ChaosModifiers.Modifier.VAZA_INVERTIDA
	var powers: Array = []
	for c in engine.hands[player]:
		powers.append(_card_power(engine, c, inverted))
	if powers.is_empty():
		return 0.0
	powers.sort()
	powers.reverse()
	var second: float = powers[1] if powers.size() > 1 else powers[0]
	return 0.6 * float(powers[0]) + 0.4 * second


## Poder de uma carta (0 a 1) considerando as regras do nível.
static func _card_power(engine: ChaosEngine, card: CardData, inverted: bool) -> float:
	if card.is_louco():
		return 0.05 if inverted else (0.85 if engine.louco_can_win() else 0.05)
	if inverted:
		return 0.1 if card.is_trunfo() else 1.0 - float(card.rank) / 14.0 * 0.85
	if card.is_trunfo():
		return 0.5 + 0.5 * float(card.rank) / 21.0
	if card.rank == 14:
		return 0.55
	if card.rank == 13:
		return 0.4
	if card.rank == 12:
		return 0.3
	if card.rank == 11:
		return 0.25
	return float(card.rank) / 14.0 * 0.2


## Chance estimada de levar a rodada (0 a 1).
static func win_chance(engine: ChaosEngine, player: int, difficulty: int, rng: RandomNumberGenerator) -> float:
	var s := hand_strength(engine, player)
	var noise := 0.22 if difficulty == BotAI.Difficulty.EASY else (0.1 if difficulty == BotAI.Difficulty.NORMAL else 0.04)
	s += rng.randf_range(-noise, noise)
	var p := 0.05 + 0.75 * s * s
	# Menos rivais na rodada = mais chance.
	p *= 1.0 + 0.3 * float(engine.num_players - engine.active_count())
	return clampf(p, 0.02, 0.95)


## Decisão de aposta do bot: {action, to, bluff}. `bluff` = aumentou sem mão.
static func bet_decision(engine: ChaosEngine, player: int, difficulty: int, rng: RandomNumberGenerator) -> Dictionary:
	var opt := engine.bet_options(player)
	var pwin := win_chance(engine, player, difficulty, rng)
	var bluff_rate := 0.0
	var raise_rate := 0.35
	var call_margin := 1.0
	if difficulty == BotAI.Difficulty.NORMAL:
		bluff_rate = 0.06
		raise_rate = 0.55
		call_margin = 1.1
	elif difficulty == BotAI.Difficulty.HARD:
		bluff_rate = 0.14
		raise_rate = 0.7
		call_margin = 1.2
	var strong := pwin >= 0.5
	var bluffing := not strong and rng.randf() < bluff_rate
	if bluffing and not opt["can_raise"]:
		bluffing = false
	var want_raise: bool = bool(opt["can_raise"]) and (bluffing or (strong and rng.randf() < raise_rate))
	if want_raise:
		var blind := float(engine.blind)
		var steps := 1
		if pwin >= 0.75 or bluffing:
			steps = rng.randi_range(2, 3)
		elif pwin >= 0.5:
			steps = rng.randi_range(1, 2)
		var to := float(engine.bet_level) + blind * float(steps)
		to = clampf(to, float(opt["min_to"]), float(opt["max_to"]))
		if pwin >= 0.92 and rng.randf() < 0.1:
			to = float(opt["max_to"])
		# Sem stack pra sustentar o blefe: não vai.
		if bluffing and to > float(engine.stacks[player]) * 0.5 + float(engine.contrib[player]):
			to = float(opt["min_to"])
		return {"action": "raise", "to": to, "bluff": bluffing and not strong}
	if opt["can_check"]:
		return {"action": "check", "to": 0.0, "bluff": false}
	var call_amt: float = opt["call"]
	var odds := call_amt / (float(opt["pot"]) + call_amt)
	if pwin > odds * call_margin or (bluffing and rng.randf() < 0.5):
		return {"action": "call", "to": 0.0, "bluff": false}
	return {"action": "fold", "to": 0.0, "bluff": false}


# ------------------------------------------------------------------ Blitz

const EXPECT_SCALE := 1.48   # calibrado por simulação (tests/blitz_sim.gd)


## Quantas rodadas a mão deve ganhar no nível (soma da chance de cada carta).
static func expected_wins(engine: ChaosEngine, player: int) -> float:
	var ev := engine.modifier
	var inverted := ev == ChaosModifiers.Modifier.VAZA_INVERTIDA
	var total := 0.0
	for c in engine.hands[player]:
		var pw := _card_power(engine, c, inverted)
		total += 0.04 + 0.62 * pw * pw
	return total * EXPECT_SCALE


## Palpite sugerido (0 a 8) — também alimenta a dica pro jogador.
static func suggested_predict(engine: ChaosEngine, player: int) -> int:
	return clampi(int(round(expected_wins(engine, player))), 0, ChaosEngine.HAND_SIZE)


## Palpite do bot (0 a 8). Difícil lê melhor a mão; fácil erra bastante.
static func blitz_pick(engine: ChaosEngine, player: int, difficulty: int, rng: RandomNumberGenerator) -> int:
	var noise := 0.9 if difficulty == BotAI.Difficulty.EASY else (0.45 if difficulty == BotAI.Difficulty.NORMAL else 0.15)
	var ex := expected_wins(engine, player) + rng.randf_range(-noise, noise)
	return clampi(int(round(ex)), 0, ChaosEngine.HAND_SIZE)


## Vitórias que a mão que sobrou ainda deve render.
static func expected_left(engine: ChaosEngine, player: int) -> float:
	return expected_wins(engine, player)


## Vale a pena pagar mais uma entrada agora: já no alvo e com a mão que sobrou fraca demais pra
## ganhar mais (na simulação acerta ~90%), ou faltando 1 rodada e uma carta certeira. Fácil nunca
## topa; normal só com muita certeza. Serve tanto pra dobrar/triplicar (seu próprio lance) quanto
## pra cobrir o lance de um rival — a conta de valer a pena é a mesma.
static func _double_worth_it(engine: ChaosEngine, player: int, difficulty: int) -> bool:
	if difficulty == BotAI.Difficulty.EASY:
		return false
	var need := engine.blitz_need(player)
	var left := expected_left(engine, player)
	if int(engine.doubles[player]) >= 1:
		# Triplicar (ou cobrir a 2ª vez): só com o palpite praticamente fechado.
		return difficulty == BotAI.Difficulty.HARD and need == 0 and left < 0.15
	if need == 0:
		return left < (0.3 if difficulty == BotAI.Difficulty.HARD else 0.15)
	if difficulty == BotAI.Difficulty.HARD and engine.tricks_left() == 1:
		return absf(left - float(need)) < 0.15
	return false


static func wants_double(engine: ChaosEngine, player: int, difficulty: int, rng: RandomNumberGenerator) -> bool:
	if not engine.can_double(player):
		return false
	return _double_worth_it(engine, player, difficulty) and rng.randf() < 0.85


## Cobrir a dobra/triplicada de um rival: mesma conta de valer a pena, mas sem esperar a rodada
## (é uma resposta imediata). Um pouco mais cauteloso, porque a decisão não foi iniciativa sua.
static func wants_cover(engine: ChaosEngine, player: int, difficulty: int, rng: RandomNumberGenerator) -> bool:
	if not engine.can_cover(player):
		return false
	return _double_worth_it(engine, player, difficulty) and rng.randf() < 0.7


## Blitz: joga cada carta pela conta de fichas esperadas — palpite (vencer ajuda ou atrapalha) +
## prêmio das cartas da mesa (quem vence leva, os rivais pagam) − custo de gastar a carta agora.
## Fácil joga ao acaso; Normal erra um pouco de vez em quando; Difícil calcula tudo.
static func _blitz_choose(engine: ChaosEngine, player: int, difficulty: int, rng: RandomNumberGenerator) -> CardData:
	var legal: Array = engine.legal_for(player)
	if difficulty == BotAI.Difficulty.EASY:
		return legal[rng.randi_range(0, legal.size() - 1)]
	if difficulty == BotAI.Difficulty.NORMAL and rng.randf() < 0.15:
		return legal[rng.randi_range(0, legal.size() - 1)]
	var inverted := engine.active_modifier() == ChaosModifiers.Modifier.VAZA_INVERTIDA
	var need := engine.blitz_need(player)
	var left := engine.tricks_left()
	# Valor de VENCER essa rodada pro palpite (negativo = vencer atrapalha).
	var dv := 0.0
	if need > 0:
		var pneed := 1.0 if need >= left else float(need) / float(left)
		dv = HIT_VALUE_BLINDS * pneed
	elif need == 0:
		dv = -HIT_VALUE_BLINDS
	# Efeitos de fichas do modificador (em blinds): Saque/Assalto rendem a quem vence, Maldita custa.
	var blind := float(engine.blind)
	match engine.active_modifier():
		ChaosModifiers.Modifier.SAQUE:
			dv += engine.chips_of(ChaosEngine.SAQUE_AMOUNT) * float(engine.active_count() - 1) / blind
		ChaosModifiers.Modifier.ASSALTO_LIDER:
			if player != engine._highest_player():
				dv += engine.chips_of(ChaosEngine.ASSALTO_AMOUNT) / blind
		ChaosModifiers.Modifier.VAZA_MALDITA:
			dv -= engine.chips_of(ChaosEngine.CURSE_PENALTY) / blind
	var k := ChaosEngine.PRIZE_PER_POINT * engine.point_factor
	var n_active := engine.active_count()
	var unseen := n_active - engine.plays.size() - 1
	var table := 0.0
	for pl in engine.plays:
		table += engine.card_value(pl["card"], player)
	var noise := 0.0 if difficulty == BotAI.Difficulty.HARD else 0.6
	var best: CardData = null
	var best_score := -INF
	for c in legal:
		var power := _card_power(engine, c, inverted)
		var pw := 0.0
		if engine.would_win(c, player):
			pw = 1.0 if unseen <= 0 else clampf(0.15 + 0.75 * power, 0.0, 0.95)
		var total := table + engine.card_value(c, player) + float(maxi(unseen, 0)) * AVG_CARD_POINTS
		var prize := k * total
		var score := pw * (dv + prize) - (1.0 - pw) * prize / float(maxi(n_active - 1, 1))
		# Guardar carta forte tem valor (poder futuro); as fracas saem primeiro.
		score -= power * 0.5
		if noise > 0.0:
			score += rng.randf_range(-noise, noise)
		if score > best_score:
			best_score = score
			best = c
	return best
