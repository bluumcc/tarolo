class_name ChaosEvents
extends RefCounted
## Eventos surpresa do modo Caos: um por rodada, sorteado no começo mas só REVELADO na
## vaza 4 — a virada que ninguém vê chegando. Também guarda os textos dos combos.

enum Event { NONE, DOURADA, INVERTIDA, SAQUE }

const ALL := [Event.DOURADA, Event.INVERTIDA, Event.SAQUE]

const NAMES := {
	Event.DOURADA: "VAZA DOURADA",
	Event.INVERTIDA: "VAZA INVERTIDA",
	Event.SAQUE: "SAQUE",
}

const ICONS := {
	Event.DOURADA: "★",
	Event.INVERTIDA: "⇅",
	Event.SAQUE: "🗡",
}

const DESCRIPTIONS := {
	Event.DOURADA: "Os pontos dessa vaza valem ×3. Quem levar, vira o jogo.",
	Event.INVERTIDA: "Nessa vaza vence a MENOR carta do naipe da rodada. Trunfo não corta.",
	Event.SAQUE: "Quem vencer essa vaza rouba 2 pontos de cada rival.",
}

const COLORS := {
	Event.DOURADA: Color("#E8C170"),
	Event.INVERTIDA: Color("#C792EA"),
	Event.SAQUE: Color("#FF5C7A"),
}

const COMBO_NAMES := {
	"MAO_QUENTE": "MÃO QUENTE",
	"CORTADO": "CORTADO",
	"CORTE_REI": "CORTE DE REI",
}

const COMBO_DESCRIPTIONS := {
	"MAO_QUENTE": "3 vazas seguidas: pontos ×1,5",
	"CORTADO": "Você quebrou a sequência de alguém: +2 pts",
	"CORTE_REI": "Cortou um Rei com Trunfo: +3 pts",
}
