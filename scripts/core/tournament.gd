class_name Tournament
extends RefCounted
## Torneio de Blitz: MTT de verdade (lógica pura, sem UI). Várias mesas tocam o mesmo nível ao
## mesmo tempo; quem quebra (fica com 0 de stack) é eliminado e sai; mesas que ficam curtas
## demais são desfeitas e seus jogadores realocados nas mesas que sobraram — até caber tudo
## numa mesa só, que toca até sobrar 1 campeão. Sem matchmaking de verdade — o campo inteiro é
## preenchido com bots; só a mesa do próprio jogador é jogada de verdade na cena, nível por
## nível (as outras tocam headless, no mesmo nível, em paralelo "no escuro").

const FIELD_SIZE := 16
## Teto de 7: o Blitz distribui 10 cartas por jogador na mão inicial (`BLITZ_DEAL_SIZE`) e o
## baralho de Tarot tem 78 — 8 jogadores precisariam de 80, não cabe. 7×10 = 70 cabe com sobra.
const MAX_TABLE := 7
## Mesa nunca fica menor que isso sem ser desfeita e redistribuída (heads-up ainda é jogável).
const MIN_TABLE := 2
const BUY_IN := 300             ## fichas, cobradas uma vez na inscrição (não por mesa/nível)
const RAKE_PCT := 0.10          ## taxa da casa sobre o bolão total
const PAYOUTS := [0.55, 0.28, 0.12, 0.05]   ## fração do bolão pros 4 melhores colocados
const STARTING_STACK := 400.0   ## mesmo de uma mesa Iniciante — igual pra todo mundo
## Blind sobe com o torneio (igual qualquer MTT de poker de verdade) — sem isso, com blind fixo
## em 10 e stack de 400 (40 blinds), quase ninguém quebra e o torneio nunca anda. Dobra a cada
## 3 níveis GLOBAIS do torneio (não por mesa): todas as mesas, inclusive as headless, jogam no
## mesmo blind no mesmo nível.
const BLIND_BASE := 10
const BLIND_DOUBLE_EVERY := 3


static func blind_for(level: int) -> int:
	return BLIND_BASE * (1 << (maxi(level, 0) / BLIND_DOUBLE_EVERY))


## Campo de 16: o jogador + 15 bots com dificuldade variada (régua: metade fácil, um terço
## normal, o resto difícil). Cada entrant carrega sua própria stack, que viaja com ele entre
## mesas conforme o torneio realoca.
static func make_field(player_name: String, bot_names: Array, rng: RandomNumberGenerator) -> Array:
	var names: Array = bot_names.duplicate()
	names.shuffle()
	var diffs := [
		BotAI.Difficulty.EASY, BotAI.Difficulty.EASY, BotAI.Difficulty.EASY, BotAI.Difficulty.EASY, BotAI.Difficulty.EASY, BotAI.Difficulty.EASY,
		BotAI.Difficulty.NORMAL, BotAI.Difficulty.NORMAL, BotAI.Difficulty.NORMAL, BotAI.Difficulty.NORMAL,
		BotAI.Difficulty.HARD, BotAI.Difficulty.HARD, BotAI.Difficulty.HARD, BotAI.Difficulty.HARD, BotAI.Difficulty.HARD,
	]
	diffs.shuffle()
	var field: Array = [{"name": player_name, "human": true, "difficulty": BotAI.Difficulty.HARD, "stack": STARTING_STACK}]
	for i in range(FIELD_SIZE - 1):
		field.append({"name": str(names[i % names.size()]), "human": false, "difficulty": int(diffs[i]), "stack": STARTING_STACK})
	return field


## Divide o campo inicial em mesas de até MAX_TABLE, o mais parelho possível (nunca abaixo de
## MIN_TABLE contanto que o campo total seja grande o bastante).
static func split_into_tables(entrants: Array) -> Array:
	var n := entrants.size()
	if n <= 0:
		return []
	if n <= MAX_TABLE:
		return [entrants.duplicate()]
	var num_tables := ceili(float(n) / float(MAX_TABLE))
	var tables: Array = []
	for i in range(num_tables):
		tables.append([])
	for i in range(n):
		(tables[i % num_tables] as Array).append(entrants[i])
	return tables


## Realocação depois que alguém quebra: se o que sobrou já cabe numa mesa só, colapsa tudo
## nela (mesa final). Senão, desfaz as mesas que caíram abaixo de MIN_TABLE e espalha quem
## sobrou nas mesas com vaga (a mais curta primeiro), igual balanceamento de torneio de poker.
static func rebalance(tables: Array) -> Array:
	var all: Array = []
	for t in tables:
		all += (t as Array)
	if all.is_empty():
		return []
	if all.size() <= MAX_TABLE:
		return [all]
	var keep: Array = []
	var pool: Array = []
	for t in tables:
		if (t as Array).size() >= MIN_TABLE:
			keep.append((t as Array).duplicate())
		else:
			pool += (t as Array)
	for entrant in pool:
		keep.sort_custom(func(a, b): return (a as Array).size() < (b as Array).size())
		var placed := false
		for t in keep:
			if (t as Array).size() < MAX_TABLE:
				(t as Array).append(entrant)
				placed = true
				break
		if not placed:
			keep.append([entrant])
	return keep


static func table_has_human(table: Array) -> bool:
	for e in table:
		if bool(e.get("human", false)):
			return true
	return false


## Roda exatamente 1 nível, headless (sem UI), numa mesa 100% de bots, a partir das stacks
## atuais dos `entrants` — e escreve as stacks finais de volta nos próprios dicionários
## (são as mesmas referências guardadas em `GameState.tournament`, por isso não devolve nada).
static func simulate_level(entrants: Array, blind: int, rng: RandomNumberGenerator) -> void:
	var n := entrants.size()
	if n <= 0:
		return
	var stacks: Array = []
	for e in entrants:
		stacks.append(float(e["stack"]))
	var eng := ChaosEngine.new()
	eng.setup_match({"seed": rng.randi(), "levels": 1, "mode": "blitz", "blind": blind, "players": n, "stacks": stacks})
	for p in range(n):
		eng.blitz_place(p, ChaosBot.blitz_pick(eng, p, int(entrants[p]["difficulty"]), rng))
	while not eng.is_round_over():
		if eng.plays.is_empty():
			eng.draw_trick_modifier()
		var pl := eng.current
		if ChaosBot.wants_double(eng, pl, int(entrants[pl]["difficulty"]), rng):
			eng.double_down(pl)
			for q in range(n):
				if q != pl and ChaosBot.wants_cover(eng, q, int(entrants[q]["difficulty"]), rng):
					eng.cover_double(q)
		eng.play(pl, ChaosBot.choose(eng, pl, int(entrants[pl]["difficulty"]), rng))
	for p in range(n):
		entrants[p]["stack"] = maxf(eng.stacks[p], 0.0)


static func prize_pool() -> int:
	return int(round(float(BUY_IN * FIELD_SIZE) * (1.0 - RAKE_PCT)))


## placement: 0 = campeão, 1 = 2º lugar, ... (índice pronto pra PAYOUTS).
static func payout_for(placement: int) -> int:
	if placement < 0 or placement >= PAYOUTS.size():
		return 0
	return int(round(float(prize_pool()) * PAYOUTS[placement]))
