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


## Limiares calibrados numa simulação de 2000 mãos aleatórias (`hand_strength` real):
## mín=10,7 · p25=20,5 · mediana=23,5 · p75=26,8 · p90=29,8 · p97=32,6 · máx=41,6.
## Antes disso os limiares eram mais baixos que a MEDIANA — mais da metade das mãos já
## batia Garde, por isso os bots pareciam sempre arriscar demais. Agora só a minoria das
## mãos (as de verdade boas) sobe além de Petite, como numa mesa real.
const STRENGTH_PETITE := 24.0
const STRENGTH_GARDE := 27.5
const STRENGTH_GARDE_SANS := 31.0
const STRENGTH_GARDE_CONTRE := 35.0

## Contrato que a mão sugere (os mesmos limiares dos bots, sem sorteio): -1 = passar.
static func recommended_contract(hand: Array) -> int:
	var strength := hand_strength(hand)
	if strength >= STRENGTH_GARDE_CONTRE:
		return Scoring.Contract.GARDE_CONTRE
	if strength >= STRENGTH_GARDE_SANS:
		return Scoring.Contract.GARDE_SANS
	if strength >= STRENGTH_GARDE:
		return Scoring.Contract.GARDE
	if strength >= STRENGTH_PETITE:
		return Scoring.Contract.PETITE
	return -1


## Decide o lance do bot na licitação. `options` = contratos disponíveis agora
## (Scoring.Contract, já filtrados pra maiores que o lance atual). `forced` = true
## quando o bot é obrigado a dar algum lance (último ativo, ninguém arrematou ainda).
## Retorna -1 (passar) ou um valor de Scoring.Contract.
static func bid_choice(hand: Array, options: Array, forced: bool, difficulty: int, rng: RandomNumberGenerator) -> int:
	var strength := hand_strength(hand)
	match difficulty:
		Difficulty.EASY:
			strength += rng.randf_range(-6.0, 6.0)
		Difficulty.NORMAL:
			strength += rng.randf_range(-3.0, 3.0)
		_:
			strength += rng.randf_range(-1.0, 1.0)

	var desired := -1
	if strength >= STRENGTH_GARDE_CONTRE:
		desired = Scoring.Contract.GARDE_CONTRE
	elif strength >= STRENGTH_GARDE_SANS:
		desired = Scoring.Contract.GARDE_SANS
	elif strength >= STRENGTH_GARDE:
		desired = Scoring.Contract.GARDE
	elif strength >= STRENGTH_PETITE:
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


## Escolhe as `n` cartas mais fracas dentre as elegíveis pro descarte (écart) — mesma
## lógica que um jogador cuidadoso usaria: nunca joga fora o que ainda pode render pontos.
static func choose_discard(legal: Array, n: int) -> Array:
	var pool: Array = legal.duplicate()
	pool.sort_custom(func(a: CardData, b: CardData) -> bool: return a.points() < b.points())
	return pool.slice(0, mini(n, pool.size()))


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


static func choose(hand: Array, plays: Array, player: int, num_players: int, difficulty: int, rng: RandomNumberGenerator, louco_can_win: bool = false) -> CardData:
	var legal := TrickRules.legal_cards(hand, plays)
	if legal.size() == 1:
		return legal[0]
	if difficulty == Difficulty.EASY:
		return legal[rng.randi_range(0, legal.size() - 1)]

	var louco := legal.filter(func(c: CardData) -> bool: return c.is_louco())
	var real := legal.filter(func(c: CardData) -> bool: return not c.is_louco())

	if plays.is_empty():
		# Abrindo a rodada: evita gastar Bouts ou Trunfos altos à toa.
		var safe := real.filter(func(c: CardData) -> bool: return not c.is_trunfo() and not c.is_bout())
		var pool: Array = safe if not safe.is_empty() else real
		pool.sort_custom(func(a: CardData, b: CardData) -> bool: return a.rank < b.rank)
		if pool.is_empty():
			return louco[0]
		if difficulty == Difficulty.NORMAL and rng.randf() < 0.2:
			return pool[rng.randi_range(0, pool.size() - 1)]
		return pool[0]

	var is_last := plays.size() == num_players - 1
	var win_pool: Array = legal if louco_can_win else real
	var winning := win_pool.filter(func(c: CardData) -> bool: return TrickRules.would_win(c, player, plays, louco_can_win))
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
