class_name Portrait
extends Control
## Retrato redondo desenhado em código (fundo em degradê, ombros, rosto e cabelo) — um
## por assento, com cores próprias. É provisório: quando houver ilustração de verdade,
## basta trocar o `_draw` por uma textura sem mexer em quem usa o retrato.

const PALETTES := [
	{"bg1": Color("#4a3a16"), "bg2": Color("#1a1408"), "skin": Color("#efcfae"), "hair": Color("#6a4a22")},
	{"bg1": Color("#1d3552"), "bg2": Color("#0b1320"), "skin": Color("#d9a984"), "hair": Color("#3a2616")},
	{"bg1": Color("#1d4a4a"), "bg2": Color("#0b1a1a"), "skin": Color("#c68b62"), "hair": Color("#141010")},
	{"bg1": Color("#5a1d2a"), "bg2": Color("#1a0b10"), "skin": Color("#e7c3b0"), "hair": Color("#1a1014")},
]

var seat := 0
var ring_color := Color(0, 0, 0, 0)
var ring_width := 4.0
var dimmed := false


func setup(p_seat: int, p_ring: Color = Color(0, 0, 0, 0), size_px: float = 64.0) -> Portrait:
	seat = p_seat
	ring_color = p_ring
	custom_minimum_size = Vector2(size_px, size_px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()
	return self


func set_ring(c: Color) -> void:
	ring_color = c
	queue_redraw()


func _draw() -> void:
	var pal: Dictionary = PALETTES[seat % PALETTES.size()]
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - ring_width
	if r <= 2.0:
		return
	# fundo em degradê radial (círculos concêntricos)
	for i in range(8):
		var t := float(i) / 7.0
		draw_circle(c, r * (1.0 - t * 0.85), (pal["bg2"] as Color).lerp(pal["bg1"], t))
	draw_arc(c, r, 0.0, TAU, 96, pal["bg2"], 1.6, true)   # borda suavizada (draw_circle não tem antialiasing)
	# ombros: fatia inferior do círculo com a borda de cima curva
	var pts := PackedVector2Array()
	for k in range(0, 21):
		var a := deg_to_rad(20.0 + 140.0 * float(k) / 20.0)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	var xl := c.x + cos(deg_to_rad(160.0)) * r
	var xr := c.x + cos(deg_to_rad(20.0)) * r
	var y_edge := c.y + sin(deg_to_rad(20.0)) * r
	for k in range(0, 13):
		var t := float(k) / 12.0
		pts.append(Vector2(lerpf(xl, xr, t), y_edge - r * 0.24 * sin(PI * t)))
	draw_colored_polygon(pts, Color("#0d0a0b"))
	draw_polyline(pts, Color("#0d0a0b"), 1.5, true)
	# cabelo atrás, rosto, franja e olhos
	_ellipse(c + Vector2(0, -r * 0.18), Vector2(r * 0.42, r * 0.46), pal["hair"])
	_ellipse(c + Vector2(0, -r * 0.08), Vector2(r * 0.34, r * 0.40), pal["skin"])
	_half_ellipse_top(c + Vector2(0, -r * 0.14), Vector2(r * 0.38, r * 0.32), pal["hair"])
	draw_circle(c + Vector2(-r * 0.13, -r * 0.05), r * 0.045, Color("#1a1014"))
	draw_circle(c + Vector2(r * 0.13, -r * 0.05), r * 0.045, Color("#1a1014"))
	if dimmed:
		draw_circle(c, r, Color(0, 0, 0, 0.55))
	if ring_color.a > 0.0:
		draw_arc(c, r + ring_width * 0.5, 0.0, TAU, 48, ring_color, ring_width, true)


func _ellipse(center: Vector2, radii: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in range(0, 33):
		var a := TAU * float(k) / 32.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, col)
	draw_polyline(pts, col, 1.5, true)
	draw_polyline(pts, col, 1.5, true)   # contorno suavizado na mesma cor: tira o serrilhado


func _half_ellipse_top(center: Vector2, radii: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in range(0, 17):
		var a := PI + PI * float(k) / 16.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, col)
	draw_polyline(pts, col, 1.5, true)
