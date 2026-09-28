class_name CardView
extends Control
## Carta reutilizável (Card.tscn). A raiz ocupa o espaço no container; o "Body" é o visual
## que se move (hover, arrasto), sem brigar com o layout do HBoxContainer.

signal tapped(view: CardView)
signal play_requested(view: CardView)
signal zoom_requested(view: CardView)

const SIZE := Vector2(96, 138)
const DRAG_PLAY_DISTANCE := 70.0
const LONG_PRESS := 0.45

const FOIL_SHADER := preload("res://shaders/foil.gdshader")
const HOLO_SHADER := preload("res://shaders/holo.gdshader")

var data: CardData
var face_up := true
var playable := false
var selected := false
var interactive := true

var _pressing := false
var _press_pos := Vector2.ZERO
var _press_time := 0.0
var _dragging := false
var _long_fired := false
var _lift_tween: Tween

@onready var body: PanelContainer = $Body
@onready var rank_label: Label = $Body/Margin/VBox/Top/Rank
@onready var suit_small: Label = $Body/Margin/VBox/Top/Suit
@onready var center_label: Label = $Body/Margin/VBox/Center
@onready var name_label: Label = $Body/Margin/VBox/Name
@onready var chips_label: Label = $Body/Margin/VBox/Bottom/Chips
@onready var mod_label: Label = $Body/Margin/VBox/Bottom/Mod
@onready var sheen: ColorRect = $Body/Sheen


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = SIZE / 2.0
	body.pivot_offset = SIZE / 2.0
	for n in [rank_label, suit_small, center_label, name_label, chips_label, mod_label]:
		(n as Label).mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	_refresh()


func setup(card: CardData, p_face_up: bool = true) -> CardView:
	data = card
	face_up = p_face_up
	if is_node_ready():
		_refresh()
	return self


func set_playable(value: bool) -> void:
	playable = value
	if not value:
		set_selected(false)
	modulate = Color(1, 1, 1, 1) if value or not interactive else Color(0.55, 0.52, 0.62, 1)


func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	_lift(-26.0 if value else 0.0)
	_refresh_border()


func _refresh() -> void:
	if data == null:
		return
	var color: Color = UIKit.SUIT_COLORS[data.suit]
	sheen.visible = false
	if not face_up:
		var back_id := str(SaveManager.section("cosmetics")["equipped"])
		var back_col := Color(UIKit.CARD_BACKS.get(back_id, UIKit.CARD_BACKS["noite"])["color"])
		body.add_theme_stylebox_override("panel", UIKit.box(back_col, UIKit.GOLD.darkened(0.35), 3, 6, 6))
		rank_label.text = ""
		suit_small.text = ""
		center_label.text = "✶"
		center_label.add_theme_color_override("font_color", UIKit.GOLD)
		name_label.text = ""
		chips_label.text = ""
		mod_label.text = ""
		return
	_refresh_border()
	rank_label.text = data.rank_label()
	rank_label.add_theme_color_override("font_color", color)
	suit_small.text = data.suit_symbol()
	suit_small.add_theme_color_override("font_color", color)
	center_label.text = data.suit_symbol()
	center_label.add_theme_color_override("font_color", color)
	name_label.text = CardData.MAJOR_ARCANA[data.rank] if data.is_arcana() else ""
	chips_label.text = "+%d" % data.base_chips()
	chips_label.add_theme_color_override("font_color", UIKit.CHIPS)
	match data.modifier:
		CardData.Modifier.FOIL:
			mod_label.text = "FOIL"
			mod_label.add_theme_color_override("font_color", Color("#CFF4FF"))
			_set_sheen(FOIL_SHADER)
		CardData.Modifier.POLYCHROME:
			mod_label.text = "POLY"
			mod_label.add_theme_color_override("font_color", Color("#FFB3F0"))
			_set_sheen(HOLO_SHADER)
		_:
			mod_label.text = ""


func _refresh_border() -> void:
	if data == null or not face_up:
		return
	var border := UIKit.BLACK
	if data.is_arcana():
		border = UIKit.SUIT_COLORS[CardData.Suit.ARCANA]
	if selected:
		border = UIKit.GOLD
	var bg := Color("#15122A") if not data.is_arcana() else Color("#221436")
	body.add_theme_stylebox_override("panel", UIKit.box(bg, border, 4 if selected else 3, 6, 6))


func _set_sheen(shader: Shader) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	sheen.material = mat
	sheen.visible = true


# ------------------------------------------------------------------ input

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			zoom_requested.emit(self)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressing = true
				_dragging = false
				_long_fired = false
				_press_pos = mb.global_position
				_press_time = 0.0
				if mb.double_click and playable:
					play_requested.emit(self)
			else:
				_release(mb.global_position)
			accept_event()
	elif event is InputEventMouseMotion and _pressing:
		var delta: Vector2 = (event as InputEventMouseMotion).global_position - _press_pos
		if delta.length() > 12.0:
			_dragging = true
		if _dragging and playable:
			body.position = Vector2(delta.x * 0.3, minf(delta.y, 0.0))
			body.rotation = clampf(delta.x * 0.002, -0.2, 0.2)


func _release(pos: Vector2) -> void:
	if not _pressing:
		return
	_pressing = false
	var delta := pos - _press_pos
	if _long_fired:
		pass
	elif _dragging:
		if playable and -delta.y >= DRAG_PLAY_DISTANCE:
			play_requested.emit(self)
			return
	else:
		tapped.emit(self)
	_dragging = false
	_lift(-26.0 if selected else 0.0)


func _process(delta: float) -> void:
	if _pressing and not _dragging and not _long_fired:
		_press_time += delta
		if _press_time >= LONG_PRESS:
			_long_fired = true
			zoom_requested.emit(self)


func _on_hover(inside: bool) -> void:
	if not interactive or not playable or _pressing or selected:
		return
	_lift(-12.0 if inside else 0.0)


func _lift(y: float) -> void:
	if _lift_tween:
		_lift_tween.kill()
	_lift_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_lift_tween.tween_property(body, "position", Vector2(0, y), GameState.anim(0.15))
	_lift_tween.parallel().tween_property(body, "rotation", 0.0, GameState.anim(0.15))


## Texto descritivo para o zoom de carta.
func describe() -> String:
	if data == null:
		return ""
	var lines: Array = [data.display_name()]
	if data.is_arcana():
		lines.append("Arcano Maior · vale %d · pode ser jogado sobre qualquer naipe e vence a vaza." % CardData.ARCANA_VALUE)
	else:
		lines.append("%d Fichas base" % data.base_chips())
	match data.modifier:
		CardData.Modifier.FOIL:
			lines.append("FOIL: +%d Fichas" % CardData.FOIL_CHIPS)
		CardData.Modifier.POLYCHROME:
			lines.append("POLYCHROME: x%s Mult" % UIKit.fmt_dec(CardData.POLY_XMULT, 1))
	return "\n".join(lines)
