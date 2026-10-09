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

var _exp_panel: PanelContainer
var _stack_row: HBoxContainer
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

	# Painel de fundo — adicionado ANTES do avatar para ficar atrás dele
	_sb_normal = UIKit.box(UIKit.PURPLE_DEEP.darkened(0.2), UIKit.VIOLET, 2, 10, 0)
	_sb_active = UIKit.box(UIKit.PURPLE_DEEP.darkened(0.2), UIKit.BRAND, 3, 10, 0)
	_exp_panel = PanelContainer.new()
	_exp_panel.add_theme_stylebox_override("panel", _sb_normal)
	_exp_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# always_stack = sempre expandido (p=0); demais: começa colapsado e togla no toque
	_exp_panel.visible = _always
	add_child(_exp_panel)

	avatar = HexAvatar.new().setup(p)
	avatar.position = Vector2((W - avatar.size.x) / 2.0, AVATAR_TOP)
	add_child(avatar)

	# HBox dentro do painel: [espaçador(avatar) | vbox texto] ou [vbox texto | espaçador(avatar)]
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_exp_panel.add_child(hbox)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	name_label = UIKit.serif_label("", 17, UIKit.BTN_OFF_WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = true
	vbox.add_child(name_label)

	var stack_row := _make_stack_row()
	vbox.add_child(stack_row)
	_stack_row = stack_row

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(avatar.size.x, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _flip:
		hbox.add_child(vbox)
		hbox.add_child(spacer)
	else:
		hbox.add_child(spacer)
		hbox.add_child(vbox)

	if not _always:
		# rivais: toque no avatar ou no painel togla expansão
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
	var chip := UIKit.label("◎", 20, UIKit.HUD_PINK, HORIZONTAL_ALIGNMENT_CENTER)
	chip.add_theme_font_size_override("font_size", 20)
	row.add_child(chip)
	stack_label = UIKit.label("0", 20, UIKit.HUD_PINK, HORIZONTAL_ALIGNMENT_CENTER)
	stack_label.add_theme_font_size_override("font_size", 20)
	stack_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(stack_label)
	return row


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
