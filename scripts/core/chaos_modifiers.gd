class_name ChaosModifiers
extends RefCounted
## Modificadores do modo Caos: todo nível sorteia UM (e só um), sem repetir na partida.
## Escopo NÍVEL = vale em todas as rodadas e é anunciado no início do nível.
## Escopo RODADA = vale numa rodada só (sorteada da 2ª à 7ª, ou fixa na 1ª/última) e, quando
## é surpresa, só é revelado quando essa rodada começa.

enum Modifier {
	TRUNFO_DOBRO, REIS_DOBRO, LOUCO_VENCE, NAIPE_FRACO, NAIPE_FORTE, MUNDO_CONTRARIO,
	VAZA_MAIS_UM, PEQUENAS_IMPORTAM, NAIPE_MALDITO,
	VAZA_DOURADA, VAZA_INVERTIDA, SAQUE, ASSALTO_LIDER, VAZA_MALDITA, PRIMEIRA_DOBRO, ULTIMA_TRIPLO,
}
enum Scope { ROUND, TRICK }

const ROUND_MODS := [
	Modifier.TRUNFO_DOBRO, Modifier.REIS_DOBRO, Modifier.LOUCO_VENCE, Modifier.NAIPE_FRACO,
	Modifier.NAIPE_FORTE, Modifier.MUNDO_CONTRARIO, Modifier.VAZA_MAIS_UM,
	Modifier.PEQUENAS_IMPORTAM, Modifier.NAIPE_MALDITO,
]
const TRICK_MODS := [
	Modifier.VAZA_DOURADA, Modifier.VAZA_INVERTIDA, Modifier.SAQUE, Modifier.ASSALTO_LIDER,
	Modifier.VAZA_MALDITA, Modifier.PRIMEIRA_DOBRO, Modifier.ULTIMA_TRIPLO,
]
## Todos os modificadores que o motor sabe aplicar (os testes cobrem todos).
const EVERY := ROUND_MODS + TRICK_MODS
## Pool ativa — versão enxuta pra testar a diversão: 4 de nível inteiro + 4 de uma rodada só.
## Os demais continuam implementados e podem voltar por nível/temporada.
const ALL := [
	Modifier.TRUNFO_DOBRO, Modifier.REIS_DOBRO, Modifier.LOUCO_VENCE, Modifier.MUNDO_CONTRARIO,
	Modifier.VAZA_DOURADA, Modifier.VAZA_INVERTIDA, Modifier.VAZA_MALDITA, Modifier.SAQUE,
]
## Pool do Blitz: só regras que mudam QUEM vence ou quantas vitórias contam (nada de prêmio em pontos).
const BLITZ_POOL := [
	Modifier.LOUCO_VENCE, Modifier.MUNDO_CONTRARIO, Modifier.VAZA_INVERTIDA, Modifier.VAZA_DOURADA,
]
## Modificadores que sorteiam um naipe.
const SUIT_MODS := [Modifier.NAIPE_FRACO, Modifier.NAIPE_FORTE, Modifier.NAIPE_MALDITO]

const NAMES := {
	Modifier.TRUNFO_DOBRO: "Trunfo em Dobro",
	Modifier.REIS_DOBRO: "Reis em Dobro",
	Modifier.LOUCO_VENCE: "O Louco Vence",
	Modifier.NAIPE_FRACO: "Naipe Fraco",
	Modifier.NAIPE_FORTE: "Naipe Forte",
	Modifier.MUNDO_CONTRARIO: "Mundo ao Contrário",
	Modifier.VAZA_MAIS_UM: "Cada Rodada Vale +1",
	Modifier.PEQUENAS_IMPORTAM: "Cartas Pequenas Importam",
	Modifier.NAIPE_MALDITO: "Naipe Maldito",
	Modifier.VAZA_DOURADA: "Rodada Dourada",
	Modifier.VAZA_INVERTIDA: "Rodada Invertida",
	Modifier.SAQUE: "Saque",
	Modifier.ASSALTO_LIDER: "Assalto ao Líder",
	Modifier.VAZA_MALDITA: "Rodada Maldita",
	Modifier.PRIMEIRA_DOBRO: "Rodada Relâmpago",
	Modifier.ULTIMA_TRIPLO: "Última é Tudo",
}

const ICONS := {
	Modifier.VAZA_DOURADA: "★", Modifier.VAZA_INVERTIDA: "⇅", Modifier.SAQUE: "⚔",
	Modifier.ASSALTO_LIDER: "♛", Modifier.VAZA_MALDITA: "☠", Modifier.PRIMEIRA_DOBRO: "⚡",
	Modifier.ULTIMA_TRIPLO: "⚑",
}

const DESCRIPTIONS := {
	Modifier.TRUNFO_DOBRO: "Toda carta de Trunfo vale o DOBRO de pontos, no nível inteiro.",
	Modifier.REIS_DOBRO: "Todo Rei vale o DOBRO de pontos, no nível inteiro.",
	Modifier.LOUCO_VENCE: "O Louco PODE vencer a rodada, como um Trunfo fraquinho (perde pra Trunfo de verdade, vence naipe comum).",
	Modifier.NAIPE_FRACO: "Um naipe sorteado vale só METADE dos pontos, no nível inteiro.",
	Modifier.NAIPE_FORTE: "Um naipe sorteado vale 1,5× os pontos, no nível inteiro.",
	Modifier.MUNDO_CONTRARIO: "Em toda rodada vence a MENOR carta do naipe. Trunfo não corta.",
	Modifier.VAZA_MAIS_UM: "Quem vence uma rodada ganha +1 ponto fixo, em toda rodada.",
	Modifier.PEQUENAS_IMPORTAM: "As cartas de 0,5 ponto valem 1,0, no nível inteiro.",
	Modifier.NAIPE_MALDITO: "Cada carta do naipe sorteado vale −1 ponto pra quem a captura.",
	Modifier.VAZA_DOURADA: "Os pontos dessa rodada valem ×3.",
	Modifier.VAZA_INVERTIDA: "Nessa rodada vence a MENOR carta do naipe. Trunfo não corta.",
	Modifier.SAQUE: "Quem vencer essa rodada rouba 2 pontos de cada rival.",
	Modifier.ASSALTO_LIDER: "Quem vencer essa rodada rouba 4 pontos de quem lidera o placar.",
	Modifier.VAZA_MALDITA: "Quem vencer essa rodada PERDE 3 pontos. Todo mundo quer perder!",
	Modifier.PRIMEIRA_DOBRO: "A primeira rodada do nível vale o DOBRO de pontos.",
	Modifier.ULTIMA_TRIPLO: "A última rodada do nível vale o TRIPLO de pontos.",
}

## Dica de jogada — o que fazer DIFERENTE por causa do modificador ativo.
const TIPS := {
	Modifier.TRUNFO_DOBRO: "Não gaste Trunfo fraco à toa: guarde os fortes pra rodadas que valem a pena ganhar.",
	Modifier.REIS_DOBRO: "Não descarte um Rei numa rodada qualquer: espere o momento certo pra ele valer.",
	Modifier.LOUCO_VENCE: "O Louco pode roubar a rodada de qualquer naipe comum. Use-o como arma, não como fuga.",
	Modifier.NAIPE_FRACO: "Livre-se cedo das cartas desse naipe: elas não vão te ajudar a pontuar.",
	Modifier.NAIPE_FORTE: "Disputem esse naipe: quem capturar mais cartas dele leva vantagem.",
	Modifier.MUNDO_CONTRARIO: "Tudo se inverte: carta baixa vence. Guarde as cartas fracas e jogue as fortes só quando quiser perder a rodada.",
	Modifier.VAZA_MAIS_UM: "Vencer muitas rodadas pequenas compensa: cada uma vale +1.",
	Modifier.PEQUENAS_IMPORTAM: "Até as cartas mais fracas somam: quantidade de cartas capturadas importa.",
	Modifier.NAIPE_MALDITO: "Empurre as cartas desse naipe pros outros: quem as captura perde pontos.",
	Modifier.VAZA_DOURADA: "Uma rodada só vale ×3. Guarde uma carta forte pra ela.",
	Modifier.VAZA_INVERTIDA: "Numa rodada só, a menor carta vence. Fique atento.",
	Modifier.SAQUE: "Numa rodada só, vencer rouba pontos dos rivais.",
	Modifier.ASSALTO_LIDER: "Numa rodada só, vencer rouba do líder do placar.",
	Modifier.VAZA_MALDITA: "Numa rodada só, vencer custa pontos. Tente perder essa!",
	Modifier.PRIMEIRA_DOBRO: "A 1ª rodada vale dobro: abra com força total.",
	Modifier.ULTIMA_TRIPLO: "A última rodada vale TRIPLO: segure suas melhores cartas até o fim.",
}

## No Blitz a Rodada Dourada conta 2 vitórias (não vale pontos).
const BLITZ_NAMES := {Modifier.VAZA_DOURADA: "Rodada Dobrada"}
const BLITZ_DESCRIPTIONS := {Modifier.VAZA_DOURADA: "Quem vencer essa rodada conta 2 vitórias no palpite, em vez de 1."}
const BLITZ_TIPS := {Modifier.VAZA_DOURADA: "Muda a conta do palpite: se você quer 2 vitórias, basta ganhar só essa. Se não quer, fuja dela."}

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


static func scope_of(modifier: int) -> int:
	return Scope.ROUND if ROUND_MODS.has(modifier) else Scope.TRICK


static func has_suit(modifier: int) -> bool:
	return SUIT_MODS.has(modifier)


## Verdadeiro se a rodada sorteada é surpresa (só revelada quando começa). A 1ª e a última
## têm posição fixa e conhecida, então são anunciadas já no início do nível.
static func is_secret(modifier: int, blitz := false) -> bool:
	if blitz:
		return false     # no Blitz tudo é anunciado: o palpite precisa de informação
	return scope_of(modifier) == Scope.TRICK and modifier != Modifier.PRIMEIRA_DOBRO and modifier != Modifier.ULTIMA_TRIPLO


static func color_of(modifier: int) -> Color:
	if modifier in [Modifier.SAQUE, Modifier.VAZA_MALDITA, Modifier.ASSALTO_LIDER]:
		return UIKit.LOSS         # perda / perigo
	if scope_of(modifier) == Scope.TRICK:
		return UIKit.COMBO        # efeito de uma rodada só
	return UIKit.MODIFIER     # modificador de nível inteiro


static func random_modifier(rng: RandomNumberGenerator) -> int:
	return ALL[rng.randi_range(0, ALL.size() - 1)]


## Rótulo pronto pra tela — inclui o naipe sorteado quando o modificador tem naipe.
static func label(modifier: int, weak_suit: int) -> String:
	if has_suit(modifier) and weak_suit != -1:
		return "%s (%s)" % [NAMES[modifier], CardData.SUIT_NAMES[weak_suit]]
	return NAMES[modifier]


## Texto do modificador conforme o modo (Blitz reescreve a Rodada Dourada).
static func name_of(modifier: int, blitz := false) -> String:
	return str(BLITZ_NAMES[modifier]) if blitz and BLITZ_NAMES.has(modifier) else str(NAMES[modifier])


static func desc_of(modifier: int, blitz := false) -> String:
	return str(BLITZ_DESCRIPTIONS[modifier]) if blitz and BLITZ_DESCRIPTIONS.has(modifier) else str(DESCRIPTIONS[modifier])


static func tip_of(modifier: int, blitz := false) -> String:
	return str(BLITZ_TIPS[modifier]) if blitz and BLITZ_TIPS.has(modifier) else str(TIPS[modifier])
