extends SceneTree
## Mede o equilíbrio do Blitz por tamanho de mesa (2 a 7 jogadores), com a aposta por rodada ligada.
## Uso: godot --headless --path . -s res://tests/blitz_size_sim.gd -- --n=5 --sessions=48
## Saída: espelho (viés de posição/sorte, ideal ≈ 0), vantagem Difícil x Normal, acerto exato de palpite.

var N := 4
var SESSIONS := 48
const LEVELS := 16


func _diff(kind: String) -> int:
	return BotAI.Difficulty.HARD if kind == "H" else (BotAI.Difficulty.NORMAL if kind == "N" else BotAI.Difficulty.EASY)


## Devolve [ganho médio do assento por nível em blinds, acertos exatos do assento, níveis jogados].
func play(kinds: Array, seat: int, seed_i: int) -> Array:
	var e := ChaosEngine.new()
	var stacks := []
	for p in range(N):
		stacks.append(400)
	e.setup_match({"players": N, "seed": seed_i * 31 + 7, "levels": 0, "mode": "blitz", "blind": 10, "stacks": stacks})
	e.rake_on = false
	e.bonus_on = false
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i + 4242
	var total := 0.0
	var hits := 0
	for lv in range(LEVELS):
		if lv > 0:
			e.advance_round()
		for p in range(N):
			if e.stacks[p] < e.blind * 6:
				e.stacks[p] = 400.0
		for p in range(N):
			if e.can_discard(p):
				e.apply_discard(p, ChaosBot.wants_discard(e, p, _diff(kinds[p]), rng))
		var before: float = e.stacks[seat]
		for p in range(N):
			e.blitz_place(p, ChaosBot.blitz_pick(e, p, _diff(kinds[p]), rng))
		while not e.is_round_over():
			e.draw_trick_modifier()
			e.begin_trick()
			var guard := 0
			while e.betting and guard < 60:
				guard += 1
				var p := e.bet_actor()
				if p == -1:
					break
				var act := ChaosBot.bet_decision(e, p, _diff(kinds[p]), rng)
				e.bet_act(p, str(act["action"]), float(act.get("to", 0.0)))
			if e.walkover_player() != -1:
				e.resolve_walkover()
				continue
			var done := false
			var pg := 0
			while not done and pg < 12:
				pg += 1
				var pl := e.current
				var res := e.play(pl, ChaosBot.choose(e, pl, _diff(kinds[pl]), rng))
				if not res.get("ok", false):
					break
				done = bool(res.get("trick_complete", false))
		total += e.stacks[seat] - before
		if int(e.wins[seat]) == int(e.predicts[seat]):
			hits += 1
	return [total / 10.0 / LEVELS, hits, LEVELS]


func avg(tested: String, others: String) -> Array:
	var m := 0.0
	var h := 0
	var lv := 0
	for i in range(SESSIONS):
		var seat := i % N
		var kinds := []
		for p in range(N):
			kinds.append(others)
		kinds[seat] = tested
		var r := play(kinds, seat, i + 500)
		m += float(r[0])
		h += int(r[1])
		lv += int(r[2])
	return [m / SESSIONS, float(h) / float(lv)]


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		if kv[0] == "n":
			N = int(kv[1])
		elif kv[0] == "sessions":
			SESSIONS = int(kv[1])
	var mirror := avg("H", "H")
	var hn := avg("H", "N")
	var nh := avg("N", "H")
	print("N=%d  espelho=%.2f (acerto %.0f%%)  Dif x Normal: %.2f vs %.2f (folga %.2f)" % [N, mirror[0], mirror[1] * 100.0, hn[0], nh[0], float(hn[0]) - float(nh[0])])
	quit()
