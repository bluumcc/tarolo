extends SceneTree
## Diagnóstico do Blitz vs bots: (1) estratégias degeneradas (palpite fixo), (2) uso de dobrar /
## triplicar / cobrir e o quanto acertam, (3) ruído por nível (quantos níveis pra "sentir" habilidade).
## Uso: godot --headless --path . -s res://tests/blitz_diag_sim.gd

const LEVELS := 30
const SESSIONS := 30

var stat := {"dbl1": 0, "dbl1_hit": 0, "dbl2": 0, "dbl2_hit": 0, "cover": 0, "cover_hit": 0, "levels": 0}

func play(fixed: int, bots: int, seed_i: int, track := false) -> Dictionary:
	var e := ChaosEngine.new()
	e.setup_match({"seed": seed_i * 31 + 7, "levels": 0, "mode": "blitz", "blind": 10, "stacks": [400, 400, 400, 400]})
	e.rake_on = false
	e.bonus_on = false
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i + 555
	var per: Array = []
	var seat := 0
	for lv in range(LEVELS):
		if lv > 0:
			e.advance_round()
		for p in range(4):
			if e.stacks[p] < e.blind * 6:
				e.stacks[p] = 400.0
		for p in range(4):
			if e.can_discard(p):
				e.apply_discard(p, ChaosBot.wants_discard(e, p, BotAI.Difficulty.HARD, rng))
		var before: float = e.stacks[seat]
		for p in range(4):
			var pick := ChaosBot.blitz_pick(e, p, BotAI.Difficulty.HARD, rng)
			if p == seat and fixed >= 0:
				pick = fixed
			e.blitz_place(p, pick)
		var cov := {}
		while not e.is_round_over():
			if e.plays.is_empty():
				e.draw_trick_modifier()
			var pl := e.current
			if ChaosBot.wants_double(e, pl, BotAI.Difficulty.HARD, rng):
				e.double_down(pl)
				for q in range(4):
					if q != pl and ChaosBot.wants_cover(e, q, BotAI.Difficulty.HARD, rng):
						if e.cover_double(q):
							cov[q] = true
			e.play(pl, ChaosBot.choose(e, pl, bots, rng))
		if track:
			var hits: Array = e.blitz_result["hits"]
			stat["levels"] += 4
			for p in range(4):
				var d := int(e.doubles[p])
				var hit := hits.has(p)
				if d >= 1:
					stat["dbl1"] += 1
					stat["dbl1_hit"] += 1 if hit else 0
				if d >= 2:
					stat["dbl2"] += 1
					stat["dbl2_hit"] += 1 if hit else 0
				if cov.has(p):
					stat["cover"] += 1
					stat["cover_hit"] += 1 if hit else 0
		per.append(e.stacks[seat] - before)
	return {"per": per}


func summarize(label: String, fixed: int, track := false) -> void:
	var all: Array = []
	var sess: Array = []
	for i in range(SESSIONS):
		var r := play(fixed, BotAI.Difficulty.HARD, i, track)
		var t := 0.0
		for d in r["per"]:
			all.append(d / 10.0)
			t += d / 10.0
		sess.append(t / LEVELS)
	var m := 0.0
	for x in all:
		m += x
	m /= all.size()
	var v := 0.0
	for x in all:
		v += (x - m) * (x - m)
	var sd := sqrt(v / all.size())
	var sm := 0.0
	for x in sess:
		sm += x
	sm /= sess.size()
	print("%-26s média %+.2f blinds/nível | desvio por nível %.2f | níveis pra 2σ com edge de 1: %d" % [label, m, sd, int(pow(2.0 * sd / 1.0, 2.0))])


func _init() -> void:
	summarize("bot normal (referência)", -1, true)
	for k in range(0, 9):
		summarize("palpite fixo %d" % k, k)
	print("dobrar 1x: %d vezes, acerta %d%% | dobrar 2x: %d, acerta %d%% | cobrir: %d, acerta %d%% | níveis-jogador %d" % [
		stat["dbl1"], 100 * stat["dbl1_hit"] / maxi(stat["dbl1"], 1), stat["dbl2"], 100 * stat["dbl2_hit"] / maxi(stat["dbl2"], 1),
		stat["cover"], 100 * stat["cover_hit"] / maxi(stat["cover"], 1), stat["levels"]])
	quit()
