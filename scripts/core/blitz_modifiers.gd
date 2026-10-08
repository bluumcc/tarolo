class_name BlitzModifiers
extends RefCounted
## Modificadores do Blitz: SEMPRE por uma jogada só. Cada Ritual sorteia uma ordem embaralhada
## dos 8 (sem repetir dentro do Ritual) e cada uma das 8 jogadas usa a próxima da lista. Sempre
## anunciado numa tela cheia antes da jogada começar — nenhum é surpresa: dá tempo de pensar e
## de decidir se vale a pena tentar vencer aquela jogada específica.
## Nenhum mexe no valor (pontos) das cartas: só em quem vence, em quantas vitórias a jogada conta
## ou em fichas movidas pelo blind (todos os de ficha movem o mesmo total).

enum Modifier {
	LOUCO_VENCE, VAZA_INVERTIDA, VAZA_DOURADA, SAQUE, ASSALTO_LIDER, VAZA_MALDITA, SILENCIO, PITAGORICO,
}

## Os 8 modificadores: um por jogada do Ritual, sem repetir.
const ALL := [
	Modifier.LOUCO_VENCE, Modifier.VAZA_INVERTIDA, Modifier.VAZA_DOURADA, Modifier.SAQUE,
	Modifier.ASSALTO_LIDER, Modifier.VAZA_MALDITA, Modifier.SILENCIO, Modifier.PITAGORICO,
]

const NAMES := {
	Modifier.LOUCO_VENCE: "Loucura",
	Modifier.VAZA_INVERTIDA: "Oposição",
	Modifier.VAZA_DOURADA: "Transmutação",
	Modifier.SAQUE: "Saque",
	Modifier.ASSALTO_LIDER: "Assalto",
	Modifier.VAZA_MALDITA: "Maldição",
	Modifier.SILENCIO: "Silêncio",
	Modifier.PITAGORICO: "Pitagórico",
}

const ICONS := {
	Modifier.LOUCO_VENCE: "🃏", Modifier.VAZA_INVERTIDA: "⇅", Modifier.VAZA_DOURADA: "★",
	Modifier.SAQUE: "⚔", Modifier.ASSALTO_LIDER: "♛", Modifier.VAZA_MALDITA: "☠",
	Modifier.SILENCIO: "⊘", Modifier.PITAGORICO: "Σ",
}

## Texto curto (uma linha, entende-se em segundos). Serve de descrição na tela e na faixa da mesa.
const DESCRIPTIONS := {
	Modifier.LOUCO_VENCE: "O Louco vence qualquer carta, até arcano maior.",
	Modifier.VAZA_INVERTIDA: "Vence a menor carta do naipe. Arcano maior só vale se abrir a jogada.",
	Modifier.VAZA_DOURADA: "O vencedor conta 2 vitórias na profecia.",
	Modifier.SAQUE: "O vencedor rouba 3 blinds, divididos entre os rivais.",
	Modifier.ASSALTO_LIDER: "O vencedor rouba 3 blinds do rival com mais fichas.",
	Modifier.VAZA_MALDITA: "O vencedor paga 3 blinds, divididos entre os rivais.",
	Modifier.SILENCIO: "Arcano maior não vence naipe. Vence a maior carta do naipe.",
	Modifier.PITAGORICO: "Jogue qualquer naipe. Vence o maior número e o arcano maior ainda vence.",
}

## Dica de jogada — o que fazer DIFERENTE por causa do modificador dessa jogada.
const TIPS := {
	Modifier.LOUCO_VENCE: "Quem tiver O Louco na mão ganha a jogada na hora, se o jogar.",
	Modifier.VAZA_INVERTIDA: "Jogue baixo para ganhar. Se um arcano maior abrir a jogada, vence o menor arcano maior.",
	Modifier.VAZA_DOURADA: "Faltam 2 vitórias para a sua profecia? Ganhar só essa já fecha a conta. Se não quer ganhar, fuja dela.",
	Modifier.SAQUE: "Ganhar rende fichas dos rivais, além de contar a vitória. Só ganhe se também servir à sua profecia.",
	Modifier.ASSALTO_LIDER: "Rouba do rival com mais fichas na mesa, não de quem está perto na profecia.",
	Modifier.VAZA_MALDITA: "Ganhar custa fichas de verdade, além de contar a vitória. Pense bem antes de forçar.",
	Modifier.SILENCIO: "Quem não tem o naipe ainda é obrigado a jogar arcano maior, que não vence. Se um arcano maior abrir a jogada, eles disputam entre si.",
	Modifier.PITAGORICO: "Toda a mão pode ser jogada. Se houver arcano maior na mesa, vence o maior deles. Empate de número: vale o naipe.",
}

## Fichas movidas (em blinds) pelos três modificadores de ficha: o mesmo total em qualquer mesa.
const STEAL_BLINDS := 3

## Desempate do Pitagórico, do mais forte ao mais fraco: Espadas, Copas, Paus, Ouros.
const TIE_ORDER := [CardData.Suit.ESPADAS, CardData.Suit.COPAS, CardData.Suit.PAUS, CardData.Suit.OUROS]

const COMBO_NAMES := {
	"MAO_QUENTE": "MÃO QUENTE",
	"CORTADO": "CORTADO",
	"CORTE_REI": "CORTE DE REI",
	"CHUVA_TRUNFOS": "CHUVA DE ARCANOS",
	"REALEZA": "REALEZA",
	"ESCADA": "ESCADA",
}

const COMBO_DESCRIPTIONS := {
	"MAO_QUENTE": "3 jogadas seguidas: pontos ×1,5 (4 seguidas: ×2)",
	"CORTADO": "Você quebrou a sequência de alguém: +2 pts",
	"CORTE_REI": "Cortou um Rei com arcano maior: +3 pts",
	"CHUVA_TRUNFOS": "3 ou mais arcanos maiores na mesa: pontos ×2",
	"REALEZA": "3 ou mais figuras (Valete, Cavaleiro, Dama, Rei) na mesa: pontos ×1,5",
	"ESCADA": "3 cartas seguidas do mesmo naipe na mesa: +3 pts",
}


## Os 8 modificadores são sorteáveis (o Blitz usa todos).
static func blitz_pool() -> Array:
	return ALL.duplicate()


static func color_of(modifier: int) -> Color:
	if modifier in [Modifier.SAQUE, Modifier.VAZA_MALDITA, Modifier.ASSALTO_LIDER]:
		return UIKit.LOSS         # perda / perigo
	return UIKit.COMBO


## Rótulo pronto pra tela.
static func label(modifier: int) -> String:
	return str(NAMES[modifier])


static func name_of(modifier: int) -> String:
	return str(NAMES[modifier])


static func desc_of(modifier: int) -> String:
	return str(DESCRIPTIONS[modifier])


## Descrição de uma linha (cabe na faixa do card da mesa).
static func short_of(modifier: int) -> String:
	return str(DESCRIPTIONS[modifier])


static func tip_of(modifier: int) -> String:
	return str(TIPS[modifier])
