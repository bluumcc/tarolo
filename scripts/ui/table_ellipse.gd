class_name TableEllipse
extends Control
## Mesa de jogo: elipse desenhada por código (sem imagem) — círculo de runas neon sobre roxo
## escuro. Também dá a geometria pros assentos e cartas da mesa.

const POINTS := 120


## Folga entre o topo da área da mesa e o topo do avatar de cima (somada ao respiro de 8 px do
## layout, dá o triplo da folga que havia entre a faixa do modificador e o avatar).
const TOP_GAP := 16.0
const SIDE_GAP := 0.0
## Do centro do avatar pra baixo: parte de baixo do avatar + plaquinha de nome.
const SEAT_BELOW := 78.0
## Quanto a mesa pode descer além da área do palco: o pedaço de baixo fica atrás do card roxo.
const TABLE_DROP := 70.0

var seat_count := 4
var my_seat_y := 0.0           ## y máximo do centro do SEU avatar (embaixo, perto do card roxo); a mesa não passa disso
var seat_floor := 0.0          ## y (da área da mesa) abaixo do qual nenhum rival pode chegar: o card roxo
var _center := Vector2.ZERO
var _r := 10.0                 ## raio horizontal (e das duas pontas arredondadas)
var _half := 0.0               ## metade do trecho reto vertical: a mesa é uma pílula (cápsula) em pé


## Ponto da borda da mesa (pílula) na direção `theta` a partir do centro; `s` encolhe a pílula
## (anéis internos). Os avatares ficam todos aqui, cada um na direção do seu assento.
func border_point(theta: float, s: float = 1.0) -> Vector2:
	var d := Vector2(cos(theta), sin(theta))
	var rr := _r * s
	var hh := _half * s
	if absf(d.x) > 0.0001:
		var t := rr / absf(d.x)
		if absf(t * d.y) <= hh:
			return _center + d * t
	var c := Vector2(0.0, hh if d.y >= 0.0 else -hh)
	var b := d.dot(c)
	var t2 := b + sqrt(maxf(b * b - c.length_squared() + rr * rr, 0.0))
	return _center + d * t2


## Meia-largura do que mais se afasta do centro de um assento: a plaquinha do nome (fixa, 150% da
## largura do avatar), o avatar e os selos (vitórias / dealer) que saem dos vértices.
static func seat_half_extent() -> float:
	var plate := HexAvatar.SIZE_PX.x * SeatView.PLATE_RATIO / 2.0
	var badge := HexAvatar.SIZE_PX.x / 2.0 + HexAvatar.BADGE_PX / 2.0
	return maxf(plate, badge)


## Encaixa a mesa na área pro nº de jogadores atual (`seat_count`): a largura é a maior que cabe (o
## que estiver mais perto da margem — avatar, borda, plaquinha ou selo — encosta nela) e a altura
## é a maior que serve (avatar do topo a `TOP_GAP` do topo, o seu avatar no limite `my_seat_y` e
## os rivais de baixo acima de `seat_floor`). Quem chama só refaz isto entre rodadas: durante as 8
## jogadas o tamanho não muda.
func fit() -> void:
	var topc := TOP_GAP + HexAvatar.RADIUS
	var r_avail := maxf(size.x / 2.0 - seat_half_extent() - SIDE_GAP, 10.0)
	var ry_cap := maxf((size.y + TABLE_DROP - topc) / 2.0, 20.0)
	if my_seat_y > 0.0:
		ry_cap = maxf(ry_cap, (my_seat_y - topc) / 2.0)
	var ry := _max_ry(r_avail, ry_cap, topc, seat_count)
	_r = minf(r_avail, ry)
	_half = maxf(ry - _r, 0.0)
	_center = Vector2(size.x / 2.0, topc + ry)
	queue_redraw()


## Maior altura (raio vertical) que serve pra `n` jogadores (bisseção: cada teste é monotônico).
func _max_ry(r_avail: float, ry_cap: float, topc: float, n: int) -> float:
	if _fits(r_avail, ry_cap, topc, n):
		return ry_cap
	var lo := 20.0
	var hi := ry_cap
	for _i in range(30):
		var mid := (lo + hi) / 2.0
		if _fits(r_avail, mid, topc, n):
			lo = mid
		else:
			hi = mid
	return lo


func _fits(r_avail: float, ry: float, topc: float, n: int) -> bool:
	_r = minf(r_avail, ry)
	_half = maxf(ry - _r, 0.0)
	_center = Vector2(size.x / 2.0, topc + ry)
	if my_seat_y > 0.0 and _center.y + ry > my_seat_y:
		return false   # o seu avatar (embaixo da pílula) passaria do limite
	if seat_floor <= 0.0:
		return true
	for p in range(1, n):
		if border_point(seat_angle(p, n)).y + SEAT_BELOW > seat_floor:
			return false
	return true


func center_point() -> Vector2:
	return _center


## Ângulo do assento: o jogador 0 fica embaixo e os demais se distribuem com ângulos iguais.
static func seat_angle(player: int, count: int) -> float:
	return PI / 2.0 + TAU * float(player) / float(maxi(count, 1))


func _points(scale: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(POINTS):
		pts.append(border_point(TAU * float(i) / float(POINTS), scale))
	return pts


## Zodíaco e planetas que rodam no anel de runas (todos na DejaVu Sans, que vai junto do jogo).
const GLYPHS := ["♈", "♉", "♊", "♋", "♌", "♍", "♎", "♏", "♐", "♑", "♒", "♓", "☉", "☽", "☿", "♀", "♂", "♃", "♄", "✦"]
static var _glyph_font: Font


func _ring(scale: float) -> PackedVector2Array:
	var pts := _points(scale)
	pts.append(pts[0])
	return pts


## Mesa-círculo de runas: miolo roxo escuro que esquenta pra borda, anéis neon e um anel de
## glifos astrológicos. Desenhada uma vez (só redesenha ao mudar de tamanho): custo zero por frame.
func _draw() -> void:
	var core := UIKit.TR_PURPLE_DARK
	var edge := UIKit.TR_RED_DARK.darkened(0.2)
	for i in range(8):
		var t := float(i) / 7.0
		draw_colored_polygon(_points(1.0 - t * 0.92), edge.lerp(core, smoothstep(0.0, 1.0, t)))
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
	var fs := 22
	for i in range(GLYPHS.size()):
		var a := TAU * float(i) / float(GLYPHS.size())
		var pos := border_point(a, 0.85)
		var tangent := (border_point(a + 0.02, 0.85) - pos).angle()
		draw_set_transform(pos, tangent, Vector2.ONE)
		draw_string(_glyph_font, Vector2(-fs * 0.5, fs * 0.35), GLYPHS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(neon, 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
