class_name Deck
extends RefCounted
## Montagem, embaralhamento e distribuição do baralho.

const DROP_POLYCHROME := 0.04
const DROP_FOIL := 0.08


## Baralho padrão de 52 cartas (4 naipes x 13) + `arcana_count` Arcanos Maiores sorteados.
## `with_modifiers` aplica a taxa de drop do Arcade (88% / 8% / 4%).
## `upgrades` (chave -> Modifier) força modificadores comprados na Loja Arcana.
static func build(rng: RandomNumberGenerator, arcana_count: int = 4, with_modifiers: bool = false, upgrades: Dictionary = {}) -> Array:
	var cards: Array = []
	for s in [CardData.Suit.OUROS, CardData.Suit.PAUS, CardData.Suit.COPAS, CardData.Suit.ESPADAS]:
		for r in range(1, 14):
			cards.append(CardData.make(s, r))
	var arcana_pool: Array = range(CardData.MAJOR_ARCANA.size())
	shuffle(arcana_pool, rng)
	for i in range(clampi(arcana_count, 0, arcana_pool.size())):
		cards.append(CardData.make(CardData.Suit.ARCANA, arcana_pool[i]))
	for c in cards:
		if upgrades.has(c.key()):
			c.modifier = int(upgrades[c.key()])
		elif with_modifiers:
			c.modifier = roll_modifier(rng)
	shuffle(cards, rng)
	return cards


static func roll_modifier(rng: RandomNumberGenerator) -> int:
	var roll := rng.randf()
	if roll < DROP_POLYCHROME:
		return CardData.Modifier.POLYCHROME
	if roll < DROP_POLYCHROME + DROP_FOIL:
		return CardData.Modifier.FOIL
	return CardData.Modifier.NONE


## Fisher-Yates determinístico (usa o RNG da partida para permitir seeds/replays).
static func shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## Distribui as cartas igualmente; sobras ficam fora da rodada.
static func deal(cards: Array, players: int) -> Array:
	var hands: Array = []
	for p in range(players):
		hands.append([])
	var per_player := cards.size() / players
	for i in range(per_player * players):
		hands[i % players].append(cards[i])
	for h in hands:
		sort_hand(h)
	return hands


static func sort_hand(hand: Array) -> void:
	hand.sort_custom(func(a: CardData, b: CardData) -> bool:
		if a.suit != b.suit:
			return a.suit < b.suit
		return a.rank < b.rank)
