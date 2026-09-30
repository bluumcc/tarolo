extends SceneTree
## Simulação da economia da Mesa Caos (usada em docs/ECONOMIA.md). Blind 10 nas contas; escale pelo blind da mesa.
## Uso: godot --headless --path . -s res://tests/economy_sim.gd
# Sessões: seat 0 senta com 20 blinds e joga até quebrar ou até 300 rodadas.
func session(diffs: Array, seed_i: int, stack_blinds: int) -> Dictionary:
	var e := ChaosEngine.new()
	e.setup_match({"seed": seed_i * 13 + 5, "levels": 0, "stacks": [stack_blinds * 10, 200, 200, 200]})
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i + 999
	var start: float = e.stacks[0]
	var n := 0
	while n < 300:
		if e.is_round_over():
			e.advance_round()
		e.refill_bots()
		if e.stacks[0] < e.blind:
			return {"bust": n, "n": n, "net": e.stacks[0] - start, "rake": e.human_rake}
		e.begin_trick()
		var g := 0
		while e.betting and g < 60:
			g += 1
			var a := e.bet_actor()
			var d := ChaosBot.bet_decision(e, a, diffs[a], rng)
			var r := e.bet_act(a, str(d["action"]), float(d.get("to", 0.0)))
			if not r["ok"]:
				r = e.bet_act(a, "check")
				if not r["ok"]: e.bet_act(a, "fold")
		if e.walkover_player() != -1:
			e.resolve_walkover()
		else:
			while true:
				var pl := e.current
				var rs := e.play(pl, ChaosBot.choose(e, pl, diffs[pl], rng))
				if rs["trick_complete"]: break
		n += 1
	return {"bust": -1, "n": n, "net": e.stacks[0] - start, "rake": e.human_rake}
func report(label: String, diffs: Array, stack_blinds: int) -> void:
	var busts := []
	var nets := []
	var b40 := 0
	var b100 := 0
	var alive := 0
	var rake := 0.0
	var N := 150
	for i in range(N):
		var r := session(diffs, i, stack_blinds)
		nets.append(r["net"])
		rake += r["rake"]
		if r["bust"] >= 0:
			busts.append(r["bust"])
			if r["bust"] <= 40: b40 += 1
			if r["bust"] <= 100: b100 += 1
		else:
			alive += 1
	nets.sort()
	busts.sort()
	var med_bust: int = busts[busts.size() / 2] if busts.size() > 0 else -1
	var mean := 0.0
	for x in nets: mean += x
	print("%-34s stack %2d bl | quebra≤40: %3d%% ≤100: %3d%% viva@300: %3d%% | líquido médio %+.0f (mediana %+.0f) | mediana rodadas até quebrar %d | taxa paga %.0f" % [label, stack_blinds, 100 * b40 / N, 100 * b100 / N, 100 * alive / N, mean / N, nets[N / 2], med_bust, rake / N])
func _init() -> void:
	# Mesas do jogo (bots por dificuldade) x nível do humano. Stack padrão: 40 blinds.
	for mix in [["Iniciante", [0, 1, 1]], ["Regular", [1, 1, 2]], ["Alta", [2, 2, 2]]]:
		for hn in [["EASY", 0], ["NORMAL", 1], ["HARD", 2]]:
			report("%s: humano %s" % [mix[0], hn[0]], [hn[1], mix[1][0], mix[1][1], mix[1][2]], 40)
	quit()
