class_name ModifierStrip
extends PanelContainer
## Card do modificador da rodada, em cima da barra de baixo: legenda pequena + nome. Tocar abre a
## regra completa (sinal `tapped`). `show_modifier` só mexe nos nós se algo mudou.

signal tapped

const HEIGHT := 80.0

var _caption: Label
var _title: Label
var _key := ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, HEIGHT)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	_caption = UIKit.serif_label("MODIFICADOR · TOQUE PARA VER A REGRA", 16, UIKit.muted_lilac(), HORIZONTAL_ALIGNMENT_CENTER)
	_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(_caption)
	_title = UIKit.serif_label("", 28, UIKit.TR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.clip_text = true
	v.add_child(_title)
	gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			UIKit.sfx("tick")
			tapped.emit())


func show_modifier(title: String, color: Color) -> void:
	var key := "%s|%s" % [title, color.to_html()]
	if key == _key:
		return
	_key = key
	_title.text = title
	_title.add_theme_color_override("font_color", color)
	add_theme_stylebox_override("panel", UIKit.rim_box(UIKit.TR_PURPLE_DARK.darkened(0.3), color.lightened(0.15), color.darkened(0.4), "small", 12, 14, 6))
	visible = title != ""
