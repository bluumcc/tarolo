extends Node
## Smoke test das cenas com autoloads: abre o menu e o lobby, joga rodadas completas de
## Tarot Vanilla (recreativo, sem elo) e de Blitz (fila única — toda mesa completa aplica
## LP/MMR automaticamente) em autoplay.
## Uso: godot --headless --path . res://tests/Smoke.tscn

const GAME := preload("res://scenes/GameScene.tscn")
const BLITZ := preload("res://scenes/BlitzScene.tscn")

var failures := 0


func _ready() -> void:
	SaveManager.persist = false
	SaveManager.data = SaveManager.defaults()
	GameState.fast = true
	GameState.autoplay = true
	await _run()
	print("SMOKE: %s" % ("OK" if failures == 0 else "%d falhas" % failures))
	get_tree().quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		printerr("FALHA: " + msg)


func _open(path: String) -> Node:
	var n: Node = load(path).instantiate()
	add_child(n)
	await get_tree().process_frame
	await get_tree().process_frame
	return n


func _play(mode: int) -> Dictionary:
	GameState.mode = mode
	var g: Node = GAME.instantiate()
	add_child(g)
	var summary: Dictionary = await g.match_finished
	check(g.engine.is_round_over(), "partida terminou")
	var total_captured := 0
	for hand in g.engine.captured:
		total_captured += (hand as Array).size()
	# No Garde Contre le Chien, o talão (6 cartas) fica fora da jogada de propósito.
	var expected := 78 if g.engine.contract != Scoring.Contract.GARDE_CONTRE else 78 - Deck.CHIEN_SIZE
	check(total_captured == expected, "todas as cartas relevantes foram capturadas (tem %d, esperava %d)" % [total_captured, expected])
	await get_tree().process_frame
	g.queue_free()
	await get_tree().process_frame
	return summary


func _play_blitz() -> Dictionary:
	# A mesa cobra o buy-in: sem saldo ela nem abre (e o teste ficaria esperando pra sempre).
	SaveManager.section("profile")["fichas"] = maxi(int(SaveManager.section("profile")["fichas"]), 2000)
	var g: Node = BLITZ.instantiate()
	add_child(g)
	var summary: Dictionary = await g.match_finished
	check(g.engine.hand_no >= 1, "mesa de blitz rodou (%d rodadas)" % g.engine.hand_no)
	check(not g.engine.match_result.is_empty(), "match_result preenchido no fim")
	await get_tree().process_frame
	g.queue_free()
	await get_tree().process_frame
	return summary


func _play_tournament_table() -> Dictionary:
	var g: Node = BLITZ.instantiate()
	add_child(g)
	var summary: Dictionary = await g.match_finished
	check(not g.engine.match_result.is_empty(), "mesa de torneio terminou")
	await get_tree().process_frame
	g.queue_free()
	await get_tree().process_frame
	return summary


## Joga um torneio inteiro em autoplay: MTT de verdade, um nível do jogador por vez, até ele
## ser eliminado ou virar campeão (campo de 16, mesas de até Tournament.MAX_TABLE).
func _run_tournament(i: int) -> void:
	SaveManager.section("profile")["fichas"] = maxi(int(SaveManager.section("profile")["fichas"]), 2000)
	var t := GameState.start_tournament()
	check(not t.is_empty(), "torneio %d: inscrição aceita" % i)
	var levels := 0
	var cap := 60   # blind escalando, 16 pro campo some bem antes disso — mais que isso é anomalia
	while not GameState.tournament.is_empty() and levels < cap:
		var s := await _play_tournament_table()
		print("Torneio %d, nível %d: %s" % [i, levels + 1, " | ".join(s["lines"])])
		levels += 1
	check(levels < cap, "torneio %d: terminou antes do teto de níveis (rodou %d)" % [i, levels])
	check(GameState.tournament.is_empty(), "torneio %d: estado fechado ao terminar" % i)


func _run() -> void:
	var menu := await _open("res://scenes/MainMenu.tscn")
	menu._open_settings()
	menu._open_rules()
	await get_tree().process_frame
	menu.queue_free()

	for i in range(8):
		var s := await _play(GameState.Mode.CLASSIC)
		print("Vanilla %d: %dº lugar · %s" % [i + 1, int(s["placement"]) + 1, " | ".join(s["lines"])])
	check(int(SaveManager.section("profile")["matches"]) == 8, "vanilla contabilizado (%d)" % int(SaveManager.section("profile")["matches"]))

	# Ranqueado é o próprio Blitz (fila única): a tela só mostra liga/histórico e manda pro Blitz.
	var lobby := await _open("res://scenes/RankedLobby.tscn")
	lobby.queue_free()

	for i in range(8):
		var s := await _play_blitz()
		print("Blitz %d: %dº lugar | %s" % [i + 1, int(s["placement"]) + 1, " | ".join(s["lines"])])
	check((GameState.ranked()["history"] as Array).size() == 8, "fila única: toda mesa de blitz completa aplica LP/MMR (tem %d)" % (GameState.ranked()["history"] as Array).size())

	# Os 5 níveis: cada um acha mesa do próprio blind, com 3 a 6 lugares; o popup abre e lista os 5.
	check(GameState.RANKED_ROOMS.size() == 5, "ranqueada tem 5 níveis")
	for r in GameState.RANKED_ROOMS:
		var found := GameState.find_ranked_room(10000000, int(r["blind"]))
		check(int(found["blind"]) == int(r["blind"]) and int(found["players"]) >= 3 and int(found["players"]) <= 6 and bool(found["affordable"]), "nível %s acha mesa do próprio blind" % r["name"])
		check(not bool(GameState.find_ranked_room(0, int(r["blind"]))["affordable"]), "nível %s sem saldo não é acessível" % r["name"])
	SaveManager.section("profile")["fichas"] = 2000
	var pm := await _open("res://scenes/MainMenu.tscn")
	pm._start_ranked_matchmaking()
	await get_tree().process_frame
	var enabled := 0
	var total := 0
	for n in pm._overlay.find_children("*", "Button", true, false):
		if (n as Button).text.contains("  O ") or (n as Button).text.contains("  A "):
			total += 1
			if not (n as Button).disabled:
				enabled += 1
	check(total == 5, "popup lista os 5 níveis (%d)" % total)
	check(enabled == 1, "com ◎2.000 só o nível de blind 10 (◎800) está liberado; o de blind 30 pede ◎2.400 (%d)" % enabled)
	pm.queue_free()
	await get_tree().process_frame

	# Mesa ranqueada de 6 lugares: gente sai e entra durante a partida (3 a 6 sentados no começo).
	var before: int = (GameState.ranked()["history"] as Array).size()
	for i in range(6):
		SaveManager.section("profile")["fichas"] = 200000   # a mesa cobra o buy-in de 80 blinds do nível
		GameState.ranked_table = {"blind": int(GameState.RANKED_ROOMS[i % 5]["blind"]), "stack_blinds": GameState.RANKED_STACK_BLINDS, "players": 3 + (i % 4)}
		var s := await _play_blitz()
		check(int(s["placement"]) >= 0, "mesa ranqueada %d (%d sentados): terminou" % [i + 1, 3 + (i % 4)])
	GameState.ranked_table = {}
	# LP só conta com um Ritual completo (8 jogadas): mesa desfeita ou quebra cedo não pontua.
	var grew: int = (GameState.ranked()["history"] as Array).size() - before
	check(grew >= 1 and grew <= 6, "mesas ranqueadas dinâmicas aplicam LP/MMR só quando há Ritual completo (%d de 6)" % grew)

	for i in range(4):
		await _run_tournament(i + 1)
	check((GameState.tournaments()["history"] as Array).size() == 4, "torneios: histórico registrado (tem %d)" % (GameState.tournaments()["history"] as Array).size())
