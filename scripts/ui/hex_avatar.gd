class_name HexAvatar
extends Control
## Avatar hexagonal (ponta pra cima) com moldura neon e retrato redondo dentro. Tudo em `_draw`
## (sem textura nem shader). Os dois selos ficam sobre os vértices de baixo e sempre visíveis:
## vitórias na rodada à esquerda, botão do dealer (D) à direita.

const RADIUS := 47.0                       ## do centro até a ponta de cima/baixo
const SIZE_PX := Vector2(81.0, 94.0)       ## largura = √3·R, altura = 2·R
const PORTRAIT_PX := 70.0
const BADGE_PX := 38.0
const WARN_FRAC := 0.5                     ## abaixo disso o anel fica dourado
const URGENT_FRAC := 0.25                  ## abaixo disso, vermelho

var active := false                        ## é a vez dele: moldura ciano e mais grossa
var portrait: Portrait
var wins_badge: PanelContainer
var dealer_badge: PanelContainer
var timer_frac := -1.0                     ## 1 → 0: anel de tempo da vez (−1 = sem anel)
var _pts := PackedVector2Array()


func setup(seat: int) -> HexAvatar:
	custom_minimum_size = SIZE_PX
	size = SIZE_PX
	pivot_offset = SIZE_PX / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	var c := SIZE_PX / 2.0
	for k in range(6):
		var a := deg_to_rad(-90.0 + 60.0 * float(k))
		_pts.append(c + Vector2(cos(a) * SIZE_PX.x / 2.0, sin(a) * RADIUS))
	portrait = Portrait.new().setup(seat, UIKit.CLEAR, PORTRAIT_PX)
	portrait.ring_width = 1.0
	portrait.position = c - Vector2(PORTRAIT_PX, PORTRAIT_PX) / 2.0
	add_child(portrait)
	wins_badge = make_badge("0", UIKit.TR_PURPLE, UIKit.TR_PURPLE_LIGHT.lightened(0.35), UIKit.TR_WHITE)
	dealer_badge = make_badge("D", UIKit.TR_GOLD, UIKit.TR_RED_LIGHT, UIKit.TR_PURPLE_DARK)
	dealer_badge.visible = false
	# Vértices de baixo: esquerdo (150°) e direito (30°).
	wins_badge.position = _pts[4] - Vector2(BADGE_PX, BADGE_PX) / 2.0
	dealer_badge.position = _pts[2] - Vector2(BADGE_PX, BADGE_PX) / 2.0
	add_child(wins_badge)
	add_child(dealer_badge)
	queue_redraw()
	return self


func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	queue_redraw()


func set_timer(f: float) -> void:
	if is_equal_approx(f, timer_frac):
		return
	timer_frac = f
	queue_redraw()


func _draw() -> void:
	var col := _ring_color()
	var w := 6.0 if active else 4.0
	draw_colored_polygon(_pts, UIKit.TR_PURPLE_DARK.darkened(0.35))
	# Com o relógio rodando, a borda vai SUMINDO: só o trecho que resta é desenhado (o consumo começa
	# no topo e avança no sentido horário).
	var ring := _perimeter(timer_frac) if timer_frac >= 0.0 else _perimeter(1.0)
	if timer_frac < 0.0:
		ring = _pts.duplicate()
		ring.append(_pts[0])
	if ring.size() > 1:
		draw_polyline(ring, Color(col, 0.14), w + 16.0, true)   # halo largo e fraco
		draw_polyline(ring, Color(col, 0.30), w + 7.0, true)    # halo curto
		draw_polyline(ring, col, w, true)


## Uma cor só em repouso (lilás); na vez, ciano; com o relógio, esquenta: dourado abaixo de 50% e
## vermelho abaixo de 25%.
func _ring_color() -> Color:
	if not active and timer_frac < 0.0:
		return UIKit.TR_PURPLE_LIGHT.lightened(0.35)
	if timer_frac >= 0.0 and timer_frac < URGENT_FRAC:
		return UIKit.TR_RED
	if timer_frac >= 0.0 and timer_frac < WARN_FRAC:
		return UIKit.TR_GOLD
	return UIKit.TR_CYAN.lightened(0.1)


## Pontos do contorno do hexágono que RESTAM (fração `f`, 0..1): o trecho que vai do ponto já
## consumido até o vértice de cima, no sentido horário. O consumo começa no topo (meio-dia) e avança
## no sentido horário, então a borda vai desaparecendo nesse sentido.
func _perimeter(f: float) -> PackedVector2Array:
	var total := 0.0
	var seg: Array = []
	for i in range(6):
		var l := _pts[i].distance_to(_pts[(i + 1) % 6])
		seg.append(l)
		total += l
	var start := total * (1.0 - clampf(f, 0.0, 1.0))   # distância (horária, do topo) já consumida
	var pts := PackedVector2Array()
	var run := 0.0
	for i in range(6):
		var l: float = seg[i]
		var a := _pts[i]
		var b := _pts[(i + 1) % 6]
		if run + l <= start:
			run += l
			continue
		if pts.is_empty():
			pts.append(a.lerp(b, (start - run) / l))
		pts.append(b)
		run += l
	return pts


## Selo redondo com texto (vitórias, dealer). O texto é o primeiro filho (os HUDs recolorem).
static func make_badge(text: String, fill: Color, border: Color, ink: Color) -> PanelContainer:
	var b := PanelContainer.new()
	b.custom_minimum_size = Vector2(BADGE_PX, BADGE_PX)
	b.size = Vector2(BADGE_PX, BADGE_PX)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_stylebox_override("panel", UIKit.box_cached(fill, border, 3, int(BADGE_PX / 2.0), 0))
	var l := UIKit.label(text, 22, ink, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_size_override("font_size", 22)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(l)
	return b
