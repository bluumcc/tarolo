extends SceneTree
## Arena do Blitz: mede o resultado (blinds/nível, sem taxa) de um tipo de jogador contra outros.
## Uso: godot --headless --path . -s res://tests/blitz_arena.gd -- <tipo_testado> <tipo_rivais> [sessoes] [niveis] [fator] [opcoes]
## Tipos: O (Oráculo), H (Difícil), N (Normal), E (Fácil), L (Difícil antigo, só palpite).
## Estilo opcional depois de "/": k = Calculista, c = Cauteloso, a = Agressivo (ex.: H/a).
## O tipo testado roda em rodízio de assentos. Opções (k=v): max_doubles, ...
## Exemplo: -- O H 20 25   → Oráculo contra 3 Difíceis.

var sessions := 30
var levels := 25
var factor := 0.5
var opts := {}

func base(k: String) -> String:
	return k.split("/")[0]


func style_of(k: String) -> int:
	var parts := k.split("/")
	if parts.size() < 2:
		return -1
	return {"k": 0, "c": 1, "a": 2}.get(parts[1], 0)


func kind_diff(k0: String) -> int:
	var k := base(k0)
	match k:
		"E": return BotAI.Difficulty.EASY
		"N": return BotAI.Difficulty.NORMAL
		"L": return ChaosBot.LEGACY
	return BotAI.Difficulty.HARD


func pick_predict(kind0: String, e: ChaosEngine, p: int, rng: RandomNumberGenerator) -> int:
	var kind := base(kind0)
	if kind == "O":
		return ChaosOracle.pick_predict(e, p, rng)
	return ChaosBot.blitz_pick(e, p, BotAI.Difficulty.EASY if kind == "E" else (BotAI.Difficulty.NORMAL if kind == "N" else BotAI.Difficulty.HARD), rng)


func pick_card(kind0: String, e: ChaosEngine, p: int, rng: RandomNumberGenerator) -> CardData:
	var kind := base(kind0)
	if kind == "O":
		return ChaosOracle.pick_card(e, p, rng)
	return ChaosBot.choose(e, p, kind_diff(kind), rng)


func run_session(kinds: Array, seat: int, seed_i: int) -> Array:
	var e := ChaosEngine.new()
	var cfg := {"seed": seed_i * 31 + 7, "levels": 0, "mode": "blitz", "blind": 10, "point_factor": factor, "stacks": [400, 400, 400, 400]}
	cfg.merge(opts)
	e.setup_match(cfg)
	for p in range(4):
		if style_of(kinds[p]) >= 0:
			e.styles[p] = style_of(kinds[p])
	e.rake_on = false
	e.bonus_on = false
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i + 4242
	var out: Array = []
	for lv in range(levels):
		if lv > 0:
			e.advance_round()
		for p in range(4):
			if e.stacks[p] < e.blind * 6:
				e.stacks[p] = 400.0
		for p in range(4):
			if e.can_discard(p):
				e.apply_discard(p, ChaosBot.wants_discard(e, p, kind_diff(kinds[p]), rng))
		var before: float = e.stacks[seat]
		for p in range(4):
			e.blitz_place(p, pick_predict(kinds[p], e, p, rng))
		while not e.is_round_over():
			if e.plays.is_empty():
				e.draw_trick_modifier()
			var pl := e.current
			var kd: int = kind_diff(kinds[pl])
			if base(kinds[pl]) == "O":
				kd = BotAI.Difficulty.HARD
			if ChaosBot.wants_double(e, pl, kd, rng):
				e.double_down(pl)
				for q in range(4):
					if q != pl:
						var kq: int = BotAI.Difficulty.HARD if base(kinds[q]) == "O" else kind_diff(kinds[q])
						if ChaosBot.wants_cover(e, q, kq, rng):
							e.cover_double(q)
			e.play(pl, pick_card(kinds[pl], e, pl, rng))
		var hit := (e.blitz_result["hits"] as Array).has(seat)
		out.append([(e.stacks[seat] - before) / 10.0, 1.0 if hit else 0.0])
	return out


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var tested := a[0] if a.size() > 0 else "H"
	var others := a[1] if a.size() > 1 else "H"
	if a.size() > 2: sessions = int(a[2])
	if a.size() > 3: levels = int(a[3])
	if a.size() > 4: factor = float(a[4])
	for i in range(5, a.size()):
		var kv := String(a[i]).split("=")
		if kv.size() == 2:
			opts[kv[0]] = float(kv[1]) if kv[1].is_valid_float() else kv[1]
	var vals: Array = []
	var hits := 0.0
	for i in range(sessions):
		var seat := i % 4
		var kinds := [others, others, others, others]
		kinds[seat] = tested
		for r in run_session(kinds, seat, i):
			vals.append(r[0])
			hits += r[1]
	var m := 0.0
	for x in vals:
		m += x
	m /= vals.size()
	var v := 0.0
	for x in vals:
		v += (x - m) * (x - m)
	var sd := sqrt(v / vals.size())
	print("RESULT %s vs 3×%s | fator %.2f %s | %+.2f blinds/nível (±%.2f ep) | desvio %.2f | acerto %d%% | n=%d" % [tested, others, factor, str(opts), m, sd / sqrt(vals.size()), sd, int(100.0 * hits / vals.size()), vals.size()])
	quit()
