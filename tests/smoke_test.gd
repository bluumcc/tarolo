extends Node
## Smoke test das cenas com autoloads: abre o menu e o lobby, joga rodadas completas de
## Tarot Vanilla (recreativo, sem elo) e de Blitz (fila única — toda mesa completa aplica
## LP/MMR automaticamente) em autoplay.
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
	GameState.chaos_mode = "blitz"
	# A mesa cobra o buy-in: sem saldo ela nem abre (e o teste ficaria esperando pra sempre).
	SaveManager.section("profile")["fichas"] = maxi(int(SaveManager.section("profile")["fichas"]), 2000)
	var g: Node = CHAOS.instantiate()
	add_child(g)
	var summary: Dictionary = await g.match_finished
	check(g.engine.hand_no >= 1, "mesa de blitz rodou (%d rodadas)" % g.engine.hand_no)
	check(g.engine.blitz, "modo da mesa respeitado")
	check(not g.engine.match_result.is_empty(), "match_result preenchido no fim")
	await get_tree().process_frame
	g.queue_free()
	await get_tree().process_frame
	return summary


func _play_tournament_table() -> Dictionary:
	var g: Node = CHAOS.instantiate()
	add_child(g)
	var summary: Dictionary = await g.match_finished
	check(not g.engine.match_result.is_empty(), "mesa de torneio terminou")
	await get_tree().process_frame
	g.queue_free()
	await get_tree().process_frame
	return summary


## Joga um torneio inteiro em autoplay: no máximo 2 mesas (Quartas, e Final se avançar).
func _run_tournament(i: int) -> void:
	SaveManager.section("profile")["fichas"] = maxi(int(SaveManager.section("profile")["fichas"]), 2000)
	var t := GameState.start_tournament()
	check(not t.is_empty(), "torneio %d: inscrição aceita" % i)
	var rounds := 0
	while not GameState.tournament.is_empty() and rounds < 3:
		var s := await _play_tournament_table()
		print("Torneio %d, mesa %d: %s" % [i, rounds + 1, " | ".join(s["lines"])])
		rounds += 1
	check(rounds in [1, 2], "torneio %d: 1 mesa (eliminado nas Quartas) ou 2 (chegou à Final), rodou %d" % [i, rounds])
	check(GameState.tournament.is_empty(), "torneio %d: estado fechado ao terminar" % i)


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

	# Ranqueado é o próprio Blitz (fila única): a tela só mostra liga/histórico e manda pro Blitz.
	var lobby := await _open("res://scenes/RankedLobby.tscn")
	lobby.queue_free()

	for i in range(8):
		var s := await _play_chaos()
		print("Blitz %d: %dº lugar | %s" % [i + 1, int(s["placement"]) + 1, " | ".join(s["lines"])])
	check((GameState.ranked()["history"] as Array).size() == 8, "fila única: toda mesa de blitz completa aplica LP/MMR (tem %d)" % (GameState.ranked()["history"] as Array).size())

	for i in range(4):
		await _run_tournament(i + 1)
	check((GameState.tournaments()["history"] as Array).size() == 4, "torneios: histórico registrado (tem %d)" % (GameState.tournaments()["history"] as Array).size())
