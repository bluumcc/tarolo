class_name Scoring
extends RefCounted
## Pontuação oficial do Jeu de Tarot: o "tomador" precisa somar, nas cartas que capturou
## (vazas vencidas + talão), um total de pontos que depende de quantos Bouts ele tem.

## Quanto mais Bouts o tomador guarda, menos pontos precisa pra bater a meta.
const TARGET_BY_BOUTS := {0: 56.0, 1: 51.0, 2: 41.0, 3: 36.0}

## Contratos de licitação e seus multiplicadores (Petite/Garde ativos hoje; os outros dois
## — Garde Sans/Garde Contre le Chien — entram quando a licitação interativa existir).
enum Contract { PETITE, GARDE, GARDE_SANS, GARDE_CONTRE }
const CONTRACT_NAMES := ["Petite", "Garde", "Garde Sans", "Garde Contre"]
const CONTRACT_MULT := {Contract.PETITE: 1, Contract.GARDE: 2, Contract.GARDE_SANS: 4, Contract.GARDE_CONTRE: 6}

## Toda rodada dá um piso de 25 pontos de aposta, que se soma à distância (pra mais ou
## pra menos) da meta — e só depois é multiplicado pelo contrato.
const BASE_SCORE := 25.0


static func target_for_bouts(bouts: int) -> float:
	return TARGET_BY_BOUTS[clampi(bouts, 0, 3)]


## `taker_points` = soma de `CardData.points()` de tudo que o tomador capturou
## (vazas vencidas + talão). `bouts` = quantos dos 3 Bouts estão nesse total.
static func resolve(taker_points: float, bouts: int, contract: int = Contract.PETITE) -> Dictionary:
	var target := target_for_bouts(bouts)
	var margin := taker_points - target
	var success := margin >= 0.0
	var mult: int = CONTRACT_MULT[clampi(contract, 0, 3)]
	var score := (BASE_SCORE + absf(margin)) * mult
	if not success:
		score = -score
	return {
		"target": target,
		"margin": margin,
		"success": success,
		"score": score,
		"contract": contract,
		"contract_mult": mult,
	}


## Delta de pontos pra cada assento: o tomador ganha/perde `score` de cada um dos outros
## 3 (ou perde/ganha, se o contrato falhou — o sinal já vem certo de `resolve`).
static func distribute(score: float, taker: int, players: int = 4) -> Array:
	var deltas: Array = []
	for p in range(players):
		deltas.append(int(round(-score)) if p != taker else int(round(score * (players - 1))))
	return deltas
