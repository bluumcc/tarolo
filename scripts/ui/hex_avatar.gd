class_name HexAvatar
extends Control
## Avatar hexagonal desenhado em código: fundo escuro + borda neon + retrato redondo.
## Interface pública mantida: set_active(), set_timer(), wins_badge, dealer_badge, SIZE_PX, BADGE_PX, RADIUS.

const RADIUS := 47.0
const SIZE_PX := Vector2(81.0, 94.0)
const PORTRAIT_PX := 60.0
const BADGE_PX := 38.0
const WARN_FRAC := 0.6
const URGENT_FRAC := 0.3
const BORDER_W := 3.0
const BORDER_W_ACTIVE := 5.0

var active := false
var portrait: Portrait
var wins_badge: PanelContainer
var dealer_badge: PanelContainer
var timer_frac := -1.0

var _border_color: Color
var _fill_color: Color


func setup(seat: int) -> HexAvatar:
	custom_minimum_size = SIZE_PX
	size = SIZE_PX
	pivot_offset = SIZE_PX / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP

	_fill_color = UIKit.PURPLE_DEEP.darkened(0.35)
	_border_color = UIKit.VIOLET

	var c := SIZE_PX / 2.0
	portrait = Portrait.new().setup(seat, UIKit.CLEAR, PORTRAIT_PX)
	portrait.ring_width = 0.0
	portrait.position = c - Vector2(PORTRAIT_PX, PORTRAIT_PX) / 2.0
	add_child(portrait)

	var pts := _hex_points()
	wins_badge = HexAvatar.make_badge("0", UIKit.PURPLE, UIKit.VIOLET, UIKit.INK)
	dealer_badge = HexAvatar.make_badge("D", UIKit.MONEY, UIKit.LOSS, UIKit.PURPLE_DEEP)
	dealer_badge.visible = false
	wins_badge.position = pts[4] - Vector2(BADGE_PX, BADGE_PX) / 2.0
	dealer_badge.position = pts[2] - Vector2(BADGE_PX, BADGE_PX) / 2.0
	add_child(wins_badge)
	add_child(dealer_badge)
	return self


func _hex_points() -> PackedVector2Array:
	var c := SIZE_PX / 2.0
	var pts := PackedVector2Array()
	for k in range(6):
		var a := deg_to_rad(-90.0 + 60.0 * float(k))
		pts.append(c + Vector2(cos(a) * SIZE_PX.x / 2.0, sin(a) * RADIUS))
	return pts


func _draw() -> void:
	var pts := _hex_points()
	draw_colored_polygon(pts, _fill_color)
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	var bw := BORDER_W_ACTIVE if active else BORDER_W
	draw_polyline(closed, _border_color, bw, true)


func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	_update_colors()
	queue_redraw()


func set_timer(f: float) -> void:
	timer_frac = f
	_update_colors()
	queue_redraw()


func _update_colors() -> void:
	var base: Color = UIKit.BRAND if active else UIKit.VIOLET
	if timer_frac < 0.0 or timer_frac > WARN_FRAC:
		_border_color = base
	elif timer_frac > URGENT_FRAC:
		var t := (WARN_FRAC - timer_frac) / (WARN_FRAC - URGENT_FRAC)
		_border_color = base.lerp(Color(1.0, 0.85, 0.2, 1.0), t)
	else:
		var t := clampf((URGENT_FRAC - timer_frac) / URGENT_FRAC, 0.0, 1.0)
		_border_color = Color(1.0, 0.85, 0.2, 1.0).lerp(Color(1.0, 0.25, 0.25, 1.0), t)


## Selo redondo com texto (vitórias, dealer).
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
