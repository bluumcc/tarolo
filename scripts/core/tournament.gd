class_name Tournament
extends RefCounted
## Torneio de Blitz: eliminação em fases, mesas de 4 jogadores (lógica pura, sem UI).
## V1 tem campo fixo de 16 (1 humano + 15 bots) em 2 fases: QUARTAS (4 mesas de 4, só o
## vencedor de cada mesa avança) e FINAL (1 mesa com os 4 vencedores das Quartas).
## Sem matchmaking de verdade — o campo inteiro é preenchido com bots; só a mesa do próprio
## jogador é jogada de verdade na cena, as outras 3 da fase são resolvidas na hora, headless.

const SIZE := 16
const TABLE_SIZE := 4
const LEVELS_PER_TABLE := 4     ## mesa de torneio é curta e decisiva: nº fixo de níveis, nunca "até quebrar"
const BUY_IN := 300             ## fichas, cobradas uma vez na inscrição (não por mesa)
const RAKE_PCT := 0.10          ## taxa da casa sobre o bolão total
const PAYOUTS := [0.55, 0.28, 0.12, 0.05]   ## fração do bolão por colocação NA MESA FINAL

const ROUND_NAMES := ["QUARTAS", "FINAL"]


## Campo de 16: o jogador na vaga 0, 15 bots com dificuldade variada (régua de dificuldade:
## metade fácil, um terço normal, o resto difícil — dá pra sentir a escada subindo nas fases).
static func make_field(player_name: String, bot_names: Array, rng: RandomNumberGenerator) -> Array:
	var names: Array = bot_names.duplicate()
	names.shuffle()
	var diffs := [
		BotAI.Difficulty.EASY, BotAI.Difficulty.EASY, BotAI.Difficulty.EASY, BotAI.Difficulty.EASY, BotAI.Difficulty.EASY, BotAI.Difficulty.EASY,
		BotAI.Difficulty.NORMAL, BotAI.Difficulty.NORMAL, BotAI.Difficulty.NORMAL, BotAI.Difficulty.NORMAL,
		BotAI.Difficulty.HARD, BotAI.Difficulty.HARD, BotAI.Difficulty.HARD, BotAI.Difficulty.HARD, BotAI.Difficulty.HARD,
	]
	diffs.shuffle()
	var field: Array = [{"name": player_name, "human": true, "difficulty": BotAI.Difficulty.HARD}]
	for i in range(SIZE - 1):
		field.append({"name": str(names[i % names.size()]), "human": false, "difficulty": int(diffs[i])})
	return field


## Agrupa os participantes de 4 em 4, na ordem em que estão — a mesa que contém o jogador é
## sempre a única que a cena precisa jogar de verdade.
static func make_tables(entrants: Array) -> Array:
	var tables: Array = []
	var i := 0
	while i < entrants.size():
		tables.append(entrants.slice(i, i + TABLE_SIZE))
		i += TABLE_SIZE
	return tables


static func table_has_human(table: Array) -> bool:
	for e in table:
		if bool(e.get("human", false)):
			return true
	return false


## Roda uma mesa 100% de bots, sem UI, pelos níveis fixos da fase, e devolve os 4 participantes
## em ordem de colocação (1º primeiro). Só pra mesas em que o jogador não está sentado — a dele
## é sempre jogada de verdade na cena.
static func simulate_table(entrants: Array, rng: RandomNumberGenerator) -> Array:
	var e := ChaosEngine.new()
	var blind := 10
	e.setup_match({"seed": rng.randi(), "levels": 0, "mode": "blitz", "blind": blind, "stacks": [400, 400, 400, 400]})
	for lv in range(LEVELS_PER_TABLE):
		if lv > 0:
			e.advance_round()
		e.refill_bots()
		for p in range(TABLE_SIZE):
			e.blitz_place(p, ChaosBot.blitz_pick(e, p, int(entrants[p]["difficulty"]), rng))
		while not e.is_round_over():
			if e.plays.is_empty():
				e.draw_trick_modifier()
			var pl := e.current
			if ChaosBot.wants_double(e, pl, int(entrants[pl]["difficulty"]), rng):
				e.double_down(pl)
				for q in range(TABLE_SIZE):
					if q != pl and ChaosBot.wants_cover(e, q, int(entrants[q]["difficulty"]), rng):
						e.cover_double(q)
			e.play(pl, ChaosBot.choose(e, pl, int(entrants[pl]["difficulty"]), rng))
	var order: Array = range(TABLE_SIZE)
	order.sort_custom(func(a, b): return float(e.stacks[a]) > float(e.stacks[b]))
	var ranked: Array = []
	for idx in order:
		ranked.append(entrants[idx])
	return ranked


## Bolão total (já líquido da taxa da casa) e o pedaço de cada colocação NA MESA FINAL.
## Só quem chega à Final leva prêmio — eliminado nas Quartas sai só com o que sobrou do stack
## daquela mesa (ilustrativo; o buy-in do torneio não volta).
static func prize_pool() -> int:
	return int(round(float(BUY_IN * SIZE) * (1.0 - RAKE_PCT)))


static func payout_for(final_placement: int) -> int:
	if final_placement < 0 or final_placement >= PAYOUTS.size():
		return 0
	return int(round(float(prize_pool()) * PAYOUTS[final_placement]))
