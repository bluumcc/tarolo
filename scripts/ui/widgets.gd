class_name Widgets
extends RefCounted
## Componentes de interface reutilizáveis do novo visual (estilo Brawl Stars / Clash).
## Medidas em pixels virtuais de 720 de largura (celular em pé): alvos de toque ≥ 56 px,
## margens de 24 px, texto nunca abaixo de 18 px.

const MARGIN := 24
const TAP_MIN := 56
const TOPBAR_H := 104
const NAV_H := 128


## Pílula de status (ícone + valor): fichas, gemas, nível.
static func stat_pill(icon: String, value: String, color: Color = UIKit.BRAND) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UIKit.box(UIKit.SURFACE_DEEP, color.darkened(0.3), 3, 30, 8)
	sb.content_margin_left = 16
	sb.content_margin_right = 20
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	h.add_child(UIKit.label(icon, 26, color))
	var v := UIKit.label(value, 26, UIKit.INK)
	v.name = "Value"
	h.add_child(v)
	p.custom_minimum_size = Vector2(0, 56)
	return p


static func set_pill_value(pill: Control, value: String) -> void:
	var l := pill.find_child("Value", true, false) as Label
	if l:
		l.text = value


## Barra superior persistente: avatar + nome/nível à esquerda, moedas à direita.
static func top_bar(name_text: String, level_text: String, chips: String, gems: String) -> PanelContainer:
	var bar := PanelContainer.new()
	var sb := UIKit.box(UIKit.SURFACE, UIKit.BLACK, 3, 0, 12)
	sb.set_corner_radius_all(0)
	sb.corner_radius_bottom_left = 28
	sb.corner_radius_bottom_right = 28
	sb.content_margin_left = MARGIN
	sb.content_margin_right = MARGIN
	bar.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bar.add_child(row)
	var av := Portrait.new().setup(0, UIKit.BRAND, 72.0)
	row.add_child(av)
	var who := VBoxContainer.new()
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	who.add_theme_constant_override("separation", 0)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(UIKit.label(name_text, 28, UIKit.INK))
	who.add_child(UIKit.label(level_text, 20, UIKit.BRAND))
	row.add_child(who)
	var a := stat_pill("◎", chips, UIKit.MONEY)
	a.name = "ChipsPill"
	row.add_child(a)
	var b := stat_pill("◆", gems, UIKit.CHIPS)
	b.name = "GemsPill"
	row.add_child(b)
	return bar


## Cartão de modo: bloco grande e colorido tocável (título, legenda, ícone).
static func mode_card(title: String, caption: String, color: Color, height: int, icon: String, on_press: Callable, title_size: int = 40) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, height)
	p.mouse_filter = Control.MOUSE_FILTER_PASS  # não engole o arrasto de quem quer rolar a lista
	p.focus_mode = Control.FOCUS_ALL
	p.add_theme_stylebox_override("panel", UIKit.chunky(color))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	p.add_child(row)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	var fg := UIKit.text_on(color)   # escuro sobre cards claros (dourado, verde)
	var t := UIKit.label(title, title_size, fg)
	t.add_theme_color_override("font_outline_color", color.darkened(0.6))
	if fg != UIKit.INK:
		t.remove_theme_constant_override("outline_size")
	col.add_child(t)
	var c := UIKit.label(caption, 20, Color(fg.r, fg.g, fg.b, 0.92))
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(c)
	var ic := UIKit.label(icon, int(height * 0.5), Color(fg.r, fg.g, fg.b, 0.95))
	ic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(ic)
	p.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				p.add_theme_stylebox_override("panel", UIKit.chunky(color, true))
			else:
				p.add_theme_stylebox_override("panel", UIKit.chunky(color))
				UIKit.sfx("tick")
				on_press.call())
	p.mouse_exited.connect(func(): p.add_theme_stylebox_override("panel", UIKit.chunky(color)))
	return p


## Barra de navegação inferior com aba central em destaque (como nos apps de cartas).
## items: [{icon, label, cb, center(bool)}]
static func bottom_nav(items: Array) -> PanelContainer:
	var bar := PanelContainer.new()
	var sb := UIKit.box(UIKit.SURFACE, UIKit.BLACK, 3, 0, 8)
	sb.set_corner_radius_all(0)
	sb.corner_radius_top_left = 32
	sb.corner_radius_top_right = 32
	sb.border_width_bottom = 0
	sb.border_width_top = 4
	sb.border_color = UIKit.OUTLINE
	sb.content_margin_bottom = 20
	bar.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	bar.add_child(row)
	for it in items:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 0)
		var center: bool = bool(it.get("center", false))
		var btn := UIKit.nav_button(str(it["icon"]), center)
		btn.pressed.connect(it["cb"])
		col.add_child(btn)
		var lab := UIKit.label(str(it["label"]), 18, UIKit.BRAND if center else UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		col.add_child(lab)
		row.add_child(col)
	return bar


## Botão de ícone quadrado: mora no UIKit (kit único de componentes).
static func icon_button(text: String, color: Color = UIKit.BUTTON_MUTED) -> Button:
	return UIKit.icon_button(text, color)


## Fileira de bolinhas de progresso (ex.: rodada 3 de 8): feitas, atual e pendentes.
static func progress_dots(row: HBoxContainer, total: int, done: int) -> void:
	# Reaproveita os pontos existentes (o HUD atualiza várias vezes por rodada).
	while row.get_child_count() > total:
		var extra := row.get_child(row.get_child_count() - 1)
		row.remove_child(extra)
		extra.queue_free()
	while row.get_child_count() < total:
		var d := Panel.new()
		d.custom_minimum_size = Vector2(22, 22)
		row.add_child(d)
	for i in range(total):
		var col := UIKit.BRAND if i < done else (UIKit.INK if i == done else UIKit.DOT_OFF)
		var sb := UIKit.dot_style(col if i <= done else UIKit.PURPLE_DEEP, UIKit.OUTLINE if i < done else col, 11)
		(row.get_child(i) as Panel).add_theme_stylebox_override("panel", sb)
