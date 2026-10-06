class_name StatCard
extends PanelContainer
## Card de número: legenda pequena em cima, valor grande embaixo (POTE, TEMPO, FEZ/PALPITE...).
## Um só componente pros três cantos da mesa; quem usa só troca `value.text` / a cor.

var caption: Label
var value: Label


func setup(cap: String, val: String, val_color: Color = UIKit.TR_GOLD, val_size: int = 32, cap_size: int = 20) -> StatCard:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UIKit.box_cached(UIKit.TR_PURPLE_DARK.darkened(0.3), UIKit.TR_PURPLE_LIGHT, 2, 12, UIKit.card_pad()))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	caption = UIKit.serif_label(cap, cap_size, UIKit.muted_lilac(), HORIZONTAL_ALIGNMENT_CENTER)
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(caption)
	value = UIKit.label(val, val_size, val_color, HORIZONTAL_ALIGNMENT_CENTER)
	value.add_theme_font_size_override("font_size", val_size)
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(value)
	return self
