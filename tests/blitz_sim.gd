extends SceneTree
## Simulação do Blitz: calibra o palpite dos bots e mede a economia (ver docs/BLITZ.md).
## Uso: godot --headless --path . -s res://tests/blitz_sim.gd

func session(diffs: Array, seed_i: int, levels: int, use_seat0_bot := true) -> Dictionary:
	var e := ChaosEngine.new()
	e.setup_match({"seed": seed_i * 17 + 3, "levels": 0, "mode": "blitz", "blind": 10, "stacks": [400, 400, 400, 400]})
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i + 4242
	var start: float = e.stacks[0]
	var exp_sum := 0.0
	var act_sum := 0.0
	var exp_n := 0
	var hits := 0
	var near := 0
	var carries := 0
	var lv := 0
	var bust := -1
	while lv < levels:
		if lv > 0:
			e.advance_round()
		e.refill_bots()
		if e.stacks[0] < e.blind:
			bust = lv
			break
		for p in range(4):
			exp_sum += ChaosBot.expected_wins(e, p)
			exp_n += 1
			e.blitz_place(p, ChaosBot.blitz_pick(e, p, diffs[p], rng))
		while not e.is_round_over():
			if e.plays.is_empty():
				e.draw_trick_modifier()
			var pl := e.current
			if ChaosBot.wants_double(e, pl, diffs[pl], rng):
				e.double_down(pl)
				for q in range(4):
					if q != pl and ChaosBot.wants_cover(e, q, diffs[q], rng):
						e.cover_double(q)
			e.play(pl, ChaosBot.choose(e, pl, diffs[pl], rng))
		for p in range(4):
			act_sum += float(e.wins[p])
		var br := e.blitz_result
		if (br["hits"] as Array).has(0):
			hits += 1
		if (br["near"] as Array).has(0):
			near += 1
		if (br["hits"] as Array).is_empty():
			carries += 1
		lv += 1
	return {"net": e.stacks[0] - start, "exp": exp_sum / maxf(exp_n, 1), "act": act_sum / maxf(exp_n, 1), "hits": hits, "near": near, "carries": carries, "lv": lv, "bust": bust, "rake": e.human_rake, "bonus": e.human_bonus, "house": e.house_rake, "total": e.stacks[0] + e.stacks[1] + e.stacks[2] + e.stacks[3] + e.carry}


func report(label: String, diffs: Array, levels: int) -> void:
	var N := 120
	var net := 0.0
	var ex := 0.0
	var ac := 0.0
	var hits := 0
	var near := 0
	var carries := 0
	var lvs := 0
	var busts := 0
	var rake := 0.0
	var bonus := 0.0
	var neg := 0
	for i in range(N):
		var r := session(diffs, i, levels)
		net += r["net"]
		ex += r["exp"]
		ac += r["act"]
		hits += r["hits"]
		near += r["near"]
		carries += r["carries"]
		lvs += r["lv"]
		rake += r["rake"]
		bonus += r["bonus"]
		if r["bust"] >= 0:
			busts += 1
		if r["net"] < 0:
			neg += 1
	print("%-30s esperado %.2f real %.2f | acerto %2d%% perto %2d%% acumula %2d%% | líquido médio %+.1f blinds | perde %d%% | quebra %d%% | taxa %.1f rakeback %.1f" % [label, ex / N, ac / N, 100 * hits / maxi(lvs, 1), 100 * near / maxi(lvs, 1), 100 * carries / maxi(lvs, 1), net / N / 10.0, 100 * neg / N, 100 * busts / N, rake / N / 10.0, bonus / N / 10.0])


func _init() -> void:
	var H := BotAI.Difficulty.HARD
	var Nm := BotAI.Difficulty.NORMAL
	var Ez := BotAI.Difficulty.EASY
	report("seat0 difícil vs 3 fáceis", [H, Ez, Ez, Ez], 10)
	report("seat0 normal vs 3 fáceis", [Nm, Ez, Ez, Ez], 10)
	report("todos difíceis (seat0 difícil)", [H, H, H, H], 30)
	report("todos normais", [Nm, Nm, Nm, Nm], 30)
	report("seat0 difícil vs fáceis", [H, Ez, Ez, Nm], 30)
	report("seat0 normal vs iniciante", [Nm, Ez, Ez, Nm], 30)
	report("seat0 fácil vs difíceis", [Ez, H, H, H], 30)
	quit()
