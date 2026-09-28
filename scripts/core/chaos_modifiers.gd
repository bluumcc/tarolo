class_name ChaosModifiers
extends RefCounted
## Modificadores do modo Caos: uma regra especial sorteada a cada rodada, sempre visível
## bem grande na tela. Só efeitos simples de entender (multiplicador de pontos ou uma
## exceção pontual de regra) — nada que exija decorar coisa nova no meio da partida.

enum Modifier { TRUNFO_DOBRO, REIS_DOBRO, LOUCO_VENCE, PRIMEIRA_DOBRO, ULTIMA_TRIPLO, NAIPE_FRACO }

const ALL := [
	Modifier.TRUNFO_DOBRO,
	Modifier.REIS_DOBRO,
	Modifier.LOUCO_VENCE,
	Modifier.PRIMEIRA_DOBRO,
	Modifier.ULTIMA_TRIPLO,
	Modifier.NAIPE_FRACO,
]

const NAMES := {
	Modifier.TRUNFO_DOBRO: "Trunfo em Dobro",
	Modifier.REIS_DOBRO: "Reis em Dobro",
	Modifier.LOUCO_VENCE: "O Louco Vence",
	Modifier.PRIMEIRA_DOBRO: "Vaza Relâmpago",
	Modifier.ULTIMA_TRIPLO: "Última é Tudo",
	Modifier.NAIPE_FRACO: "Naipe Fraco",
}

const DESCRIPTIONS := {
	Modifier.TRUNFO_DOBRO: "Toda carta de Trunfo vale o DOBRO de pontos nessa rodada.",
	Modifier.REIS_DOBRO: "Todo Rei vale o DOBRO de pontos nessa rodada.",
	Modifier.LOUCO_VENCE: "Só nessa rodada, O Louco PODE vencer a vaza — funciona como um Trunfo fraquinho (perde pra Trunfo de verdade, vence naipe comum).",
	Modifier.PRIMEIRA_DOBRO: "A primeira vaza da rodada vale o DOBRO de pontos.",
	Modifier.ULTIMA_TRIPLO: "A última vaza da rodada vale o TRIPLO de pontos — segura suas cartas boas até o fim.",
	Modifier.NAIPE_FRACO: "Um naipe sorteado vale só METADE dos pontos nessa rodada.",
}

## Dica de jogada — o que fazer DIFERENTE por causa do modificador ativo. Mostrada no
## banner de início de rodada, pra deixar claro que é uma decisão do jogador, não só
## matemática passiva.
const TIPS := {
	Modifier.TRUNFO_DOBRO: "Seus trunfos valem o dobro agora — não gaste os fracos à toa, guarde os fortes pra vazas que valem a pena ganhar.",
	Modifier.REIS_DOBRO: "Seus Reis valem o dobro — não descarte um Rei numa vaza qualquer, espere o momento certo pra fazer ele valer.",
	Modifier.LOUCO_VENCE: "O Louco pode roubar a vaza de qualquer naipe comum nessa rodada — use-o como arma, não como fuga.",
	Modifier.PRIMEIRA_DOBRO: "A 1ª vaza vale dobro — abra com força total, essa é a hora de arriscar.",
	Modifier.ULTIMA_TRIPLO: "A última vaza vale TRIPLO — segure suas melhores cartas até o fim, mesmo que doa perder vazas no meio.",
	Modifier.NAIPE_FRACO: "As cartas desse naipe valem metade — livre-se delas cedo, elas não vão te ajudar a pontuar.",
}


static func random_modifier(rng: RandomNumberGenerator) -> int:
	return ALL[rng.randi_range(0, ALL.size() - 1)]


## Rótulo pronto pra mostrar na tela — já inclui o naipe sorteado quando for Naipe Fraco.
static func label(modifier: int, weak_suit: int) -> String:
	if modifier == Modifier.NAIPE_FRACO and weak_suit != -1:
		return "%s (%s)" % [NAMES[modifier], CardData.SUIT_NAMES[weak_suit]]
	return NAMES[modifier]
