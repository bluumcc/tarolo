class_name TrickRules
extends RefCounted
## Regras de rodada do Jeu de Tarot. `plays` é um Array de { "player": int, "card": CardData }
## na ordem jogada.
##
## - É obrigatório seguir o naipe líder.
## - Sem o naipe líder, é obrigatório jogar Trunfo se tiver.
## - Se alguém já cortou com Trunfo, quem também for cortar deve jogar um Trunfo MAIOR
##   que o maior já jogado ("cobrir"), se tiver algum que consiga.
## - O Louco pode ser jogado a qualquer momento, ignora naipe e Trunfo, e nunca vence
##   a rodada (só o dono mantém os pontos da carta).


## Naipe líder: o da primeira carta que não é O Louco. Se só O Louco foi jogado até
## agora, o naipe ainda está em aberto (-1) — a próxima carta real vai defini-lo.
static func lead_suit(plays: Array) -> int:
	for p in plays:
		var c: CardData = p["card"]
		if not c.is_louco():
			return c.suit
	return -1


## Maior Trunfo já jogado nesta rodada (0 = nenhum Trunfo na mesa ainda).
static func highest_trunfo(plays: Array) -> int:
	var best := 0
	for p in plays:
		var c: CardData = p["card"]
		if c.is_trunfo() and c.rank > best:
			best = c.rank
	return best


## Cartas que o jogador pode jogar agora.
## `must_cover` = false (Mesa Blitz): quem pode cobrir NÃO é obrigado a jogar Trunfo maior;
## qualquer Trunfo serve quando o naipe (ou o corte) pede Trunfo.
static func legal_cards(hand: Array, plays: Array, must_cover: bool = true) -> Array:
	var louco := hand.filter(func(c: CardData) -> bool: return c.is_louco())
	var rest := hand.filter(func(c: CardData) -> bool: return not c.is_louco())
	var ls := lead_suit(plays)

	if ls == -1:
		return hand.duplicate()  # abrindo a rodada (ou só O Louco na mesa): qualquer carta

	var matching := rest.filter(func(c: CardData) -> bool: return c.suit == ls)
	if not matching.is_empty():
		if ls == CardData.Suit.TRUNFO:
			var cover := _cover_options(matching, plays) if must_cover else []
			if not cover.is_empty():
				return cover + louco
		return matching + louco

	# Sem o naipe líder: obrigado a cortar com Trunfo, se tiver.
	var trunfos := rest.filter(func(c: CardData) -> bool: return c.is_trunfo())
	if not trunfos.is_empty():
		var cover := _cover_options(trunfos, plays) if must_cover else []
		if not cover.is_empty():
			return cover + louco
		return trunfos + louco  # não consegue cobrir, mas é obrigado a cortar mesmo assim

	return rest + louco  # nem naipe líder nem Trunfo: descarte livre


## Dentre os Trunfos disponíveis, os que conseguem cobrir o maior já jogado na rodada.
## Vazio = nenhum consegue cobrir (aí qualquer Trunfo disponível serve).
static func _cover_options(trunfos: Array, plays: Array) -> Array:
	var highest := highest_trunfo(plays)
	return trunfos.filter(func(c: CardData) -> bool: return c.rank > highest)


static func is_legal(card: CardData, hand: Array, plays: Array, must_cover: bool = true) -> bool:
	for c in legal_cards(hand, plays, must_cover):
		if c.equals(card):
			return true
	return false


## Índice (dentro de `plays`) da carta vencedora. Por padrão O Louco nunca vence: Trunfo
## mais alto vence qualquer naipe comum; sem Trunfo, vence a maior carta do naipe líder.
## `louco_can_win` (modo Blitz, modificador "O Louco Vence"): O Louco passa a valer como
## um Trunfo fraquinho — perde pra qualquer Trunfo de verdade, mas vence naipe comum.
static func winning_index(plays: Array, louco_can_win: bool = false) -> int:
	var ls := lead_suit(plays)
	var best := -1
	var best_is_trunfo := false
	var best_rank := -1
	for i in range(plays.size()):
		var c: CardData = plays[i]["card"]
		if c.is_louco():
			if not louco_can_win:
				continue
			if best == -1 or not best_is_trunfo:
				best = i
				best_is_trunfo = true
				best_rank = -1
			continue
		if c.is_trunfo():
			if best == -1 or not best_is_trunfo or c.rank > best_rank:
				best = i
				best_is_trunfo = true
				best_rank = c.rank
		elif not best_is_trunfo and c.suit == ls:
			if best == -1 or c.rank > best_rank:
				best = i
				best_rank = c.rank
	return best


## Se `card` fosse jogada agora pelo `player`, ela venceria a rodada parcial?
static func would_win(card: CardData, player: int, plays: Array, louco_can_win: bool = false) -> bool:
	if card.is_louco() and not louco_can_win:
		return false
	var sim := plays.duplicate()
	sim.append({"player": player, "card": card})
	return winning_index(sim, louco_can_win) == sim.size() - 1


## Cartas jogáveis sob um modificador: no Pitagórico qualquer carta da mão serve (sem obrigação de
## seguir o naipe nem de cortar); nos demais valem as regras de sempre.
static func legal_cards_for(hand: Array, plays: Array, must_cover: bool, modifier: int) -> Array:
	if modifier == BlitzModifiers.Modifier.PITAGORICO:
		return hand.duplicate()
	return legal_cards(hand, plays, must_cover)


## Índice da carta vencedora sob um modificador de jogada (-1 = nenhum). O Louco só vence na Loucura.
##  - Loucura: O Louco vence qualquer carta, até arcano maior.
##  - Oposição: vence a MENOR carta do naipe líder; Trunfo só vale se abriu a jogada (aí o naipe é Trunfo).
##    Nessa jogada de Trunfo, O Louco conta como o menor arcano maior (abaixo do Mago) e vence.
##  - Silêncio: Trunfo não corta; vence a MAIOR carta do naipe líder (se o Trunfo abriu, eles disputam).
##  - Pitagórico: vence o maior Trunfo, se houver; senão o maior número, qualquer naipe (empate: ver TIE_ORDER).
static func winning_index_mod(plays: Array, modifier: int) -> int:
	var mods := BlitzModifiers.Modifier
	var ls := lead_suit(plays)
	match modifier:
		mods.LOUCO_VENCE:
			for i in range(plays.size()):
				if (plays[i]["card"] as CardData).is_louco():
					return i
		mods.VAZA_INVERTIDA:
			var low := -1
			var low_rank := 0
			for i in range(plays.size()):
				var c: CardData = plays[i]["card"]
				var louco_baixo := c.is_louco() and ls == CardData.Suit.TRUNFO   # o Louco é o arcano 0
				if not louco_baixo and (c.is_louco() or c.suit != ls):
					continue
				var r := 0 if louco_baixo else c.rank
				if low == -1 or r < low_rank:
					low = i
					low_rank = r
			if low != -1:
				return low
		mods.SILENCIO:
			if ls != CardData.Suit.TRUNFO:
				var high := -1
				for i in range(plays.size()):
					var c: CardData = plays[i]["card"]
					if c.is_louco() or c.suit != ls:
						continue
					if high == -1 or c.rank > (plays[high]["card"] as CardData).rank:
						high = i
				if high != -1:
					return high
		mods.PITAGORICO:
			var best := -1
			for i in range(plays.size()):
				var c: CardData = plays[i]["card"]
				if c.is_louco():
					continue
				if best == -1 or _pitagorico_beats(c, plays[best]["card"]):
					best = i
			if best != -1:
				return best
	return winning_index(plays, false)


## Pitagórico: `a` vence `b`? Trunfo antes de naipe, depois o maior número, depois o naipe.
static func _pitagorico_beats(a: CardData, b: CardData) -> bool:
	if a.is_trunfo() != b.is_trunfo():
		return a.is_trunfo()
	if a.rank != b.rank:
		return a.rank > b.rank
	if a.is_trunfo():
		return false
	return BlitzModifiers.TIE_ORDER.find(a.suit) < BlitzModifiers.TIE_ORDER.find(b.suit)


## Se `card` fosse jogada agora pelo `player`, ela venceria a jogada parcial sob esse modificador?
static func would_win_mod(card: CardData, player: int, plays: Array, modifier: int) -> bool:
	var sim := plays.duplicate()
	sim.append({"player": player, "card": card})
	return winning_index_mod(sim, modifier) == sim.size() - 1
