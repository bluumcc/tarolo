class_name BlitzCombos
extends RefCounted
## Combos lidos direto na mesa (lógica pura): dá pra ver as cartas e saber na hora se
## valeu. Quem leva a rodada leva o bônus.

const CHUVA_MULT := 2.0     # 3+ Trunfos na mesma rodada
const REALEZA_MULT := 1.5   # 3+ figuras (Valete, Cavaleiro, Dama, Rei) na mesma rodada
const ESCADA_BONUS := 3.0   # 3+ cartas seguidas do mesmo naipe (ex.: 7, 8, 9 de Paus)
const REALEZA_MIN_RANK := 11

const STREAK_LEVELS := [1.0, 1.0, 1.25, 1.5, 2.0]   # multiplicador por nº de vitórias seguidas (0..4+)


static func streak_mult(wins_in_row: int) -> float:
	return STREAK_LEVELS[clampi(wins_in_row, 0, STREAK_LEVELS.size() - 1)]


## Quantas chamas mostrar no medidor (0..3).
static func flame_level(wins_in_row: int) -> int:
	return clampi(wins_in_row - 1, 0, 3)


## `plays` = [{player, card}]. Devolve os ids dos combos de mesa presentes.
static func detect(plays: Array) -> Array:
	var out: Array = []
	var trunfos := 0
	var royals := 0
	var by_suit := {}
	for pl in plays:
		var c: CardData = pl["card"]
		if c.is_louco():
			continue
		if c.is_trunfo():
			trunfos += 1
		elif c.rank >= REALEZA_MIN_RANK:
			royals += 1
		if not by_suit.has(c.suit):
			by_suit[c.suit] = []
		(by_suit[c.suit] as Array).append(c.rank)
	if trunfos >= 3:
		out.append("CHUVA_TRUNFOS")
	if royals >= 3:
		out.append("REALEZA")
	for s in by_suit:
		if _has_run(by_suit[s], 3):
			out.append("ESCADA")
			break
	return out


static func _has_run(ranks: Array, length: int) -> bool:
	if ranks.size() < length:
		return false
	var sorted := ranks.duplicate()
	sorted.sort()
	var run := 1
	for i in range(1, sorted.size()):
		if int(sorted[i]) == int(sorted[i - 1]) + 1:
			run += 1
			if run >= length:
				return true
		elif int(sorted[i]) != int(sorted[i - 1]):
			run = 1
	return false
