extends Node
## Rolagem da mão: arrastar no HandScroller move o conteúdo, uma carta tocada sem arrastar
## continua sendo toque, e uma carta arrastada não conta como toque.
## Uso: godot --headless --path . res://tests/HandScrollTest.tscn

var failures := 0
var taps := 0


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

	print("HANDSCROLL: %s" % ("OK" if failures == 0 else "%d falhas" % failures))
	get_tree().quit(1 if failures > 0 else 0)
