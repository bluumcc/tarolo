class_name HpBar
extends Control
## Barra de vida do chefe (ou de progresso da sua meta, quando você é o Tomador). Quando o
## valor cai, um rastro claro fica pra trás e desce depois — assim o dano dá pra ver.

var value := 1.0
var max_value := 1.0
var ghost := 1.0
var fill_color := Color("#E2463B")
var track_color := Color("#2a1715")
var _tween: Tween
var _fill_sb := StyleBoxFlat.new()
var _track_sb := StyleBoxFlat.new()
var _ghost_sb := StyleBoxFlat.new()


func _init() -> void:
	custom_minimum_size = Vector2(0, 26)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for sb in [_fill_sb, _track_sb, _ghost_sb]:
		(sb as StyleBoxFlat).set_corner_radius_all(6)
	_ghost_sb.bg_color = Color("#f3ece0")


func set_colors(fill: Color, track: Color) -> void:
	fill_color = fill
	track_color = track
	queue_redraw()


## `animate`: a barra cai devagar até o novo valor, com o rastro claro atrasado.
func set_values(v: float, m: float, animate: bool = true) -> void:
	var new_value := clampf(v, 0.0, maxf(m, 0.001))
	var old_value := value
	max_value = maxf(m, 0.001)
	if _tween:
		_tween.kill()
	if not animate or not is_inside_tree():
		value = new_value
		ghost = new_value
		queue_redraw()
		return
	value = new_value
	if new_value >= old_value:
		ghost = new_value
		queue_redraw()
		return
	_tween = create_tween()
	_tween.tween_interval(GameState.anim(0.35))
	_tween.tween_method(func(g: float):
		ghost = g
		queue_redraw(), ghost, new_value, GameState.anim(0.6))
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	_track_sb.bg_color = track_color
	_fill_sb.bg_color = fill_color
	draw_style_box(_track_sb, Rect2(0, 0, w, h))
	var gw := w * clampf(ghost / max_value, 0.0, 1.0)
	if gw > 2.0 and ghost > value:
		draw_style_box(_ghost_sb, Rect2(0, 0, gw, h))
	var fw := w * clampf(value / max_value, 0.0, 1.0)
	if fw > 2.0:
		draw_style_box(_fill_sb, Rect2(0, 0, fw, h))
		draw_rect(Rect2(3, 3, maxf(fw - 6.0, 0.0), h * 0.28), Color(1, 1, 1, 0.18))
	draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.0))
