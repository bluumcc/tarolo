class_name ChaosBot
extends RefCounted
## IA dos bots da Mesa Caos: escolhem a carta (ciente do modificador) e decidem as apostas
## (passar, aumentar, pagar, desistir) pela força da mão, com blefe nos níveis difíceis.


static func choose(engine: ChaosEngine, player: int, difficulty: int, rng: RandomNumberGenerator) -> CardData:
	var legal: Array = engine.legal_for(player)
	if legal.size() == 1:
		return legal[0]
	if difficulty == BotAI.Difficulty.EASY:
		return legal[rng.randi_range(0, legal.size() - 1)]
	if difficulty == BotAI.Difficulty.NORMAL and rng.randf() < 0.15:
		return legal[rng.randi_range(0, legal.size() - 1)]

	var ev := engine.active_modifier()
	var inverted := ev == ChaosModifiers.Modifier.MUNDO_CONTRARIO or ev == ChaosModifiers.Modifier.VAZA_INVERTIDA
	var mods := ChaosModifiers.Modifier
	# Quer perder a rodada? (Rodada Maldita, ou Assalto ao Líder sendo ele o líder não muda nada.)
	var want_lose := ev == mods.VAZA_MALDITA
	# Aposta alta: vale gastar a carta mais forte pra garantir.
	var high_stakes := ev in [mods.VAZA_DOURADA, mods.ULTIMA_TRIPLO, mods.PRIMEIRA_DOBRO, mods.SAQUE] \
		or (ev == mods.ASSALTO_LIDER and player == engine._highest_player()) \
		or engine.pot > float(engine.blind) * 8.0

	var is_last := engine.plays.size() == engine.active_count() - 1
	var winners: Array = legal.filter(func(c: CardData) -> bool: return engine.would_win(c, player))
	var losers: Array = legal.filter(func(c: CardData) -> bool: return not engine.would_win(c, player))

	if want_lose:
		if not losers.is_empty():
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

	if engine.plays.is_empty() and not inverted and engine.pot > float(engine.blind) * float(engine.active_count()) * 1.2:
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
	var inverted := ev == ChaosModifiers.Modifier.MUNDO_CONTRARIO or ev == ChaosModifiers.Modifier.VAZA_INVERTIDA
	var powers: Array = []
	for c in engine.hands[player]:
		var card: CardData = c
		var pw := 0.0
		if card.is_louco():
			pw = 0.85 if engine.louco_can_win() else 0.05
			if inverted:
				pw = 0.05
		elif inverted:
			pw = 0.1 if card.is_trunfo() else 1.0 - float(card.rank) / 14.0 * 0.85
		elif card.is_trunfo():
			pw = 0.5 + 0.5 * float(card.rank) / 21.0
		elif card.rank == 14:
			pw = 0.55
		elif card.rank == 13:
			pw = 0.4
		elif card.rank == 12:
			pw = 0.3
		elif card.rank == 11:
			pw = 0.25
		else:
			pw = float(card.rank) / 14.0 * 0.2
		powers.append(pw)
	if powers.is_empty():
		return 0.0
	powers.sort()
	powers.reverse()
	var second: float = powers[1] if powers.size() > 1 else powers[0]
	return 0.6 * float(powers[0]) + 0.4 * second


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
