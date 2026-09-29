extends Node
## Smoke test das cenas com autoloads: abre o menu e o lobby, e joga rodadas completas
## de Tarot Vanilla em autoplay nos modos Vanilla e Ranqueado.
## Uso: godot --headless --path . res://tests/Smoke.tscn

const GAME := preload("res://scenes/GameScene.tscn")
const CHAOS := preload("res://scenes/ChaosScene.tscn")

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


func _play_chaos() -> Dictionary:
	var g: Node = CHAOS.instantiate()
	add_child(g)
	var summary: Dictionary = await g.match_finished
	check(g.engine.hand_no >= ChaosEngine.HAND_SIZE, "mesa de Caos rodou pelo menos um nível (%d rodadas de aposta)" % g.engine.hand_no)
	check(not g.engine.match_result.is_empty(), "match_result preenchido no fim")
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

	for i in range(8):
		var s := await _play(GameState.Mode.CLASSIC)
		print("Vanilla %d: %dº lugar · %s" % [i + 1, int(s["placement"]) + 1, " | ".join(s["lines"])])
	check(int(SaveManager.section("profile")["matches"]) == 8, "vanilla contabilizado (%d)" % int(SaveManager.section("profile")["matches"]))

	var lobby := await _open("res://scenes/RankedLobby.tscn")
	lobby.queue_free()
	for i in range(6):
		GameState.find_ranked_lobby()
		var s := await _play(GameState.Mode.RANKED)
		print("Ranqueado %d: %dº · %s" % [i + 1, int(s["placement"]) + 1, " | ".join(s["lines"])])
	check((GameState.ranked()["history"] as Array).size() == 6, "histórico ranqueado")
	lobby = await _open("res://scenes/RankedLobby.tscn")
	lobby.queue_free()

	for i in range(4):
		var s := await _play_chaos()
		print("Caos %d: %dº lugar | %s" % [i + 1, int(s["placement"]) + 1, " | ".join(s["lines"])])
