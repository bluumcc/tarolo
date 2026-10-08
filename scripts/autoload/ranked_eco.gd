extends Node
## Ecossistema ranqueado ao vivo: pool de contas de bots com fichas reais,
## que entram em salas, formam mesas, jogam e saem — como jogadores humanos.
## Roda em background via _process(). O player encontra esse mundo já em movimento.

const TICK_INTERVAL  := 4.0   # segundos entre ticks do ecossistema
const BOT_POOL_SIZE  := 72    # total de contas de bots no servidor simulado
const LEVELS_PER_MATCH := 8   # rodadas por partida (mesmo que o Blitz real)

## Conta de bot: {name, fichas, status (0=idle 1=waiting 2=playing), room_blind}
var bots: Array = []
## Mesas ativas: {id, blind, seats:[{name,fichas}], rounds_left}
var tables: Array = []

var _next_id := 0
var _timer  := 0.0
var _rng    := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 99991
	_init_bots()
	# Aquece o ecossistema: vários ticks iniciais para popular as mesas antes do player abrir o jogo
	for _i in range(12):
		_tick()


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= TICK_INTERVAL:
		_timer -= TICK_INTERVAL
		_tick()


# ── Inicialização ──────────────────────────────────────────────────────────

func _init_bots() -> void:
	var pool: Array = GameState.BOT_NAMES.duplicate()
	# Sufixos para chegar em BOT_POOL_SIZE nomes únicos
	for i in range(pool.size(), BOT_POOL_SIZE):
		pool.append(GameState.BOT_NAMES[i % GameState.BOT_NAMES.size()] + str(i))
	pool.shuffle()
	for i in range(BOT_POOL_SIZE):
		bots.append({
			"name":       str(pool[i]),
			"fichas":     _rand_fichas(),
			"status":     0,   # idle
			"room_blind": 0,
		})


## Distribuição realista de fichas: maioria casual, poucos ricos.
func _rand_fichas() -> int:
	var r := _rng.randf()
	if r < 0.45: return _rng.randi_range(400,  2000)    # casual
	if r < 0.70: return _rng.randi_range(2000, 8000)    # regular
	if r < 0.88: return _rng.randi_range(8000, 30000)   # experiente
	return           _rng.randi_range(30000, 120000)     # whale


# ── Tick principal ─────────────────────────────────────────────────────────

func _tick() -> void:
	_advance_tables()
	_seat_idle_bots()
	_natural_churn()   # chegadas e saídas espontâneas


## Avança rodadas; partidas encerradas redistribuem fichas e liberam os bots.
func _advance_tables() -> void:
	var still: Array = []
	for table in tables:
		table["rounds_left"] = maxi(0, int(table["rounds_left"]) - 1)
		if int(table["rounds_left"]) > 0:
			still.append(table)
		else:
			_resolve_table(table)
	tables = still


## Resultado simplificado: um vencedor aleatorio, os outros perdem o buy-in.
func _resolve_table(table: Dictionary) -> void:
	var seats: Array = table["seats"]
	if seats.is_empty():
		return
	var blind  := int(table["blind"])
	var buy_in := blind * GameState.RANKED_STACK_BLINDS
	var winner := _rng.randi() % seats.size()
	for i in range(seats.size()):
		var bot := _bot_by_name(str((seats[i] as Dictionary)["name"]))
		if bot.is_empty():
			continue
		if i == winner:
			bot["fichas"] = int(bot["fichas"]) + buy_in * (seats.size() - 1)
		else:
			bot["fichas"] = maxi(0, int(bot["fichas"]) - buy_in)
		bot["status"]     = 0
		bot["room_blind"] = 0


## Distribui bots ociosos em salas que eles podem pagar e forma novas mesas.
func _seat_idle_bots() -> void:
	var idle: Array = bots.filter(func(b: Dictionary) -> bool: return int(b["status"]) == 0)
	idle.shuffle()

	for bot in idle:
		# Filtra salas acessíveis para esse bot
		var rooms: Array = []
		for r in GameState.RANKED_ROOMS:
			if int(bot["fichas"]) >= int(r["blind"]) * GameState.RANKED_STACK_BLINDS:
				rooms.append(r)
		if rooms.is_empty():
			continue
		# Escolhe sala com preferência pelas mais caras que o bot alcança (mas aleatório)
		var picked: Dictionary = rooms[_rng.randi() % rooms.size()]
		var blind := int(picked["blind"])

		# Tenta sentar numa mesa já em andamento com vaga
		var joined := false
		for table in tables:
			if int(table["blind"]) == blind and (table["seats"] as Array).size() < 6:
				(table["seats"] as Array).append({"name": bot["name"], "fichas": int(bot["fichas"])})
				bot["status"]     = 2
				bot["room_blind"] = blind
				joined = true
				break

		if not joined:
			bot["status"]     = 1   # aguardando mesa
			bot["room_blind"] = blind

	# Forma novas mesas para bots em espera
	for r in GameState.RANKED_ROOMS:
		var blind := int(r["blind"])
		var waiting: Array = bots.filter(func(b: Dictionary) -> bool: return int(b["status"]) == 1 and int(b["room_blind"]) == blind)
		while waiting.size() >= 4:
			var sz := mini(_rng.randi_range(4, 6), waiting.size())
			var seats: Array = []
			for i in range(sz):
				var bot: Dictionary = waiting[i]
				bot["status"] = 2
				seats.append({"name": str(bot["name"]), "fichas": int(bot["fichas"])})
			tables.append({
				"id":          _next_id,
				"blind":       blind,
				"seats":       seats,
				"rounds_left": _rng.randi_range(4, LEVELS_PER_MATCH),
			})
			_next_id += 1
			waiting = waiting.slice(sz)


## Chegadas e saídas espontâneas: simula jogadores novos entrando e velhos saindo.
func _natural_churn() -> void:
	# Saídas: bots com fichas muito baixas vão embora (quebram ou desistem)
	for bot in bots:
		if int(bot["status"]) == 0 and int(bot["fichas"]) < 200 and _rng.randf() < 0.3:
			bot["fichas"] = _rand_fichas()   # "recarregam" e voltam com saldo novo
	# Chegadas: bots ociosos ocasionalmente decidem entrar logo
	var idle_count := 0
	for bot in bots:
		if int(bot["status"]) == 0:
			idle_count += 1
	# Se muitos estão ociosos, acelera o assento (próximo tick vai lidar)


# ── API para o matchmaking ─────────────────────────────────────────────────

## Retorna a mesa mais acessível ao jogador excluindo o blind recusado.
## Campos: blind, players, rounds_left, affordable, only_room.
func find_table(fichas: int, exclude_blind: int = -1) -> Dictionary:
	# Candidatos: mesas com vaga ou prestes a terminar (player entra na próxima)
	var candidates: Array = []
	for table in tables:
		if int(table["blind"]) == exclude_blind:
			continue
		var sz := (table["seats"] as Array).size()
		var rl  := int(table["rounds_left"])
		if sz < 6 or rl <= 1:
			candidates.append({"blind": int(table["blind"]), "players": sz, "rounds_left": rl})

	# Salas com fila suficiente para formar mesa imediata
	for r in GameState.RANKED_ROOMS:
		var blind := int(r["blind"])
		if blind == exclude_blind:
			continue
		var waiting := bots.filter(func(b: Dictionary) -> bool: return int(b["status"]) == 1 and int(b["room_blind"]) == blind)
		if waiting.size() >= 2:
			candidates.append({"blind": blind, "players": waiting.size() + 1, "rounds_left": 0})

	# Fallback: qualquer sala exceto a excluída
	if candidates.is_empty():
		for r in GameState.RANKED_ROOMS:
			if int(r["blind"]) != exclude_blind:
				var blind := int(r["blind"])
				var waiting := bots.filter(func(b: Dictionary) -> bool: return int(b["room_blind"]) == blind)
				candidates.append({"blind": blind, "players": maxi(3, waiting.size() + 1), "rounds_left": _rng.randi_range(2, 6)})

	var only_room := candidates.is_empty()
	if only_room:
		# Único recurso: a sala excluída de volta
		for r in GameState.RANKED_ROOMS:
			candidates.append({"blind": int(r["blind"]), "players": 4, "rounds_left": _rng.randi_range(1, 5)})

	# Prefere mesa prestes a abrir (rounds_left baixo)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["rounds_left"]) < int(b["rounds_left"]))
	var best: Dictionary = candidates[0]
	return {
		"blind":       int(best["blind"]),
		"players":     clampi(int(best["players"]), 3, 6),
		"rounds_left": int(best["rounds_left"]),
		"affordable":  fichas >= int(best["blind"]) * GameState.RANKED_STACK_BLINDS,
		"only_room":   only_room,
	}


## Snapshot das salas para exibição (quantas mesas e jogadores por blind).
func room_snapshot() -> Array:
	var snap: Array = []
	for r in GameState.RANKED_ROOMS:
		var blind := int(r["blind"])
		var room_tables := tables.filter(func(t: Dictionary) -> bool: return int(t["blind"]) == blind)
		var online := 0
		for t in room_tables:
			online += (t["seats"] as Array).size()
		var waiting := bots.filter(func(b: Dictionary) -> bool: return int(b["status"]) == 1 and int(b["room_blind"]) == blind)
		snap.append({"blind": blind, "tables": room_tables.size(), "online": online + waiting.size()})
	return snap


func _bot_by_name(n: String) -> Dictionary:
	for b in bots:
		if str(b["name"]) == n:
			return b
	return {}
