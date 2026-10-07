extends SceneTree
## Ritmo de cada torneio (estrutura de Tournament.OPEN_EVENTS): níveis até o campeão e quebras por nível.
## Uso: godot --headless --path . -s res://tests/sim/tournament_pace.gd
func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	for cfg in Tournament.OPEN_EVENTS:
		var levels_total := 0
		var busts_by_level := {}
		var runs := 25
		for r in range(runs):
			var names: Array = []
			for i in range(30):
				names.append("b%d" % i)
			var field := Tournament.make_field("eu", names, rng, float(cfg["stack"]))
			var tables := Tournament.split_into_tables(field)
			var level := 0
			while level < 80:
				var blind := Tournament.blind_for(level, cfg)
				var before := 0
				for t in tables:
					before += (t as Array).size()
				for t in tables:
					Tournament.simulate_level(t, blind, rng, tables.size() == 1)
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
		var line := "%s (stack %d): dura %.1f níveis | quebras/nível: " % [cfg["name"], int(cfg["stack"]), float(levels_total) / runs]
		for l in range(0, 20):
			if busts_by_level.has(l):
				line += "%d:%.1f " % [l + 1, float(busts_by_level[l]) / runs]
		print(line)
	quit()
