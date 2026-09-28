class_name BotAI
extends RefCounted
## IA dos bots. `TrickRules.legal_cards` já garante seguir naipe / cortar / cobrir com
## Trunfo — o bot só decide qual carta legal jogar.

enum Difficulty { EASY, NORMAL, HARD }

const DIFFICULTY_NAMES := ["Fácil", "Normal", "Difícil"]


static func choose(hand: Array, plays: Array, player: int, num_players: int, difficulty: int, rng: RandomNumberGenerator) -> CardData:
	var legal := TrickRules.legal_cards(hand, plays)
	if legal.size() == 1:
		return legal[0]
	if difficulty == Difficulty.EASY:
		return legal[rng.randi_range(0, legal.size() - 1)]

	var louco := legal.filter(func(c: CardData) -> bool: return c.is_louco())
	var real := legal.filter(func(c: CardData) -> bool: return not c.is_louco())

	if plays.is_empty():
		# Abrindo a vaza: evita gastar Bouts ou Trunfos altos à toa.
		var safe := real.filter(func(c: CardData) -> bool: return not c.is_trunfo() and not c.is_bout())
		var pool: Array = safe if not safe.is_empty() else real
		pool.sort_custom(func(a: CardData, b: CardData) -> bool: return a.rank < b.rank)
		if pool.is_empty():
			return louco[0]
		if difficulty == Difficulty.NORMAL and rng.randf() < 0.2:
			return pool[rng.randi_range(0, pool.size() - 1)]
		return pool[0]

	var is_last := plays.size() == num_players - 1
	var winning := real.filter(func(c: CardData) -> bool: return TrickRules.would_win(c, player, plays))
	winning.sort_custom(func(a: CardData, b: CardData) -> bool: return a.rank < b.rank)

	if not winning.is_empty():
		# Último a jogar: vence com o mínimo necessário. Senão, garante com o máximo.
		return winning[0] if is_last else winning[winning.size() - 1]

	if real.is_empty():
		return louco[0]

	# Não dá pra vencer: descarta a carta mais fraca, evitando jogar um Bout fora à toa.
	var pool: Array = real.filter(func(c: CardData) -> bool: return not c.is_bout())
	if pool.is_empty():
		pool = real
	pool.sort_custom(func(a: CardData, b: CardData) -> bool: return a.rank < b.rank)
	return pool[0]
