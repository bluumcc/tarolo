class_name UIKit
extends RefCounted
## Paleta Dark Brutalist e fábrica de estilos/nós Control reutilizados pelas cenas.

## Tamanhos mínimos de texto (padrão de mercado pra 720 de largura): nada menor que isso.
const MIN_FONT := 26
const MIN_BUTTON_FONT := 30

const NIGHT := Color("#150E45")
const PURPLE := Color("#3A2A9C")
const PURPLE_DEEP := Color("#241A70")
const BLACK := Color("#0B0626")
const INK := Color("#FFFFFF")
const MUTED := Color("#A9A4E0")
const GOLD := Color("#FFC933")
const VIOLET := Color("#8B5CFF")  ## destaque principal (botão primário, barras)
const DANGER := Color("#FF4D6A")
const OK := Color("#36D97B")
const CHIPS := Color("#3FA9FF")
const MULT := Color("#FF5C7A")
## Duelo do Vanilla: o Atacante é o "chefe" (vermelho), a Defesa é o time contra ele (azul).
const BOSS := Color("#E2463B")
const DEF := Color("#5AA9FF")

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


## Painel "chapado" estilo Brawl/Clash: contorno escuro grosso e uma base mais espessa,
## que dá volume sem precisar de arte. `border` colorido vira o contorno de destaque.
static func box(bg: Color, border: Color = BLACK, border_w: int = 3, radius: int = 4, pad: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	if border == BLACK:
		sb.border_color = Color("#0B0626")
		sb.set_border_width_all(3)
		sb.border_width_bottom = 6
	else:
		sb.border_color = border
		sb.set_border_width_all(mini(border_w, 4))
	sb.set_corner_radius_all(maxi(radius, 18))
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad + (3 if border == BLACK else 0)
	sb.anti_aliasing = true
	return sb


## Texto com contorno escuro (só a partir de 24 px) — é o que dá o ar "arcade" e garante
## contraste em cima de qualquer fundo.
static func label(text: String, size: int = 22, color: Color = INK, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	# Textos pequenos ganham +2 px além do mínimo: no celular real (tela ~390 pt) 720 px
	# virtuais viram quase metade, e 18–20 px ficava ilegível.
	size = maxi(size + (4 if size < 28 else 0), MIN_FONT)
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if size >= 24:
		l.add_theme_constant_override("outline_size", maxi(size / 8, 3))
		l.add_theme_color_override("font_outline_color", Color("#0B0626"))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Face de botão 3D: cor viva, contorno escuro e base grossa; ao apertar, "afunda".
static func chunky(face: Color, pressed: bool = false) -> StyleBoxFlat:
	var edge := face.darkened(0.55)
	var sb := StyleBoxFlat.new()
	sb.bg_color = face
	sb.border_color = edge
	sb.set_border_width_all(4)
	sb.border_width_bottom = 4 if pressed else 12
	sb.set_corner_radius_all(26)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 18 if pressed else 12
	sb.content_margin_bottom = 12 if pressed else 18
	sb.anti_aliasing = true
	sb.shadow_color = Color(0, 0, 0, 0.0 if pressed else 0.25)
	sb.shadow_size = 0 if pressed else 6
	sb.shadow_offset = Vector2(0, 4)
	return sb


static func button(text: String, accent: Color = GOLD, size: int = 30) -> Button:
	size = maxi(size, MIN_BUTTON_FONT)
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0, 84)
	b.add_theme_font_size_override("font_size", size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, INK)
	b.add_theme_color_override("font_disabled_color", MUTED)
	b.add_theme_constant_override("outline_size", 5)
	b.add_theme_color_override("font_outline_color", accent.darkened(0.6))
	var face := accent if accent != MUTED else Color("#6B6BC4")
	b.add_theme_stylebox_override("normal", chunky(face))
	b.add_theme_stylebox_override("hover", chunky(face.lightened(0.12)))
	b.add_theme_stylebox_override("pressed", chunky(face.darkened(0.08), true))
	b.add_theme_stylebox_override("focus", chunky(face.lightened(0.12)))
	b.add_theme_stylebox_override("disabled", chunky(Color("#3A3570")))
	b.pressed.connect(func(): sfx("tick"))
	return b


## Botão em pílula (mantido pra chips e botões pequenos).
static func pill(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(40)
	sb.set_content_margin_all(16)
	sb.anti_aliasing = true
	return sb


## Toca um efeito via autoload `Sfx` (resolvido em runtime para o kit funcionar fora da árvore).
static func sfx(name: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var node := tree.root.get_node_or_null("Sfx") if tree else null
	if node:
		node.play(name)


static func panel(bg: Color = PURPLE_DEEP, border: Color = BLACK, pad: int = 20) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, border, 3, 4, pad))
	return p


## Painel que reage a toque (ex.: card de jogador que expande detalhe) sem trocar de
## nó — PanelContainer se auto-dimensiona certinho ao redor do conteúdo (Button não faz
## isso com filhos arbitrários, então nunca use Button só pra "ser clicável").
## Conecte o retorno de `on_tap` pra tratar o toque (recebe o próprio painel).
static func tap_panel(bg: Color = PURPLE_DEEP, border: Color = MUTED, pad: int = 10, on_tap: Callable = Callable()) -> PanelContainer:
	var p := panel(bg, border, pad)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	if on_tap.is_valid():
		p.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				sfx("tick")
				on_tap.call())
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


## Centraliza um popup na tela. Rola quando o conteúdo passa da altura (celular) e, em
## retrato, amplia os textos e botões do popup (BOOST) — no celular 720 px virtuais viram
## ~390 pt e o tamanho de desktop fica pequeno.
static func centered(child: Control) -> Control:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var c := CenterContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.add_child(child)
	scroll.add_child(c)
	boost_later(child)
	return scroll


const BOOST := 1.3

## Amplia (uma única vez) fontes e botões de uma árvore, só em tela retrato.
static func boost(node: Node) -> void:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return
	var vp := node.get_viewport().get_visible_rect().size
	if vp.y <= vp.x:
		return
	_boost_rec(node)


static func boost_later(node: Node) -> void:
	node.ready.connect(func(): boost.call_deferred(node), CONNECT_ONE_SHOT)


static func _boost_rec(n: Node) -> void:
	if n.has_meta("boosted"):
		return
	if n is Label:
		var l := n as Label
		var sz := l.get_theme_font_size("font_size")
		l.add_theme_font_size_override("font_size", int(round(sz * BOOST)))
		if l.has_theme_constant_override("outline_size"):
			l.add_theme_constant_override("outline_size", int(round(l.get_theme_constant("outline_size") * BOOST)))
		n.set_meta("boosted", true)
	elif n is Button:
		var b := n as Button
		b.add_theme_font_size_override("font_size", int(round(b.get_theme_font_size("font_size") * 1.2)))
		b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, 100.0)
		n.set_meta("boosted", true)
	for ch in n.get_children():
		_boost_rec(ch)


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
static func modal(overlay_layer: Control, title: String, width: float = 660.0) -> VBoxContainer:
	var ov := overlay()
	overlay_layer.add_child(ov)
	var box_p := panel(PURPLE_DEEP, GOLD, 30)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size = Vector2(width, 0)
	box_p.add_child(v)
	v.add_child(label(title, 44, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(box_p)
	scroll.add_child(center)
	ov.add_child(scroll)
	boost.call_deferred(box_p)
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
