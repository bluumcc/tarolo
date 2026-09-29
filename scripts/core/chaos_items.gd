class_name ChaosItems
extends RefCounted
## Poderes do modo Caos: no começo de cada rodada você escolhe 1 dos 3 e o usa UMA vez,
## quando quiser, na sua vez (botão PODER na mesa). Simples de entender e cada um muda
## o jogo de um jeito: pegar carta, ver informação ou apostar a vaza.

enum Item { NONE, TROCA, ESPIADA, ARRISCAR }

const POOL := [Item.TROCA, Item.ESPIADA, Item.ARRISCAR]

const NAMES := {
	Item.NONE: "Nenhum",
	Item.TROCA: "Roubar Trunfo",
	Item.ESPIADA: "Espiar",
	Item.ARRISCAR: "Arriscar",
}

const ICONS := {
	Item.NONE: "",
	Item.TROCA: "⇅",
	Item.ESPIADA: "◎",
	Item.ARRISCAR: "⚡",
}

const DESCRIPTIONS := {
	Item.TROCA: "Escolha um rival: você entrega sua carta mais fraca e leva o melhor Trunfo dele.",
	Item.ESPIADA: "Escolha um rival e veja a mão inteira dele.",
	Item.ARRISCAR: "Na vaza que você escolher: se vencer, ×2 nos pontos. Se perder, −2.",
}

const SHORT := {
	Item.TROCA: "Troca sua pior carta por um Trunfo de um rival",
	Item.ESPIADA: "Vê a mão de um rival",
	Item.ARRISCAR: "Vaza vale ×2 se vencer, −2 se perder",
}


## Os 3 poderes, em ordem embaralhada.
static func offer(rng: RandomNumberGenerator) -> Array:
	var pool := POOL.duplicate()
	Deck.shuffle(pool, rng)
	return pool
