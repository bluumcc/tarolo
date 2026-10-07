extends SceneTree
## Equilíbrio entre os 8 modificadores do Blitz (só bots, sem UI). Uso:
##   godot --headless --path . -s res://tests/sim/modifier_balance.gd [-- --n=1500]
## Cada Ritual usa os 8 uma vez, então todos têm a mesma amostra. Mede, por modificador:
##  - muda quem vence: % das jogadas em que o vencedor é outro que não o da regra normal;
##  - fichas movidas pelo modificador: média em blinds (Saque, Assalto, Maldição), já limitadas pela stack;
##  - vitórias creditadas: média (Transmutação = 2);
##  - mexe na profecia: % das jogadas em que, sem o modificador (regra normal, 1 vitória), alguém teria
##    acertado ou errado a profecia de forma diferente;
##  - peso total: fichas movidas + o que a profecia muda, tudo em blinds, na mesma moeda. O valor de
##    acertar, errar por 1 ou errar por 2+ vem da média real (entre todos os jogadores e Rituais).
func _init() -> void:
	var n := 1500
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		if kv[0] == "n":
			n = int(kv[1])
	var stats := {}
	for m in ChaosModifiers.ALL:
		stats[m] = {"n": 0, "flip": 0, "moved": 0.0, "value": 0.0, "profecia": 0, "swing": 0.0, "zero": 0}
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var diffs := [BotAI.Difficulty.HARD, BotAI.Difficulty.HARD, BotAI.Difficulty.HARD, BotAI.Difficulty.HARD]
	var cat_sum := [0.0, 0.0, 0.0]
	var cat_n := [0, 0, 0]
	var records: Array = []   # um por jogada: {m, wins, predicts, winner, w0, value}
	var stuck := 0
	var blind := 10.0
	for r in range(n):
		var e := ChaosEngine.new()
		e.setup_match({"seed": 9000 + r, "mode": "blitz", "blind": int(blind), "stacks": [4000.0, 4000.0, 4000.0, 4000.0]})
		e.rake_on = false
		e.bonus_on = false
		if not SimLib.play_level(e, rng, diffs, "bot"):
			stuck += 1
			continue
		var net: Array = e.blitz_result["net"]
		for p in range(e.num_players):
			var c := _cat(int(e.wins[p]), int(e.predicts[p]))
			cat_sum[c] += float(net[p]) / blind
			cat_n[c] += 1
		for h in e.history:
			if bool(h.get("walkover", false)) or (h["plays"] as Array).is_empty():
				continue
			var plays: Array = h["plays"]
			var winner := int(h["winner"])
			var ni := TrickRules.winning_index(plays, false)
			records.append({
				"m": int(h["modifier"]), "wins": (e.wins as Array).duplicate(), "predicts": (e.predicts as Array).duplicate(),
				"winner": winner, "w0": int(plays[ni]["player"]) if ni != -1 else winner, "value": int(h.get("value", 1)),
				"moved": (float(h.get("saque_amount", 0.0)) + float(h.get("assalto_amount", 0.0)) + float(h.get("curse_amount", 0.0))) / blind,
			})
	var cat_mean: Array = []
	for c in range(3):
		cat_mean.append(cat_sum[c] / maxf(float(cat_n[c]), 1.0))
	for rec in records:
		var st: Dictionary = stats[int(rec["m"])]
		st["n"] += 1
		if int(rec["w0"]) != int(rec["winner"]):
			st["flip"] += 1
		st["moved"] += float(rec["moved"])
		if float(rec["moved"]) <= 0.0:
			st["zero"] += 1
		st["value"] += float(rec["value"])
		var alt: Array = (rec["wins"] as Array).duplicate()
		alt[int(rec["winner"])] = int(alt[int(rec["winner"])]) - int(rec["value"])
		alt[int(rec["w0"])] = int(alt[int(rec["w0"])]) + 1
		var differs := false
		var swing := 0.0
		for p in range(alt.size()):
			var a1 := _cat(int(rec["wins"][p]), int(rec["predicts"][p]))
			var a2 := _cat(int(alt[p]), int(rec["predicts"][p]))
			if a1 != a2:
				differs = true
				swing += absf(float(cat_mean[a1]) - float(cat_mean[a2]))
		if differs:
			st["profecia"] += 1
		st["swing"] += swing / 2.0
	print("rituais jogados: %d (travados: %d) | média de fichas por categoria de profecia (blinds): acertou %+.2f, errou por 1 %+.2f, errou por 2+ %+.2f" % [n - stuck, stuck, cat_mean[0], cat_mean[1], cat_mean[2]])
	print("%-14s %7s %16s %15s %9s %14s %13s" % ["modificador", "jogadas", "muda quem vence", "fichas (blinds)", "vitórias", "mexe profecia", "peso (blinds)"])
	for m in ChaosModifiers.ALL:
		var st: Dictionary = stats[m]
		var c := maxf(float(st["n"]), 1.0)
		var weight: float = (float(st["moved"]) + float(st["swing"])) / c
		print("%-14s %7d %15.1f%% %15.2f %9.2f %13.1f%% %13.2f" % [ChaosModifiers.name_of(m), int(st["n"]), 100.0 * float(st["flip"]) / c, float(st["moved"]) / c, float(st["value"]) / c, 100.0 * float(st["profecia"]) / c, weight])
	for m in [ChaosModifiers.Modifier.SAQUE, ChaosModifiers.Modifier.ASSALTO_LIDER, ChaosModifiers.Modifier.VAZA_MALDITA]:
		var st: Dictionary = stats[m]
		print("%s: sem nenhuma ficha movida em %.1f%% das jogadas" % [ChaosModifiers.name_of(m), 100.0 * float(st["zero"]) / maxf(float(st["n"]), 1.0)])
	quit()


## 0 = acertou, 1 = errou por 1, 2 = errou por 2 ou mais.
func _cat(wins: int, predict: int) -> int:
	return mini(absi(wins - predict), 2)
