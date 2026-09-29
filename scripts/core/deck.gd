class_name Deck
extends RefCounted
## Monta e distribui o baralho fixo de 78 cartas do Tarot: 4 naipes × 14 (Ás a Rei,
## passando por Valete/Cavaleiro/Rainha) + 21 Trunfos + O Louco.

const TOTAL_CARDS := 78
const CHIEN_SIZE := 6  # talão do modo Vanilla (4 jogadores × 18 cartas + 6 = 78)


## Baralho completo e embaralhado. Sempre as mesmas 78 cartas — nada é sorteado "dentre"
## um subconjunto, como no protótipo antigo.
static func build(rng: RandomNumberGenerator) -> Array:
	var cards: Array = []
	for s in [CardData.Suit.OUROS, CardData.Suit.PAUS, CardData.Suit.COPAS, CardData.Suit.ESPADAS]:
		for r in range(1, 15):
			cards.append(CardData.make(s, r))
	for r in range(1, 22):
		cards.append(CardData.make(CardData.Suit.TRUNFO, r))
	cards.append(CardData.louco())
	shuffle(cards, rng)
	return cards


## Fisher-Yates determinístico (usa o RNG da partida para permitir seeds/replays).
static func shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## Distribui `per_player` cartas para cada jogador a partir do baralho já embaralhado.
## O que sobra vira "rest" — no Vanilla (18 cartas/jogador) são as 6 do talão (chien);
## no Caos (8 cartas/jogador) é o restante do baralho, não usado nessa rodada.
static func deal(cards: Array, players: int, per_player: int) -> Dictionary:
	var hands: Array = []
	for p in range(players):
		hands.append([])
	var idx := 0
	for p in range(players):
		for i in range(per_player):
			hands[p].append(cards[idx])
			idx += 1
	var rest: Array = cards.slice(idx)
	for h in hands:
		sort_hand(h)
	return {"hands": hands, "rest": rest}


static func sort_hand(hand: Array) -> void:
	hand.sort_custom(func(a: CardData, b: CardData) -> bool:
		if a.suit != b.suit:
			return a.suit < b.suit
		return a.rank < b.rank)
