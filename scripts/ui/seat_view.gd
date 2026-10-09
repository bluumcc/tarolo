class_name SeatView
extends Control
## Assento de um jogador na mesa.
## Rival: avatar recolhido (PNG) por padrão; toque expande por STACK_SECONDS mostrando nome+stack.
## Você (always_stack): sempre expandido (nome + stack visíveis).
## Interface pública mantida: name_label, stack_label, bet_label, avatar, layout(), W, H,
## AVATAR_CENTER_Y, PLATE_RATIO.

const W := 130.0
const H := 127.0
const PLATE_RATIO := 1.5
const PLATE_MIN_W := HexAvatar.SIZE_PX.x * PLATE_RATIO
const AVATAR_TOP := 2.0
const AVATAR_CENTER_Y := AVATAR_TOP + HexAvatar.SIZE_PX.y / 2.0
const STACK_SECONDS := 7.0
const WIDE_SCALE := 1.3

var avatar: HexAvatar
var name_label: Label
var stack_label: Label
var bet_label: Label

var _plate: PanelContainer
var _exp_panel: Control
var _exp_tex: TextureRect
var _stack_row: HBoxContainer
var _always := false
var _token := 0

var _tex_exp_normal: Texture2D
var _tex_exp_active: Texture2D


func setup(p: int, always_stack: bool = false) -> SeatView:
	_always = always_stack
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_tex_exp_normal = load("res://assets/ui/jogador-expandido-normal.png") as Texture2D
	_tex_exp_active = load("res://assets/ui/jogador-expandido-vez.png") as Texture2D

	avatar = HexAvatar.new().setup(p)
	avatar.position = Vector2((W - avatar.size.x) / 2.0, AVATAR_TOP)
	add_child(avatar)

	if _always:
		_plate = PanelContainer.new()
		_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := UIKit.box_cached(UIKit.PURPLE_DEEP.darkened(0.2), UIKit.VIOLET, 2, 10, 4)
		_plate.add_theme_stylebox_override("panel", sb)
		add_child(_plate)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_plate.add_child(row)

		name_label = UIKit.serif_label("", 19, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(name_label)

		var stack_row := _make_stack_row()
		row.add_child(stack_row)
		_stack_row = stack_row
		_stack_row.visible = true
	else:
		_exp_panel = Control.new()
		_exp_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		_exp_panel.visible = false
		add_child(_exp_panel)

		_exp_tex = TextureRect.new()
		_exp_tex.texture = _tex_exp_normal
		_exp_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_exp_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_exp_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_exp_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_exp_panel.add_child(_exp_tex)

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 2)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_exp_panel.add_child(vbox)

		name_label = UIKit.serif_label("", 17, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.clip_text = true
		name_label.custom_minimum_size = Vector2(PLATE_MIN_W - 16.0, 0)
		vbox.add_child(name_label)

		var stack_row := _make_stack_row()
		vbox.add_child(stack_row)
		_stack_row = stack_row
		_stack_row.visible = true

		avatar.gui_input.connect(_on_gui_input)
		_exp_panel.gui_input.connect(_on_gui_input)

	bet_label = UIKit.label("", 22, UIKit.MONEY, HORIZONTAL_ALIGNMENT_CENTER)
	bet_label.add_theme_font_size_override("font_size", 22)
	bet_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	bet_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bet_label.visible = false
	add_child(bet_label)

	return self


func _make_stack_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip := UIKit.label("◎", 20, UIKit.MONEY, HORIZONTAL_ALIGNMENT_CENTER)
	chip.add_theme_font_size_override("font_size", 20)
	row.add_child(chip)
	stack_label = UIKit.label("0", 20, UIKit.MONEY, HORIZONTAL_ALIGNMENT_CENTER)
	stack_label.add_theme_font_size_override("font_size", 20)
	stack_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(stack_label)
	return row


func layout() -> void:
	if _always and _plate != null:
		var ps := _plate.get_combined_minimum_size()
		_plate.size = Vector2(maxf(ps.x, PLATE_MIN_W), ps.y)
		_plate.position = Vector2((W - _plate.size.x) / 2.0, avatar.position.y + avatar.size.y + 4.0)
		var bh := bet_label.get_combined_minimum_size().y
		bet_label.size = Vector2(W, bh)
		bet_label.position = Vector2(0.0, -bh - 2.0)
	elif not _always and _exp_panel != null:
		var ew := PLATE_MIN_W + 16.0
		var eh := HexAvatar.SIZE_PX.y + 40.0
		_exp_panel.size = Vector2(ew, eh)
		_exp_panel.position = Vector2((W - ew) / 2.0, AVATAR_TOP - 20.0)
		var bh := bet_label.get_combined_minimum_size().y
		bet_label.size = Vector2(W, bh)
		bet_label.position = Vector2(0.0, avatar.position.y + avatar.size.y + 4.0)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _exp_panel.visible:
			_collapse()
		else:
			_expand()
		accept_event()


func _expand() -> void:
	Sfx.play("tick")
	_exp_panel.visible = true
	_token += 1
	var mine := _token
	get_tree().create_timer(STACK_SECONDS).timeout.connect(func():
		if mine == _token and is_instance_valid(self):
			_collapse())


func _collapse() -> void:
	Sfx.play("tick")
	_token += 1
	_exp_panel.visible = false


func set_expanded_active(on: bool) -> void:
	if _exp_tex != null:
		_exp_tex.texture = _tex_exp_active if on else _tex_exp_normal


func show_stack() -> void:
	if not _always and _exp_panel != null:
		_expand()

func show_name() -> void:
	if not _always and _exp_panel != null:
		_collapse()
