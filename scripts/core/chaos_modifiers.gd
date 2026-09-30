class_name ChaosModifiers
extends RefCounted
## Modificadores do Caos/Blitz: SEMPRE por uma vaza só. Cada nível sorteia uma ordem embaralhada
## dos 12 (sem repetir dentro do nível) e cada uma das 8 vazas usa a próxima da lista. Sempre
## anunciado numa tela cheia antes da vaza começar — nenhum é surpresa: dá tempo de pensar e, no
## Blitz, de decidir se vale a pena tentar vencer aquela vaza específica.

enum Modifier {
	TRUNFO_DOBRO, FIGURAS_DOBRO, LOUCO_VENCE, NAIPE_FRACO, NAIPE_FORTE, VAZA_INVERTIDA,
	VAZA_MAIS_UM, PEQUENAS_IMPORTAM, VAZA_DOURADA, SAQUE, ASSALTO_LIDER, VAZA_MALDITA,
}

## Os 11 modificadores ativos (Cada Rodada Vale +1 foi removido; o enum mantém o valor só por compatibilidade) — todo nível embaralha esta lista e usa 8, um por vaza.
const ALL := [
	Modifier.TRUNFO_DOBRO, Modifier.FIGURAS_DOBRO, Modifier.LOUCO_VENCE, Modifier.NAIPE_FRACO,
	Modifier.NAIPE_FORTE, Modifier.VAZA_INVERTIDA, Modifier.PEQUENAS_IMPORTAM,
	Modifier.VAZA_DOURADA, Modifier.SAQUE, Modifier.ASSALTO_LIDER, Modifier.VAZA_MALDITA,
]
## Modificadores que sorteiam um naipe-alvo.
const SUIT_MODS := [Modifier.NAIPE_FRACO, Modifier.NAIPE_FORTE]
## No Blitz, só estes mudam fichas ou quem vence de verdade; os demais só valem no Caos (o
## motor não move nada com eles no Blitz — a tela avisa).
const BLITZ_EFFECT := [
	Modifier.LOUCO_VENCE, Modifier.VAZA_INVERTIDA, Modifier.VAZA_DOURADA, Modifier.SAQUE,
	Modifier.ASSALTO_LIDER, Modifier.VAZA_MALDITA,
]

const NAMES := {
	Modifier.TRUNFO_DOBRO: "Trunfo em Dobro",
	Modifier.FIGURAS_DOBRO: "Figuras em Dobro",
	Modifier.LOUCO_VENCE: "O Louco Vence",
	Modifier.NAIPE_FRACO: "Naipe Fraco",
	Modifier.NAIPE_FORTE: "Naipe Forte",
	Modifier.VAZA_INVERTIDA: "Rodada Invertida",
	Modifier.VAZA_MAIS_UM: "Cada Rodada Vale +1",
	Modifier.PEQUENAS_IMPORTAM: "Cartas Pequenas Importam",
	Modifier.VAZA_DOURADA: "Rodada Dourada",
	Modifier.SAQUE: "Saque",
	Modifier.ASSALTO_LIDER: "Assalto ao Líder",
	Modifier.VAZA_MALDITA: "Rodada Maldita",
}

const ICONS := {
	Modifier.TRUNFO_DOBRO: "✦", Modifier.FIGURAS_DOBRO: "♛", Modifier.LOUCO_VENCE: "🃏",
	Modifier.NAIPE_FRACO: "▽", Modifier.NAIPE_FORTE: "▲", Modifier.VAZA_INVERTIDA: "⇅",
	Modifier.VAZA_MAIS_UM: "+1", Modifier.PEQUENAS_IMPORTAM: "•", Modifier.VAZA_DOURADA: "★",
	Modifier.SAQUE: "⚔", Modifier.ASSALTO_LIDER: "♛", Modifier.VAZA_MALDITA: "☠",
}

const DESCRIPTIONS := {
	Modifier.TRUNFO_DOBRO: "Toda carta de Trunfo vale o DOBRO de pontos nessa rodada.",
	Modifier.FIGURAS_DOBRO: "Valete, Cavaleiro, Dama e Rei valem o DOBRO de pontos nessa rodada.",
	Modifier.LOUCO_VENCE: "Nessa rodada O Louco PODE vencer, como um Trunfo fraquinho (perde pra Trunfo de verdade, vence naipe comum).",
	Modifier.NAIPE_FRACO: "Um naipe sorteado vale só METADE dos pontos nessa rodada.",
	Modifier.NAIPE_FORTE: "Um naipe sorteado vale 1,5× os pontos nessa rodada.",
	Modifier.VAZA_INVERTIDA: "Nessa rodada vence a MENOR carta do naipe. Trunfo não corta.",
	Modifier.VAZA_MAIS_UM: "Quem vencer essa rodada ganha +1 ponto fixo.",
	Modifier.PEQUENAS_IMPORTAM: "Nessa rodada, as cartas de 0,5 ponto valem 1,0.",
	Modifier.VAZA_DOURADA: "Os pontos dessa rodada valem ×3.",
	Modifier.SAQUE: "Quem vencer essa rodada rouba 2 pontos de cada rival.",
	Modifier.ASSALTO_LIDER: "Quem vencer essa rodada rouba 4 pontos de quem lidera o placar.",
	Modifier.VAZA_MALDITA: "Quem vencer essa rodada PERDE 3 pontos. Todo mundo quer perder!",
}

## Dica de jogada — o que fazer DIFERENTE por causa do modificador dessa rodada.
const TIPS := {
	Modifier.TRUNFO_DOBRO: "Vale gastar um Trunfo forte agora: essa rodada paga o dobro.",
	Modifier.FIGURAS_DOBRO: "Se tiver uma figura na mão, essa é a hora de jogá-la.",
	Modifier.LOUCO_VENCE: "O Louco pode roubar a rodada de qualquer naipe comum. Use-o como arma, não como fuga.",
	Modifier.NAIPE_FRACO: "Livre-se agora das cartas desse naipe: elas não valem quase nada nessa rodada.",
	Modifier.NAIPE_FORTE: "Vale disputar essa rodada com esse naipe: paga mais que o normal.",
	Modifier.VAZA_INVERTIDA: "Tudo se inverte: a menor carta vence. Jogue baixo se quiser ganhar.",
	Modifier.VAZA_MAIS_UM: "Rodada pequena que ainda compensa: vale +1 ponto fixo além do normal.",
	Modifier.PEQUENAS_IMPORTAM: "Até a carta mais fraca da mão rende o dobro agora.",
	Modifier.VAZA_DOURADA: "Essa rodada vale ×3. Se tiver uma carta forte, é a hora de usá-la.",
	Modifier.SAQUE: "Vencer essa rodada rouba pontos dos rivais, além do normal.",
	Modifier.ASSALTO_LIDER: "Vencer essa rodada rouba de quem lidera o placar.",
	Modifier.VAZA_MALDITA: "Vencer essa rodada custa pontos. Tente perder essa uma!",
}

## No Blitz, Rodada Dourada não multiplica pontos (o Blitz não tem prêmio em pontos): conta
## como 2 vitórias no palpite. Saque/Assalto/Maldita continuam mexendo em fichas (efeito à
## parte do palpite); os demais 5 não têm efeito nenhum no Blitz — só valem no Caos.
const BLITZ_NAMES := {Modifier.VAZA_DOURADA: "Rodada Dobrada"}
const BLITZ_DESCRIPTIONS := {
	Modifier.VAZA_DOURADA: "Quem vencer essa rodada conta 2 vitórias no palpite, em vez de 1.",
	Modifier.SAQUE: "Quem vencer essa rodada rouba fichas de cada rival, além de contar a vitória.",
	Modifier.ASSALTO_LIDER: "Quem vencer essa rodada rouba fichas de quem lidera a stack, além de contar a vitória.",
	Modifier.VAZA_MALDITA: "Quem vencer essa rodada PAGA fichas aos rivais, além de contar a vitória.",
}
const BLITZ_TIPS := {
	Modifier.VAZA_DOURADA: "Muda a conta do palpite: se você quer 2 vitórias, basta ganhar só essa. Se não quer, fuja dela.",
	Modifier.SAQUE: "Vencer rende fichas extras aqui, mas só conta 1 vitória — vença só se também servir ao seu palpite.",
	Modifier.ASSALTO_LIDER: "Rouba de quem tem mais fichas na mesa, não necessariamente de quem está por perto no palpite.",
	Modifier.VAZA_MALDITA: "Vencer aqui custa fichas de verdade, não só a conta do palpite. Pense bem antes de forçar essa vitória.",
}
## Efeito genérico mostrado quando o modificador não move fichas no Blitz (os outros 5).
const BLITZ_NO_EFFECT_NOTE := "No Blitz isso só vale no Caos: aqui não muda nenhuma ficha, só quem vence a rodada conta pro seu palpite."

const COMBO_NAMES := {
	"MAO_QUENTE": "MÃO QUENTE",
	"CORTADO": "CORTADO",
	"CORTE_REI": "CORTE DE REI",
	"CHUVA_TRUNFOS": "CHUVA DE TRUNFOS",
	"REALEZA": "REALEZA",
	"ESCADA": "ESCADA",
}

const COMBO_DESCRIPTIONS := {
	"MAO_QUENTE": "3 rodadas seguidas: pontos ×1,5 (4 seguidas: ×2)",
	"CORTADO": "Você quebrou a sequência de alguém: +2 pts",
	"CORTE_REI": "Cortou um Rei com Trunfo: +3 pts",
	"CHUVA_TRUNFOS": "3 ou mais Trunfos na mesa: pontos ×2",
	"REALEZA": "3 ou mais figuras (Valete, Cavaleiro, Dama, Rei) na mesa: pontos ×1,5",
	"ESCADA": "3 cartas seguidas do mesmo naipe na mesa: +3 pts",
}


static func has_suit(modifier: int) -> bool:
	return SUIT_MODS.has(modifier)


## Verdadeiro se esse modificador move fichas de verdade no Blitz (os outros só valem no Caos).
static func has_blitz_effect(modifier: int) -> bool:
	return BLITZ_EFFECT.has(modifier)


static func color_of(modifier: int) -> Color:
	if modifier in [Modifier.SAQUE, Modifier.VAZA_MALDITA, Modifier.ASSALTO_LIDER]:
		return UIKit.LOSS         # perda / perigo
	return UIKit.COMBO


## Rótulo pronto pra tela — inclui o naipe sorteado quando o modificador tem naipe.
static func label(modifier: int, weak_suit: int) -> String:
	if has_suit(modifier) and weak_suit != -1:
		return "%s (%s)" % [NAMES[modifier], CardData.SUIT_NAMES[weak_suit]]
	return NAMES[modifier]


## Texto do modificador conforme o modo (Blitz reescreve alguns).
static func name_of(modifier: int, blitz := false) -> String:
	return str(BLITZ_NAMES[modifier]) if blitz and BLITZ_NAMES.has(modifier) else str(NAMES[modifier])


static func desc_of(modifier: int, blitz := false) -> String:
	if blitz and BLITZ_DESCRIPTIONS.has(modifier):
		return str(BLITZ_DESCRIPTIONS[modifier])
	if blitz and not has_blitz_effect(modifier):
		return "%s %s" % [str(DESCRIPTIONS[modifier]), BLITZ_NO_EFFECT_NOTE]
	return str(DESCRIPTIONS[modifier])


static func tip_of(modifier: int, blitz := false) -> String:
	return str(BLITZ_TIPS[modifier]) if blitz and BLITZ_TIPS.has(modifier) else str(TIPS[modifier])
