extends Node
## A interface da mesa nunca pode passar da largura da tela, qualquer que seja o texto do aviso
## ou o tamanho do nome. Um Label sem corte alarga o container e estica a mesa toda pra direita.
## Uso: godot --headless --path . res://tests/LayoutStretchTest.tscn

const BLITZ := preload("res://scenes/BlitzScene.tscn")
const WIDE := "WWWWWWWWWWWWWWWW"

var failures := 0
var scene: Node
var worst := 0.0
var worst_text := ""


func _ready() -> void:
	SaveManager.persist = false
	SaveManager.data = SaveManager.defaults()
	SaveManager.section("profile")["fichas"] = 1000000
	GameState.fast = true
	GameState.autoplay = true
	var be := LocalAccountBackend.new()
	be.persist = false
	await Accounts.use_backend(be)
	await Accounts.rename(WIDE)
	get_tree().root.size = Vector2i(390, 844)   # celular em pé
	await get_tree().process_frame
	await get_tree().process_frame
	scene = BLITZ.instantiate()
	add_child(scene)
	await _frames()

	var texts := [
		"Você venceu",
		"%s roubou de %s" % [WIDE, WIDE],
		"%s venceu · %s leva o lateral ◎12.345 · ◎9.999 voltam pra %s" % [WIDE, WIDE, WIDE],
		"%s pagou aos rivais" % WIDE,
	]
	var vw := get_viewport().get_visible_rect().size.x
	var worst_need := 0.0
	for t in texts:
		scene._banner(t, "", UIKit.OK)
		# Mede na hora (a partida segue rodando e trocaria o texto num quadro): quanto de largura a
		# caixa principal PRECISARIA. Acima da tela, a mesa inteira estica pra direita.
		var need: float = scene.margin_box.get_combined_minimum_size().x
		if need > worst_need:
			worst_need = need
			worst_text = "aviso: " + t
	worst = maxf(worst, worst_need - vw)
	check(worst_need <= vw + 0.5, "o aviso não estica a mesa: precisaria de %.0f px numa tela de %.0f (%s)" % [worst_need, vw, worst_text])

	# Partida inteira em autoplay, conferindo a cada quadro.
	var runner := _Watcher.new()
	runner.owner_test = self
	add_child(runner)
	await scene.match_finished
	runner.queue_free()
	check(worst <= 0.5, "partida inteira sem esticar a mesa: estouro máximo %.0f px (pior caso: %s)" % [worst, worst_text])

	print("LAYOUT STRETCH: %s" % ("OK" if failures == 0 else "%d falhas" % failures))
	get_tree().quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		printerr("FALHA: " + msg)


func _frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


## Quanto a caixa principal passa da largura da tela (0 = cabe).
func _measure(label: String) -> void:
	var vw := get_viewport().get_visible_rect().size.x
	var over: float = maxf(scene.margin_box.size.x, scene.margin_box.get_combined_minimum_size().x) - vw
	if over > worst:
		worst = over
		worst_text = label


class _Watcher extends Node:
	var owner_test: Node

	func _process(_d: float) -> void:
		if owner_test.scene != null and is_instance_valid(owner_test.scene):
			owner_test._measure("quadro %d: %s" % [Engine.get_process_frames(), str(owner_test.scene.banner_title.text)])
