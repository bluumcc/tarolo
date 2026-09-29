class_name ChaosBot
extends RefCounted
## IA dos bots do Caos: como a do BotAI, mas ciente do modificador da vaza (inversão,
## Vaza Maldita, Naipe Maldito, vazas de aposta alta, Assalto ao Líder).


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
	# Quer perder a vaza? (Vaza Maldita, ou Assalto ao Líder sendo ele o líder não muda nada.)
	var want_lose := ev == mods.VAZA_MALDITA
	# Aposta alta: vale gastar a carta mais forte pra garantir.
	var high_stakes := ev in [mods.VAZA_DOURADA, mods.ULTIMA_TRIPLO, mods.PRIMEIRA_DOBRO, mods.SAQUE] \
		or (ev == mods.ASSALTO_LIDER and player == engine._highest_player()) \
		or engine.is_final_round()

	var is_last := engine.plays.size() == engine.num_players - 1
	var winners: Array = legal.filter(func(c: CardData) -> bool: return engine.would_win(c, player))
	var losers: Array = legal.filter(func(c: CardData) -> bool: return not engine.would_win(c, player))

	if want_lose:
		if not losers.is_empty():
			return _cheapest(engine, losers, player)
		return _cheapest(engine, winners, player)

	if not engine.plays.is_empty() and not winners.is_empty():
		# Cartas do naipe maldito somam negativo na própria vaza: evita usá-las pra vencer.
		var clean: Array = winners.filter(func(c: CardData) -> bool: return engine.card_value(c, player) >= 0.0)
		var pool: Array = clean if not clean.is_empty() else winners
		pool.sort_custom(func(a: CardData, b: CardData) -> bool: return a.rank < b.rank)
		# Invertido: o mais seguro é a menor carta; normal: a maior.
		if is_last or (not high_stakes and not inverted and pool.size() > 1 and _trick_value(engine) < 1.0):
			return pool[0]
		return pool[0] if inverted else pool[pool.size() - 1]

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


## Poder que o bot leva pra rodada: Espiar não ajuda quem já decide por regra, então só
## Roubar Trunfo ou Arriscar.
static func choose_power(rng: RandomNumberGenerator) -> int:
	return ChaosItems.Item.TROCA if rng.randf() < 0.5 else ChaosItems.Item.ARRISCAR


## Aposta do bot: estima quantas vazas a mão rende (Trunfos altos e Reis) e escolhe o
## degrau que combina. Bots fáceis chutam mais.
static func choose_bet(hand: Array, difficulty: int, rng: RandomNumberGenerator) -> int:
	var expected := 0.0
	for c in hand:
		var card: CardData = c
		if card.is_louco():
			continue
		if card.is_trunfo():
			expected += 0.35 + float(card.rank) / 60.0
		elif card.rank == 14:
			expected += 0.45
		elif card.rank == 13:
			expected += 0.2
	if difficulty == BotAI.Difficulty.EASY:
		expected += rng.randf_range(-1.5, 1.5)
	elif difficulty == BotAI.Difficulty.NORMAL:
		expected += rng.randf_range(-0.7, 0.7)
	if expected >= 5.0:
		return 2
	if expected >= 3.2:
		return 1
	return 0


## Se o bot deve usar o poder agora (antes de jogar a carta). Retorna {} ou
## {"item": Item, "target": int}.
static func maybe_power(engine: ChaosEngine, player: int, difficulty: int, rng: RandomNumberGenerator) -> Dictionary:
	if not engine.can_use_power(player):
		return {}
	var item: int = engine.player_items[player]
	if item == ChaosItems.Item.TROCA:
		if engine.trick_number > 3 or (difficulty == BotAI.Difficulty.EASY and rng.randf() < 0.5):
			return {}
		var target := -1
		var best := 0
		for q in range(engine.num_players):
			if q == player:
				continue
			var n := (engine.hands[q] as Array).filter(func(c: CardData) -> bool: return c.is_trunfo() and not c.is_louco()).size()
			if n > best:
				best = n
				target = q
		if target == -1:
			return {}
		return {"item": item, "target": target}
	if item == ChaosItems.Item.ARRISCAR:
		var legal: Array = engine.legal_for(player)
		var can_win := legal.any(func(c: CardData) -> bool: return engine.would_win(c, player))
		var last := engine.plays.size() == engine.num_players - 1
		if can_win and (last or engine.trick_number >= HAND_LAST):
			if engine.active_modifier() != ChaosModifiers.Modifier.VAZA_MALDITA:
				return {"item": item, "target": -1}
	return {}


const HAND_LAST := 6
