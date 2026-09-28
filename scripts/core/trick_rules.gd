class_name TrickRules
extends RefCounted
## Regras da vaza. `plays` é um Array de { "player": int, "card": CardData } na ordem jogada.


## Naipe líder: o da primeira carta numérica jogada. Se a vaza abriu com um Arcano,
## a primeira carta de naipe que vier depois define o naipe a seguir. -1 = livre.
static func lead_suit(plays: Array) -> int:
	for p in plays:
		var c: CardData = p["card"]
		if not c.is_arcana():
			return c.suit
	return -1


## Cartas que o jogador pode jogar agora. Quem tem o naipe líder é obrigado a segui-lo,
## mas Arcanos Maiores ignoram a restrição e sempre podem ser jogados.
static func legal_cards(hand: Array, plays: Array) -> Array:
	var ls := lead_suit(plays)
	if ls == -1:
		return hand.duplicate()
	var follow := hand.filter(func(c: CardData) -> bool: return c.suit == ls)
	if follow.is_empty():
		return hand.duplicate()
	return follow + hand.filter(func(c: CardData) -> bool: return c.is_arcana())


static func is_legal(card: CardData, hand: Array, plays: Array) -> bool:
	for c in legal_cards(hand, plays):
		if c == card:
			return true
	return false


## Índice (dentro de `plays`) da carta vencedora.
## O primeiro Arcano Maior jogado vence; sem Arcanos, vence a maior carta do naipe líder.
static func winning_index(plays: Array) -> int:
	if plays.is_empty():
		return -1
	for i in range(plays.size()):
		if (plays[i]["card"] as CardData).is_arcana():
			return i
	var ls := lead_suit(plays)
	var best := -1
	for i in range(plays.size()):
		var c: CardData = plays[i]["card"]
		if c.suit != ls:
			continue
		if best == -1 or c.rank > (plays[best]["card"] as CardData).rank:
			best = i
	return best


## Se `card` fosse jogada agora pelo `player`, ela venceria a vaza parcial?
static func would_win(card: CardData, player: int, plays: Array) -> bool:
	var sim := plays.duplicate()
	sim.append({"player": player, "card": card})
	return winning_index(sim) == sim.size() - 1
