class_name SeatView
extends Control
## Assento de um jogador na mesa.
## Rival: avatar sempre visível; toque → card cresce lateralmente como um único elemento.
##   Avatar fixo no lugar; zona de texto aparece ao lado (direita por padrão, esquerda se flip).
## Você (always_stack): plaquinha abaixo do avatar sempre visível com nome+stack.
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
const EXP_W := 100.0   ## largura da zona de texto no card expandido

var avatar: HexAvatar
var name_label: Label
var stack_label: Label
var bet_label: Label

@onready var _exp_panel: PanelContainer = $ExpPanel
@onready var _hbox: HBoxContainer = $ExpPanel/HBox
@onready var _spacer: Control = $ExpPanel/HBox/Spacer
@onready var _text_zone: VBoxContainer = $ExpPanel/HBox/TextZone
@onready var _chip_lbl: Label = $ExpPanel/HBox/TextZone/StackRow/ChipLabel
@onready var _stack_lbl: Label = $ExpPanel/HBox/TextZone/StackRow/StackLabel
@onready var _bet_lbl: Label = $BetLabel

var _always := false
var _flip := false      ## true = avatar à direita, texto à esquerda
var _token := 0

var _sb_normal: StyleBoxFlat
var _sb_active: StyleBoxFlat


func setup(p: int, always_stack: bool = false, flip_expand: bool = false) -> SeatView:
	_always = always_stack
	_flip = flip_expand
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_sb_normal = UIKit.box(UIKit.PURPLE_DEEP.darkened(0.2), UIKit.VIOLET, 2, 10, 0)
	_sb_active = UIKit.box(UIKit.PURPLE_DEEP.darkened(0.2), UIKit.BRAND, 3, 10, 0)
	_exp_panel.add_theme_stylebox_override("panel", _sb_normal)
	_exp_panel.visible = _always

	# Avatar hexagonal: sempre criado dinamicamente (precisa do número do assento)
	avatar = HexAvatar.new().setup(p)
	avatar.position = Vector2((W - avatar.size.x) / 2.0, AVATAR_TOP)
	add_child(avatar)

	# Spacer tem a largura do avatar para alinhar o texto ao lado dele
	_spacer.custom_minimum_size = Vector2(avatar.size.x, 0)

	# Flip: texto à esquerda do avatar (assentos 4 e 5)
	if _flip:
		_hbox.move_child(_text_zone, 0)

	# Configura labels (fontes e cores aplicadas aqui; a estrutura vem do .tscn)
	name_label = $ExpPanel/HBox/TextZone/NameLabel
	name_label.text = ""
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", UIKit.serif())
	name_label.add_theme_font_size_override("font_size", UIKit.snap_font(17))
	name_label.add_theme_color_override("font_color", UIKit.BTN_OFF_WHITE)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	stack_label = _stack_lbl
	_chip_lbl.add_theme_font_size_override("font_size", 20)
	_chip_lbl.add_theme_color_override("font_color", UIKit.HUD_PINK)
	stack_label.add_theme_font_size_override("font_size", 20)
	stack_label.add_theme_color_override("font_color", UIKit.HUD_PINK)
	stack_label.autowrap_mode = TextServer.AUTOWRAP_OFF

	if not _always:
		avatar.gui_input.connect(_on_gui_input)
		_exp_panel.gui_input.connect(_on_gui_input)

	bet_label = _bet_lbl
	bet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bet_label.add_theme_font_size_override("font_size", 22)
	bet_label.add_theme_color_override("font_color", UIKit.MONEY)
	bet_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	bet_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	return self


func layout() -> void:
	if _exp_panel != null:
		var ah := avatar.size.y
		var ph := _exp_panel.get_combined_minimum_size().y
		var panel_h := maxf(ph, ah)
		var total_w := avatar.size.x + EXP_W
		_exp_panel.size = Vector2(total_w, panel_h)
		if _flip:
			_exp_panel.position = Vector2(avatar.position.x - EXP_W, AVATAR_TOP)
		else:
			_exp_panel.position = Vector2(avatar.position.x, AVATAR_TOP)
		var bh := bet_label.get_combined_minimum_size().y
		bet_label.size = Vector2(W, bh)
		if _always:
			bet_label.position = Vector2(0.0, -bh - 2.0)
		else:
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
	if _exp_panel != null and _sb_normal != null and _sb_active != null:
		_exp_panel.add_theme_stylebox_override("panel", _sb_active if on else _sb_normal)


func show_stack() -> void:
	if not _always and _exp_panel != null:
		_expand()

func show_name() -> void:
	if not _always and _exp_panel != null:
		_collapse()
