class_name BotAI
extends RefCounted
## IA dos bots. `TrickRules.legal_cards` já garante seguir naipe / cortar / cobrir com
## Trunfo — o bot só decide qual carta legal jogar.

enum Difficulty { EASY, NORMAL, HARD }

const DIFFICULTY_NAMES := ["Fácil", "Normal", "Difícil"]


## Força estimada de uma mão pra decidir lance na licitação: soma os pontos das cartas,
## com peso extra pra Trunfos e principalmente pros Bouts.
static func hand_strength(hand: Array) -> float:
	var s := 0.0
	for c in hand:
		var card: CardData = c
		if card.is_bout():
			s += 4.0
		elif card.is_trunfo():
			s += 1.2
		else:
			s += card.points()
	return s


## Decide o lance do bot na licitação. `options` = contratos disponíveis agora
## (Scoring.Contract, já filtrados pra maiores que o lance atual). `forced` = true
## quando o bot é obrigado a dar algum lance (último ativo, ninguém arrematou ainda).
## Retorna -1 (passar) ou um valor de Scoring.Contract.
static func bid_choice(hand: Array, options: Array, forced: bool, difficulty: int, rng: RandomNumberGenerator) -> int:
	var strength := hand_strength(hand)
	match difficulty:
		Difficulty.EASY:
			strength += rng.randf_range(-10.0, 10.0)
		Difficulty.NORMAL:
			strength += rng.randf_range(-4.0, 4.0)
		_:
			strength += rng.randf_range(-1.5, 1.5)

	var desired := -1
	if strength >= 34.0:
		desired = Scoring.Contract.GARDE_CONTRE
	elif strength >= 28.0:
		desired = Scoring.Contract.GARDE_SANS
	elif strength >= 21.0:
		desired = Scoring.Contract.GARDE
	elif strength >= 14.0:
		desired = Scoring.Contract.PETITE

	if options.is_empty():
		return -1 if not forced else options[0]  # ninguém pode subir mais (alguém já deu Garde Contre)
	if desired != -1 and options.has(desired):
		return desired
	# o que o bot queria já não está mais disponível (alguém arrematou antes) —
	# só sobe um degrau além do que pretendia, senão desiste.
	var next_opt: int = options[0]
	if desired != -1 and next_opt <= desired + 1:
		return next_opt
	return next_opt if forced else -1


## Declarar Poignée é sempre vantajoso pro bot (não há como a IA hoje usar a informação
## revelada contra ele mesmo), então declara sempre que elegível.
static func decide_poignee(trump_count: int) -> bool:
	return trump_count >= 10


## Anunciar Chelem só compensa com uma mão excepcional — a penalidade de falhar é alta.
## Só bots Normal/Difícil arriscam, e só ocasionalmente mesmo com mão muito forte.
static func decide_chelem(hand_strength: float, difficulty: int, rng: RandomNumberGenerator) -> bool:
	if difficulty == Difficulty.EASY or hand_strength < 38.0:
		return false
	return rng.randf() < 0.35


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
