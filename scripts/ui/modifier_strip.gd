class_name ModifierStrip
extends PanelContainer
## Faixa fixa, de largura total, com o modificador da rodada (losango + nome + efeito curto).
## Nunca some nem é coberta por avisos: quem usa só chama `show_modifier` quando muda.
## Tocar abre a explicação completa (sinal `tapped`).

signal tapped

var _gem: Gem
var _title: Label
var _desc: Label
var _key := ""


class Gem extends Control:
	var color := UIKit.TR_RED

	func _init() -> void:
		custom_minimum_size = Vector2(24, 24)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		var h := 9.0
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h - 4), c + Vector2(h + 4, 0), c + Vector2(0, h + 4), c + Vector2(-h - 4, 0)]), Color(color, 0.3))
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h), c + Vector2(h, 0), c + Vector2(0, h), c + Vector2(-h, 0)]), color)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, 46)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_gem = Gem.new()
	_gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_gem)
	_title = UIKit.serif_label("", 24, UIKit.TR_GOLD)
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_title)
	_desc = UIKit.serif_label("", 20, UIKit.TR_WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	_desc.autowrap_mode = TextServer.AUTOWRAP_OFF
	_desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_desc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_desc)
	gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			tapped.emit())


## Só mexe nos nós se algo mudou (o HUD chama isso a cada atualização).
func show_modifier(title: String, desc: String, color: Color) -> void:
	var key := "%s|%s|%s" % [title, desc, color.to_html()]
	if key == _key:
		return
	_key = key
	_title.text = title
	_desc.text = desc
	_gem.color = color
	_gem.queue_redraw()
	add_theme_stylebox_override("panel", UIKit.rim_box(UIKit.TR_RED_DARK.darkened(0.35), UIKit.TR_RED_LIGHT if color == UIKit.TR_RED else color.lightened(0.3), color, "small", 12, 14))
	visible = title != ""
