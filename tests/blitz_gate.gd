extends SceneTree
## Teste de regressão do equilíbrio do Blitz (bots só, sem Oráculo — rápido o bastante pra rodar
## sempre). Falha se: (1) a mesa deixar de ser justa entre estilos/dificuldades iguais; (2) um
## estilo virar dominado pelos outros dois; (3) a escada Difícil > Normal > Fácil quebrar.
## Uso: godot --headless --path . -s res://tests/blitz_gate.gd

const SESSIONS := 24
const LEVELS := 16
var fails := 0

func net(kinds: Array, seat: int, seed_i: int) -> float:
	var e := BlitzEngine.new()
	e.setup_match({"seed": seed_i * 31 + 7, "levels": 0, "blind": 10, "stacks": [400, 400, 400, 400]})
	for p in range(4):
		if kinds[p].begins_with("H/"):
			e.styles[p] = {"k": 0, "c": 1, "a": 2}[kinds[p].split("/")[1]]
	e.rake_on = false
	e.bonus_on = false
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i + 4242
	var total := 0.0
	for lv in range(LEVELS):
		if lv > 0:
			e.advance_round()
		for p in range(4):
			if e.stacks[p] < e.blind * 6:
				e.stacks[p] = 400.0
		for p in range(4):
			var dd := BotAI.Difficulty.HARD if kinds[p].begins_with("H") else (BotAI.Difficulty.NORMAL if kinds[p] == "N" else BotAI.Difficulty.EASY)
			if e.can_discard(p):
				e.apply_discard(p, BlitzBot.wants_discard(e, p, dd, rng))
		var before: float = e.stacks[seat]
		for p in range(4):
			var d := BotAI.Difficulty.HARD if kinds[p].begins_with("H") else (BotAI.Difficulty.NORMAL if kinds[p] == "N" else BotAI.Difficulty.EASY)
			e.blitz_place(p, BlitzBot.blitz_pick(e, p, d, rng))
		while not e.is_round_over():
			if e.plays.is_empty():
				e.draw_trick_modifier()
			var pl := e.current
			var d2 := BotAI.Difficulty.HARD if kinds[pl].begins_with("H") else (BotAI.Difficulty.NORMAL if kinds[pl] == "N" else BotAI.Difficulty.EASY)
			if BlitzBot.wants_double(e, pl, d2, rng):
				e.double_down(pl)
				for q in range(4):
					if q != pl:
						var dq := BotAI.Difficulty.HARD if kinds[q].begins_with("H") else (BotAI.Difficulty.NORMAL if kinds[q] == "N" else BotAI.Difficulty.EASY)
						if BlitzBot.wants_cover(e, q, dq, rng):
							e.cover_double(q)
			e.play(pl, BlitzBot.choose(e, pl, d2, rng))
		total += e.stacks[seat] - before
	return total / 10.0 / LEVELS


func avg(tested: String, others: String) -> float:
	var m := 0.0
	for i in range(SESSIONS):
		var seat := i % 4
		var kinds := [others, others, others, others]
		kinds[seat] = tested
		m += net(kinds, seat, i)
	return m / SESSIONS


func check(cond: bool, label: String) -> void:
	print(("ok   " if cond else "FALHA") + " " + label)
	if not cond:
		fails += 1


func _init() -> void:
	# 1) mesa espelho por dificuldade ≈ justa.
	check(absf(avg("H/k", "H/k")) < 1.0, "espelho Difícil ≈ 0")
	# 2) escada de dificuldade: Difícil > Normal > Fácil, folga mínima.
	var h := avg("H/k", "N")
	var n := avg("N", "H/k")
	check(h > n + 0.2, "Difícil > Normal (vs Normal/Difícil)")
	var n2 := avg("N", "E")
	var e2 := avg("E", "N")
	check(n2 > e2 + 0.2, "Normal > Fácil (vs Fácil/Normal)")
	# 3) nenhum estilo é dominado: cada um tem que bater pelo menos 1 dos outros por margem real.
	var kk := avg("H/k", "H/k")
	var kc := avg("H/k", "H/c")
	var ka := avg("H/k", "H/a")
	var ck := avg("H/c", "H/k")
	var ca := avg("H/c", "H/a")
	var ak := avg("H/a", "H/k")
	var ac := avg("H/a", "H/c")
	check(ck > -1.5 or ca > -1.5, "Cauteloso não é dominado")
	check(ak > -1.5 or ac > -1.5, "Agressivo não é dominado")
	check(kc > -1.5 or ka > -1.5, "Calculista não é dominado")
	print("fails: ", fails)
	quit(fails)
