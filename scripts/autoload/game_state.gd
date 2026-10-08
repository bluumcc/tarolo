extends Node
## Estado da sessão: modo atual, lobby ranqueado e fechamento de partidas.

## Clássico é só recreativo (sem Mode.RANKED): o Elo agora é inteiramente do Blitz, fila única —
## toda mesa real de Blitz vale fichas E LP/MMR ao mesmo tempo (`report_blitz_match`). Mesa de
## torneio é um caminho totalmente separado (`report_tournament_table`) que nunca toca o Elo.
enum Mode { CLASSIC }

const MODE_NAMES := ["Clássico"]
const BOT_NAMES := ["João", "Ana", "Felipe", "Mateus", "Lucas", "Sabrina", "Joana", "Pedro", "Márcio", "Júnior", "Fábio", "Marcos"]

var mode: int = Mode.CLASSIC
## Testes/demos: o assento do jogador passa a ser controlado por um bot difícil.
var autoplay := false
## Remove esperas de animação (testes headless).
var fast := false
## Partida de tutorial: mão fixa + dicas contextuais, não mexe em Gemas/elo.
var tutorial := false


func start_tutorial() -> void:
	mode = Mode.CLASSIC
	tutorial = true

var ranked_lobby: Array = []   # [{name, mmr}] adversários encontrados no matchmaking
var last_summary: Dictionary = {}
## Mesa contínua do Clássico: os mesmos jogadores ficam sentados e o placar acumula, mão
## após mão, até alguém levantar. {names, totals, hands}
var table: Dictionary = {}

## Torneio em andamento (vazio = nenhum). {field, round, round_name, player_table, bg_winners}
## — ver `start_tournament`/`report_tournament_table`.
var tournament: Dictionary = {}


func leave_table() -> void:
	table = {}


## Soma os pontos da mão ao placar da mesa (só Clássico, fora do tutorial).
func table_add(deltas: Array) -> void:
	if table.is_empty():
		return
	for i in range(deltas.size()):
		table["totals"][i] = float(table["totals"][i]) + float(deltas[i])
	table["hands"] = int(table["hands"]) + 1



func _ready() -> void:
	_install_symbol_font()
	get_tree().root.theme = UIKit.build_theme()
	apply_settings()
	get_tree().root.size_changed.connect(_update_content_scale)
	_update_content_scale()


## O navegador do celular não tem fonte com ♥ ♦ ♠ ♣ ✦ ✶ ♛ (o PC usa a fonte do sistema e
## esconde o problema): a DejaVu Sans vai junto do jogo como reserva da fonte padrão.
func _install_symbol_font() -> void:
	var sym := load("res://assets/fonts/DejaVuSans.ttf") as Font
	var display := load("res://assets/fonts/LilitaOne-Regular.ttf") as FontFile
	var dt := ThemeDB.get_default_theme()
	if sym == null or display == null or dt == null:
		return
	# Fonte padrão do jogo: Lilita One (arredondada, grossa, estilo arcade). A DejaVu Sans
	# fica de reserva pros símbolos (♥ ♦ ♠ ♣ ✦ ✶ ♨) que a Lilita não tem — o navegador do
	# celular não tem fonte de sistema com eles.
	var list: Array[Font] = [sym]
	display.fallbacks = list
	dt.default_font = display
	if OS.get_environment("TAROLO_NO_SYSFONT") == "1":
		display.allow_system_fallback = false


## Resolução base 1920x1200 no paisagem (PC) e 720x1280 no retrato (smartphone),
## para a UI não encolher pela metade em telas verticais.
func _update_content_scale() -> void:
	var win := get_tree().root.size
	var portrait := win.y > win.x
	get_tree().root.content_scale_size = Vector2i(720, 1280) if portrait else Vector2i(1920, 1200)


# ------------------------------------------------------------------ settings

func settings() -> Dictionary:
	return SaveManager.section("settings")


func apply_settings() -> void:
	var s := settings()
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_set_bus_volume("Music", float(s["music_volume"]))
	_set_bus_volume("SFX", float(s["sfx_volume"]))
	if not OS.has_feature("mobile") and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if s["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED)


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


## Duração de animação ajustada pela velocidade escolhida pelo jogador.
func anim(seconds: float) -> float:
	if fast:
		return 0.001
	return seconds / maxf(float(settings()["anim_speed"]), 0.25)


# ------------------------------------------------------------------ ranked

func ranked() -> Dictionary:
	return SaveManager.section("ranked")


func find_ranked_lobby() -> Array:
	var mmr := int(ranked()["mmr"])
	var names := BOT_NAMES.duplicate()
	names.shuffle()
	ranked_lobby = []
	for i in range(3):
		ranked_lobby.append({"name": names[i], "mmr": maxi(0, mmr + randi_range(-120, 120))})
	return ranked_lobby


func lobby_avg_mmr() -> int:
	if ranked_lobby.is_empty():
		return int(ranked()["mmr"])
	var total := 0
	for o in ranked_lobby:
		total += int(o["mmr"])
	return total / ranked_lobby.size()


# ------------------------------------------------------------------ match setup / close

func player_name() -> String:
	return Accounts.display_name()


## Mesas do Blitz: blind, com buy-in de 20 blinds (a stack com que você senta).
const BLITZ_TABLES := [
	{"name": "Iniciante", "blind": 10, "bots": [0, 0, 1]},   # Fácil, Fácil, Normal
	{"name": "Regular", "blind": 50, "bots": [1, 1, 2]},     # Normal, Normal, Difícil
	{"name": "Alta", "blind": 200, "bots": [2, 2, 2]},       # Difícil x3
]
var blitz_table := 0

## Ranqueada = fila única com 5 níveis (arcanos). Quem toca em JOGAR escolhe o nível e o jogo procura
## uma mesa dele. O buy-in é fixo (80 blinds) em todos; os pontos valem igual em qualquer nível.
const RANKED_ROOMS := [
	{"name": "O LOUCO",       "numeral": "0",   "blind": 10},
	{"name": "O MAGO",        "numeral": "I",   "blind": 30},
	{"name": "A SACERDOTISA", "numeral": "II",  "blind": 100},
	{"name": "O IMPERADOR",   "numeral": "IV",  "blind": 300},
	{"name": "O MUNDO",       "numeral": "XXI", "blind": 1000},
]
const RANKED_STACK_BLINDS := 80   # buy-in de todo nível: 80 blinds (stack fundo, joga à vontade)
var ranked_table := {}   # {blind, stack_blinds} da mesa ranqueada que está sendo aberta


func ranked_room_buy_in(room: Dictionary) -> int:
	return int(room["blind"]) * RANKED_STACK_BLINDS


## Salas que o saldo paga.
func ranked_rooms_open(fichas: int) -> Array:
	return RANKED_ROOMS.filter(func(r: Dictionary) -> bool: return fichas >= ranked_room_buy_in(r))


## Delega ao ecossistema ao vivo (RankedEco). Retorna a sala mais acessível excluindo `exclude_blind`.
## Campos do resultado: blind, players, rounds_left, affordable, only_room.
func find_ranked_room(fichas: int, blind: int) -> Dictionary:
	return RankedEco.find_table(fichas, blind)


## Nível (RANKED_ROOMS) do blind dado.
func ranked_room_for_blind(blind: int) -> Dictionary:
	for r in RANKED_ROOMS:
		if int(r["blind"]) == blind:
			return r
	return RANKED_ROOMS[0]






func blitz_buy_in(table: int = -1) -> int:
	var t: Dictionary = BLITZ_TABLES[clampi(blitz_table if table < 0 else table, 0, BLITZ_TABLES.size() - 1)]
	return int(t["blind"]) * BlitzEngine.BUY_IN_BLINDS


## Configuração da mesa pra BlitzScene / BlitzEngine — todo mundo joga pra si. Já cobra o
## buy-in das fichas do jogador (config["entered"] = false se não tinha saldo); ele volta
## como stack final quando você sai da mesa.


func blitz_config() -> Dictionary:
	var names := BOT_NAMES.duplicate()
	names.shuffle()
	var profile := SaveManager.section("profile")
	find_ranked_lobby()
	var t: Dictionary = BLITZ_TABLES[clampi(blitz_table, 0, BLITZ_TABLES.size() - 1)]
	var blind := int(t["blind"])
	var buy_in := blitz_buy_in()
	var difficulty := [BotAI.Difficulty.NORMAL, int(t["bots"][0]), int(t["bots"][1]), int(t["bots"][2])]
	var table_name := str(t["name"])
	var stacks: Array = []
	var n_players := 4
	var vacant: Array = []
	var dynamic := false
	if not ranked_table.is_empty():
		blind = int(ranked_table["blind"])
		buy_in = blind * int(ranked_table["stack_blinds"])
		# A mesa ranqueada tem 6 lugares; você entra numa com 3 a 6 sentados e, durante a partida,
		# gente sai e gente nova senta (espera o próximo Ritual). Ver BlitzEngine.pop_table_events.
		var occupied := clampi(int(ranked_table.get("players", 4)), BlitzEngine.MIN_SEATED, BlitzEngine.TABLE_SEATS)
		n_players = BlitzEngine.TABLE_SEATS
		dynamic = true
		var free_seats: Array = range(1, n_players)
		free_seats.shuffle()
		vacant = free_seats.slice(0, n_players - occupied)
		var d := Ranked.bot_difficulty_for_mmr(int(ranked()["mmr"]))
		# Slot 0 = humano; slots 1..n_players-1 = bots (ou assento vago)
		difficulty = [BotAI.Difficulty.NORMAL]
		for _i in range(n_players - 1):
			difficulty.append(d)
		table_name = "Ranqueada · %s · blind ◎%d" % [str(ranked_room_for_blind(blind)["name"]).capitalize(), blind]
		stacks = [float(buy_in)]
		for i in range(1, n_players):
			stacks.append(0.0 if vacant.has(i) else float(randi_range(int(BlitzEconomy.BOT_STACK_BLINDS[0]), int(BlitzEconomy.BOT_STACK_BLINDS[1])) * blind))
	var bot_names: Array = names.slice(0, n_players - 1)
	var entered := int(profile["fichas"]) >= buy_in
	if entered:
		profile["fichas"] = int(profile["fichas"]) - buy_in
		SaveManager.save_game()
	var cfg := {
		"players": n_players,
		"start_leader": randi() % n_players,
		"names": ([player_name()] as Array) + bot_names,
		"difficulty": difficulty,
		"blind": blind,
		"buy_in": buy_in,
		"table_name": table_name,
		"levels": 3 if autoplay else 0,
		"entered": entered,
	}
	if not stacks.is_empty():
		cfg["stacks"] = stacks
	if dynamic:
		cfg["dynamic_seats"] = true
		cfg["vacant"] = vacant
	return cfg


## Fecha uma sessão de mesa Blitz real (você saiu, quebrou ou a partida de teste acabou): devolve
## a stack final às fichas do perfil, dá Gemas e — fila única — aplica LP/MMR se jogou pelo menos
## um nível completo. Mesas de torneio NUNCA passam por aqui (ver `report_tournament_table`).
## result: { standings, stacks, payout (sua stack), buy_in, hands }
func report_blitz_match(result: Dictionary) -> Dictionary:
	var standings: Array = result["standings"]
	var placement := standings.find(0)
	var profile := SaveManager.section("profile")
	var payout := int(round(float(result.get("payout", 0.0))))
	var buy_in := int(round(float(result.get("buy_in", 0.0))))
	var hands := int(result.get("hands", 0))
	var net := payout - buy_in
	var won := net > 0
	var frag := 0
	var lines: Array = []
	if hands >= BlitzEngine.HAND_SIZE:
		profile["matches"] = int(profile["matches"]) + 1
		if won:
			profile["wins"] = int(profile["wins"]) + 1
		var frag_by_place := [15, 10, 6, 3]
		frag = frag_by_place[clampi(placement, 0, 3)]
		profile["gems"] = int(profile["gems"]) + frag
		var n_players: int = (result["standings"] as Array).size()
		lines.append_array(apply_ranked_progress(placement, int(round(net)), n_players))
	profile["fichas"] = int(profile["fichas"]) + payout
	SaveManager.save_game()
	if frag > 0:
		lines.append("+%d Gemas" % frag)
	lines.append("%s%d fichas nessa mesa (stack final %d)" % ["+" if net >= 0 else "", net, payout])
	var summary := {
		"placement": placement,
		"won": won,
		"lines": lines,
		"payout": payout,
		"net_fichas": net,
	}
	last_summary = summary
	return summary


# ------------------------------------------------------------------ torneios

func tournaments() -> Dictionary:
	return SaveManager.section("tournaments")


## Torneio: a rotação atual da mesa do jogador (as MESMAS referências de `tournament["tables"]`,
## na ordem que foi usada pra montar a config da cena) — pra escrever as stacks de volta sem
## precisar procurar por nome depois que o nível termina.
var _tournament_order: Array = []


## Inscreve, cobra o buy-in, sorteia o campo de 16 e monta as mesas iniciais (até
## `Tournament.MAX_TABLE` por mesa). Devolve {} se não tinha fichas pro buy-in.
func start_tournament(buy_in: int = Tournament.BUY_IN) -> Dictionary:
	var profile := SaveManager.section("profile")
	if int(profile["fichas"]) < buy_in:
		return {}
	profile["fichas"] = int(profile["fichas"]) - buy_in
	SaveManager.save_game()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var names: Array = BOT_NAMES.duplicate()
	for n in BOT_NAMES:   # precisa de 15 bots e só há 12 nomes: os extras ganham um "2" pra nunca haver dois iguais na mesa
		names.append("%s 2" % n)
	var cfg := Tournament.event_for(buy_in)
	var field := Tournament.make_field(player_name(), names, rng, float(cfg["stack"]))
	tournament = {"tables": Tournament.split_into_tables(field), "total_entrants": field.size(), "level": 0, "buy_in": buy_in, "cfg": cfg}
	return tournament


## Mesa atual do jogador dentro de `tournament["tables"]`.
func _tournament_player_table() -> Array:
	for t in (tournament["tables"] as Array):
		if Tournament.table_has_human(t):
			return t
	return []


## Config pra BlitzScene jogar 1 RODADA da mesa atual do jogador no torneio — stacks são as
## reais do torneio (viajam com cada jogador entre mesas), mas o buy-in já foi cobrado na
## inscrição, então não mexe nas fichas de verdade até o prêmio final
## (`report_tournament_table`). A mesa toca só esse nível; o resultado decide a próxima.
## Blind deste nível: tabela fixa do evento (Tournament.blind_for). Guardado em `tournament["blind_now"]`.
func _tournament_blind() -> int:
	var b := Tournament.blind_for(int(tournament.get("level", 0)), tournament.get("cfg", {}))
	tournament["blind_now"] = b
	return b


func tournament_table_config() -> Dictionary:
	var t := _tournament_player_table()
	var human_i := 0
	for i in range(t.size()):
		if bool((t[i] as Dictionary).get("human", false)):
			human_i = i
	# A cena sempre senta o jogador na vaga 0 — gira a ordem sem mudar quem joga contra quem.
	# Guarda as MESMAS referências nessa ordem, pra escrever a stack de volta depois sem procurar.
	_tournament_order = (t.slice(human_i) as Array) + (t.slice(0, human_i) as Array)
	var names: Array = []
	var difficulty: Array = []
	var stacks: Array = []
	for e in _tournament_order:
		names.append(str(e["name"]))
		difficulty.append(int(e["difficulty"]))
		stacks.append(float(e["stack"]))
	var blind := _tournament_blind()
	var alive := 0
	for tb in (tournament["tables"] as Array):
		alive += (tb as Array).size()
	return {
		"players": _tournament_order.size(),
		"start_leader": randi() % maxi(_tournament_order.size(), 1),
		"names": names,
		"difficulty": difficulty,
		"blind": blind,
		"buy_in": 0,
		"stacks": stacks,
		"table_name": "Torneio · %d restantes · blind ◎%d" % [alive, blind],
		"levels": 1,
		"entered": true,
		"tournament": true,
	}


## Fecha o nível de torneio do jogador: atualiza as stacks de todo mundo (a mesa dele de
## verdade, as outras headless no mesmo nível), tira quem quebrou, realoca quem sobrou e diz
## se o jogador avança, é campeão (só 1 sobra no torneio inteiro) ou foi eliminado.
## result: engine.make_standings() + stacks (igual report_blitz_match).
func report_tournament_table(result: Dictionary) -> Dictionary:
	var final_stacks: Array = result["stacks"]
	var out_flags: Array = result.get("busted", [])
	for i in range(_tournament_order.size()):
		var is_out: bool = i < out_flags.size() and bool(out_flags[i])
		(_tournament_order[i] as Dictionary)["stack"] = 0.0 if is_out else maxf(float(final_stacks[i]), 0.0)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var blind := int(tournament.get("blind_now", 0))
	if blind <= 0:
		blind = _tournament_blind()
	# Mesas de bots (todas, exceto a do jogador, que já tocou de verdade) jogam o mesmo nível,
	# no mesmo blind — o blind sobe com o torneio inteiro, não por mesa.
	for t in (tournament["tables"] as Array):
		if not Tournament.table_has_human(t):
			Tournament.simulate_level(t, blind, rng)
	var before := int(tournament.get("total_entrants", 0))
	if before <= 0:
		for t in (tournament["tables"] as Array):
			before += (t as Array).size()
	var survivors: Array = []
	for t in (tournament["tables"] as Array):
		for e in (t as Array):
			if float(e["stack"]) > 0.0:
				survivors.append(e)
	var busted_count := before - survivors.size()
	var profile := SaveManager.section("profile")
	var lines: Array = []
	var next := "eliminated"
	var human_alive := false
	for e in survivors:
		if bool(e.get("human", false)):
			human_alive = true
	if not human_alive:
		var placement := survivors.size() + 1   # 1 = campeão; empatou com quem mais quebrou junto
		var prize := Tournament.payout_for(placement - 1, int(tournament.get("buy_in", Tournament.BUY_IN)))
		if prize > 0:
			profile["fichas"] = int(profile["fichas"]) + prize
			lines.append("%dº lugar — +◎%d do bolão" % [placement, prize])
		else:
			lines.append("%dº lugar — eliminado, %d jogadores restantes." % [placement, survivors.size()])
		var trk := tournaments()
		(trk["history"] as Array).push_front({"result": "%dº lugar" % placement, "time": Time.get_datetime_string_from_system(false, true)})
		next = "eliminated"
		tournament = {}
	elif survivors.size() == 1:
		var prize := Tournament.payout_for(0, int(tournament.get("buy_in", Tournament.BUY_IN)))
		profile["fichas"] = int(profile["fichas"]) + prize
		var trk2 := tournaments()
		trk2["trophies"] = int(trk2.get("trophies", 0)) + 1
		(trk2["titles"] as Array).append("Campeão do Torneio")
		(trk2["history"] as Array).push_front({"result": "campeão", "time": Time.get_datetime_string_from_system(false, true)})
		lines.append("🏆 CAMPEÃO DO TORNEIO! +◎%d do bolão" % prize)
		next = "champion"
		tournament = {}
	else:
		var regrouped := Tournament.rebalance(_tables_from(survivors, tournament["tables"]))
		tournament["tables"] = regrouped
		tournament["total_entrants"] = survivors.size()
		tournament["level"] = int(tournament.get("level", 0)) + 1
		if busted_count > 0:
			lines.append("%d jogador(es) eliminado(s) nesse Ritual — %d restantes." % [busted_count, survivors.size()])
		else:
			lines.append("%d jogadores restantes." % survivors.size())
		next = "advance"
	SaveManager.save_game()
	var summary := {"won": next == "champion", "lines": lines, "next": next}
	last_summary = summary
	return summary


## Reagrupa os sobreviventes nas MESMAS mesas que já estavam (preservando quem ficou com quem),
## só removendo quem quebrou — `Tournament.rebalance` cuida de desfazer as que ficaram curtas.
func _tables_from(survivors: Array, old_tables: Array) -> Array:
	var out: Array = []
	for t in old_tables:
		var kept: Array = []
		for e in (t as Array):
			if survivors.has(e):
				kept.append(e)
		if not kept.is_empty():
			out.append(kept)
	return out


## Dificuldade dos bots no Clássico (Ajustes): 0 Fácil, 1 Normal, 2 Difícil. O tutorial usa
## sempre Fácil (jogadas previsíveis). Clássico é recreativo — não lê elo nenhum.
func bots_difficulty() -> int:
	if tutorial:
		return BotAI.Difficulty.EASY
	return clampi(int(settings().get("difficulty", 1)), 0, 2)


## Configuração da partida para a GameScene / MatchEngine conforme o modo.
func match_config() -> Dictionary:
	var names := BOT_NAMES.duplicate()
	names.shuffle()
	var cfg := {
		"players": 4,
		"names": [player_name(), names[0], names[1], names[2]],
		"difficulty": [BotAI.Difficulty.HARD, bots_difficulty(), bots_difficulty(), bots_difficulty()],
		"tutorial": tutorial,
	}
	if not tutorial:
		if table.is_empty():
			table = {"names": cfg["names"].duplicate(), "totals": [0.0, 0.0, 0.0, 0.0], "hands": 0}
		else:
			cfg["names"] = table["names"].duplicate()
	return cfg


## Fecha a partida de Clássico (recreativo puro — nunca mexe em elo) e devolve um resumo para
## a tela de resultado.
## result: { placement: int, taker: int, contract: int, success: bool, deltas: Array }
func report_match(result: Dictionary) -> Dictionary:
	var placement := int(result["placement"])
	if tutorial:
		tutorial = false
		var was_taker_t: bool = int(result.get("taker", -1)) == 0
		var role_t := "Atacante" if was_taker_t else "Defesa"
		var outcome_t := "bateu a meta" if bool(result.get("success", false)) else "não bateu a meta"
		return {
			"mode": mode,
			"placement": placement,
			"won": placement == 0,
			"lines": [
				"%s · %s" % [role_t, outcome_t] if was_taker_t else role_t,
				"%s%d pontos" % ["+" if int(result["deltas"][0]) >= 0 else "", int(result["deltas"][0])],
			],
			"next": "menu",
		}
	var profile := SaveManager.section("profile")
	profile["matches"] = int(profile["matches"]) + 1
	var won := placement == 0
	var summary := {"mode": mode, "placement": placement, "won": won, "lines": [], "next": "menu"}

	var was_taker: bool = int(result.get("taker", -1)) == 0
	var role := "Atacante" if was_taker else "Defesa"
	var outcome := "bateu a meta" if bool(result.get("success", false)) else "não bateu a meta"
	summary["lines"].append("%s · %s" % [role, outcome] if was_taker else role)
	summary["lines"].append("%s%d pontos" % ["+" if int(result["deltas"][0]) >= 0 else "", int(result["deltas"][0])])

	var frag := 8 if won else 3
	profile["gems"] = int(profile["gems"]) + frag
	summary["lines"].append("+%d Gemas" % frag)

	if won:
		profile["wins"] = int(profile["wins"]) + 1
	SaveManager.save_game()
	last_summary = summary
	return summary


## Fila única do Blitz: placement (0 = 1º), players = tamanho real da mesa (3–6).
## Devolve as linhas de resumo prontas pra mostrar. Chamado só por `report_blitz_match`.
func apply_ranked_progress(placement: int, score: int, players: int = 4) -> Array:
	var rk := ranked()
	var mmr := int(rk["mmr"])
	var lobby := lobby_avg_mmr()
	var d_lp := Ranked.lp_delta(placement, mmr, lobby, players)
	var d_mmr := Ranked.mmr_delta(placement, mmr, lobby, players)
	var before := Ranked.tier_info(int(rk["points"]), mmr)
	rk["points"] = maxi(0, int(rk["points"]) + d_lp)
	rk["mmr"] = maxi(0, mmr + d_mmr)
	rk["peak_points"] = maxi(int(rk["peak_points"]), int(rk["points"]))
	if placement <= 1:
		rk["wins"] = int(rk["wins"]) + 1
	else:
		rk["losses"] = int(rk["losses"]) + 1
	var after := Ranked.tier_info(int(rk["points"]), int(rk["mmr"]))
	var hist: Array = rk["history"]
	hist.push_front({"placement": placement + 1, "lp": d_lp, "score": score, "tier": after["label"], "time": Time.get_datetime_string_from_system(false, true)})
	while hist.size() > 20:
		hist.pop_back()
	var lines: Array = ["%s%d LP  ·  MMR %s%d" % ["+" if d_lp >= 0 else "", d_lp, "+" if d_mmr >= 0 else "", d_mmr]]
	if after["tier"] > before["tier"]:
		lines.append("PROMOÇÃO! %s" % after["label"])
	elif after["tier"] < before["tier"]:
		lines.append("Rebaixamento: %s" % after["label"])
	else:
		lines.append(after["label"])
	return lines
