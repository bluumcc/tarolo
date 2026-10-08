extends Node
## Verifica as etapas sem mesa (descarte e palpite) com toques reais injetados. Requer display
## (ex.: xvfb-run -a -s "-screen 0 720x1280x24" godot --path . --resolution 720x1280
## --rendering-driver opengl3 res://tests/PhaseCheck.tscn). Sai com código 1 se algo falhar.
## Checa: título e subtítulo na mesma altura nas duas etapas; CONFIRMAR responde ao toque.

var inst: Node
var t := 0.0
var d_title := -1.0
var d_sub := -1.0
var finished := false
var failures := 0


func _ready() -> void:
	SaveManager.persist = false
	SaveManager.section("profile")["fichas"] = 100000
	for k in ["blitz_intro", "turn", "power", "double", "bet", "predict", "discard"]:
		SaveManager.section("tips")[k] = true
	GameState.chaos_mode = "blitz"
	GameState.autoplay = false
	GameState.ranked_table = {"blind": 10, "stack_blinds": 40, "players": 4}
	Engine.time_scale = 4.0
	inst = load("res://scenes/BlitzScene.tscn").instantiate()
	get_tree().root.add_child.call_deferred(inst)


func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "FALHA ") + msg)
	if not ok:
		failures += 1


func _tap(pos: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = pos
		e.global_position = pos
		e.pressed = pressed
		Input.parse_input_event(e)
		await get_tree().process_frame
		await get_tree().process_frame


func _process(delta: float) -> void:
	t += delta
	if finished or inst == null or not inst.is_inside_tree() or inst.engine == null:
		return
	var ps: PhaseScreen = inst.phase_screen
	if inst.phase == "discard" and ps.visible and d_title < 0.0:
		await get_tree().create_timer(0.8).timeout
		d_title = ps.title.get_global_rect().position.y
		d_sub = ps.subtitle.get_global_rect().position.y
	for b in inst.find_children("*", "Button", true, false):
		var bb := b as Button
		if not bb.is_visible_in_tree() or bb.disabled:
			continue
		if bb.text.begins_with("VAMOS") or bb.text.begins_with("ENTENDI"):
			bb.pressed.emit()
			break
		if bb.text.begins_with("CONFIRMAR") and not finished:
			finished = true
			await get_tree().create_timer(0.8).timeout
			print("viewport ", get_viewport().get_visible_rect().size)
			get_viewport().get_texture().get_image().save_png("/tmp/phase_predict_%d.png" % int(get_viewport().get_visible_rect().size.y))
			_check(d_title >= 0.0, "etapa de descarte medida")
			_check(is_equal_approx(ps.title.get_global_rect().position.y, d_title), "título do palpite na mesma altura do descarte")
			_check(is_equal_approx(ps.subtitle.get_global_rect().position.y, d_sub), "subtítulo do palpite na mesma altura do descarte")
			await _tap(bb.get_global_rect().get_center())
			await get_tree().create_timer(0.6).timeout
			_check(not ps.visible, "CONFIRMAR responde ao toque e fecha o palpite")
			get_tree().quit(1 if failures > 0 else 0)
			return
	if t > 300.0:
		print("FALHA nunca chegou no palpite")
		get_tree().quit(1)
