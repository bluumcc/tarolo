class_name Scoring
extends RefCounted
## O "coração Balatro": Fichas x Mult de cada vaza.
## Ordem de aplicação: Fichas (base + Foil + curingas) -> +Mult -> xMult (Polychrome,
## sinergias, curingas, multiplicador de fase).

const BASE_MULT := 1.0
const MONOPOLY_XMULT := 2.0
const SEQUENCE_XMULT := 2.5
const SEQUENCE_MIN_CARDS := 3


## Monopólio de Naipe: todas as cartas da vaza do mesmo naipe (Arcanos quebram o monopólio).
## `tolerance` = quantas cartas podem destoar (curinga Caos Ordenado = 1).
static func is_monopoly(cards: Array, tolerance: int = 0) -> bool:
	if cards.size() < 2:
		return false
	var counts := {}
	for c in cards:
		var s: int = (c as CardData).suit
		counts[s] = counts.get(s, 0) + 1
	var best_suit := -1
	var best := 0
	for s in counts.keys():
		if s != CardData.Suit.ARCANA and counts[s] > best:
			best = counts[s]
			best_suit = s
	if best_suit == -1:
		return false
	return cards.size() - best <= tolerance and best >= 2


## Sequência Caótica: valores consecutivos (em qualquer ordem de jogada), ex. 4-5-6-7.
static func is_sequence(cards: Array) -> bool:
	if cards.size() < SEQUENCE_MIN_CARDS:
		return false
	var ranks: Array = []
	for c in cards:
		if (c as CardData).is_arcana():
			return false
		ranks.append((c as CardData).rank)
	ranks.sort()
	for i in range(1, ranks.size()):
		if ranks[i] != ranks[i - 1] + 1:
			return false
	return true


## Avalia a pontuação de uma vaza para quem a venceu.
## `winner_card` = carta que venceu; `jokers` = ids dos curingas do vencedor.
static func evaluate(cards: Array, winner_card: CardData, jokers: Array = [], stage_mult: float = 1.0) -> Dictionary:
	var chips := 0
	var add_mult := BASE_MULT
	var x_mult := 1.0
	var synergies: Array = []
	var modified := 0

	var foil_bonus := CardData.FOIL_CHIPS * (2 if jokers.has("espelho") else 1)
	var poly_x := 3.0 if jokers.has("prisma") else CardData.POLY_XMULT

	for c in cards:
		var card: CardData = c
		chips += card.base_chips()
		if card.is_arcana() and jokers.has("eclipse"):
			chips += 30
		if card.rank == 1 and not card.is_arcana() and jokers.has("as_oculto"):
			chips += 25
		if card.suit == CardData.Suit.COPAS and jokers.has("copas_sangrentas"):
			add_mult += 3
		match card.modifier:
			CardData.Modifier.FOIL:
				chips += foil_bonus
				modified += 1
			CardData.Modifier.POLYCHROME:
				x_mult *= poly_x
				modified += 1

	if jokers.has("mesa_cheia"):
		chips += 8 * cards.size()
	if jokers.has("louco"):
		add_mult += 4

	if is_monopoly(cards, 1 if jokers.has("caos") else 0):
		x_mult *= MONOPOLY_XMULT
		synergies.append("Monopólio de Naipe")
	if is_sequence(cards):
		x_mult *= 3.5 if jokers.has("escada_ceu") else SEQUENCE_XMULT
		synergies.append("Sequência Caótica")
	if jokers.has("monarca") and winner_card != null and not winner_card.is_arcana() and winner_card.rank == 13:
		x_mult *= 1.5
		synergies.append("Monarca")
	if jokers.has("torre") and modified >= 2:
		x_mult *= 2.0
		synergies.append("A Torre")

	x_mult *= stage_mult
	var mult := add_mult * x_mult
	return {
		"chips": chips,
		"mult": mult,
		"total": int(round(chips * mult)),
		"synergies": synergies,
	}
