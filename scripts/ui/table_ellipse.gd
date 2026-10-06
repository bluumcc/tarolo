class_name TableEllipse
extends Control
## Mesa de jogo: elipse desenhada por código (sem imagem) — círculo de runas neon sobre roxo
## escuro. Também dá a geometria pros assentos e cartas da mesa.

const POINTS := 80


## Folga entre o topo da área da mesa e o topo do avatar de cima (somada ao respiro de 8 px do
## layout, dá o triplo da folga que havia entre a faixa do modificador e o avatar).
const TOP_GAP := 16.0
const SIDE_GAP := 0.0
## Do centro do avatar pra baixo: parte de baixo do avatar + plaquinha de nome.
const SEAT_BELOW := 78.0
## Quanto a mesa pode descer além da área do palco: o pedaço de baixo fica atrás do card roxo.
const TABLE_DROP := 70.0

var seat_count := 4
var seat_floor := 0.0          ## y (da área da mesa) abaixo do qual nenhum rival pode chegar: o card roxo
var _center := Vector2.ZERO
var _radii := Vector2(10, 10)


## Encaixa a mesa na área: os avatares ficam todos NA borda da elipse (cada um na direção do
## seu assento) e a mesa cresce com eles até um avatar tocar na lateral ou no topo, ou o de
## baixo chegar perto do card roxo (`seat_floor`).
func fit() -> void:
	var r_av := HexAvatar.RADIUS
	var half_w := HexAvatar.SIZE_PX.x / 2.0 + HexAvatar.BADGE_PX / 2.0   # avatar + selo que sai do vértice
	var topc := TOP_GAP + r_av
	var max_cos := 0.0
	var min_sin := 0.0
	var max_sin := 0.0
	for p in range(1, seat_count):
		var a := seat_angle(p, seat_count)
		max_cos = maxf(max_cos, absf(cos(a)))
		min_sin = minf(min_sin, sin(a))
		max_sin = maxf(max_sin, sin(a))
	var rx := size.x / 2.0 - SIDE_GAP
	if max_cos > 0.01:
		rx = minf(rx, (size.x / 2.0 - half_w - SIDE_GAP) / max_cos)
	var ry := (size.y + TABLE_DROP - topc) / 2.0
	if max_sin - min_sin > 0.01 and seat_floor > 0.0:
		ry = minf(ry, (seat_floor - SEAT_BELOW - topc) / (max_sin - min_sin))
	_radii = Vector2(maxf(rx, 10.0), maxf(ry, 10.0))
	_center = Vector2(size.x / 2.0, topc - min_sin * _radii.y)
	queue_redraw()


func center_point() -> Vector2:
	return _center


## Raio visual da elipse (a mesa).
func radii() -> Vector2:
	return _radii


## Órbita dos centros dos avatares: a própria borda da elipse.
func seat_edge_radii() -> Vector2:
	return _radii


## Ângulo do assento: o jogador 0 fica embaixo e os demais se distribuem com ângulos iguais.
static func seat_angle(player: int, count: int) -> float:
	return PI / 2.0 + TAU * float(player) / float(maxi(count, 1))


func _points(r: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var c := center_point()
	for i in range(POINTS):
		var a := TAU * float(i) / float(POINTS)
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


## Zodíaco e planetas que rodam no anel de runas (todos na DejaVu Sans, que vai junto do jogo).
const GLYPHS := ["♈", "♉", "♊", "♋", "♌", "♍", "♎", "♏", "♐", "♑", "♒", "♓", "☉", "☽", "☿", "♀", "♂", "♃", "♄", "✦"]
static var _glyph_font: Font


func _ring(scale: float) -> PackedVector2Array:
	var pts := _points(radii() * scale)
	pts.append(pts[0])
	return pts


## Mesa-círculo de runas: miolo roxo escuro que esquenta pra borda, anéis neon e um anel de
## glifos astrológicos. Desenhada uma vez (só redesenha ao mudar de tamanho): custo zero por frame.
func _draw() -> void:
	var r := radii()
	var core := UIKit.TR_PURPLE_DARK
	var edge := UIKit.TR_RED_DARK.darkened(0.2)
	for i in range(8):
		var t := float(i) / 7.0
		draw_colored_polygon(_points(r * (1.0 - t * 0.92)), edge.lerp(core, smoothstep(0.0, 1.0, t)))
	var neon := UIKit.TR_RED_GLOW.lightened(0.15)
	draw_polyline(_ring(1.0), Color(neon, 0.18), 16.0, true)
	draw_polyline(_ring(1.0), Color(neon, 0.40), 7.0, true)
	draw_polyline(_ring(1.0), neon, 3.0, true)
	var soft := UIKit.TR_PURPLE_LIGHT.lightened(0.3)
	draw_polyline(_ring(0.93), Color(soft, 0.9), 1.5, true)
	draw_polyline(_ring(0.77), Color(soft, 0.9), 1.5, true)
	draw_polyline(_ring(0.46), Color(soft, 0.35), 1.2, true)
	if _glyph_font == null:
		_glyph_font = load("res://assets/fonts/DejaVuSans.ttf") as Font
	var c := center_point()
	var rg := r * 0.85
	var fs := 22
	for i in range(GLYPHS.size()):
		var a := TAU * float(i) / float(GLYPHS.size())
		var pos := c + Vector2(cos(a) * rg.x, sin(a) * rg.y)
		var tangent := atan2(cos(a) * rg.y, -sin(a) * rg.x)
		draw_set_transform(pos, tangent, Vector2.ONE)
		draw_string(_glyph_font, Vector2(-fs * 0.5, fs * 0.35), GLYPHS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(neon, 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
