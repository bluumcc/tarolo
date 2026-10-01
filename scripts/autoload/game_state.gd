extends Node
## Estado da sessão: modo atual, lobby ranqueado e fechamento de partidas.

## Vanilla é só recreativo (sem Mode.RANKED): o Elo agora é inteiramente do Blitz, fila
## única — toda mesa real de Blitz vale fichas E LP/MMR ao mesmo tempo (ver `blitz_ranked`).
enum Mode { CLASSIC }

const MODE_NAMES := ["Vanilla"]
const BOT_NAMES := ["João", "Ana", "Felipe", "Mateus", "Lucas", "Sabrina", "Joana", "Pedro", "Márcio", "Júnior", "Fábio", "Marcos"]

var mode: int = Mode.CLASSIC
## Testes/demos: o assento do jogador passa a ser controlado por um bot difícil.
var autoplay := false
## Remove esperas de animação (testes headless).
var fast := false
## Partida de tutorial: mão fixa + dicas contextuais, não mexe em Gemas/elo.
var tutorial := false
## Falso só pra mesas de torneio: elas valem fichas (o bolão) mas não mexem no Elo da fila
## regular — tudo mais (ex.: jogar Blitz pelo menu) é fila única e sempre ranqueada.
var blitz_ranked := true


func start_tutorial() -> void:
	mode = Mode.CLASSIC
	tutorial = true

var ranked_lobby: Array = []   # [{name, mmr}] adversários encontrados no matchmaking
var last_summary: Dictionary = {}
## Resgate automático de fichas (ChaosEconomy.rescue_if_broke) aplicado na última sentada na
## mesa — a cena mostra um aviso uma vez e zera isso de novo.
var last_rescue := 0
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
	return str(SaveManager.section("profile")["name"])


## Mesas do Caos: blind, com buy-in de 20 blinds (a stack com que você senta).
const CHAOS_TABLES := [
	{"name": "Iniciante", "blind": 10, "bots": [0, 0, 1]},   # Fácil, Fácil, Normal
	{"name": "Regular", "blind": 50, "bots": [1, 1, 2]},     # Normal, Normal, Difícil
	{"name": "Alta", "blind": 200, "bots": [2, 2, 2]},       # Difícil x3
]
var chaos_table := 0
var chaos_mode := "blitz"    # só "blitz" existe hoje (Caos removido); campo mantido por compatibilidade de save


func chaos_buy_in(table: int = -1) -> int:
	var t: Dictionary = CHAOS_TABLES[clampi(chaos_table if table < 0 else table, 0, CHAOS_TABLES.size() - 1)]
	return int(t["blind"]) * ChaosEngine.BUY_IN_BLINDS


## Configuração da mesa pra ChaosScene / ChaosEngine — todo mundo joga pra si. Já cobra o
## buy-in das fichas do jogador (config["entered"] = false se não tinha saldo); ele volta
## como stack final quando você sai da mesa.
const ONBOARDING_LEVELS := 3   # 1ª, 2ª e 3ª mesas de Blitz: sem dobrar/cobrir, pra aprender o palpite sozinho (modificador continua ativo sempre)


func chaos_config() -> Dictionary:
	var names := BOT_NAMES.duplicate()
	names.shuffle()
	var profile := SaveManager.section("profile")
	last_rescue = ChaosEconomy.rescue_if_broke(profile)
	if last_rescue > 0:
		SaveManager.save_game()
	if blitz_ranked:
		find_ranked_lobby()
	var t: Dictionary = CHAOS_TABLES[clampi(chaos_table, 0, CHAOS_TABLES.size() - 1)]
	var blind := int(t["blind"])
	var buy_in := chaos_buy_in()
	var entered := int(profile["fichas"]) >= buy_in
	if entered:
		profile["fichas"] = int(profile["fichas"]) - buy_in
		SaveManager.save_game()
	return {
		"players": 4,
		"names": [player_name(), names[0], names[1], names[2]],
		"difficulty": [BotAI.Difficulty.NORMAL, int(t["bots"][0]), int(t["bots"][1]), int(t["bots"][2])],
		"blind": blind,
		"buy_in": buy_in,
		"table_name": str(t["name"]),
		"mode": chaos_mode,
		"levels": 3 if autoplay else 0,
		"entered": entered,
		"onboarding_levels": maxi(0, ONBOARDING_LEVELS - int(profile.get("blitz_levels", 0))) if chaos_mode == "blitz" else 0,
	}


## Chamado a cada nível de Blitz concluído: conta pro fim das regras simplificadas dos primeiros
## níveis (ver `ONBOARDING_LEVELS`). Não faz nada fora do Blitz.
func blitz_level_played() -> void:
	var profile := SaveManager.section("profile")
	profile["blitz_levels"] = int(profile.get("blitz_levels", 0)) + 1
	SaveManager.save_game()


## Fecha uma sessão de mesa Blitz (você saiu, quebrou ou a partida de teste acabou): devolve
## a stack final às fichas do perfil, dá Gemas e — fila única — aplica LP/MMR se jogou pelo
## menos um nível completo (torneio chama com `blitz_ranked = false`, então não mexe no Elo).
## result: { standings, stacks, payout (sua stack), buy_in, hands }
func report_chaos_match(result: Dictionary) -> Dictionary:
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
	if hands >= ChaosEngine.HAND_SIZE:
		profile["matches"] = int(profile["matches"]) + 1
		if won:
			profile["wins"] = int(profile["wins"]) + 1
		var frag_by_place := [15, 10, 6, 3]
		frag = frag_by_place[clampi(placement, 0, 3)]
		profile["gems"] = int(profile["gems"]) + frag
		if blitz_ranked:
			lines.append_array(apply_ranked_progress(placement, int(round(net))))
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


## Dificuldade dos bots no Vanilla (Ajustes): 0 Fácil, 1 Normal, 2 Difícil. O tutorial usa
## sempre Fácil (jogadas previsíveis). Vanilla é recreativo — não lê elo nenhum.
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


## Fecha a partida de Vanilla (recreativo puro — nunca mexe em elo) e devolve um resumo para
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


## Fila única do Blitz: placement (0 = 1º ... 3 = 4º) e o LP/MMR de acordo. Devolve as linhas
## de resumo prontas pra mostrar. Usado só quando `blitz_ranked` (torneio chama com false).
func apply_ranked_progress(placement: int, score: int) -> Array:
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
