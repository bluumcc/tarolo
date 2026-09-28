class_name Ranked
extends RefCounted
## Ligas, elos, LP e MMR do Modo Ranqueado.
## "Pontos de escada" (points): Bronze IV = 0 ... Diamante I = 1999; cada divisão = 100 LP.
## Mestre a partir de 2000 e Desafiante a partir de 2600 (+ MMR mínimo).

const TIERS := ["Bronze", "Prata", "Ouro", "Platina", "Diamante", "Mestre", "Desafiante"]
const TIER_COLORS := ["#B0764A", "#AEB6C2", "#E8C170", "#5FD3C0", "#7FA8FF", "#C792EA", "#FF6B8B"]
const DIVISIONS := ["IV", "III", "II", "I"]
const LP_PER_DIVISION := 100
const MASTER_POINTS := 2000
const CHALLENGER_POINTS := 2600
const CHALLENGER_MMR := 1900
const BASE_MMR := 1000


static func tier_info(points: int, mmr: int = BASE_MMR) -> Dictionary:
	points = maxi(points, 0)
	if points >= CHALLENGER_POINTS and mmr >= CHALLENGER_MMR:
		return {"tier": 6, "division": "", "lp": points - MASTER_POINTS, "label": "Desafiante", "progress": 1.0}
	if points >= MASTER_POINTS:
		var lp := points - MASTER_POINTS
		return {"tier": 5, "division": "", "lp": lp, "label": "Mestre", "progress": clampf(float(lp) / (CHALLENGER_POINTS - MASTER_POINTS), 0.0, 1.0)}
	var tier := points / (LP_PER_DIVISION * 4)
	var div := (points / LP_PER_DIVISION) % 4
	var lp_in := points % LP_PER_DIVISION
	return {
		"tier": tier,
		"division": DIVISIONS[div],
		"lp": lp_in,
		"label": "%s %s" % [TIERS[tier], DIVISIONS[div]],
		"progress": float(lp_in) / LP_PER_DIVISION,
	}


## Pontuação esperada (Elo) contra a média do lobby.
static func expected(mmr: int, lobby_mmr: int) -> float:
	return 1.0 / (1.0 + pow(10.0, float(lobby_mmr - mmr) / 400.0))


## placement: 0 = 1º lugar ... 3 = 4º lugar (partida de 4 jogadores).
static func mmr_delta(placement: int, mmr: int, lobby_mmr: int, players: int = 4) -> int:
	var actual := 1.0 - float(placement) / float(players - 1)
	return int(round(48.0 * (actual - expected(mmr, lobby_mmr))))


static func lp_delta(placement: int, mmr: int, lobby_mmr: int) -> int:
	var base: Array = [28, 10, -9, -21]
	var adjust := clampi(int(round(float(lobby_mmr - mmr) / 50.0)), -8, 8)
	var delta: int = base[clampi(placement, 0, 3)] + adjust
	# Vitórias sempre dão LP e derrotas sempre tiram (sensação de progresso previsível).
	if placement <= 1:
		return maxi(delta, 4)
	return mini(delta, -4)


## Nível dos bots do lobby conforme o MMR do jogador.
static func bot_difficulty_for_mmr(mmr: int) -> int:
	if mmr < 950:
		return BotAI.Difficulty.EASY
	if mmr < 1250:
		return BotAI.Difficulty.NORMAL
	return BotAI.Difficulty.HARD
