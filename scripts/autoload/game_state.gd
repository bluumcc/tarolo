extends Node
## Estado da sessão: modo atual, run do Arcade, lobby ranqueado e fechamento de partidas.

enum Mode { CLASSIC, ARCADE, RANKED }

const MODE_NAMES := ["Clássico", "Arcade", "Ranqueado"]
const BOT_NAMES := ["João", "Ana", "Felipe", "Mateus", "Lucas", "Sabrina", "Joana", "Pedro", "Márcio", "Júnior", "Fábio", "Marcos"]
const ARCADE_BASE_GOLD := 4

var mode: int = Mode.CLASSIC
## Testes/demos: o assento do jogador passa a ser controlado por um bot difícil.
var autoplay := false
## Remove esperas de animação (testes headless).
var fast := false

var ranked_lobby: Array = []   # [{name, mmr}] adversários encontrados no matchmaking
var last_summary: Dictionary = {}


func _ready() -> void:
	apply_settings()
	get_tree().root.size_changed.connect(_update_content_scale)
	_update_content_scale()


## Resolução base 1280x720 no paisagem (PC) e 720x1280 no retrato (smartphone),
## para a UI não encolher pela metade em telas verticais.
func _update_content_scale() -> void:
	var win := get_tree().root.size
	var portrait := win.y > win.x
	get_tree().root.content_scale_size = Vector2i(720, 1280) if portrait else Vector2i(1280, 720)


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


# ------------------------------------------------------------------ arcade

func run() -> Dictionary:
	return SaveManager.section("arcade")["run"]


func has_run() -> bool:
	return not run().is_empty()


func start_arcade_run() -> void:
	var arcade := SaveManager.section("arcade")
	arcade["run"] = {"stage": 1, "gold": ARCADE_BASE_GOLD, "jokers": [], "upgrades": {}, "rerolls": 0, "seed": randi()}
	arcade["runs"] = int(arcade["runs"]) + 1
	mode = Mode.ARCADE
	SaveManager.save_game()


func abandon_run() -> void:
	var arcade := SaveManager.section("arcade")
	arcade["best_stage"] = maxi(int(arcade["best_stage"]), int(run().get("stage", 1)) - 1)
	arcade["run"] = {}
	SaveManager.save_game()


## Cada fase tem um Chefe (um Arcano Maior) que o jogador precisa superar no placar.
func arcade_boss(stage: int) -> Dictionary:
	var idx := (stage - 1) % CardData.MAJOR_ARCANA.size()
	var diff := BotAI.Difficulty.EASY if stage <= 2 else (BotAI.Difficulty.NORMAL if stage <= 5 else BotAI.Difficulty.HARD)
	return {"name": CardData.MAJOR_ARCANA[idx], "mult": 1.0 + 0.2 * (stage - 1), "difficulty": diff}


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


## Configuração da partida para a GameScene / MatchEngine conforme o modo.
func match_config() -> Dictionary:
	var names := BOT_NAMES.duplicate()
	names.shuffle()
	var cfg := {
		"players": 4,
		"arcana_count": 4,
		"modifiers": false,
		"upgrades": {},
		"jokers": [],
		"stage_mult": [1.0, 1.0, 1.0, 1.0],
		"names": [player_name(), names[0], names[1], names[2]],
		"difficulty": [BotAI.Difficulty.HARD, BotAI.Difficulty.NORMAL, BotAI.Difficulty.NORMAL, BotAI.Difficulty.NORMAL],
		"boss_seat": -1,
	}
	match mode:
		Mode.ARCADE:
			var r := run()
			var stage := int(r["stage"])
			var boss := arcade_boss(stage)
			cfg["modifiers"] = true
			cfg["upgrades"] = r["upgrades"]
			cfg["jokers"] = r["jokers"]
			cfg["seed"] = int(r["seed"]) + stage * 7919
			cfg["boss_seat"] = 2
			cfg["names"][2] = boss["name"]
			cfg["stage_mult"][2] = boss["mult"]
			var easy := BotAI.Difficulty.EASY if stage <= 3 else BotAI.Difficulty.NORMAL
			cfg["difficulty"] = [BotAI.Difficulty.HARD, easy, boss["difficulty"], easy]
		Mode.RANKED:
			var diff := Ranked.bot_difficulty_for_mmr(int(ranked()["mmr"]))
			cfg["difficulty"] = [BotAI.Difficulty.HARD, diff, diff, diff]
			for i in range(mini(ranked_lobby.size(), 3)):
				cfg["names"][i + 1] = ranked_lobby[i]["name"]
	return cfg


## Fecha a partida, aplica economia/LP e devolve um resumo para a tela de resultado.
## result: { placement, scores, tricks_won, gold_earned, beat_boss }
func report_match(result: Dictionary) -> Dictionary:
	var placement := int(result["placement"])
	var profile := SaveManager.section("profile")
	profile["matches"] = int(profile["matches"]) + 1
	var won := placement == 0
	var summary := {"mode": mode, "placement": placement, "won": won, "lines": [], "next": "menu"}

	match mode:
		Mode.CLASSIC:
			var frag := 8 if won else 3
			profile["fragments"] = int(profile["fragments"]) + frag
			summary["lines"].append("+%d Fragmentos" % frag)
		Mode.ARCADE:
			var r := run()
			var stage := int(r["stage"])
			won = bool(result.get("beat_boss", won))
			summary["won"] = won
			if won:
				var gold_trick := int(result.get("gold_earned", 0))
				var clear_bonus := 3 + stage
				var interest := 0
				if (r["jokers"] as Array).has("juros"):
					interest = mini(int(r["gold"]) / 4, 8)
				else:
					interest = mini(int(r["gold"]) / 5, 5)
				r["gold"] = int(r["gold"]) + gold_trick + clear_bonus + interest
				r["stage"] = stage + 1
				r["rerolls"] = 0
				summary["lines"].append("Ouro das vazas: +%d" % gold_trick)
				summary["lines"].append("Fase %d concluída: +%d" % [stage, clear_bonus])
				summary["lines"].append("Juros: +%d" % interest)
				summary["next"] = "shop"
				profile["fragments"] = int(profile["fragments"]) + 2
			else:
				summary["lines"].append("Run encerrada na fase %d" % stage)
				var frag := stage * 2
				profile["fragments"] = int(profile["fragments"]) + frag
				summary["lines"].append("+%d Fragmentos" % frag)
				abandon_run()
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
			hist.push_front({"placement": placement + 1, "lp": d_lp, "score": int(result["scores"][0]), "tier": after["label"], "time": Time.get_datetime_string_from_system(false, true)})
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
