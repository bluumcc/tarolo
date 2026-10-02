class_name GlowPanel
extends MarginContainer
## Painel com borda de brilho procedural (sem imagens).
## Usa _draw() puro — funciona em web, mobile e desktop.

var accent := UIKit.VIOLET
var bg := Color(0.04, 0.02, 0.10, 0.95)
var corner_size := 18.0
var glow_layers := 4
var pulse_speed := 0.9

var _pulse := 1.0


func _ready() -> void:
	for s in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + s, 16)
	set_process(true)


func _process(dt: float) -> void:
	_pulse = sin(Time.get_ticks_msec() * 0.001 * pulse_speed) * 0.08 + 0.92
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var rad := 16.0

	# Fundo escuro
	draw_rect(r, bg)

	# Camadas de brilho externo (glow difuso)
	for i in range(glow_layers, 0, -1):
		var expand := float(i) * 2.8
		var alpha := (1.0 - float(i) / float(glow_layers + 1)) * 0.18 * _pulse
		draw_rect(r.grow(expand), Color(accent.r, accent.g, accent.b, alpha), false, 1.2)

	# Borda principal
	draw_rect(r, Color(accent.r, accent.g, accent.b, 0.7 * _pulse), false, 1.8)

	# Cantos em L: linhas brilhantes nos 4 cantos
	var bright := Color(minf(accent.r * 1.4, 1.0), minf(accent.g * 1.4, 1.0), minf(accent.b * 1.4, 1.0), _pulse)
	var bw := 2.5
	var cs := corner_size
	var tl := r.position
	var tr := Vector2(r.end.x, r.position.y)
	var bl := Vector2(r.position.x, r.end.y)
	var br := r.end

	# Canto superior-esquerdo
	draw_line(tl + Vector2(cs, 0), tl, bright, bw)
	draw_line(tl, tl + Vector2(0, cs), bright, bw)
	# Canto superior-direito
	draw_line(tr + Vector2(-cs, 0), tr, bright, bw)
	draw_line(tr, tr + Vector2(0, cs), bright, bw)
	# Canto inferior-esquerdo
	draw_line(bl + Vector2(cs, 0), bl, bright, bw)
	draw_line(bl, bl + Vector2(0, -cs), bright, bw)
	# Canto inferior-direito
	draw_line(br + Vector2(-cs, 0), br, bright, bw)
	draw_line(br, br + Vector2(0, -cs), bright, bw)
