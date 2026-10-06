class_name HexAvatar
extends Control
## Avatar hexagonal (ponta pra cima) com moldura neon e retrato redondo dentro. Tudo em `_draw`
## (sem textura nem shader). Os dois selos ficam sobre os vértices de baixo e sempre visíveis:
## vitórias na rodada à esquerda, botão do dealer (D) à direita.

const RADIUS := 47.0                       ## do centro até a ponta de cima/baixo
const SIZE_PX := Vector2(81.0, 94.0)       ## largura = √3·R, altura = 2·R
const PORTRAIT_PX := 70.0
const BADGE_PX := 38.0

var accent := UIKit.TR_RED                 ## cor da moldura em repouso (muda por assento)
var active := false                        ## é a vez dele: moldura ciano e mais grossa
var portrait: Portrait
var wins_badge: PanelContainer
var dealer_badge: PanelContainer
var _pts := PackedVector2Array()


func setup(seat: int, p_accent: Color) -> HexAvatar:
	accent = p_accent
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


func _draw() -> void:
	var col := UIKit.TR_CYAN.lightened(0.1) if active else accent
	var w := 6.0 if active else 4.0
	draw_colored_polygon(_pts, UIKit.TR_PURPLE_DARK.darkened(0.35))
	var ring := _pts.duplicate()
	ring.append(_pts[0])
	draw_polyline(ring, Color(col, 0.14), w + 16.0, true)   # halo largo e fraco
	draw_polyline(ring, Color(col, 0.30), w + 7.0, true)    # halo curto
	draw_polyline(ring, col, w, true)


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
