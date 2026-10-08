class_name BlitzOracle
extends RefCounted
## "Oráculo": jogador quase perfeito do Blitz, usado só como RÉGUA do teto de habilidade (nunca
## como bot do jogo — é lento). Determiniza as mãos que não vê (sorteia cartas ainda não vistas
## pros rivais), simula o resto do nível com o Difícil e escolhe o palpite / a carta de maior
## fichas esperadas. Não trapaceia: só usa o que um jogador veria (a ordem dos modificadores
## ainda não revelados também é sorteada).

const ROLLOUTS_CARD := 20
const ROLLOUTS_PREDICT := 14


## Sorteia um mundo compatível com o que `me` vê: mãos dos rivais, ordem dos modificadores futuros
## e os palpites dos rivais (pela mão sorteada, como um Difícil faria).
static func _world(engine: BlitzEngine, me: int, known_mods: int, place_predicts: bool, rng: RandomNumberGenerator) -> BlitzEngine:
	var sim := engine.clone_for_sim()
	sim.rng.seed = rng.randi()
	var seen := {}
	for c in engine.hands[me]:
		seen[(c as CardData).key()] = true
	for pl in engine.plays:
		seen[(pl["card"] as CardData).key()] = true
	for cp in engine.captured:
		for c in cp:
			seen[(c as CardData).key()] = true
	var unseen: Array = []
	for c in Deck.build(rng):
		if not seen.has((c as CardData).key()):
			unseen.append(c)
	Deck.shuffle(unseen, rng)
	var idx := 0
	for p in range(engine.num_players):
		if p == me:
			continue
		var n: int = (engine.hands[p] as Array).size()
		sim.hands[p] = unseen.slice(idx, idx + n)
		idx += n
	# Modificadores ainda não revelados: sorteia a ordem do que resta.
	var pool := BlitzModifiers.blitz_pool() if engine.blitz else BlitzModifiers.ALL.duplicate()
	var known: Array = []
	for i in range(known_mods):
		known.append(engine.modifier_sequence[i])
	var rest: Array = pool.filter(func(m): return not known.has(m))
	Deck.shuffle(rest, rng)
	sim.modifier_sequence = known + rest
	if place_predicts:
		for p in range(engine.num_players):
			if p != me and sim.predicts[p] == -1:
				sim.blitz_place(p, BlitzBot.blitz_pick(sim, p, BotAI.Difficulty.HARD, rng))
	return sim


## Termina o nível com o Difícil jogando por todos (dobrar/cobrir incluídos).
static func _play_out(sim: BlitzEngine, rng: RandomNumberGenerator) -> void:
	while not sim.is_round_over():
		if sim.plays.is_empty():
			sim.draw_trick_modifier()
		var pl := sim.current
		if BlitzBot.wants_double(sim, pl, BotAI.Difficulty.HARD, rng):
			sim.double_down(pl)
			for q in range(sim.num_players):
				if q != pl and BlitzBot.wants_cover(sim, q, BotAI.Difficulty.HARD, rng):
					sim.cover_double(q)
		sim.play(pl, BlitzBot.choose(sim, pl, BotAI.Difficulty.HARD, rng))


## Palpite: o que rende mais fichas esperadas no nível (mãos dos rivais sorteadas).
static func pick_predict(engine: BlitzEngine, me: int, rng: RandomNumberGenerator) -> int:
	var base_worlds: Array = []
	for i in range(ROLLOUTS_PREDICT):
		base_worlds.append(_world(engine, me, 0, true, rng))
	var best_k := 0
	var best := -INF
	for k in range(0, BlitzEngine.HAND_SIZE + 1):
		var total := 0.0
		for w in base_worlds:
			var sim: BlitzEngine = (w as BlitzEngine).clone_for_sim()
			var before: float = sim.stacks[me]
			sim.blitz_place(me, k)
			_play_out(sim, rng)
			total += sim.stacks[me] - before
		var ev := total / float(base_worlds.size())
		if ev > best:
			best = ev
			best_k = k
	return best_k


## Carta: a de maior fichas esperadas até o fim do nível (mesmos mundos pra todas as candidatas).
static func pick_card(engine: BlitzEngine, me: int, rng: RandomNumberGenerator) -> CardData:
	var legal: Array = engine.legal_for(me)
	if legal.size() == 1:
		return legal[0]
	var worlds: Array = []
	for i in range(ROLLOUTS_CARD):
		worlds.append(_world(engine, me, engine.trick_number + 1, false, rng))
	var best: CardData = legal[0]
	var best_ev := -INF
	for c in legal:
		var total := 0.0
		for w in worlds:
			var sim: BlitzEngine = (w as BlitzEngine).clone_for_sim()
			var before: float = sim.stacks[me]
			sim.play(me, c)
			_play_out(sim, rng)
			total += sim.stacks[me] - before
		var ev := total / float(worlds.size())
		if ev > best_ev:
			best_ev = ev
			best = c
	return best
