extends SceneTree
## Economia com o fluxo COMPLETO do nível (ante + blind por jogada, apostas, potes laterais, taxa da
## casa ligada): quanto cada perfil ganha por nível, em blinds, contra bots Difíceis e Normais.
## Uso: godot --headless --path . -s res://tests/sim/economy_sim.gd -- --n=4 --sessions=60
## Esperado: espelho (todos iguais) ≈ −taxa; Oráculo > Difícil > Normal > Fácil; a casa nunca perde.

var N := 4
var SESSIONS := 60
const LEVELS := 12


func _diff(k: String) -> int:
	return BotAI.Difficulty.HARD if k == "H" else (BotAI.Difficulty.NORMAL if k == "N" else BotAI.Difficulty.EASY)


## Joga uma sessão; o assento 0 usa `kind` ("O" = Oráculo). Devolve {net, rake, levels}.
func session(kinds: Array, seed_i: int) -> Dictionary:
	var e := ChaosEngine.new()
	var stacks: Array = []
	for p in range(N):
		stacks.append(400.0)
	e.setup_match({"players": N, "seed": seed_i * 31 + 5, "levels": 0, "mode": "blitz", "blind": 10, "stacks": stacks})
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i + 777
	var net := 0.0
	var played := 0
	for lv in range(LEVELS):
		if lv > 0:
			e.advance_round()
		if e.stacks[0] < e.blind * 8:
			break   # o jogador testado quebrou: a sessão acaba (sem reposição que mascararia perda)
		for p in range(1, N):
			if e.stacks[p] < e.blind * 8:
				e.stacks[p] = 400.0   # bots quebrados são repostos
		var before: float = e.stacks[0]
		for p in range(N):
			if e.can_discard(p):
				e.apply_discard(p, ChaosBot.wants_discard(e, p, _diff(kinds[p].replace("O", "H")), rng))
		for p in range(N):
			var k := ChaosOracle.pick_predict(e, p, rng) if kinds[p] == "O" else ChaosBot.blitz_pick(e, p, _diff(kinds[p]), rng)
			e.blitz_place(p, k)
		while not e.is_round_over():
			e.draw_trick_modifier()
			e.begin_trick()
			var g := 0
			while e.betting and g < 80:
				g += 1
				var a := e.bet_actor()
				if a == -1:
					break
				var act := ChaosBot.bet_decision(e, a, _diff(str(kinds[a]).replace("O", "H")), rng)
				e.bet_act(a, str(act["action"]), float(act.get("to", 0.0)))
			if e.walkover_player() != -1:
				e.resolve_walkover()
				continue
			var done := false
			var pg := 0
			while not done and pg < 12:
				pg += 1
				var pl := e.current
				var card: CardData = ChaosOracle.pick_card(e, pl, rng) if kinds[pl] == "O" else ChaosBot.choose(e, pl, _diff(kinds[pl]), rng)
				var res := e.play(pl, card)
				if not res.get("ok", false):
					break
				done = bool(res.get("trick_complete", false))
		net += e.stacks[0] - before
		played += 1
	return {"net": net / 10.0, "levels": played, "rake": e.house_rake / 10.0}


func avg(tested: String, others: String) -> Array:
	var net := 0.0
	var lv := 0
	var rake := 0.0
	for i in range(SESSIONS):
		var kinds: Array = []
		for p in range(N):
			kinds.append(others)
		kinds[0] = tested
		var r := session(kinds, i + 100)
		net += float(r["net"])
		lv += int(r["levels"])
		rake += float(r["rake"])
	return [net / maxf(lv, 1), rake / maxf(lv, 1)]


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		if kv[0] == "n":
			N = int(kv[1])
		elif kv[0] == "sessions":
			SESSIONS = int(kv[1])
	var rows := [["H", "H"], ["O", "H"], ["H", "N"], ["N", "H"], ["E", "H"], ["N", "N"]]
	for r in rows:
		var res := avg(r[0], r[1])
		print("N=%d  %s contra %s: %+.2f blinds/nível   (taxa da casa %.2f blinds/nível na mesa)" % [N, r[0], r[1], res[0], res[1]])
	quit()
