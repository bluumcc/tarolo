extends SceneTree
## Ritmo do torneio: quantos níveis dura e quantos quebram por nível, para vários ritmos de blind.
## Uso: godot --headless --path . -s res://tests/sim/tournament_pace.gd
func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	for every in [3, 4, 6, 8]:
		var levels_total := 0
		var busts_by_level := {}
		var runs := 25
		for r in range(runs):
			var names: Array = []
			for i in range(30):
				names.append("b%d" % i)
			var field := Tournament.make_field("eu", names, rng)
			var tables := Tournament.split_into_tables(field)
			var level := 0
			while level < 80:
				var blind: int = Tournament.BLIND_BASE * (1 << (level / every))
				var before := 0
				for t in tables:
					before += (t as Array).size()
				for t in tables:
					Tournament.simulate_level(t, blind, rng)
				var surv: Array = []
				var out: Array = []
				for t in tables:
					var kept: Array = []
					for e in (t as Array):
						if float(e["stack"]) > 0.0:
							kept.append(e)
					if not kept.is_empty():
						out.append(kept)
						surv += kept
				busts_by_level[level] = int(busts_by_level.get(level, 0)) + (before - surv.size())
				level += 1
				if surv.size() <= 1:
					break
				tables = Tournament.rebalance(out)
			levels_total += level
		var line := "blind dobra a cada %d níveis → dura %.1f níveis em média | quebras/nível: " % [every, float(levels_total) / runs]
		for l in range(0, 14):
			if busts_by_level.has(l):
				line += "%d:%.1f " % [l + 1, float(busts_by_level[l]) / runs]
		print(line)
	quit()
