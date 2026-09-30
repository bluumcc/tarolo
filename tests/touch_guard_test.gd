extends SceneTree
## Simula toque x arrasto sobre botão/LineEdit numa lista rolável registrada no TouchGuard.

var clicks := 0
var fails := 0

func _ev(pressed: bool, pos: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	return e

func _mv(pos: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	return e

func _send(e: InputEvent) -> void:
	root.push_input(e, true)

func check(name: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + name)
	if not ok:
		fails += 1

func _initialize() -> void:
	var tg = load("res://scripts/autoload/touch_guard.gd").new()
	root.add_child(tg)
	var sc := ScrollContainer.new()
	sc.position = Vector2(0, 0)
	sc.size = Vector2(400, 400)
	root.add_child(sc)
	sc.add_to_group("touch_scroll")
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(400, 0)
	sc.add_child(v)
	var b := Button.new()
	b.text = "x"
	b.custom_minimum_size = Vector2(400, 100)
	b.pressed.connect(func(): clicks += 1)
	v.add_child(b)
	var le := LineEdit.new()
	le.custom_minimum_size = Vector2(400, 100)
	v.add_child(le)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(400, 1500)
	v.add_child(pad)
	await process_frame
	await process_frame
	# 1. toque rápido no botão
	_send(_ev(true, Vector2(200, 50)))
	_send(_ev(false, Vector2(200, 50)))
	await process_frame
	check("toque clica", clicks == 1)
	# 2. arrasto começando no botão
	_send(_ev(true, Vector2(200, 50)))
	for i in range(1, 11):
		_send(_mv(Vector2(200, 50 - i * 12)))
	_send(_ev(false, Vector2(200, 50 - 120)))
	await process_frame
	check("arrasto não clica", clicks == 1)
	check("arrasto rolou", sc.scroll_vertical > 60)
	# 3. arrasto começando no LineEdit
	sc.scroll_vertical = 0
	await create_timer(1.2).timeout
	sc.scroll_vertical = 0
	await process_frame
	await process_frame
	_send(_ev(true, Vector2(200, 150)))
	for i in range(1, 11):
		_send(_mv(Vector2(200, 150 + i * 12)))
	_send(_ev(false, Vector2(200, 270)))
	await process_frame
	check("arrasto em LineEdit sem foco", not le.has_focus())
	# 4. começa fora (livre) e termina sobre o botão
	sc.scroll_vertical = 0
	await create_timer(1.2).timeout
	sc.scroll_vertical = 0
	await process_frame
	await process_frame
	var before := clicks
	_send(_ev(true, Vector2(200, 380)))
	for i in range(1, 11):
		_send(_mv(Vector2(200, 380 - i * 32)))
	_send(_ev(false, Vector2(200, 60)))
	await process_frame
	check("terminar sobre botão não clica", clicks == before)
	# 5. toque no LineEdit foca
	await create_timer(1.5).timeout
	sc.scroll_vertical = 0
	await process_frame
	await process_frame
	_send(_ev(true, Vector2(200, 150)))
	_send(_ev(false, Vector2(200, 150)))
	await process_frame
	check("toque foca LineEdit", le.has_focus())
	sc.remove_from_group("touch_scroll")
	le.release_focus()
	_send(_ev(true, Vector2(200, 150)))
	_send(_ev(false, Vector2(200, 150)))
	await process_frame
	print("baseline sem guard foca: ", le.has_focus(), " scroll=", sc.scroll_vertical)
	print("falhas: ", fails)
	quit(fails)
