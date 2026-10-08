extends SceneTree
## Versão 2: o "automático" de 1 jogada só tem ruído próprio (embutido na dificuldade Normal),
## que atrapalha mais do que ajuda. Em vez de 1 jogada do automático, faz a MÉDIA de várias —
## um "quanto essa mão renderia, em média" de verdade, sem o ruído de uma rodada só.
const LEVELS := 80
const BASELINE_ROLLOUTS := 12

func deal_hand(seed_i: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i
	var deck := Deck.build(rng)
	return (Deck.deal(deck, 4, BlitzEngine.BLITZ_DEAL_SIZE)["hands"] as Array)[0].duplicate()

func play_once(my_hand: Array, diff0: int, seed_i: int) -> float:
	var e := BlitzEngine.new()
	e.setup_match({"seed": seed_i, "mode": "blitz", "blind": 10, "stacks": [400.0,400.0,400.0,400.0]})
	e.rake_on = false
	e.bonus_on = false
	e.hands[0] = (my_hand as Array).duplicate()   # sua mão é sempre a mesma; o resto (rivais, naipes) varia
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = seed_i + 555
	for p in range(4):
		if e.can_discard(p):
			var d0 := diff0 if p == 0 else BotAI.Difficulty.HARD
			e.apply_discard(p, BlitzBot.wants_discard(e, p, d0, rng2))
	var before: float = e.stacks[0]
	for p in range(4):
		var d0 := diff0 if p == 0 else BotAI.Difficulty.HARD
		e.blitz_place(p, BlitzBot.blitz_pick(e, p, d0, rng2))
	while not e.is_round_over():
		if e.plays.is_empty():
			e.draw_trick_modifier()
		var pl := e.current
		var d0 := diff0 if pl == 0 else BotAI.Difficulty.HARD
		if BlitzBot.wants_double(e, pl, d0, rng2):
			e.double_down(pl)
			for q in range(4):
				if q != pl:
					var dq := diff0 if q == 0 else BotAI.Difficulty.HARD
					if BlitzBot.wants_cover(e, q, dq, rng2):
						e.cover_double(q)
		e.play(pl, BlitzBot.choose(e, pl, d0, rng2))
	return (e.stacks[0] - before) / 10.0

func _init() -> void:
	var raw_hard: Array = []
	var vs_avg_baseline: Array = []
	for i in range(LEVELS):
		var seed_i := i * 131 + 7
		var hand := deal_hand(seed_i)
		var hard_result := play_once(hand, BotAI.Difficulty.HARD, seed_i)
		raw_hard.append(hard_result)
		var base_sum := 0.0
		for k in range(BASELINE_ROLLOUTS):
			base_sum += play_once(hand, BotAI.Difficulty.NORMAL, seed_i * 97 + k + 1)
		var baseline_avg := base_sum / float(BASELINE_ROLLOUTS)
		vs_avg_baseline.append(hard_result - baseline_avg)
	var m1 := 0.0
	for x in raw_hard: m1 += x
	m1 /= raw_hard.size()
	var v1 := 0.0
	for x in raw_hard: v1 += (x - m1) * (x - m1)
	var sd1 := sqrt(v1 / raw_hard.size())
	var m2 := 0.0
	for x in vs_avg_baseline: m2 += x
	m2 /= vs_avg_baseline.size()
	var v2 := 0.0
	for x in vs_avg_baseline: v2 += (x - m2) * (x - m2)
	var sd2 := sqrt(v2 / vs_avg_baseline.size())
	print("líquido bruto:              média %+.2f  desvio %.2f  níveis p/ 2σ: %d" % [m1, sd1, int(pow(2.0*sd1/maxf(absf(m1),0.02), 2.0))])
	print("vs média de %d automáticos: média %+.2f  desvio %.2f  níveis p/ 2σ: %d" % [BASELINE_ROLLOUTS, m2, sd2, int(pow(2.0*sd2/maxf(absf(m2),0.02), 2.0))])
	quit()
