class_name ChaosItems
extends RefCounted
## Itens do modo Caos: a cada rodada a partir da 2ª, cada jogador escolhe 1 de 2 itens
## sorteados — uma vantagem ativa que só vale pra quem escolheu, só naquela rodada.
## É a decisão extra que faltava entre as rodadas: o modificador é igual pra mesa toda,
## o item é a resposta de cada jogador a ele.

enum Item { NONE, ESCUDO_NAIPE, TRUNFO_AFIADO, FOLEGO_PESSOAL, ROUBO_VAZA }

const POOL := [Item.ESCUDO_NAIPE, Item.TRUNFO_AFIADO, Item.FOLEGO_PESSOAL, Item.ROUBO_VAZA]

const NAMES := {
	Item.NONE: "Nenhum",
	Item.ESCUDO_NAIPE: "Escudo de Naipe",
	Item.TRUNFO_AFIADO: "Trunfo Afiado",
	Item.FOLEGO_PESSOAL: "Fôlego Pessoal",
	Item.ROUBO_VAZA: "Roubo de Vaza",
}

const ICONS := {
	Item.NONE: "",
	Item.ESCUDO_NAIPE: "🛡",
	Item.TRUNFO_AFIADO: "⚔",
	Item.FOLEGO_PESSOAL: "💨",
	Item.ROUBO_VAZA: "🗡",
}

const DESCRIPTIONS := {
	Item.ESCUDO_NAIPE: "Se a rodada sortear Naipe Fraco, suas cartas desse naipe NÃO perdem valor — só pra você.",
	Item.TRUNFO_AFIADO: "Toda vaza que você vencer com um Trunfo, esse Trunfo vale +1 ponto extra.",
	Item.FOLEGO_PESSOAL: "Todos os pontos que você capturar nessa rodada valem ×1,25 — acumula com o Fôlego da mesa.",
	Item.ROUBO_VAZA: "A 1ª vaza que você vencer nessa rodada rouba 4 pontos de quem está em 1º lugar no total.",
}


## Sorteia 2 itens distintos pra oferecer como escolha.
static func offer(rng: RandomNumberGenerator) -> Array:
	var pool := POOL.duplicate()
	Deck.shuffle(pool, rng)
	return [pool[0], pool[1]]


## Escolha do bot: prioriza o item que combina com o modificador da rodada que vem,
## senão sorteia entre as duas opções oferecidas.
static func bot_choose(options: Array, modifier: int, rng: RandomNumberGenerator) -> int:
	if modifier == ChaosModifiers.Modifier.NAIPE_FRACO and options.has(Item.ESCUDO_NAIPE):
		return Item.ESCUDO_NAIPE
	if modifier == ChaosModifiers.Modifier.TRUNFO_DOBRO and options.has(Item.TRUNFO_AFIADO):
		return Item.TRUNFO_AFIADO
	return options[rng.randi_range(0, options.size() - 1)]
