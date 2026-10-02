class_name GlitchPanel
extends MarginContainer
## Painel com borda glitch vermelha procedural — sem imagens.
## Efeitos: brilho difuso, borda pulsante, cantos em teal, linhas de aberração cromática.

var accent := UIKit.DANGER
var bg    := Color(0.04, 0.02, 0.10, 0.95)
var corner_size := 20.0
var glow_layers := 5

var _t            := 0.0
var _show_jitter  := false
var _jitter_y     := 0.0
var _jitter_h     := 2.0
var _jitter_shift := 0.0
var _next_jitter  := 0.45


func _ready() -> void:
	for s in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + s, 16)


func _process(delta: float) -> void:
	_t += delta
	if _t >= _next_jitter:
		_show_jitter  = true
		_jitter_y     = randf() * maxf(size.y - 12.0, 1.0) + 4.0
		_jitter_h     = randf_range(1.0, 4.0)
		_jitter_shift = randf_range(-8.0, 8.0)
		_next_jitter  = _t + randf_range(0.22, 0.68)
		var delay: float = 0.04 + randf() * 0.04
		get_tree().create_timer(delay).timeout.connect(
				func(): _show_jitter = false; queue_redraw())
	queue_redraw()


func _draw() -> void:
	var r     := Rect2(Vector2.ZERO, size)
	var pulse := 0.82 + sin(_t * 2.8) * 0.18

	draw_rect(r, bg)

	for i in range(glow_layers, 0, -1):
		var expand := float(i) * 3.2
		var alpha  := (1.0 - float(i) / float(glow_layers + 1)) * 0.28 * pulse
		draw_rect(r.grow(expand), Color(accent.r, accent.g, accent.b, alpha), false, 1.2)

	draw_rect(r, Color(accent.r, accent.g, accent.b, 0.78 * pulse), false, 2.0)

	# Cantos em teal
	var teal := UIKit.TURN
	var bw   := 2.5
	var cs   := corner_size
	var tl   := r.position
	var tr   := Vector2(r.end.x, r.position.y)
	var bl   := Vector2(r.position.x, r.end.y)
	var br   := r.end
	draw_line(tl + Vector2(cs, 0),  tl,                    teal, bw)
	draw_line(tl,                   tl + Vector2(0, cs),   teal, bw)
	draw_line(tr + Vector2(-cs, 0), tr,                    teal, bw)
	draw_line(tr,                   tr + Vector2(0, cs),   teal, bw)
	draw_line(bl + Vector2(cs, 0),  bl,                    teal, bw)
	draw_line(bl,                   bl + Vector2(0, -cs),  teal, bw)
	draw_line(br + Vector2(-cs, 0), br,                    teal, bw)
	draw_line(br,                   br + Vector2(0, -cs),  teal, bw)

	if not _show_jitter:
		return
	# Aberração cromática: linha vermelha deslocada + linha ciano contra-deslocada
	var jy  := clampf(_jitter_y, 0.0, size.y - _jitter_h)
	var js  := _jitter_shift
	var w   := size.x
	var h   := _jitter_h
	draw_rect(Rect2(Vector2(maxf(js, 0.0),        jy), Vector2(w - absf(js), h)),
			Color(1.0, 0.08, 0.25, 0.42))
	draw_rect(Rect2(Vector2(maxf(-js * 0.6, 0.0), jy), Vector2(w - absf(js) * 0.6, h)),
			Color(0.15, 0.85, 0.9, 0.30))
