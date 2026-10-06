class_name SeatView
extends Control
## Assento de um jogador na mesa: avatar hexagonal + plaquinha com o nome embaixo.
## Rival: tocar no avatar OU no nome abre o card com o stack (fecha sozinho em 3 s).
## Você (`always_stack`): a plaquinha mostra nome e stack o tempo todo.
## O tamanho do assento é fixo (W×H), então a mesa pode posicioná-lo sem medir texto.

const W := 130.0
const H := 127.0
const PLATE_MIN_W := 112.0

var avatar: HexAvatar
var name_label: Label
var stack_label: Label      ## no card (rival) ou na própria plaquinha (você)
var bet_label: Label        ## aposta da rodada, logo abaixo do nome (rival)
var _plate: PanelContainer
var _card: PanelContainer
var _always := false
var _token := 0


func setup(p: int, accent: Color, always_stack: bool = false) -> SeatView:
	_always = always_stack
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar = HexAvatar.new().setup(p, accent)
	avatar.position = Vector2((W - avatar.size.x) / 2.0, 2.0)
	add_child(avatar)

	_plate = PanelContainer.new()
	_plate.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := UIKit.box_cached(UIKit.TR_PURPLE_DARK.darkened(0.2), UIKit.TR_PURPLE_LIGHT, 2, 10, 4)
	_plate.add_theme_stylebox_override("panel", sb)
	add_child(_plate)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(row)
	name_label = UIKit.serif_label("", 22, UIKit.TR_WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(name_label)

	var stack_row := HBoxContainer.new()   # ◎ + stack: no card (rival) ou na plaquinha (você)
	stack_row.add_theme_constant_override("separation", 4)
	stack_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip := UIKit.label("◎", 22, UIKit.TR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	chip.add_theme_font_size_override("font_size", 22)
	stack_row.add_child(chip)
	stack_label = UIKit.label("0", 22, UIKit.TR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	stack_label.add_theme_font_size_override("font_size", 22)
	stack_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	stack_row.add_child(stack_label)
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override("panel", UIKit.box_cached(UIKit.TR_PURPLE_DARK.darkened(0.2), UIKit.TR_GOLD.darkened(0.4), 2, 10, 6))
	_card.visible = false
	if _always:
		row.add_child(stack_row)
	else:
		_card.add_child(stack_row)
	add_child(_card)

	bet_label = UIKit.label("", 22, UIKit.TR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	bet_label.add_theme_font_size_override("font_size", 22)
	bet_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	bet_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bet_label.visible = false
	add_child(bet_label)

	if not _always:
		avatar.gui_input.connect(_on_gui_input)
		_plate.gui_input.connect(_on_gui_input)
	return self


## Posiciona plaquinha, aposta e card (chamar depois de mudar texto/fonte).
func layout() -> void:
	var ps := _plate.get_combined_minimum_size()
	_plate.size = Vector2(maxf(ps.x, PLATE_MIN_W), ps.y)
	_plate.position = Vector2((W - _plate.size.x) / 2.0, avatar.position.y + avatar.size.y - 10.0)
	var y := _plate.position.y + _plate.size.y
	var bh := bet_label.get_combined_minimum_size().y
	bet_label.position = Vector2(0.0, y)
	bet_label.size = Vector2(W, bh)
	_card.size = _card.get_combined_minimum_size()
	_card.position = Vector2((W - _card.size.x) / 2.0, y + bh + 2.0)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_card()
		accept_event()


func toggle_card() -> void:
	Sfx.play("tick")
	_card.visible = not _card.visible
	_token += 1
	if _card.visible:
		var mine := _token
		get_tree().create_timer(3.0).timeout.connect(func():
			if mine == _token and is_instance_valid(_card):
				_card.visible = false)
