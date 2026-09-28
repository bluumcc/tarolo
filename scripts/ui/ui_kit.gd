class_name UIKit
extends RefCounted
## Paleta Dark Brutalist e fábrica de estilos/nós Control reutilizados pelas cenas.

const NIGHT := Color("#0B1026")
const PURPLE := Color("#2A1B3D")
const PURPLE_DEEP := Color("#1A1128")
const BLACK := Color("#07070B")
const INK := Color("#EDE6F2")
const MUTED := Color("#8C82A3")
const GOLD := Color("#E8C170")
const DANGER := Color("#FF5C7A")
const OK := Color("#7FD1AE")
const CHIPS := Color("#5FA8FF")
const MULT := Color("#FF5C7A")

# Ouros, Paus, Copas, Espadas, Trunfo, O Louco.
const SUIT_COLORS := [Color("#E8C170"), Color("#7FD1AE"), Color("#FF5C7A"), Color("#9AA7FF"), Color("#C792EA"), Color("#F2F0F8")]

const CARD_BACKS := {
	"noite": {"name": "Noite", "color": "#1C2350", "price": 0},
	"ametista": {"name": "Ametista", "color": "#5B2A86", "price": 30},
	"brasa": {"name": "Brasa", "color": "#7A2335", "price": 60},
	"abismo": {"name": "Abismo", "color": "#0F3B3A", "price": 100},
	"ouro_velho": {"name": "Ouro Velho", "color": "#6B5321", "price": 160},
	"desafiante": {"name": "Desafiante", "color": "#9E1F4A", "price": 0, "requires_tier": 4},
}


static func box(bg: Color, border: Color = BLACK, border_w: int = 3, radius: int = 4, pad: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb


static func label(text: String, size: int = 18, color: Color = INK, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, accent: Color = GOLD, size: int = 20) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", BLACK)
	b.add_theme_color_override("font_pressed_color", BLACK)
	b.add_theme_color_override("font_focus_color", INK)
	b.add_theme_color_override("font_disabled_color", MUTED)
	b.add_theme_stylebox_override("normal", box(PURPLE, accent, 3, 2, 10))
	b.add_theme_stylebox_override("hover", box(accent, accent, 3, 2, 10))
	b.add_theme_stylebox_override("pressed", box(accent.darkened(0.2), INK, 3, 2, 10))
	b.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), INK, 2, 2, 10))
	b.add_theme_stylebox_override("disabled", box(PURPLE_DEEP, MUTED.darkened(0.4), 3, 2, 10))
	b.pressed.connect(func(): sfx("tick"))
	return b


## Toca um efeito via autoload `Sfx` (resolvido em runtime para o kit funcionar fora da árvore).
static func sfx(name: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var node := tree.root.get_node_or_null("Sfx") if tree else null
	if node:
		node.play(name)


static func panel(bg: Color = PURPLE_DEEP, border: Color = BLACK, pad: int = 16) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, border, 3, 4, pad))
	return p


static func background() -> ColorRect:
	var bg := ColorRect.new()
	bg.color = NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/background.gdshader")
	bg.material = mat
	return bg


## Camada de sobreposição escura (modais: zoom, resultado, pausa).
static func overlay() -> ColorRect:
	var o := ColorRect.new()
	o.color = Color(0.02, 0.02, 0.05, 0.82)
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	return o


static func centered(child: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(child)
	return c


## Formato numérico PT-BR: 1.234.567
static func fmt_int(n: int) -> String:
	var neg := n < 0
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if neg else "") + s + out


## Formato decimal PT-BR: 1.234,5
static func fmt_dec(x: float, decimals: int = 1) -> String:
	var whole := int(floor(absf(x)))
	var frac := absf(x) - whole
	var frac_str := str(int(round(frac * pow(10, decimals))))
	if int(frac_str) >= int(pow(10, decimals)):
		whole += 1
		frac_str = "0"
	frac_str = frac_str.pad_zeros(decimals)
	return ("-" if x < 0 else "") + fmt_int(whole) + ("," + frac_str if decimals > 0 else "")


## Modal genérico (fundo escurecido + painel com scroll) usado fora do menu principal —
## ex: o botão de ajuda dentro da partida, pra explicar regras sem exigir decorar tudo antes.
static func modal(overlay_layer: Control, title: String, width: float = 380.0) -> VBoxContainer:
	var ov := overlay()
	overlay_layer.add_child(ov)
	var box_p := panel(PURPLE_DEEP, GOLD, 24)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size = Vector2(width, 0)
	box_p.add_child(v)
	v.add_child(label(title, 26, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(box_p)
	scroll.add_child(center)
	ov.add_child(scroll)
	return v


static func close_button(overlay_layer: Control, v: VBoxContainer) -> void:
	var close := button("FECHAR", MUTED)
	close.pressed.connect(func():
		overlay_layer.get_child(overlay_layer.get_child_count() - 1).queue_free())
	v.add_child(close)
	close.grab_focus.call_deferred()


static func is_portrait(node: Control) -> bool:
	var s := node.get_viewport_rect().size
	return s.y > s.x
