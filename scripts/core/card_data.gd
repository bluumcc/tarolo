class_name CardData
extends RefCounted
## Dados puros de uma carta. Não conhece a UI.

enum Suit { OUROS, PAUS, COPAS, ESPADAS, ARCANA }
enum Modifier { NONE, FOIL, POLYCHROME }

const SUIT_NAMES := ["Ouros", "Paus", "Copas", "Espadas", "Arcano Maior"]
const SUIT_SYMBOLS := ["♦", "♣", "♥", "♠", "✶"]
const MODIFIER_NAMES := ["Padrão", "Foil", "Polychrome"]
const ARCANA_VALUE := 15
const FOIL_CHIPS := 50
const POLY_XMULT := 2.0

const MAJOR_ARCANA := [
	"O Louco", "O Mago", "A Sacerdotisa", "A Imperatriz", "O Imperador",
	"O Hierofante", "Os Enamorados", "O Carro", "A Força", "O Eremita",
	"A Roda da Fortuna", "A Justiça", "O Enforcado", "A Morte", "A Temperança",
	"O Diabo", "A Torre", "A Estrela", "A Lua", "O Sol", "O Julgamento", "O Mundo",
]
const ROMAN := [
	"0", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
	"XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX", "XXI",
]

var suit: int = Suit.OUROS
## 1 (Ás) a 13 (Rei). Para Arcanos Maiores, índice 0..21 do arcano.
var rank: int = 1
var modifier: int = Modifier.NONE


static func make(p_suit: int, p_rank: int, p_modifier: int = Modifier.NONE) -> CardData:
	var c := CardData.new()
	c.suit = p_suit
	c.rank = p_rank
	c.modifier = p_modifier
	return c


func is_arcana() -> bool:
	return suit == Suit.ARCANA


## Valor numérico usado na disputa da vaza. O Ás vale 1 (menor carta do naipe).
func value() -> int:
	return ARCANA_VALUE if is_arcana() else rank


## Fichas base que a carta soma ao placar (sem modificadores).
func base_chips() -> int:
	return value()


## Identificador estável da carta dentro do baralho (usado para upgrades da loja).
func key() -> String:
	return "%d:%d" % [suit, rank]


func rank_label() -> String:
	if is_arcana():
		return ROMAN[rank]
	match rank:
		1: return "A"
		11: return "J"
		12: return "Q"
		13: return "K"
	return str(rank)


func suit_symbol() -> String:
	return SUIT_SYMBOLS[suit]


func display_name() -> String:
	if is_arcana():
		return "%s (%s)" % [MAJOR_ARCANA[rank], ROMAN[rank]]
	var names := {1: "Ás", 11: "Valete", 12: "Dama", 13: "Rei"}
	var r: String = names.get(rank, str(rank))
	return "%s de %s" % [r, SUIT_NAMES[suit]]


func equals(other: CardData) -> bool:
	return other != null and other.suit == suit and other.rank == rank


func to_dict() -> Dictionary:
	return {"suit": suit, "rank": rank, "modifier": modifier}


static func from_dict(d: Dictionary) -> CardData:
	return make(int(d.get("suit", 0)), int(d.get("rank", 1)), int(d.get("modifier", 0)))


static func key_to_name(k: String) -> String:
	var parts := k.split(":")
	if parts.size() != 2:
		return k
	return make(int(parts[0]), int(parts[1])).display_name()
