class_name Scoring
extends RefCounted
## Pontuação oficial do Jeu de Tarot: o "atacante" precisa somar, nas cartas que capturou
## (rodadas vencidas + talão), um total de pontos que depende de quantos Bouts ele tem.

## Soma dos pontos de todas as 78 cartas (56 de naipe + 21 trunfos + O Louco).
const TOTAL_POINTS := 91.0

## Quanto mais Bouts o atacante guarda, menos pontos precisa pra bater a meta.
const TARGET_BY_BOUTS := {0: 56.0, 1: 51.0, 2: 41.0, 3: 36.0}

## Contratos de licitação e seus multiplicadores, do mais leve ao mais arriscado.
enum Contract { PETITE, GARDE, GARDE_SANS, GARDE_CONTRE }
const CONTRACT_NAMES := ["Petite", "Garde", "Garde Sans", "Garde Contre"]
const CONTRACT_MULT := {Contract.PETITE: 1, Contract.GARDE: 2, Contract.GARDE_SANS: 4, Contract.GARDE_CONTRE: 6}
## Explicação curta de cada contrato pra mostrar na tela de licitação — o jogo tem
## regras demais pra aprender de uma vez, então isso fica sempre visível ao lado do botão.
## Em linguagem direta: o que muda de verdade se você vencer ou perder com esse contrato.
const CONTRACT_HINTS := [
	"Risco baixo. Você pega o monte (6 cartas viradas), olha e devolve 6. Se bater a meta, ganha pouco de cada um; se não bater, perde pouco.",
	"Risco médio. Você também pega o monte e devolve 6, mas ganha ou perde o dobro (x2) da Petite.",
	"Risco alto. Você NÃO pega o monte (não vê as 6 cartas), mas os pontos delas contam a seu favor. Ganha ou perde x4.",
	"Risco máximo. Você NÃO pega o monte, e os pontos dele vão pra Defesa. Ganha ou perde x6.",
]

## Todo nível dá um piso de 25 pontos de aposta, que se soma à distância (pra mais ou
## pra menos) da meta — e só depois é multiplicado pelo contrato.
const BASE_SCORE := 25.0

## Poignée: bônus por segurar muitos trunfos na mão inicial. É uma escolha do atacante —
## declarar mostra as cartas de trunfo pros outros (dá informação), então só entra se
## `poignee_declared` estiver marcado. Valores oficiais de mesa com 4 jogadores; soma-se
## ao placar já multiplicado, não entra na conta da meta.
const POIGNEE_THRESHOLDS := [[15, 40.0], [13, 30.0], [10, 20.0]]  # [trunfos mínimos, bônus]

## Chelem: o atacante vence as 18 rodadas sozinho. Também é uma escolha: anunciar antes de
## jogar vale mais se conseguir, mas pune se falhar; não anunciar é mais seguro (só rende
## se acontecer, sem risco).
const CHELEM_ANNOUNCED_BONUS := 400.0
const CHELEM_ANNOUNCED_FAIL_PENALTY := 200.0
const CHELEM_UNANNOUNCED_BONUS := 200.0

## Petit au bout: quem vence a última rodada com Le Petit dentro leva 10 pontos extras —
## a favor do atacante se for ele, da defesa se for outro jogador.
const PETIT_AU_BOUT_BONUS := 10.0


static func target_for_bouts(bouts: int) -> float:
	return TARGET_BY_BOUTS[clampi(bouts, 0, 3)]


## Maior bônus de Poignée que `trump_count` trunfos na mão inicial alcança (0 se nenhum).
static func poignee_bonus(trump_count: int) -> float:
	for pair in POIGNEE_THRESHOLDS:
		if trump_count >= pair[0]:
			return pair[1]
	return 0.0


## `taker_points` = soma de `CardData.points()` de tudo que o atacante capturou
## (rodadas vencidas + talão). `bouts` = quantos dos 3 Bouts estão nesse total.
## `bonuses` (opcional) = { poignee, chelem, petit_au_bout }, já com o sinal certo
## (positivo a favor do atacante, negativo a favor da defesa) — somados depois do
## multiplicador do contrato, como no jogo real.
static func resolve(taker_points: float, bouts: int, contract: int = Contract.PETITE, bonuses: Dictionary = {}) -> Dictionary:
	var target := target_for_bouts(bouts)
	var margin := taker_points - target
	var success := margin >= 0.0
	var mult: int = CONTRACT_MULT[clampi(contract, 0, 3)]
	var score := (BASE_SCORE + absf(margin)) * mult
	if not success:
		score = -score
	var bonus_total := float(bonuses.get("poignee", 0.0)) + float(bonuses.get("chelem", 0.0)) + float(bonuses.get("petit_au_bout", 0.0))
	score += bonus_total
	return {
		"target": target,
		"margin": margin,
		"success": success,
		"score": score,
		"contract": contract,
		"contract_mult": mult,
		"bonuses": bonuses,
		"bonus_total": bonus_total,
	}


## Delta de pontos pra cada assento: o atacante ganha/perde `score` de cada um dos outros
## 3 (ou perde/ganha, se o contrato falhou — o sinal já vem certo de `resolve`).
static func distribute(score: float, taker: int, players: int = 4) -> Array:
	var deltas: Array = []
	for p in range(players):
		deltas.append(int(round(-score)) if p != taker else int(round(score * (players - 1))))
	return deltas
