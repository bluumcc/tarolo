class_name BotStrategy
extends RefCounted
## Jogo estratégico dos bots no Vanilla. Só usa o que um jogador de verdade sabe: a própria
## mão, o que já foi jogado (nas vazas e na mesa), quem é o Tomador e o contrato — nunca a
## mão dos outros.
##
## Ideias que aplica (de mesa de tarot):
## - Defesa se ajuda: quando a vaza vai ficar com a Defesa, "alimenta" ela com a carta de
##   mais pontos (até Bouts); quando o Tomador ainda vai jogar, segura as cartas boas.
## - Ninguém corta o próprio parceiro; só toma a vaza do Tomador se compensa (trunfo caro
##   só por vaza com pontos).
## - O Louco vale pontos pra quem levar a vaza, então nunca é jogado à toa.
## - O Petit é guardado pro fim (Petit au bout).
## - O Tomador puxa os trunfos dos outros com os seus altos e segura os Bouts.
## - Nível Difícil conta as cartas que já saíram: joga as cartas "mestras" (que ninguém
##   mais pode bater), abre por um naipe curto pra poder cortar depois, e sabe quando a
##   carta do parceiro já é segura.

const T := CardData.Suit.TRUNFO


static func choose(e: MatchEngine, player: int, difficulty: int, rng: RandomNumberGenerator) -> CardData:
	var hand: Array = e.hands[player]
	var legal: Array = TrickRules.legal_cards(hand, e.plays)
	if legal.size() == 1:
		return legal[0]
	var deep := difficulty == BotAI.Difficulty.HARD
	var seen: Dictionary = _seen_cards(e, player) if deep else {}
	var pick: CardData
	if e.plays.is_empty() or TrickRules.lead_suit(e.plays) == -1:
		pick = _lead(e, player, legal, seen, deep)
	else:
		pick = _follow(e, player, legal, seen, deep)
	# Nível Normal escorrega de vez em quando (uma jogada aleatória entre as legais).
	if not deep and rng.randf() < 0.10:
		return legal[rng.randi_range(0, legal.size() - 1)]
	return pick


# ------------------------------------------------------------------ conhecimento

static func _key(c: CardData) -> int:
	return int(c.suit) * 100 + c.rank


static func _seen_cards(e: MatchEngine, player: int) -> Dictionary:
	var seen := {}
	for c in e.hands[player]:
		seen[_key(c)] = true
	for t in e.history:
		for entry in (t["plays"] as Array):
			seen[_key(entry["card"])] = true
	for entry in e.plays:
		seen[_key(entry["card"])] = true
	# o Tomador que pegou o talão conhece o próprio descarte; sem talão (Sans/Contre), não
	if player == e.taker and (e.contract == Scoring.Contract.PETITE or e.contract == Scoring.Contract.GARDE):
		for c in e.captured[player]:
			seen[_key(c)] = true
	return seen


## Ninguém mais pode bater essa carta dentro do próprio naipe (ou entre os trunfos).
static func _is_master(c: CardData, seen: Dictionary) -> bool:
	var top := 21 if c.is_trunfo() else 14
	for r in range(c.rank + 1, top + 1):
		if not seen.has(int(c.suit) * 100 + r):
			return false
	return true


static func _unseen_trumps(seen: Dictionary) -> int:
	var n := 0
	for r in range(1, 22):
		if not seen.has(int(T) * 100 + r):
			n += 1
	return n


# ------------------------------------------------------------------ abrindo a vaza

static func _lead(e: MatchEngine, p: int, legal: Array, seen: Dictionary, deep: bool) -> CardData:
	var is_taker := p == e.taker
	var hand: Array = e.hands[p]
	var real: Array = legal.filter(func(c: CardData) -> bool: return not c.is_louco())
	if real.is_empty():
		return legal[0]
	var trumps: Array = real.filter(func(c: CardData) -> bool: return c.is_trunfo())
	var unseen := _unseen_trumps(seen) if deep else maxi(0, 21 - trumps.size() - 3)
	var draw_mode := is_taker and trumps.size() >= 4 and unseen >= 2
	var trump_heavy := trumps.size() >= 6
	var suit_len := {}
	for c in hand:
		suit_len[int(c.suit)] = int(suit_len.get(int(c.suit), 0)) + 1
	var best: CardData = real[0]
	var best_score := -INF
	for c in real:
		var card: CardData = c
		var s := 0.0
		if card.is_trunfo():
			if card.rank == CardData.PETIT and hand.size() > 1:
				s = -100.0                       # guarda o Petit pro fim
			elif draw_mode:
				s = 10.0 + float(card.rank) * 0.3   # o Tomador puxa os trunfos, dos altos pra baixo
			elif trump_heavy:
				s = 3.0 + float(card.rank) * 0.1
			else:
				s = -4.0 - card.points()
		else:
			if deep and _is_master(card, seen):
				s = 7.0 + card.points() * 0.3    # cartas mestras: pontos garantidos
			else:
				s = 2.0 - card.points() - float(card.rank) * 0.05
				if deep and not is_taker:
					s += (3.0 - float(suit_len.get(int(card.suit), 3))) * 0.8   # naipe curto: dá pra cortar logo
		if s > best_score or (is_equal_approx(s, best_score) and card.rank < best.rank):
			best_score = s
			best = card
	return best


# ------------------------------------------------------------------ respondendo à vaza

static func _by_value_low(a: CardData, b: CardData) -> bool:
	# menos valiosa primeiro: pontos, depois trunfos por último, depois rank
	if not is_equal_approx(a.points(), b.points()):
		return a.points() < b.points()
	if a.is_trunfo() != b.is_trunfo():
		return not a.is_trunfo()
	return a.rank < b.rank


static func _by_value_high(a: CardData, b: CardData) -> bool:
	# mais pontos primeiro; empate: a mais baixa (gasta menos força)
	if not is_equal_approx(a.points(), b.points()):
		return a.points() > b.points()
	if a.is_trunfo() != b.is_trunfo():
		return not a.is_trunfo()
	return a.rank < b.rank


static func _follow(e: MatchEngine, p: int, legal: Array, seen: Dictionary, deep: bool) -> CardData:
	var is_taker := p == e.taker
	var plays: Array = e.plays
	var n := e.num_players
	var last := plays.size() == n - 1
	var widx := TrickRules.winning_index(plays)
	var winner_player: int = int(plays[widx]["player"]) if widx >= 0 else -1
	var table_pts := 0.0
	var taker_played := false
	for entry in plays:
		table_pts += ((entry as Dictionary)["card"] as CardData).points()
		if int(entry["player"]) == e.taker:
			taker_played = true
	var real: Array = legal.filter(func(c: CardData) -> bool: return not c.is_louco())
	var louco: Array = legal.filter(func(c: CardData) -> bool: return c.is_louco())
	var wins: Array = real.filter(func(c: CardData) -> bool: return TrickRules.would_win(c, p, plays))

	if not is_taker:
		var partner_winning := winner_player != -1 and winner_player != e.taker
		var taker_behind := not taker_played
		if partner_winning:
			var safe := not taker_behind
			if not safe and deep:
				var wc: CardData = plays[widx]["card"]
				if _is_master(wc, seen) and (wc.is_trunfo() or _unseen_trumps(seen) == 0):
					safe = true   # a carta do parceiro ninguém mais bate: pode alimentar
			var pool: Array = legal.duplicate()
			if safe:
				pool.sort_custom(_by_value_high)          # alimenta com o que tiver de mais valioso
				return pool[0]
			var cheap: Array = real.filter(func(c: CardData) -> bool: return not c.is_bout())
			if cheap.is_empty():
				cheap = real if not real.is_empty() else louco
			cheap.sort_custom(_by_value_low)
			return cheap[0]
		# o Tomador está levando (ou a vaza está aberta pra ele): vale tomar?
		if not wins.is_empty():
			wins.sort_custom(func(a: CardData, b: CardData) -> bool: return a.rank < b.rank)
			var cheapest: CardData = wins[0]
			var free := not cheapest.is_trunfo() or TrickRules.lead_suit(plays) == T
			if free or table_pts >= 2.0 or (last and table_pts >= 1.0):
				return cheapest
		var dump: Array = real.filter(func(c: CardData) -> bool: return not c.is_bout() and c.rank != 14)
		if dump.is_empty():
			dump = real if not real.is_empty() else louco
		dump.sort_custom(_by_value_low)
		return dump[0]

	# ---- Tomador
	if not wins.is_empty():
		var non_bout: Array = wins.filter(func(c: CardData) -> bool: return not c.is_bout())
		if last:
			var pool_last: Array = non_bout if not non_bout.is_empty() else wins
			pool_last.sort_custom(func(a: CardData, b: CardData) -> bool: return a.rank < b.rank)
			var cheapest_last: CardData = pool_last[0]
			var free_last := not cheapest_last.is_trunfo() or TrickRules.lead_suit(plays) == T
			if free_last or table_pts >= 1.5:
				return cheapest_last
		else:
			if not non_bout.is_empty() and (table_pts >= 1.5 or not (non_bout[0] as CardData).is_trunfo()):
				non_bout.sort_custom(func(a: CardData, b: CardData) -> bool: return a.rank > b.rank)
				return non_bout[0]
			if table_pts >= 4.0:
				wins.sort_custom(func(a: CardData, b: CardData) -> bool: return a.rank > b.rank)
				return wins[0]
	var dump_t: Array = real.filter(func(c: CardData) -> bool: return not c.is_bout() and c.rank != 14)
	if dump_t.is_empty():
		dump_t = real if not real.is_empty() else louco
	dump_t.sort_custom(_by_value_low)
	return dump_t[0]


# ------------------------------------------------------------------ descarte do Tomador

## Devolve 6 cartas ao monte do jeito que um bom Tomador faria: esvazia naipes curtos (pra
## poder cortar com trunfo depois) e leva pra casa, em segurança, os pontos de damas e
## cavaleiros soltos em naipe curto. Nunca descarta as cartas que seguram um naipe longo.
static func choose_discard(hand: Array, legal: Array, n: int) -> Array:
	var suit_len := {}
	for c in hand:
		suit_len[int(c.suit)] = int(suit_len.get(int(c.suit), 0)) + 1
	var scored: Array = []
	for c in legal:
		var card: CardData = c
		var len_s := int(suit_len.get(int(card.suit), 1))
		var s := 0.0
		if card.is_trunfo():
			s = -20.0 - float(card.rank) * 0.1     # trunfo comum só em último caso
		else:
			s = 5.0 - float(len_s) * 1.2           # naipe curto: candidato a esvaziar
			s += card.points() * 0.5               # pontos que ficam garantidos
			if card.rank >= 11 and len_s >= 4:
				s -= 4.0                           # figura de naipe longo: vale mais na mão
			s -= float(card.rank) * 0.05
		scored.append({"card": card, "s": s})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) > float(b["s"]))
	var out: Array = []
	for i in range(mini(n, scored.size())):
		out.append(scored[i]["card"])
	return out
