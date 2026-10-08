class_name SimLib
extends RefCounted
## Utilidades das simulações: dirigem o motor (BlitzEngine) com a mesma sequência do jogo real
## (descarte → palpite → [ante/blind + apostas + cartas] × 8 → fechamento) e conferem invariantes.

const EPS := 0.01


## Fichas em jogo: tudo que existe numa mesa. A casa guarda a taxa e paga bônus do próprio cofre.
static func total_chips(e: BlitzEngine) -> float:
	var s := 0.0
	for x in e.stacks:
		s += float(x)
	return s + e.trick_pot + e.pot + e.carry + e.house_rake - e.human_bonus + e.cashed_out - e.cashed_in


## Política de aposta. mode: "bot" (decisão do bot), "fuzz" (ação válida aleatória, incl. all-in).
static func bet_step(e: BlitzEngine, rng: RandomNumberGenerator, mode: String, diffs: Array) -> void:
	var a := e.bet_actor()
	if a == -1:
		return
	if mode == "bot":
		var act := BlitzBot.bet_decision(e, a, int(diffs[a]), rng)
		e.bet_act(a, str(act["action"]), float(act.get("to", 0.0)))
		return
	var o := e.bet_options(a)
	var roll := rng.randf()
	if bool(o["can_raise"]) and roll < 0.35:
		var to: float = float(o["max_to"]) if rng.randf() < 0.3 else rng.randf_range(float(o["min_to"]), float(o["max_to"]))
		e.bet_act(a, "raise", to)
	elif bool(o["can_check"]):
		e.bet_act(a, "check")
	elif roll < 0.85:
		e.bet_act(a, "call")
	else:
		e.bet_act(a, "fold")


## Joga UM nível completo. `on_trick` é chamado depois de cada jogada resolvida (invariantes).
## Devolve false se o motor travou (guarda de iterações).
static func play_level(e: BlitzEngine, rng: RandomNumberGenerator, diffs: Array, mode: String, on_trick: Callable = Callable(), dynamic := false) -> bool:
	var n := e.num_players
	for p in range(n):
		if e.can_discard(p):
			e.apply_discard(p, BlitzBot.wants_discard(e, p, int(diffs[p]), rng))
	for p in range(n):
		e.blitz_place(p, BlitzBot.blitz_pick(e, p, int(diffs[p]), rng) if mode == "bot" else rng.randi_range(0, BlitzEngine.HAND_SIZE))
	var guard := 0
	while not e.is_round_over():
		guard += 1
		if guard > 40:
			return false
		if dynamic:
			e.pop_table_events()   # gente entrando e saindo entre as jogadas (mesa ranqueada)
		var alive := 0
		for q in range(e.num_players):
			if not e.busted[q]:
				alive += 1
		if alive < 2:
			e.void_remaining_tricks()   # sobrou só um: o Ritual não vale (a cena realoca)
			return true
		e.draw_trick_modifier()
		e.begin_trick()
		var bg := 0
		while e.betting:
			bg += 1
			if bg > 200:
				return false
			bet_step(e, rng, mode, diffs)
		if e.walkover_player() != -1:
			e.resolve_walkover()
		else:
			var pg := 0
			var done := false
			while not done:
				pg += 1
				if pg > 12:
					return false
				var pl := e.current
				var res := e.play(pl, BlitzBot.choose(e, pl, int(diffs[pl]), rng))
				if not res.get("ok", false):
					return false
				done = bool(res.get("trick_complete", false))
		if on_trick.is_valid():
			on_trick.call(e)
	return true
