class_name BotAI
extends RefCounted
## IA dos bots. Fácil = aleatório legal; Normal = heurística gulosa; Difícil = gulosa
## com gestão de Arcanos e leitura do valor da vaza.

enum Difficulty { EASY, NORMAL, HARD }

const DIFFICULTY_NAMES := ["Fácil", "Normal", "Difícil"]


static func choose(hand: Array, plays: Array, player: int, num_players: int, difficulty: int, rng: RandomNumberGenerator) -> CardData:
	var legal := TrickRules.legal_cards(hand, plays)
	if legal.size() == 1:
		return legal[0]
	if difficulty == Difficulty.EASY:
		return legal[rng.randi_range(0, legal.size() - 1)]

	var numeric := legal.filter(func(c: CardData) -> bool: return not c.is_arcana())
	var arcana := legal.filter(func(c: CardData) -> bool: return c.is_arcana())

	# Abrindo a vaza: puxa a carta mais forte do naipe mais longo (força os outros a gastar).
	if plays.is_empty():
		if numeric.is_empty():
			return arcana[0]
		var suit_len := {}
		for c in numeric:
			suit_len[c.suit] = suit_len.get(c.suit, 0) + 1
		numeric.sort_custom(func(a: CardData, b: CardData) -> bool:
			if suit_len[a.suit] != suit_len[b.suit]:
				return suit_len[a.suit] > suit_len[b.suit]
			return a.rank > b.rank)
		if difficulty == Difficulty.NORMAL and rng.randf() < 0.25:
			return numeric[rng.randi_range(0, numeric.size() - 1)]
		return numeric[0]

	var is_last := plays.size() == num_players - 1
	var table_chips := 0
	for p in plays:
		table_chips += (p["card"] as CardData).base_chips()
		if (p["card"] as CardData).modifier != CardData.Modifier.NONE:
			table_chips += 40

	var winning_numeric := numeric.filter(func(c: CardData) -> bool: return TrickRules.would_win(c, player, plays))
	winning_numeric.sort_custom(func(a: CardData, b: CardData) -> bool: return a.rank < b.rank)

	if not winning_numeric.is_empty():
		# Último a jogar: vence com a menor carta suficiente. Senão, garante com a maior.
		return winning_numeric[0] if is_last else winning_numeric[winning_numeric.size() - 1]

	# Não dá para vencer com carta numérica: decide se gasta um Arcano.
	var arcana_on_table := plays.any(func(p) -> bool: return (p["card"] as CardData).is_arcana())
	if not arcana.is_empty() and not arcana_on_table:
		var threshold := 30 if difficulty == Difficulty.HARD else 20
		var spend := table_chips >= threshold or (is_last and difficulty == Difficulty.HARD and table_chips >= 18)
		if difficulty == Difficulty.NORMAL and rng.randf() < 0.2:
			spend = true
		if spend or numeric.is_empty():
			return arcana[0]

	# Descarta a carta mais fraca (sem jogar fora cartas modificadas se puder).
	var pool := numeric if not numeric.is_empty() else legal
	pool.sort_custom(func(a: CardData, b: CardData) -> bool:
		var am := 1 if a.modifier != CardData.Modifier.NONE else 0
		var bm := 1 if b.modifier != CardData.Modifier.NONE else 0
		if am != bm and difficulty == Difficulty.HARD:
			return am < bm
		return a.rank < b.rank)
	return pool[0]
