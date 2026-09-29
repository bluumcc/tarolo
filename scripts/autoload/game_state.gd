extends Node
## Estado da sessão: modo atual, lobby ranqueado e fechamento de partidas.

enum Mode { CLASSIC, RANKED }

const MODE_NAMES := ["Vanilla", "Ranqueado"]
const BOT_NAMES := ["João", "Ana", "Felipe", "Mateus", "Lucas", "Sabrina", "Joana", "Pedro", "Márcio", "Júnior", "Fábio", "Marcos"]

var mode: int = Mode.CLASSIC
## Testes/demos: o assento do jogador passa a ser controlado por um bot difícil.
var autoplay := false
## Remove esperas de animação (testes headless).
var fast := false
## Partida de tutorial: mão fixa + dicas contextuais, não mexe em Fragmentos/elo.
var tutorial := false


func start_tutorial() -> void:
	mode = Mode.CLASSIC
	tutorial = true

var ranked_lobby: Array = []   # [{name, mmr}] adversários encontrados no matchmaking
var last_summary: Dictionary = {}
## Mesa contínua do Vanilla: os mesmos jogadores ficam sentados e o placar acumula, mão
## após mão, até alguém levantar. {names, totals, hands}
var table: Dictionary = {}


func leave_table() -> void:
	table = {}


## Soma os pontos da mão ao placar da mesa (só Vanilla, fora do tutorial).
func table_add(deltas: Array) -> void:
	if table.is_empty():
		return
	for i in range(deltas.size()):
		table["totals"][i] = float(table["totals"][i]) + float(deltas[i])
	table["hands"] = int(table["hands"]) + 1



func _ready() -> void:
	_install_symbol_font()
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
	# fica de reserva pros símbolos (♥ ♦ ♠ ♣ ✦ ✶ 🔥) que a Lilita não tem — o navegador do
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
	return str(SaveManager.section("profile")["name"])


## Configuração da partida pra ChaosScene / ChaosEngine — todo mundo joga pra si, sem
## Atacante/Defesa, então não precisa de dificuldade especial pro assento do jogador.
## Já cobra o buy-in das fichas do jogador (config["entered"] = false se não tinha saldo).
func chaos_config() -> Dictionary:
	var names := BOT_NAMES.duplicate()
	names.shuffle()
	var profile := SaveManager.section("profile")
	var buy_in := ChaosEngine.BUY_IN
	var entered := int(profile["fichas"]) >= buy_in
	if entered:
		profile["fichas"] = int(profile["fichas"]) - buy_in
		SaveManager.save_game()
	return {
		"players": 4,
		"names": [player_name(), names[0], names[1], names[2]],
		"difficulty": [BotAI.Difficulty.NORMAL, BotAI.Difficulty.NORMAL, BotAI.Difficulty.NORMAL, BotAI.Difficulty.NORMAL],
		"buy_in": buy_in,
		"entered": entered,
	}


## Fecha uma partida de Caos e devolve um resumo pra tela de resultado. Dá Fragmentos
## conforme a colocação e paga a fatia do pote correspondente em fichas (o buy-in já
## saiu do bolso na entrada, via chaos_config). Não mexe em LP/elo — isso é só do
## Ranqueado (Vanilla).
## result: { standings: Array, totals: Array, payout: float, buy_in: float }
func report_chaos_match(result: Dictionary) -> Dictionary:
	var standings: Array = result["standings"]
	var placement := standings.find(0)
	var profile := SaveManager.section("profile")
	profile["matches"] = int(profile["matches"]) + 1
	var won := placement == 0
	if won:
		profile["wins"] = int(profile["wins"]) + 1
	var frag_by_place := [15, 10, 6, 3]
	var frag: int = frag_by_place[clampi(placement, 0, 3)]
	profile["fragments"] = int(profile["fragments"]) + frag
	var payout := int(round(float(result.get("payout", 0.0))))
	var buy_in := int(round(float(result.get("buy_in", 0.0))))
	profile["fichas"] = int(profile["fichas"]) + payout
	SaveManager.save_game()
	var net := payout - buy_in
	var summary := {
		"placement": placement,
		"won": won,
		"lines": [
			"%s%d Fragmentos" % ["+" if frag >= 0 else "", frag],
			"%s%d fichas nessa mesa (pote pagou %d)" % ["+" if net >= 0 else "", net, payout],
		],
		"payout": payout,
		"net_fichas": net,
	}
	last_summary = summary
	return summary


## Dificuldade dos bots no Vanilla comum (Ajustes): 0 Fácil, 1 Normal, 2 Difícil. O
## tutorial usa sempre Fácil (jogadas previsíveis) e o Ranqueado usa o seu elo.
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
	if mode == Mode.CLASSIC and not tutorial:
		if table.is_empty():
			table = {"names": cfg["names"].duplicate(), "totals": [0.0, 0.0, 0.0, 0.0], "hands": 0}
		else:
			cfg["names"] = table["names"].duplicate()
	if mode == Mode.RANKED:
		var diff := Ranked.bot_difficulty_for_mmr(int(ranked()["mmr"]))
		cfg["difficulty"] = [BotAI.Difficulty.HARD, diff, diff, diff]
		for i in range(mini(ranked_lobby.size(), 3)):
			cfg["names"][i + 1] = ranked_lobby[i]["name"]
	return cfg


## Fecha a partida, aplica economia/LP e devolve um resumo para a tela de resultado.
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

	match mode:
		Mode.CLASSIC:
			var frag := 8 if won else 3
			profile["fragments"] = int(profile["fragments"]) + frag
			summary["lines"].append("+%d Fragmentos" % frag)
		Mode.RANKED:
			var rk := ranked()
			var mmr := int(rk["mmr"])
			var lobby := lobby_avg_mmr()
			var d_lp := Ranked.lp_delta(placement, mmr, lobby)
			var d_mmr := Ranked.mmr_delta(placement, mmr, lobby)
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
			hist.push_front({"placement": placement + 1, "lp": d_lp, "score": int(result["deltas"][0]), "tier": after["label"], "time": Time.get_datetime_string_from_system(false, true)})
			while hist.size() > 20:
				hist.pop_back()
			summary["lines"].append("%s%d LP  ·  MMR %s%d" % ["+" if d_lp >= 0 else "", d_lp, "+" if d_mmr >= 0 else "", d_mmr])
			if after["tier"] > before["tier"]:
				summary["lines"].append("PROMOÇÃO! %s" % after["label"])
			elif after["tier"] < before["tier"]:
				summary["lines"].append("Rebaixamento: %s" % after["label"])
			else:
				summary["lines"].append(after["label"])
			var frag := 12 if placement == 0 else 5
			profile["fragments"] = int(profile["fragments"]) + frag
			summary["lines"].append("+%d Fragmentos" % frag)
			summary["next"] = "ranked"

	if won:
		profile["wins"] = int(profile["wins"]) + 1
	SaveManager.save_game()
	last_summary = summary
	return summary
