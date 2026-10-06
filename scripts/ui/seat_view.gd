class_name SeatView
extends Control
## Assento de um jogador na mesa: avatar hexagonal + plaquinha com o nome embaixo.
## Rival: tocar no avatar OU no nome troca o nome pelo stack; o nome volta sozinho em 7 s.
## Você (`always_stack`): a plaquinha mostra nome e stack o tempo todo.
## O tamanho do assento é fixo (W×H), então a mesa pode posicioná-lo sem medir texto.

const W := 130.0
const H := 127.0
const PLATE_RATIO := 1.5      ## largura fixa da plaquinha de nome: 150% da largura do avatar
const PLATE_MIN_W := HexAvatar.SIZE_PX.x * PLATE_RATIO
const AVATAR_TOP := 2.0
const AVATAR_CENTER_Y := AVATAR_TOP + HexAvatar.SIZE_PX.y / 2.0   ## centro do avatar, medido do topo do assento
const STACK_SECONDS := 7.0

var avatar: HexAvatar
var name_label: Label
var stack_label: Label      ## troca com o nome (rival) ou fica ao lado dele (você)
var bet_label: Label        ## aposta da rodada, logo abaixo do nome (rival)
var _plate: PanelContainer
var _stack_row: HBoxContainer
var _always := false
var _token := 0


func setup(p: int, accent: Color, always_stack: bool = false) -> SeatView:
	_always = always_stack
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar = HexAvatar.new().setup(p, accent)
	avatar.position = Vector2((W - avatar.size.x) / 2.0, AVATAR_TOP)
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
	name_label = UIKit.serif_label("", 19, UIKit.TR_WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if not _always:   # rival: nome comprido é cortado, a plaquinha tem largura fixa
		name_label.clip_text = true
		name_label.custom_minimum_size = Vector2(PLATE_MIN_W - 16.0, 0)
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
	_stack_row = stack_row
	stack_row.visible = _always
	row.add_child(stack_row)

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


## Posiciona plaquinha e aposta (chamar depois de mudar texto/fonte). A aposta dos rivais fica
## embaixo da plaquinha; a sua (`always_stack`), no mesmo estilo, em cima do avatar.
func layout() -> void:
	var ps := _plate.get_combined_minimum_size()
	_plate.size = Vector2(maxf(ps.x, PLATE_MIN_W) if _always else PLATE_MIN_W, ps.y)   # rival: largura fixa
	_plate.position = Vector2((W - _plate.size.x) / 2.0, avatar.position.y + avatar.size.y + 4.0)
	var bh := bet_label.get_combined_minimum_size().y
	bet_label.size = Vector2(W, bh)
	bet_label.position = Vector2(0.0, -bh - 2.0) if _always else Vector2(0.0, _plate.position.y + _plate.size.y)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _stack_row.visible:
			show_name()   # tocar de novo volta pro nome
		else:
			show_stack()
		accept_event()


## Troca o nome pelo stack por `STACK_SECONDS`; tocar de novo reinicia a contagem.
func show_stack() -> void:
	Sfx.play("tick")
	name_label.visible = false
	_stack_row.visible = true
	layout()
	_token += 1
	var mine := _token
	get_tree().create_timer(STACK_SECONDS).timeout.connect(func():
		if mine == _token and is_instance_valid(self):
			name_label.visible = true
			_stack_row.visible = false
			layout())


func show_name() -> void:
	Sfx.play("tick")
	_token += 1   # cancela a volta automática pendente
	name_label.visible = true
	_stack_row.visible = false
	layout()
