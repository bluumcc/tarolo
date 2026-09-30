extends SceneTree
## Com a taxa da casa ligada (padrão real, `rake_on = true`), um jogador nível Oráculo ainda lucra
## contra os bots das mesas atuais, ou a taxa segura? Pergunta central da Fase 5 (economia vs bots,
## ver docs/PLANO_COMPETITIVO.md). Lento (usa o Oráculo) — poucas sessões, olhar a tendência, não
## o número exato. Uso: godot --headless --path . -s res://tests/blitz_economy_check.gd
const SESSIONS := 6
const LEVELS := 10
func _init():
	var totals := []
	for i in range(SESSIONS):
		var e := ChaosEngine.new()
		e.setup_match({"seed": i*13+1, "mode": "blitz", "blind": 10, "stacks": [400,400,400,400]})
		var rng := RandomNumberGenerator.new(); rng.seed = i + 900
		var start = e.stacks[0]
		for lv in range(LEVELS):
			if lv > 0: e.advance_round()
			for p in range(4):
				if e.stacks[p] < e.blind*6: e.stacks[p] = 400.0
			for p in range(4):
				var k = ChaosOracle.pick_predict(e, p, rng) if p==0 else ChaosBot.blitz_pick(e,p,BotAI.Difficulty.HARD,rng)
				e.blitz_place(p,k)
			while not e.is_round_over():
				if e.plays.is_empty(): e.draw_trick_modifier()
				var pl = e.current
				if ChaosBot.wants_double(e,pl,BotAI.Difficulty.HARD,rng):
					e.double_down(pl)
					for q in range(4):
						if q!=pl and ChaosBot.wants_cover(e,q,BotAI.Difficulty.HARD,rng): e.cover_double(q)
				var card = ChaosOracle.pick_card(e, pl, rng) if pl==0 else ChaosBot.choose(e,pl,BotAI.Difficulty.HARD,rng)
				e.play(pl, card)
		var net = (e.stacks[0] - start) / 10.0 / LEVELS
		totals.append(net)
		print("sessao ", i, " net/nivel ", net, " house_rake ", e.house_rake, " human_rake ", e.human_rake, " bonus ", e.human_bonus)
	var m=0.0
	for x in totals: m+=x
	print("MEDIA net/nivel (com rake): ", m/totals.size())
	quit()
