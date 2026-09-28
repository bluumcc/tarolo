extends Node
## Smoke test das cenas com autoloads: abre menus/loja/lobby e joga partidas completas em
## autoplay nos três modos. Uso: godot --headless --path . res://tests/Smoke.tscn

const GAME := preload("res://scenes/GameScene.tscn")

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
	await get_tree().process_frame
	g.queue_free()
	await get_tree().process_frame
	return summary


func _run() -> void:
	var menu := await _open("res://scenes/MainMenu.tscn")
	menu._open_settings()
	menu._open_cosmetics()
	menu._open_rules()
	await get_tree().process_frame
	menu.queue_free()

	var s := await _play(GameState.Mode.CLASSIC)
	check(int(SaveManager.section("profile")["matches"]) == 1, "clássico contabilizado")
	print("Clássico: %dº lugar" % (int(s["placement"]) + 1))

	GameState.start_arcade_run()
	var stages := 0
	for i in range(6):
		s = await _play(GameState.Mode.ARCADE)
		if not s["won"]:
			break
		stages += 1
		var shop := await _open("res://scenes/Shop.tscn")
		GameState.run()["gold"] = 50
		shop._render()
		await get_tree().process_frame
		if not shop.offers_jokers.is_empty():
			shop._buy_joker(shop.offers_jokers[0], 1)
		if not shop.offers_cards.is_empty():
			shop._buy_card(0)
		shop.queue_free()
		await get_tree().process_frame
	print("Arcade: %d fases superadas, curingas %s" % [stages, GameState.run().get("jokers", [])])
	check(stages == 6 or not GameState.has_run(), "run encerrada ao perder")

	var lobby := await _open("res://scenes/RankedLobby.tscn")
	lobby.queue_free()
	for i in range(5):
		GameState.find_ranked_lobby()
		s = await _play(GameState.Mode.RANKED)
		print("Ranqueado: %dº · %s" % [int(s["placement"]) + 1, " | ".join(s["lines"])])
	check((GameState.ranked()["history"] as Array).size() == 5, "histórico ranqueado")
	lobby = await _open("res://scenes/RankedLobby.tscn")
	lobby.queue_free()
