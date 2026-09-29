class_name ChaosBot
extends RefCounted
## IA dos bots do Caos: como a do BotAI, mas ciente do modificador da rodada (inversão,
## Rodada Maldita, Naipe Maldito, rodadas de aposta alta, Assalto ao Líder).


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
	# Palpite exato: no alvo, não ganha mais; faltando tudo que resta, vai pra cima.
	var bet_lose := false
	var bet_push := false
	var predict: int = engine.bet_predict[player]
	if predict >= 0:
		var won := engine.tricks_won_by(player)
		if won >= predict:
			bet_lose = true
		elif engine.tricks_left() <= predict - won:
			bet_push = true
	# Aposta alta: vale gastar a carta mais forte pra garantir.
	var high_stakes := ev in [mods.VAZA_DOURADA, mods.ULTIMA_TRIPLO, mods.PRIMEIRA_DOBRO, mods.SAQUE] \
		or (ev == mods.ASSALTO_LIDER and player == engine._highest_player()) \
		or engine.is_final_round() or bet_push

	var is_last := engine.plays.size() == engine.num_players - 1
	var winners: Array = legal.filter(func(c: CardData) -> bool: return engine.would_win(c, player))
	var losers: Array = legal.filter(func(c: CardData) -> bool: return not engine.would_win(c, player))

	if bet_lose and not want_lose and not losers.is_empty():
		# Já cumpriu o palpite: joga a carta forte que não vence (larga o risco de ganhar depois).
		var shed: Array = losers.filter(func(c: CardData) -> bool: return not c.is_bout())
		if shed.is_empty():
			shed = losers
		shed.sort_custom(func(a: CardData, b: CardData) -> bool: return a.rank > b.rank)
		return shed[0]
	if bet_lose and not want_lose and losers.is_empty():
		return _cheapest(engine, winners, player)
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


## Poder que o bot leva pra nível: Espiar não ajuda quem já decide por regra, então só
## Roubar Trunfo ou Arriscar.
static func choose_power(rng: RandomNumberGenerator) -> int:
	return ChaosItems.Item.TROCA if rng.randf() < 0.5 else ChaosItems.Item.ARRISCAR


## Palpite do bot: estima quantas rodadas a mão rende (Trunfos altos e Reis) e crava o
## número. Devolve {predict, stake} ou {} se ficar de fora. Bots fáceis erram mais.
static func choose_bet(hand: Array, difficulty: int, rng: RandomNumberGenerator) -> Dictionary:
	var expected := 0.0
	for c in hand:
		var card: CardData = c
		if card.is_louco():
			continue
		if card.is_trunfo():
			expected += 0.8 if card.rank >= 14 else (0.5 if card.rank >= 8 else 0.2)
		elif card.rank == 14:
			expected += 0.6
		elif card.rank == 13:
			expected += 0.3
	if difficulty == BotAI.Difficulty.EASY:
		expected += rng.randf_range(-1.5, 1.5)
	elif difficulty == BotAI.Difficulty.NORMAL:
		expected += rng.randf_range(-0.7, 0.7)
	var predict := clampi(roundi(expected), 0, 7)
	if difficulty == BotAI.Difficulty.EASY and rng.randf() < 0.35:
		return {}
	var stake: int = ChaosEngine.STAKES[0]
	if difficulty == BotAI.Difficulty.HARD:
		# Mais confiança quando a mão é decisiva (muito forte ou muito fraca).
		if predict >= 4 or predict == 0:
			stake = ChaosEngine.STAKES[2]
		elif predict >= 2:
			stake = ChaosEngine.STAKES[1]
	elif difficulty == BotAI.Difficulty.NORMAL:
		stake = ChaosEngine.STAKES[1] if predict >= 3 else ChaosEngine.STAKES[0]
	return {"predict": predict, "stake": stake}


## Se o bot deve DOBRAR agora (na vez dele).
static func maybe_double(engine: ChaosEngine, player: int, difficulty: int, rng: RandomNumberGenerator) -> bool:
	if difficulty == BotAI.Difficulty.EASY or not engine.can_double(player):
		return false
	var predict: int = engine.bet_predict[player]
	var won := engine.tricks_won_by(player)
	var chance := 0.0
	if won == predict:
		# Já cumpriu: dobra se ainda tem carta que não ganha (dá pra perder de propósito).
		var legal: Array = engine.legal_for(player)
		var can_lose := legal.any(func(c: CardData) -> bool: return not engine.would_win(c, player))
		chance = 0.55 if can_lose else 0.0
	elif predict - won == 1 and engine.tricks_left() >= 2:
		var strong := (engine.hands[player] as Array).any(func(c: CardData) -> bool: return c.is_trunfo() and c.rank >= 15)
		chance = 0.5 if strong else 0.0
	if difficulty == BotAI.Difficulty.NORMAL:
		chance *= 0.6
	return rng.randf() < chance


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
