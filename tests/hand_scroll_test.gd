extends Node
## Rolagem da mão: arrastar no HandScroller move o conteúdo, uma carta tocada sem arrastar
## continua sendo toque, e uma carta arrastada não conta como toque.
## Uso: godot --headless --path . res://tests/HandScrollTest.tscn

var failures := 0
var taps := 0
var throws := 0


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		printerr("FALHA: " + msg)


func _mouse(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	Input.parse_input_event(e)


func _move(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	Input.parse_input_event(e)


func _frames(n: int = 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func _ready() -> void:
	SaveManager.persist = false
	# sem escala de conteúdo, as coordenadas dos eventos injetados batem 1:1 com a tela
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.size_changed.disconnect(GameState._update_content_scale)
	var scroller := HandScroller.new()
	scroller.position = Vector2(50, 50)
	scroller.size = Vector2(300, 260)
	var content := Control.new()
	scroller.set_content(content)
	add_child(scroller)
	scroller.set_content_size(Vector2(900, 260))
	var card: CardView = load("res://scenes/Card.tscn").instantiate()
	card.setup(CardData.make(CardData.Suit.OUROS, 5), true)
	content.add_child(card)
	card.position = Vector2(0, 0)
	card.tapped.connect(func(_v): taps += 1)
	card.set_playable(true)
	var layer := Control.new()
	add_child(layer)
	scroller.ghost_layer = layer
	scroller.throw_requested.connect(func(_v, _p): throws += 1)
	await _frames()
	check(scroller.max_scroll() == 600.0, "max_scroll = 600 (900 - 300), veio %s" % scroller.max_scroll())

	# arrasto pra esquerda por cima da carta: rola e não conta como toque
	_mouse(Vector2(100, 150), true)
	await _frames(1)
	_move(Vector2(80, 150))
	await _frames(1)
	_move(Vector2(20, 150))
	await _frames(1)
	_mouse(Vector2(20, 150), false)
	await _frames()
	check(is_equal_approx(scroller.scroll_x, 80.0), "arrasto de 80px rola 80, veio %s" % scroller.scroll_x)
	check(taps == 0, "arrasto não pode virar toque na carta (taps=%d)" % taps)

	# toque parado na carta: continua sendo toque
	scroller.set_scroll(0.0)
	await _frames()
	_mouse(Vector2(100, 150), true)
	await _frames(1)
	_mouse(Vector2(100, 150), false)
	await _frames()
	check(taps == 1, "toque sem arrastar conta como toque (taps=%d)" % taps)

	# limite: não passa do fim nem do começo
	scroller.set_scroll(9999.0)
	check(scroller.scroll_x == 600.0, "clamp no fim")
	scroller.set_scroll(-50.0)
	check(scroller.scroll_x == 0.0, "clamp no começo")
	scroller.reveal(700.0, 150.0)
	check(scroller.scroll_x + scroller.size.x >= 850.0, "reveal mostra a carta do fim")


	# arrasto pra cima além do limite: a carta é jogada e a rolagem não mexe
	scroller.set_scroll(0.0)
	await _frames()
	_mouse(Vector2(100, 150), true)
	await _frames(1)
	_move(Vector2(100, 120))
	await _frames(1)
	check(layer.get_child_count() == 1, "carta arrastada aparece na camada de cima")
	_move(Vector2(100, -50))
	await _frames(1)
	_mouse(Vector2(100, -50), false)
	await _frames()
	check(throws == 1, "arrasto de 200px pra cima joga a carta (throws=%d)" % throws)
	check(scroller.scroll_x == 0.0, "arrastar a carta pra cima não rola a mão")
	check(layer.get_child_count() == 0, "a carta fantasma some ao jogar")

	# arrasto curto pra cima: a carta volta pra mão, no mesmo lugar
	card.visible = true
	_mouse(Vector2(100, 150), true)
	await _frames(1)
	_move(Vector2(100, 120))
	await _frames(1)
	_move(Vector2(100, 90))
	await _frames(1)
	_mouse(Vector2(100, 90), false)
	await get_tree().create_timer(0.5).timeout
	check(throws == 1, "arrasto curto não joga (throws=%d)" % throws)
	check(card.visible, "a carta volta a aparecer na mão")
	check(layer.get_child_count() == 0, "a carta fantasma some ao voltar")
	check(taps == 1, "arrasto curto também não vira toque (taps=%d)" % taps)

	# arrasto pra baixo: nada acontece
	_mouse(Vector2(100, 100), true)
	await _frames(1)
	_move(Vector2(100, 200))
	await _frames(1)
	_mouse(Vector2(100, 200), false)
	await _frames()
	check(throws == 1 and card.visible and taps == 1, "arrasto pra baixo não faz nada")

	# carta inclinada (ponta do leque): o ponto agarrado fica embaixo do mouse durante todo o arrasto
	scroller.set_scroll(0.0)
	card.visible = true
	card.rotation = 0.5
	await _frames()
	var grab_pt: Vector2 = card.get_global_transform() * (CardView.SIZE * Vector2(0.75, 0.3))
	_mouse(grab_pt, true)
	await _frames(1)
	var steps := [Vector2(0, -30), Vector2(0, -80), Vector2(10, -140)]
	for st in steps:
		var cur: Vector2 = grab_pt + st
		_move(cur)
		await _frames(1)
		if layer.get_child_count() > 0:
			var gh := layer.get_child(0) as Control
			var under: Vector2 = gh.get_global_transform() * scroller._grab_local
			check(under.distance_to(cur) < 1.5, "carta inclinada: o ponto agarrado acompanha o mouse (erro %.1f px em %s)" % [under.distance_to(cur), str(st)])
		else:
			check(false, "carta inclinada: arrasto não começou")
	_mouse(grab_pt + steps[2], false)
	await get_tree().create_timer(0.5).timeout
	card.rotation = 0.0

	print("HANDSCROLL: %s" % ("OK" if failures == 0 else "%d falhas" % failures))
	get_tree().quit(1 if failures > 0 else 0)
