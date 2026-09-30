extends SceneTree
## Mede a vantagem de habilidade do Blitz: o bot que joga os pontos das cartas (Difícil novo) contra
## o Difícil ANTIGO (só palpite, ignora pontos), em vários fatores de pontos→fichas. Resultado em
## blinds por nível ANTES da taxa da casa (a taxa é igual pra todos e só desconta).
## Uso: godot --headless --path . -s res://tests/blitz_skill_sim.gd

const LEVELS := 30
const SESSIONS := 60

func play(diffs: Array, factor: float, seed_i: int, seat: int) -> Dictionary:
	var e := ChaosEngine.new()
	e.setup_match({"seed": seed_i * 31 + 7, "levels": 0, "mode": "blitz", "blind": 10, "point_factor": factor, "stacks": [400, 400, 400, 400]})
	e.rake_on = false   # sem taxa/bônus da casa: mede só a habilidade (soma zero entre os 4)
	e.bonus_on = false
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i + 999
	var hits := 0
	var start := 400.0
	var got := 0.0
	var lv := 0
	var prev := 0.0
	var per_level: Array = []
	while lv < LEVELS:
		if lv > 0:
			e.advance_round()
		for p in range(4):
			if e.stacks[p] < e.blind * 6:
				e.stacks[p] = 400.0   # recompra de todos (mede só habilidade, sem quebrar)
		var before: float = e.stacks[seat]
		for p in range(4):
			e.blitz_place(p, ChaosBot.blitz_pick(e, p, BotAI.Difficulty.HARD, rng))
		while not e.is_round_over():
			if e.plays.is_empty():
				e.draw_trick_modifier()
			var pl := e.current
			if ChaosBot.wants_double(e, pl, BotAI.Difficulty.HARD, rng):
				e.double_down(pl)
				for q in range(4):
					if q != pl and ChaosBot.wants_cover(e, q, BotAI.Difficulty.HARD, rng):
						e.cover_double(q)
			e.play(pl, ChaosBot.choose(e, pl, diffs[pl], rng))
		if (e.blitz_result["hits"] as Array).has(seat):
			hits += 1
		var d: float = e.stacks[seat] - before
		per_level.append(d)
		lv += 1
	var total := 0.0
	for d in per_level:
		total += d
	# taxa da casa paga pelo assento 0 é contada só pro seat 0; aqui medimos bruto (soma zero entre os 4).
	return {"net": total / 10.0 / LEVELS, "hits": float(hits) / LEVELS, "levels": per_level}


func run(label: String, tested: int, others: int, factor: float) -> void:
	var nets: Array = []
	var lv_all: Array = []
	var hit := 0.0
	for i in range(SESSIONS):
		var seat := i % 4
		var diffs := [others, others, others, others]
		diffs[seat] = tested
		var r := play(diffs, factor, i, seat)
		nets.append(r["net"])
		for d in r["levels"]:
			lv_all.append(float(d) / 10.0)
		hit += r["hits"]
	var m := 0.0
	for x in nets:
		m += x
	m /= nets.size()
	var v := 0.0
	for x in nets:
		v += (x - m) * (x - m)
	var sd := sqrt(v / nets.size())
	var lm := 0.0
	for x in lv_all:
		lm += x
	lm /= lv_all.size()
	var lv2 := 0.0
	for x in lv_all:
		lv2 += (x - lm) * (x - lm)
	var lsd := sqrt(lv2 / lv_all.size())
	var need := int(pow(2.0 * lsd / maxf(absf(m), 0.05), 2.0))
	print("%-44s fator %.2f | líquido %+.2f blinds/nível (±%.2f ep) | desvio/nível %.2f | níveis pra 2σ %d | acerto %2d%%" % [label, factor, m, sd / sqrt(nets.size()), lsd, need, int(100.0 * hit / SESSIONS)])


func _init() -> void:
	var H := BotAI.Difficulty.HARD
	var Nm := BotAI.Difficulty.NORMAL
	var Ez := BotAI.Difficulty.EASY
	var L := ChaosBot.LEGACY
	var factors: Array = [0.0, 0.25, 0.5, 1.0]
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		factors = [float(args[0])]
	for f in factors:
		run("espelho: difícil-antigo vs 3 difíceis-antigos", L, L, f)
		run("difícil-NOVO (pontos) vs 3 difíceis-antigos", H, L, f)
		run("difícil-antigo vs 3 difíceis-NOVOS", L, H, f)
		run("difícil-NOVO vs 3 fáceis", H, Ez, f)
		run("fácil vs 3 difíceis-NOVOS", Ez, H, f)
		print("")
	quit()
