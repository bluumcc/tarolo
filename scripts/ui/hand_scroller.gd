class_name HandScroller
extends Control
## Rolagem lateral da mão, feita à mão (em vez do ScrollContainer): arrastar em qualquer
## ponto da faixa da mão rola de lado — no dedo (o toque vira mouse) e no mouse. O
## ScrollContainer do Godot dependia do toque chegar nele através das cartas, e no
## celular isso falhava; aqui o arrasto é lido antes de qualquer carta e, quando passa
## da zona morta, as cartas são avisadas pra não contarem como toque.

const DEADZONE := 14.0

var content: Control
var scroll_x := 0.0
var _pressing := false
var _dragging := false
var _press_x := 0.0
var _start_scroll := 0.0


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS


func set_content(c: Control) -> void:
	content = c
	add_child(c)


func set_content_size(s: Vector2) -> void:
	content.custom_minimum_size = s
	content.size = s
	content.position.y = 0.0
	set_scroll(scroll_x)


func max_scroll() -> float:
	if content == null:
		return 0.0
	return maxf(0.0, content.size.x - size.x)


func set_scroll(v: float) -> void:
	scroll_x = clampf(v, 0.0, max_scroll())
	if content:
		content.position.x = -scroll_x
	queue_redraw()


## Rola o mínimo necessário pra a carta em [x, x+w) (coordenadas do conteúdo) ficar toda à vista.
func reveal(x: float, w: float) -> void:
	if x < scroll_x:
		set_scroll(x - 12.0)
	elif x + w > scroll_x + size.x:
		set_scroll(x + w - size.x + 12.0)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or content == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if get_global_rect().has_point(mb.global_position):
					_pressing = true
					_dragging = false
					_press_x = mb.global_position.x
					_start_scroll = scroll_x
			else:
				if _dragging:
					get_viewport().set_input_as_handled()
				_pressing = false
				_dragging = false
		elif mb.pressed and get_global_rect().has_point(mb.global_position):
			match mb.button_index:
				MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
					set_scroll(scroll_x - 90.0)
				MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
					set_scroll(scroll_x + 90.0)
	elif event is InputEventMouseMotion and _pressing:
		var dx := (event as InputEventMouseMotion).global_position.x - _press_x
		if not _dragging and absf(dx) > DEADZONE:
			_dragging = true
			for c in content.get_children():
				if c is CardView:
					(c as CardView).cancel_press()
		if _dragging:
			set_scroll(_start_scroll - dx)
			get_viewport().set_input_as_handled()


func _draw() -> void:
	var m := max_scroll()
	if m <= 1.0:
		return
	var track_w := size.x - 24.0
	var thumb_w := maxf(track_w * size.x / content.size.x, 40.0)
	var x := 12.0 + (track_w - thumb_w) * (scroll_x / m)
	draw_rect(Rect2(12.0, size.y - 8.0, track_w, 4.0), Color(1, 1, 1, 0.08))
	draw_rect(Rect2(x, size.y - 8.0, thumb_w, 4.0), Color(1, 1, 1, 0.42))
