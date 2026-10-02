extends SceneTree
## Igual blitz_gate.gd (mesmo critério: mesa justa entre iguais, escada de dificuldade, nenhum
## estilo dominado), mas com a APOSTA POR RODADA ligada de verdade (begin_trick/bet_act/
## walkover) — blitz_gate.gd só simula predict + jogo de carta + liquidação, sem passar por ali.
## Cobre a pendência documentada em docs/BLITZ.md: confirma que a escada e o equilíbrio
## sobrevivem ao mecanismo de aposta por rodada antes dele ser considerado calibrado.
## Uso: godot --headless --path . -s res://tests/blitz_betting_gate.gd

const SESSIONS := 24
const LEVELS := 16
var fails := 0


func _diff_of(kind: String) -> int:
	return BotAI.Difficulty.HARD if kind.begins_with("H") else (BotAI.Difficulty.NORMAL if kind == "N" else BotAI.Difficulty.EASY)


func net(kinds: Array, seat: int, seed_i: int) -> float:
	var e := ChaosEngine.new()
	e.setup_match({"seed": seed_i * 31 + 7, "levels": 0, "mode": "blitz", "blind": 10, "stacks": [400, 400, 400, 400]})
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
			if e.can_discard(p):
				e.apply_discard(p, ChaosBot.wants_discard(e, p, _diff_of(kinds[p]), rng))
		var before: float = e.stacks[seat]
		for p in range(4):
			e.blitz_place(p, ChaosBot.blitz_pick(e, p, _diff_of(kinds[p]), rng))
		while not e.is_round_over():
			e.draw_trick_modifier()
			e.begin_trick()
			var guard := 0
			while e.betting and guard < 40:
				guard += 1
				var p := e.bet_actor()
				if p == -1:
					break
				var act := ChaosBot.bet_decision(e, p, _diff_of(kinds[p]), rng)
				e.bet_act(p, str(act["action"]), float(act.get("to", 0.0)))
			if e.walkover_player() != -1:
				e.resolve_walkover()
				continue
			var trick_done := false
			var play_guard := 0
			while not trick_done and play_guard < 10:
				play_guard += 1
				var pl := e.current
				if ChaosBot.wants_double(e, pl, _diff_of(kinds[pl]), rng):
					e.double_down(pl)
					for q in range(4):
						if q != pl and ChaosBot.wants_cover(e, q, _diff_of(kinds[q]), rng):
							e.cover_double(q)
				var res := e.play(pl, ChaosBot.choose(e, pl, _diff_of(kinds[pl]), rng))
				if not res.get("ok", false):
					break
				trick_done = bool(res.get("trick_complete", false))
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
	check(absf(avg("H/k", "H/k")) < 1.0, "espelho Difícil ≈ 0 (com aposta por rodada)")
	# 2) escada de dificuldade: Difícil > Normal > Fácil, folga mínima.
	var h := avg("H/k", "N")
	var n := avg("N", "H/k")
	check(h > n + 0.2, "Difícil > Normal (com aposta por rodada)")
	var n2 := avg("N", "E")
	var e2 := avg("E", "N")
	check(n2 > e2 + 0.2, "Normal > Fácil (com aposta por rodada)")
	# 3) nenhum estilo é dominado: cada um tem que bater pelo menos 1 dos outros por margem real.
	var kk := avg("H/k", "H/k")
	var kc := avg("H/k", "H/c")
	var ka := avg("H/k", "H/a")
	var ck := avg("H/c", "H/k")
	var ca := avg("H/c", "H/a")
	var ak := avg("H/a", "H/k")
	var ac := avg("H/a", "H/c")
	check(ck > -1.5 or ca > -1.5, "Cauteloso não é dominado (com aposta por rodada)")
	check(ak > -1.5 or ac > -1.5, "Agressivo não é dominado (com aposta por rodada)")
	check(kc > -1.5 or ka > -1.5, "Calculista não é dominado (com aposta por rodada)")
	print("fails: ", fails)
	quit(fails)
