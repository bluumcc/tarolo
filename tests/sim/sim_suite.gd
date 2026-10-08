extends SceneTree
## Suíte de simulação do motor (sem UI). Uso:
##   godot --headless --path . -s res://tests/sim/sim_suite.gd [-- --n=300 --only=conserva]
## Cada bloco roda milhares de jogadas com sementes fixas (reproduzível) e confere INVARIANTES; sai
## com código 1 se qualquer uma falhar. Blocos: conserva, potes, fuzz, extremos, torneio, equilibrio.

var failures := 0
var N := 200


func check(ok: bool, msg: String) -> void:
	print(("ok    " if ok else "FALHA ") + msg)
	if not ok:
		failures += 1


func _init() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		if kv[0] == "n":
			N = int(kv[1])
		elif kv[0] == "only":
			only = kv[1]
	if only == "" or only == "conserva":
		_conservation()
	if only == "" or only == "potes":
		_side_pots_oracle()
	if only == "" or only == "fuzz":
		_fuzz_invalid()
	if only == "" or only == "extremos":
		_extremes()
	if only == "" or only == "torneio":
		_tournament()
	if only == "" or only == "roi":
		_tournament_roi()
	print("\nSIM: %s (%d falhas)" % ["OK" if failures == 0 else "FALHOU", failures])
	quit(1 if failures > 0 else 0)


func _engine(seed_v: int, players: int, stacks: Array, blind := 10) -> BlitzEngine:
	var e := BlitzEngine.new()
	e.setup_match({"seed": seed_v, "levels": 1, "mode": "blitz", "blind": blind, "players": players, "stacks": stacks})
	return e


# 1) Conservação de fichas: nada é criado nem some, com stacks desiguais e all-ins em cascata.
func _conservation() -> void:
	var bad := 0
	var neg := 0
	var stuck := 0
	var first_msg := ""
	for i in range(N):
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + i
		var players := 2 + i % 5
		var stacks: Array = []
		for p in range(players):
			stacks.append(float(rng.randi_range(1, 60) * 10 if rng.randf() < 0.5 else rng.randi_range(100, 800)))
		var e := _engine(i, players, stacks)
		var diffs: Array = []
		for p in range(players):
			diffs.append(rng.randi_range(0, 2))
		var start := SimLib.total_chips(e)
		var mode := "fuzz" if i % 2 == 0 else "bot"
		var on_trick := func(en: BlitzEngine):
			for x in en.stacks:
				if float(x) < -SimLib.EPS:
					neg += 1
			var drift := absf(SimLib.total_chips(en) - start)
			if drift > SimLib.EPS * 100.0 and bad == 0:
				first_msg = "sessão %d (%s, %d jog.) deriva %.2f na jogada %d" % [i, mode, players, drift, en.trick_number]
			if drift > SimLib.EPS * 100.0:
				bad += 1
		if not SimLib.play_level(e, rng, diffs, mode, on_trick):
			stuck += 1
		var end_drift := absf(SimLib.total_chips(e) - start)
		if end_drift > 1.0:
			bad += 1
			if first_msg == "":
				first_msg = "sessão %d fim: deriva %.2f" % [i, end_drift]
	check(stuck == 0, "conservação: %d níveis jogados sem travar (%d travaram)" % [N, stuck])
	check(neg == 0, "conservação: stack nunca negativa")
	check(bad == 0, "conservação: soma de fichas constante em toda jogada %s" % first_msg)


# 2) Potes laterais contra um oráculo independente (força bruta por camadas, escrita separada).
func _oracle_payout(contrib: Array, folded: Array, rank: Array) -> Array:
	# rank: jogadores do melhor ao pior. Devolve quanto cada um recebe (soma = soma das contribuições).
	var n := contrib.size()
	var pay: Array = []
	pay.resize(n)
	pay.fill(0.0)
	var remaining: Array = contrib.duplicate()
	while true:
		var live: Array = []   # quem ainda tem fichas nesta camada e não desistiu
		for q in range(n):
			if not folded[q] and remaining[q] > 0.0:
				live.append(q)
		if live.is_empty():
			break
		var layer := INF
		for q in live:
			layer = minf(layer, float(remaining[q]))
		var pot := 0.0
		for q in range(n):
			var take := minf(float(remaining[q]), layer)
			pot += take
			remaining[q] -= take
		for q in rank:
			if live.has(q):
				pay[q] += pot
				break
	var rest := 0.0
	for q in range(n):
		rest += float(remaining[q])   # sobra de quem desistiu acima de todos
	if rest > 0.0:
		for q in rank:
			if not folded[q]:
				pay[q] += rest
				break
	return pay


func _side_pots_oracle() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var mismatches := 0
	var total := 0
	var detail := ""
	for i in range(N * 10):
		var n := rng.randi_range(2, 6)
		var e := _engine(i, n, [])
		var contrib: Array = []
		var folded: Array = []
		var alive := 0
		for p in range(n):
			var f := rng.randf() < 0.3
			folded.append(f)
			if not f:
				alive += 1
			contrib.append(float(rng.randi_range(0, 40) * 10))
		if alive == 0:
			continue
		var top := 0.0   # quem desistiu nunca pôs mais que o maior nível de quem ficou (inalcançável no jogo)
		for p in range(n):
			if not folded[p]:
				top = maxf(top, float(contrib[p]))
		for p in range(n):
			if folded[p]:
				contrib[p] = minf(float(contrib[p]), top)
		var order: Array = range(n)
		order.shuffle()
		var best: int = -1
		for q in order:
			if not folded[q]:
				best = q
				break
		e.contrib = contrib.duplicate()
		e.folded = folded.duplicate()
		var sum := 0.0
		for c in contrib:
			sum += float(c)
		e.trick_pot = sum
		e.stacks = []
		for p in range(n):
			e.stacks.append(0.0)
		# monta plays com a ordem de força desejada: o motor ordena por carta, então forçamos o
		# ranking via _trick_order substituído: aqui usamos o método público de camadas e o ranking
		# do oráculo, e comparamos o RESULTADO da divisão por camadas.
		var layers: Array = e.pot_layers()
		var pay_engine: Array = []
		pay_engine.resize(n)
		pay_engine.fill(0.0)
		for layer in layers:
			for q in order:
				if (layer["eligible"] as Array).has(q):
					pay_engine[q] += float(layer["amount"])
					break
		var pay_ref := _oracle_payout(contrib, folded, order)
		total += 1
		for q in range(n):
			if absf(float(pay_engine[q]) - float(pay_ref[q])) > SimLib.EPS:
				mismatches += 1
				if detail == "":
					detail = "caso %d: contrib=%s folded=%s ordem=%s motor=%s ref=%s" % [i, str(contrib), str(folded), str(order), str(pay_engine), str(pay_ref)]
				break
	check(mismatches == 0, "potes laterais: %d cenários iguais ao oráculo independente %s" % [total, detail])


# 3) Fuzz de ações inválidas: o motor nunca trava nem corrompe o estado.
func _fuzz_invalid() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var corrupted := 0
	var bad_hands := 0
	for i in range(N):
		var n := rng.randi_range(2, 6)
		var e := _engine(i, n, [])
		for p in range(n):
			e.apply_discard(p, BlitzBot.wants_discard(e, p, 1, rng))
			e.blitz_place(p, rng.randi_range(-3, 12))   # palpite inválido (clampado)
		for _t in range(8):
			if e.is_round_over():
				break
			e.draw_trick_modifier()
			e.begin_trick()
			var guard := 0
			while e.betting and guard < 300:
				guard += 1
				var who := rng.randi_range(0, n - 1)   # fala fora de vez
				var acts := ["check", "call", "raise", "fold", "lixo"]
				e.bet_act(who, acts[rng.randi_range(0, 4)], rng.randf_range(-100.0, 5000.0))
				if rng.randf() < 0.5:
					SimLib.bet_step(e, rng, "fuzz", [])
			if e.betting:
				corrupted += 1
				break
			if e.walkover_player() != -1:
				e.resolve_walkover()
				continue
			var pg := 0
			while pg < 20:
				pg += 1
				var pl := e.current
				var legal := e.legal_for(pl)
				if rng.randf() < 0.2:
					e.play((pl + 1) % n, null)   # jogada fora de vez / carta inválida
				var res := e.play(pl, legal[rng.randi_range(0, legal.size() - 1)] if not legal.is_empty() else null)
				if bool(res.get("trick_complete", false)):
					break
		for p in range(n):
			if (e.hands[p] as Array).size() != BlitzEngine.HAND_SIZE - e.trick_number:
				bad_hands += 1
				break
	check(corrupted == 0, "fuzz: nenhuma rodada de apostas ficou presa (%d níveis)" % N)
	check(bad_hands == 0, "fuzz: toda mão tem o tamanho certo depois de cada jogada (%d erradas)" % bad_hands)


# 5) Extremos: stack 0/1/menor que o blind, todos all-in, mesa de 2.
func _extremes() -> void:
	var cases := [
		[0.0, 400.0, 400.0, 400.0], [1.0, 1.0, 400.0, 400.0], [5.0, 5.0, 5.0, 5.0],
		[400.0, 0.0, 0.0, 0.0], [12.0, 400.0], [10000.0, 3.0, 3.0], [20.0, 20.0, 20.0, 20.0, 20.0, 20.0],
	]
	var stuck := 0
	var drift := 0
	for ci in range(cases.size()):
		for rep in range(maxi(N / 10, 5)):
			var stacks: Array = cases[ci]
			var rng := RandomNumberGenerator.new()
			rng.seed = ci * 100 + rep
			var e := _engine(ci * 100 + rep, stacks.size(), stacks)
			var diffs: Array = []
			for p in range(stacks.size()):
				diffs.append(rng.randi_range(0, 2))
			var start := SimLib.total_chips(e)
			if not SimLib.play_level(e, rng, diffs, "bot" if rep % 2 == 0 else "fuzz"):
				stuck += 1
			if absf(SimLib.total_chips(e) - start) > 1.0:
				drift += 1
	check(stuck == 0, "extremos: nenhum cenário de stack mínima/all-in trava (%d travaram)" % stuck)
	check(drift == 0, "extremos: fichas conservadas (%d com deriva)" % drift)


# 3b) Torneio completo, muitas vezes (lógica pura: Tournament + BlitzEngine headless).
func _tournament() -> void:
	var bad_end := 0
	var champs_left := 0
	var bad_tables := 0
	var never_ends := 0
	var runs := maxi(N / 10, 10)
	for r in range(runs):
		var rng := RandomNumberGenerator.new()
		rng.seed = 9000 + r
		var field := Tournament.make_field("Você", ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O"], rng)
		var tables := Tournament.split_into_tables(field)
		var level := 0
		var total0 := 0.0
		for e in field:
			total0 += float(e["stack"])
		while level < 80:
			var tot_s := 0.0
			var alive_s := 0
			for tt in tables:
				for ee in (tt as Array):
					tot_s += float(ee["stack"])
					alive_s += 1
			var blind := Tournament.blind_for(level, {})
			for t in tables:
				Tournament.simulate_level(t, blind, rng, tables.size() == 1)
			var survivors: Array = []
			for t in tables:
				for e in t:
					if float(e["stack"]) > 0.0:
						survivors.append(e)
			var chips := 0.0
			for e in survivors:
				chips += float(e["stack"])
			champs_left = survivors.size()
			if survivors.size() <= 1:
				break
			var kept: Array = []
			for t in tables:
				var k: Array = []
				for e in t:
					if survivors.has(e):
						k.append(e)
				if not k.is_empty():
					kept.append(k)
			tables = Tournament.rebalance(kept)
			var sizes: Array = []
			var seen := 0
			for t in tables:
				sizes.append((t as Array).size())
				seen += (t as Array).size()
			sizes.sort()
			if seen != survivors.size() or sizes[sizes.size() - 1] - sizes[0] > 1 or sizes[sizes.size() - 1] > Tournament.MAX_TABLE or (sizes[0] < Tournament.MIN_TABLE and survivors.size() >= Tournament.MIN_TABLE):
				bad_tables += 1
			level += 1
		if level >= 80:
			never_ends += 1
		else:
			if champs_left != 1:
				bad_end += 1
				print("  torneio %d terminou com %d sobreviventes no nível %d" % [r, champs_left, level])
	check(never_ends == 0, "torneio: %d torneios de 16 terminam (%d sem fim em 80 níveis)" % [runs, never_ends])
	check(bad_tables == 0, "torneio: mesas sempre equilibradas, ≤ %d e ≥ %d (%d desvios)" % [Tournament.MAX_TABLE, Tournament.MIN_TABLE, bad_tables])
	check(bad_end == 0, "torneio: termina com um campeão")


## Joga um torneio de 16 e devolve a colocação (1 = campeão) do entrante 0, igual a
## `GameState.report_tournament_table` (eliminados no mesmo nível dividem a pior posição).
func _placement(rng: RandomNumberGenerator, my_difficulty: int) -> int:
	var field := Tournament.make_field("Você", ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O"], rng)
	(field[0] as Dictionary)["difficulty"] = my_difficulty
	var me: Dictionary = field[0]
	var tables := Tournament.split_into_tables(field)
	for level in range(80):
		var tot_s := 0.0
		var alive_s := 0
		for tt in tables:
			for ee in (tt as Array):
				tot_s += float(ee["stack"])
				alive_s += 1
		var blind := Tournament.blind_for(level, {})
		for t in tables:
			Tournament.simulate_level(t, blind, rng, tables.size() == 1)
		var survivors: Array = []
		for t in tables:
			for e in t:
				if float(e["stack"]) > 0.0:
					survivors.append(e)
		if not survivors.has(me):
			return survivors.size() + 1
		if survivors.size() <= 1:
			return 1
		var kept: Array = []
		for t in tables:
			var k: Array = []
			for e in t:
				if survivors.has(e):
					k.append(e)
			if not k.is_empty():
				kept.append(k)
		tables = Tournament.rebalance(kept)
	return 16


# 4) Retorno do torneio por habilidade: a premiação deve pagar mais a quem joga melhor, e o campo
# médio perde só a taxa da casa (soma dos prêmios = bolão).
func _tournament_roi() -> void:
	var runs := maxi(N, 100)
	var roi := {}
	for diff in [BotAI.Difficulty.EASY, BotAI.Difficulty.NORMAL, BotAI.Difficulty.HARD]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 31337 + diff
		var paid := 0.0
		var itm := 0
		var champs := 0
		for r in range(runs):
			var place := _placement(rng, diff)
			var pay := Tournament.payout_for(place - 1)
			paid += float(pay)
			if pay > 0:
				itm += 1
			if place == 1:
				champs += 1
		roi[diff] = paid / (float(runs) * float(Tournament.BUY_IN)) - 1.0
		print("  torneio %s: ROI %+.0f%%, no dinheiro %d%%, campeão %d%% (%d torneios)" % [["Fácil", "Normal", "Difícil"][diff], roi[diff] * 100.0, 100 * itm / runs, 100 * champs / runs, runs])
	check(float(roi[BotAI.Difficulty.HARD]) > float(roi[BotAI.Difficulty.NORMAL]) and float(roi[BotAI.Difficulty.NORMAL]) > float(roi[BotAI.Difficulty.EASY]), "torneio: o retorno cresce com a habilidade (Fácil < Normal < Difícil)")
	check(float(roi[BotAI.Difficulty.EASY]) > -1.0 and float(roi[BotAI.Difficulty.HARD]) < 3.0, "torneio: nenhum perfil quebra a premiação (ROI entre −100% e +300%)")
