extends SceneTree
## Será que comparar "seu resultado" vs "o que a MESMA mão renderia no automático" separa
## habilidade de sorte mais rápido que o líquido bruto sozinho?
const LEVELS := 150

func run_pair(seed_i: int) -> Dictionary:
	var deck_rng := RandomNumberGenerator.new()
	deck_rng.seed = seed_i
	var deck := Deck.build(deck_rng)
	var dealt := Deck.deal(deck, 4, ChaosEngine.BLITZ_DEAL_SIZE)
	var mods := ChaosModifiers.blitz_pool().duplicate()
	Deck.shuffle(mods, deck_rng)

	var play_rng := RandomNumberGenerator.new()
	play_rng.seed = seed_i + 99999

	var results := {}
	for policy in ["hard", "normal"]:
		var e := ChaosEngine.new()
		e.setup_match({"seed": seed_i, "mode": "blitz", "blind": 10, "stacks": [400.0,400.0,400.0,400.0]})
		e.rake_on = false
		e.bonus_on = false
		e.hands = []
		for h in dealt["hands"]:
			e.hands.append((h as Array).duplicate())
		e.modifier_sequence = mods.duplicate()
		var diff0 := BotAI.Difficulty.HARD if policy == "hard" else BotAI.Difficulty.NORMAL
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = play_rng.randi()
		for p in range(4):
			if e.can_discard(p):
				var d0 := diff0 if p == 0 else BotAI.Difficulty.HARD
				e.apply_discard(p, ChaosBot.wants_discard(e, p, d0, rng2))
		var before: float = e.stacks[0]
		for p in range(4):
			var d0 := diff0 if p == 0 else BotAI.Difficulty.HARD
			e.blitz_place(p, ChaosBot.blitz_pick(e, p, d0, rng2))
		while not e.is_round_over():
			if e.plays.is_empty():
				e.draw_trick_modifier()
			var pl := e.current
			var d0 := diff0 if pl == 0 else BotAI.Difficulty.HARD
			if ChaosBot.wants_double(e, pl, d0, rng2):
				e.double_down(pl)
				for q in range(4):
					if q != pl:
						var dq := diff0 if q == 0 else BotAI.Difficulty.HARD
						if ChaosBot.wants_cover(e, q, dq, rng2):
							e.cover_double(q)
			e.play(pl, ChaosBot.choose(e, pl, d0, rng2))
		results[policy] = (e.stacks[0] - before) / 10.0
	return results

func _init() -> void:
	var raw_hard: Array = []
	var vs_baseline: Array = []
	for i in range(LEVELS):
		var r := run_pair(i * 131 + 7)
		raw_hard.append(r["hard"])
		vs_baseline.append(r["hard"] - r["normal"])
	var m1 := 0.0
	for x in raw_hard: m1 += x
	m1 /= raw_hard.size()
	var v1 := 0.0
	for x in raw_hard: v1 += (x - m1) * (x - m1)
	var sd1 := sqrt(v1 / raw_hard.size())
	var m2 := 0.0
	for x in vs_baseline: m2 += x
	m2 /= vs_baseline.size()
	var v2 := 0.0
	for x in vs_baseline: v2 += (x - m2) * (x - m2)
	var sd2 := sqrt(v2 / vs_baseline.size())
	print("líquido bruto:        média %+.2f  desvio %.2f  níveis p/ 2σ: %d" % [m1, sd1, int(pow(2.0*sd1/maxf(absf(m1),0.02), 2.0))])
	print("vs baseline (mesma mão): média %+.2f  desvio %.2f  níveis p/ 2σ: %d" % [m2, sd2, int(pow(2.0*sd2/maxf(absf(m2),0.02), 2.0))])
	quit()
