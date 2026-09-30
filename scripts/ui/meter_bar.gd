class_name MeterBar
extends Control
## Barra de meta do Atacante: começa vazia e enche com os pontos que ele captura. A Defesa
## joga pra segurar a barra; o Atacante joga pra enchê-la. O valor sobe animado.

var value := 0.0
var max_value := 1.0
var fill_color := UIKit.BOSS
var track_color := UIKit.BOSS_TRACK
var marks: Array = []   # valores onde desenhar um traço (ex.: limiares de contrato)
var _tween: Tween
var _fill_sb := UIKit.bar_style(UIKit.BOSS)
var _track_sb := UIKit.bar_style(UIKit.BOSS_TRACK)


func _init() -> void:
	custom_minimum_size = Vector2(0, 32)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_colors(fill: Color, track: Color) -> void:
	fill_color = fill
	track_color = track
	queue_redraw()


func set_values(v: float, m: float, animate: bool = true) -> void:
	var new_value := clampf(v, 0.0, maxf(m, 0.001))
	max_value = maxf(m, 0.001)
	if _tween:
		_tween.kill()
	if not animate or not is_inside_tree() or is_equal_approx(new_value, value):
		value = new_value
		queue_redraw()
		return
	_tween = create_tween()
	_tween.tween_method(func(x: float):
		value = x
		queue_redraw(), value, new_value, GameState.anim(0.55)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	_track_sb.bg_color = track_color
	_fill_sb.bg_color = fill_color
	draw_style_box(_track_sb, Rect2(0, 0, size.x, size.y))
	var fw := size.x * clampf(value / max_value, 0.0, 1.0)
	if fw > 2.0:
		draw_style_box(_fill_sb, Rect2(0, 0, fw, size.y))
		draw_rect(Rect2(3, 3, maxf(fw - 6.0, 0.0), size.y * 0.28), Color(1, 1, 1, 0.18))
	for m in marks:
		var x := size.x * clampf(float(m) / max_value, 0.0, 1.0)
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1, 1, 1, 0.6), 2.0)
