class_name CardData
extends RefCounted
## Uma carta do baralho de Tarot (78 cartas): 4 naipes de 14 cartas, 21 Trunfos e O Louco.
## Compartilhada pelos modos Clássico e Blitz — só muda quantas cartas cada um recebe na mão.

enum Suit { OUROS, PAUS, COPAS, ESPADAS, TRUNFO, LOUCO }

const SUIT_NAMES := ["Ouros", "Paus", "Copas", "Espadas", "Arcano Maior", "O Louco"]
const SUIT_SYMBOLS := ["♦", "♣", "♥", "♠", "✦", "✶"]

## Os 3 "Bouts" (cartas de ponta): Le Petit, Le Monde e O Louco. Valem 4,5 pontos cada,
## igual a um Rei — são as cartas que decidem a pontuação do nível.
const PETIT := 1
const MONDE := 21

var suit: int = Suit.OUROS
## Naipes comuns: 1 (Ás) a 14 (Rei). Trunfo: 1 a 21. O Louco: sempre 0.
var rank: int = 1


static func make(p_suit: int, p_rank: int) -> CardData:
	var c := CardData.new()
	c.suit = p_suit
	c.rank = p_rank
	return c


static func louco() -> CardData:
	return make(Suit.LOUCO, 0)


func is_trunfo() -> bool:
	return suit == Suit.TRUNFO


func is_louco() -> bool:
	return suit == Suit.LOUCO


## Bout: as 3 cartas mais valiosas do baralho (Le Petit, Le Monde e O Louco).
func is_bout() -> bool:
	return is_louco() or (is_trunfo() and (rank == PETIT or rank == MONDE))


## Valor de comparação dentro do próprio naipe/trunfo (maior vence). O Louco nunca é
## comparado por valor — ele nunca vence uma rodada (ver TrickRules.winning_index).
func value() -> int:
	return rank


## Pontuação oficial do Jeu de Tarot: Rei/Bout = 4,5 · Rainha = 3,5 · Cavaleiro = 2,5 ·
## Valete = 1,5 · qualquer outra carta (números e trunfos comuns) = 0,5.
func points() -> float:
	if is_bout():
		return 4.5
	if is_trunfo():
		return 0.5
	match rank:
		14: return 4.5  # Rei
		13: return 3.5  # Rainha
		12: return 2.5  # Cavaleiro
		11: return 1.5  # Valete
		_: return 0.5


func rank_label() -> String:
	if is_louco():
		return "✶"
	if is_trunfo():
		return str(rank)
	match rank:
		1: return "A"
		11: return "J"
		12: return "N"
		13: return "Q"
		14: return "K"
	return str(rank)


func suit_symbol() -> String:
	return SUIT_SYMBOLS[suit]


func display_name() -> String:
	if is_louco():
		return "O Louco"
	if is_trunfo():
		var label := "Le Petit" if rank == PETIT else ("Le Monde" if rank == MONDE else "Arcano %d" % rank)
		return label
	var names := {1: "Ás", 11: "Valete", 12: "Cavaleiro", 13: "Rainha", 14: "Rei"}
	var r: String = names.get(rank, str(rank))
	return "%s de %s" % [r, SUIT_NAMES[suit]]


func key() -> String:
	return "%d:%d" % [suit, rank]


func equals(other: CardData) -> bool:
	return other != null and other.suit == suit and other.rank == rank


func to_dict() -> Dictionary:
	return {"suit": suit, "rank": rank}


static func from_dict(d: Dictionary) -> CardData:
	return make(int(d.get("suit", 0)), int(d.get("rank", 1)))
