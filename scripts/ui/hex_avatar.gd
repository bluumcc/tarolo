class_name HexAvatar
extends Control
## Avatar hexagonal com moldura neon e retrato redondo dentro.
## Visual via PNGs (jogador-recolhido-normal/vez). Mantém a mesma interface pública
## de sempre: set_active(), set_timer(), wins_badge, dealer_badge, SIZE_PX, BADGE_PX, RADIUS.

const RADIUS := 47.0
const SIZE_PX := Vector2(81.0, 94.0)
const PORTRAIT_PX := 60.0
const BADGE_PX := 38.0
const WARN_FRAC := 0.6
const URGENT_FRAC := 0.3

var active := false
var portrait: Portrait
var wins_badge: PanelContainer
var dealer_badge: PanelContainer
var timer_frac := -1.0

var _bg: TextureRect
var _tex_normal: Texture2D
var _tex_active: Texture2D


func setup(seat: int) -> HexAvatar:
	custom_minimum_size = SIZE_PX
	size = SIZE_PX
	pivot_offset = SIZE_PX / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP

	_tex_normal = load("res://assets/ui/jogador-recolhido-normal.png") as Texture2D
	_tex_active = load("res://assets/ui/jogador-recolhido-vez.png") as Texture2D

	_bg = TextureRect.new()
	_bg.texture = _tex_normal
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	var c := SIZE_PX / 2.0
	portrait = Portrait.new().setup(seat, UIKit.CLEAR, PORTRAIT_PX)
	portrait.ring_width = 1.0
	portrait.position = c - Vector2(PORTRAIT_PX, PORTRAIT_PX) / 2.0
	add_child(portrait)

	# Vértices de baixo do hexágono (posições para os selos).
	var pts := PackedVector2Array()
	for k in range(6):
		var a := deg_to_rad(-90.0 + 60.0 * float(k))
		pts.append(c + Vector2(cos(a) * SIZE_PX.x / 2.0, sin(a) * RADIUS))

	wins_badge = make_badge("0", UIKit.PURPLE, UIKit.VIOLET, UIKit.INK)
	dealer_badge = make_badge("D", UIKit.MONEY, UIKit.LOSS, UIKit.PURPLE_DEEP)
	dealer_badge.visible = false
	wins_badge.position = pts[4] - Vector2(BADGE_PX, BADGE_PX) / 2.0
	dealer_badge.position = pts[2] - Vector2(BADGE_PX, BADGE_PX) / 2.0
	add_child(wins_badge)
	add_child(dealer_badge)
	return self


func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	if _bg != null:
		_bg.texture = _tex_active if on else _tex_normal


func set_timer(f: float) -> void:
	timer_frac = f
	if _bg == null:
		return
	# Aplica tint conforme o tempo acaba.
	if f < 0.0:
		_bg.modulate = Color.WHITE
	elif f > WARN_FRAC:
		_bg.modulate = Color.WHITE
	elif f > URGENT_FRAC:
		var t := (WARN_FRAC - f) / (WARN_FRAC - URGENT_FRAC)
		_bg.modulate = Color.WHITE.lerp(Color(1.0, 0.85, 0.2, 1.0), t)
	else:
		var t := clampf((URGENT_FRAC - f) / URGENT_FRAC, 0.0, 1.0)
		_bg.modulate = Color(1.0, 0.85, 0.2, 1.0).lerp(Color(1.0, 0.25, 0.25, 1.0), t)


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
