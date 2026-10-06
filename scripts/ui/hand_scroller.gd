class_name HandScroller
extends Control
## Faixa da mão, com dois gestos lidos aqui (antes de qualquer carta):
## - arrastar de lado rola a mão;
## - arrastar uma carta jogável pra CIMA a solta na mesa: a carta acompanha o dedo e, se
##   passar do limite, é jogada; senão volta pra mão, no mesmo lugar.
## O gesto é decidido nos primeiros pixels: mais horizontal = rolagem, mais vertical pra
## cima = arrasto da carta. Toque parado continua selecionando a carta (ver CardView).

signal throw_requested(view: CardView, drop_global: Vector2)

const DEADZONE := 14.0
const THROW_DISTANCE := 130.0
const CARD_SCENE := preload("res://scenes/Card.tscn")

var content: Control
var ghost_layer: Control        # camada por cima de tudo, onde a carta arrastada aparece
var throw_allowed: Callable     # a cena diz se arrastar a carta pra cima faz algo agora (inválido = sempre)
var scroll_x := 0.0
var _pressing := false
var _mode := ""                 # "" = ainda decidindo · "scroll" · "card" · "none"
var _press_pos := Vector2.ZERO
var _start_scroll := 0.0
var _card: CardView
var _ghost: CardView
var _ghost_origin := Vector2.ZERO
var _base_scale := Vector2.ONE
var ghost_scale_mult := 1.0     # a carta arrastada aparece maior que a da mão (tamanho "destacado")
var _armed := false


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
					_mode = ""
					_press_pos = mb.global_position
					_start_scroll = scroll_x
			else:
				if _mode == "card":
					_finish_card_drag()
				if _mode != "":
					get_viewport().set_input_as_handled()
				_pressing = false
				_mode = ""
		elif mb.pressed and get_global_rect().has_point(mb.global_position):
			match mb.button_index:
				MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
					set_scroll(scroll_x - 90.0)
				MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
					set_scroll(scroll_x + 90.0)
	elif event is InputEventMouseMotion and _pressing:
		var d := (event as InputEventMouseMotion).global_position - _press_pos
		if _mode == "" and d.length() > DEADZONE:
			_decide_gesture(d)
		match _mode:
			"scroll":
				set_scroll(_start_scroll - d.x)
			"card":
				_update_card_drag(d)
		if _mode != "":
			get_viewport().set_input_as_handled()


func _decide_gesture(d: Vector2) -> void:
	var pressed := _pressed_card()
	for c in content.get_children():
		if c is CardView:
			(c as CardView).cancel_press()   # esse toque virou gesto: não conta como toque
	var can_scroll := max_scroll() > 1.0
	if can_scroll and absf(d.x) >= absf(d.y):
		_mode = "scroll"
	elif d.y < 0.0 and pressed != null and pressed.playable and ghost_layer != null and (not throw_allowed.is_valid() or bool(throw_allowed.call())) and (absf(d.y) > absf(d.x) * 0.5 or not can_scroll):
		_mode = "card"
		_begin_card_drag(pressed)
	else:
		_mode = "none"


func _pressed_card() -> CardView:
	for c in content.get_children():
		if c is CardView and (c as CardView).is_pressing():
			return c
	return null


func _begin_card_drag(c: CardView) -> void:
	_card = c
	_ghost = CARD_SCENE.instantiate()
	_ghost.setup(c.data, true)
	_ghost.interactive = false
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost_layer.add_child(_ghost)
	_ghost.pivot_offset = c.pivot_offset
	_ghost.rotation = c.rotation
	_ghost.scale = c.scale * ghost_scale_mult
	_ghost.global_position = c.global_position
	_ghost.set_selected(c.selected)
	_ghost_origin = c.global_position
	_base_scale = c.scale * ghost_scale_mult
	_armed = false
	c.visible = false


func _update_card_drag(d: Vector2) -> void:
	if _ghost == null or not is_instance_valid(_ghost):
		return
	_ghost.global_position = _ghost_origin + d
	var up := maxf(0.0, -d.y)
	_ghost.rotation = lerp_angle(_card.rotation, 0.0, clampf(up / THROW_DISTANCE, 0.0, 1.0))
	var armed_now := up >= THROW_DISTANCE
	if armed_now != _armed:
		_armed = armed_now
		create_tween().tween_property(_ghost, "scale", _base_scale * (1.12 if _armed else 1.0), 0.1)


func _finish_card_drag() -> void:
	if _ghost == null or not is_instance_valid(_ghost) or _card == null or not is_instance_valid(_card):
		_ghost = null
		_card = null
		return
	var g := _ghost
	var c := _card
	_ghost = null
	_card = null
	if _armed:
		var drop := g.global_position
		g.queue_free()
		throw_requested.emit(c, drop)
		return
	# não passou do limite: volta pra mão, no mesmo lugar
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(g, "global_position", _ghost_origin, 0.22)
	tw.tween_property(g, "rotation", c.rotation, 0.22)
	tw.tween_property(g, "scale", c.scale, 0.22)
	tw.chain().tween_callback(func():
		if is_instance_valid(c):
			c.visible = true
		g.queue_free())


func _draw() -> void:
	var m := max_scroll()
	if m <= 1.0:
		return
	var track_w := size.x - 24.0
	var thumb_w := maxf(track_w * size.x / content.size.x, 40.0)
	var x := 12.0 + (track_w - thumb_w) * (scroll_x / m)
	draw_rect(Rect2(12.0, size.y - 8.0, track_w, 4.0), Color(1, 1, 1, 0.08))
	draw_rect(Rect2(x, size.y - 8.0, thumb_w, 4.0), Color(1, 1, 1, 0.42))
