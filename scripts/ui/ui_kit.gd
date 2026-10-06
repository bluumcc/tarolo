class_name UIKit
extends RefCounted
## Paleta Dark Brutalist e fábrica de estilos/nós Control reutilizados pelas cenas.

## Tamanhos mínimos de texto (padrão de mercado pra 720 de largura): nada menor que isso.
const MIN_FONT := 26
const MIN_BUTTON_FONT := 30

const NIGHT := Color("#08051C")      ## fundo principal: quase preto com toque violeta
const PURPLE := Color("#2D1E8A")
const PURPLE_DEEP := Color("#1A1060")
const BLACK := Color("#04030F")
const INK := Color("#EEE8FF")         ## branco levemente lilás (mais suave que branco puro)
const MUTED := Color("#8880CC")
const GOLD := Color("#FFD060")        ## dourado mais quente/âmbar
const VIOLET := Color("#A87AFF")      ## destaque: roxo mais vivo
const DANGER := Color("#FF3A5C")
const OK := Color("#2EE87A")
const CHIPS := Color("#2FB8FF")
const MULT := Color("#FF4D78")

# ---- Papéis de cor (cor = função; ver docs/DESIGN_CORES.md). Use estes nomes nas telas.
const ACTION := VIOLET                  ## ação primária (um botão por tela)
const MONEY := GOLD                     ## fichas, stack, pote, ganho
const TURN := Color("#5EEAD4")          ## vez / foco / ordem de jogada
const GAIN := OK                        ## ganho, sucesso
const LOSS := Color("#FF6F86")          ## perda, perigo (legível como texto sobre roxo)
const INFO := CHIPS                     ## informação neutra
const COMBO := Color("#FF9A3D")         ## chamas, sequência, combos
const MODIFIER := Color("#C792EA")      ## modificador de nível, Trunfos
const TEXT_ON_LIGHT := Color("#1A1240") ## texto sobre superfícies claras (dourado, verde)

## Identidade (o dourado da marca): títulos e molduras de popup; e o jogador local.
const BRAND := GOLD
const BROWN := Color("#D9B48F")   ## marrom claro: títulos e valores do hub
const RANK_PLAY_BG := Color("#4A0D1A")      ## botão JOGAR RANKEADA: vermelho escuro
const RANK_PLAY_GLOW := Color("#FF2D55")    ## brilho/borda falhada do botão de jogar
const ENTER_BLUE := Color("#2A4373")        ## botão ENTRAR dos torneios
const ENTER_BLUE_EDGE := Color("#16264A")   ## borda suave do botão ENTRAR
const ME := GOLD
const CLEAR := Color(0, 0, 0, 0)

## Superfícies e fundos (roxo profundo do jogo).
const SURFACE := Color("#120D40")          ## barras e caixas de informação
const SURFACE_DEEP := Color("#09071F")     ## selos e pílulas escuras
const SURFACE_POT := Color("#1E1245")      ## caixa do pote
const TABLE_FILL := Color(0.06, 0.04, 0.18, 0.93)  ## mesa: quase preto-violeta
const TABLE_EDGE := Color("#4A3DBF")
const SCRIM := Color(0.02, 0.01, 0.05, 0.97)      ## tela cheia de transição
const SCRIM_SOFT := Color(0.03, 0.02, 0.05, 0.90)
const OUTLINE := Color("#04030F")           ## contorno escuro de textos e barras
const BUTTON_MUTED := Color("#5A5AB8")      ## face de botão secundário
const DOT_OFF := Color("#3A318A")           ## bolinha pendente
const GOLD_LIGHT := Color("#FFE999")
const TITLE_OUTLINE := Color("#2A1490")
const GOOD_ON_LIGHT := Color("#1E8A5C")     ## verde legível sobre carta clara
const BAD_ON_LIGHT := Color("#D42A3C")
## Painéis do Vanilla (duelo chefe x defesa).
const BOSS_BG := Color(0.20, 0.07, 0.08, 0.9)
const BOSS_TRACK := Color("#2a1715")
const BOSS_META_TEXT := Color("#f0c7c2")
const ME_BG := Color(0.24, 0.20, 0.08, 0.9)
const ME_TRACK := Color("#2b2413")
const RULE_TEXT := Color("#d6cbbb")
const PAPER := Color("#f3ece0")
const TICK_EMPTY := Color("#2a2320")
const HUD_DIM := Color(0.8, 0.78, 0.86, 1.0)
const HINT_BG := Color(0.10, 0.08, 0.14, 0.9)
const TOAST_BG := Color(0.03, 0.03, 0.07, 0.92)

## Paleta Tarot Royale — ver docs/PALETA.md para referência completa.
const TR_BLACK  := Color("#080413")   ## sombra / contorno / fundo de carta
const TR_WHITE  := Color("#e8e7e6")   ## branco — texto principal, face de carta
const TR_GOLD   := Color("#d8c7aa")   ## dourado — recompensas, fichas, destaque
const TR_CYAN   := Color("#6cbfc5")   ## ciano (info, seleção, ação secundária)
const TR_RED_LIGHT := Color("#ffd4e0")  ## vermelho-claro — quase branco, texto sobre vermelho
const TR_RED       := Color("#f61b54")  ## vermelho-normal — perigo, naipes, RANKEADA
const TR_RED_DARK  := Color("#5d1440")  ## vermelho-escuro — fundo/sombra de botão vermelho
const TR_RED_GLOW  := Color("#d63060")  ## glow difuso do botão vermelho
const TR_RED_NEON  := Color("#ff8099")  ## neon quente: borda interna do botão big-glow
const TR_BLUE          := Color("#236592")  ## azul (defesa, elementos de fundo)
const TR_PURPLE_LIGHT  := Color("#4f346a")  ## roxo-claro — superfícies elevadas, botões ativos
const TR_PURPLE        := Color("#191430")  ## roxo-normal — painéis, modais
const TR_PURPLE_DARK   := Color("#140c33")  ## roxo-escuro — fundo da tela, camada mais profunda

## Duelo do Vanilla: o Atacante é o "chefe" (vermelho), a Defesa é o time contra ele (azul).
const BOSS := Color("#E2463B")
const DEF := Color("#5AA9FF")
const BOSS_TEXT := Color("#FF7A6E")   ## versão legível (texto) do vermelho do chefe

# Ouros, Paus, Copas, Espadas, Trunfo, O Louco.
const SUIT_COLORS := [Color("#E8C170"), Color("#7FD1AE"), Color("#FF5C7A"), Color("#9AA7FF"), Color("#C792EA"), Color("#F2F0F8")]

const CARD_BACKS := {
	"noite":      {"name": "Noite",      "color": "#1C2350", "cover": "cover_b", "price": 0},
	"ametista":   {"name": "Ametista",   "color": "#5B2A86", "cover": "cover_d", "price": 30},
	"brasa":      {"name": "Brasa",      "color": "#7A2335", "cover": "cover_a", "price": 60},
	"abismo":     {"name": "Abismo",     "color": "#0F3B3A", "cover": "cover_c", "price": 100},
	"ouro_velho": {"name": "Ouro Velho", "color": "#6B5321", "price": 160},
	"desafiante": {"name": "Desafiante", "color": "#9E1F4A", "price": 0, "requires_tier": 4},
}


## Painel "chapado" estilo Brawl/Clash: contorno escuro grosso e uma base mais espessa,
## que dá volume sem precisar de arte. `border` colorido vira o contorno de destaque.
static func box(bg: Color, border: Color = BLACK, border_w: int = 3, radius: int = 4, pad: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	if border == BLACK:
		sb.border_color = OUTLINE
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


## Padrão de borda com bloom: borda na cor clara (linha visual) + glow esparso na cor normal.
## Encapsula o padrão visual do projeto: [cor]-claro na borda, [cor]-normal no glow.
## size: "large" (botões de destaque, glow_size 30, alpha 0.42) ou "small" (cards/botões secundários, glow_size 14, alpha 0.35).
static func rim_box(bg: Color, rim_col: Color, glow_col: Color, size: String = "large", radius: int = 10, pad_h: int = 12) -> StyleBoxFlat:
	var glow_size := 30 if size == "large" else 14
	var shad_a    := 0.42 if size == "large" else 0.35
	return glow_box(bg, glow_col, glow_size, 2, radius, pad_h, rim_col, shad_a)


## StyleBox com sombra/glow colorida — para botões primários e de destaque.
## `glow_col` é a cor da sombra; `border_col` substitui a cor da borda (padrão = glow_col).
## `shadow_alpha` controla a opacidade do halo externo.
static func glow_box(bg: Color, glow_col: Color, glow_size: int = 10, border_w: int = 3, radius: int = 10, pad_h: int = 12, border_col: Color = Color.TRANSPARENT, shadow_alpha: float = 0.55) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border_col if border_col.a > 0.0 else glow_col
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(glow_col.r, glow_col.g, glow_col.b, shadow_alpha)
	sb.shadow_size   = glow_size
	sb.shadow_offset = Vector2.ZERO
	sb.content_margin_left  = pad_h
	sb.content_margin_right = pad_h
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
		l.add_theme_color_override("font_outline_color", OUTLINE)
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


## Luminância relativa (WCAG) e razão de contraste entre duas cores.
static func luminance(c: Color) -> float:
	var f := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)


static func contrast(a: Color, b: Color) -> float:
	var la := luminance(a)
	var lb := luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## Cor de texto legível sobre uma face: branco, ou escuro se a face for clara (dourado, verde).
static func text_on(face: Color) -> Color:
	return INK if contrast(INK, face) >= 3.0 else TEXT_ON_LIGHT


## Estilos reaproveitados (mesmos parâmetros = mesmo objeto): evita recriar StyleBoxFlat a
## cada atualização de HUD.
static var _box_cache := {}

static func box_cached(bg: Color, border: Color = BLACK, border_w: int = 3, radius: int = 4, pad: int = 12) -> StyleBoxFlat:
	var key := "%s|%s|%d|%d|%d" % [bg.to_html(), border.to_html(), border_w, radius, pad]
	if not _box_cache.has(key):
		_box_cache[key] = box(bg, border, border_w, radius, pad)
	return _box_cache[key]


## Animação padrão de entrada de popup: cresce de 88% com leve "mola".
static func pop_in(node: Control, seconds: float = 0.2) -> void:
	node.scale = Vector2(0.88, 0.88)
	var center := func(): node.pivot_offset = node.size / 2.0
	node.resized.connect(center)
	center.call()
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2.ONE, seconds).set_trans(Tween.TRANS_BACK)


## Fundo opaco com borda suave (translúcida + sombra difusa), sem brilho.
static func soft_box(bg: Color, edge: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(3)
	sb.border_color = Color(edge, 0.75)
	sb.shadow_color = Color(edge, 0.5)
	sb.shadow_size = 6
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	return sb


## Véu translúcido pra estados hover/pressed de botões sem fundo.
static func tint_box(alpha: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, alpha)
	return sb


static func button(text: String, accent: Color = ACTION, size: int = 30) -> Button:
	size = maxi(size, MIN_BUTTON_FONT)
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_PASS  # não engole o arrasto de quem quer rolar a lista
	b.custom_minimum_size = Vector2(0, 84)
	b.add_theme_font_size_override("font_size", size)
	var face0 := accent if accent != MUTED else BUTTON_MUTED
	var fg := text_on(face0)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_color_override("font_disabled_color", MUTED)
	b.add_theme_constant_override("outline_size", 5 if fg == INK else 0)
	b.add_theme_color_override("font_outline_color", accent.darkened(0.6))
	var face := face0
	b.add_theme_stylebox_override("normal", chunky(face))
	b.add_theme_stylebox_override("hover", chunky(face.lightened(0.12)))
	b.add_theme_stylebox_override("pressed", chunky(face.darkened(0.08), true))
	b.add_theme_stylebox_override("focus", chunky(face.lightened(0.12)))
	b.add_theme_stylebox_override("disabled", chunky(Color("#3A3570")))
	b.pressed.connect(func(): sfx("tick"))
	# Feedback de toque: o botão "afunda" um pouco ao apertar.
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	b.button_down.connect(func():
		if b.disabled:
			return
		b.create_tween().tween_property(b, "scale", Vector2(0.97, 0.97), 0.06))
	b.button_up.connect(func(): b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK))
	return b


## Botão de ícone quadrado (68 px, acima do mínimo de toque de 56).
static func icon_button(text: String, color: Color = BUTTON_MUTED) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.custom_minimum_size = Vector2(68, 68)
	b.add_theme_font_size_override("font_size", 32)
	for cn in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(cn, text_on(color))
	var n := chunky(color)
	n.set_corner_radius_all(22)
	n.set_border_width_all(3)
	n.border_width_bottom = 8
	n.content_margin_left = 6
	n.content_margin_right = 6
	n.content_margin_top = 6
	n.content_margin_bottom = 12
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = color.lightened(0.12)
	var pr := chunky(color, true)
	pr.set_corner_radius_all(22)
	pr.border_width_bottom = 3
	pr.content_margin_left = 6
	pr.content_margin_right = 6
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", pr)
	b.pressed.connect(func(): sfx("tick"))
	return b


## Botão de navegação (barra inferior): o central é um botão 3D em destaque, os outros são planos.
static func nav_button(icon: String, center: bool, face: Color = DANGER) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.text = icon
	btn.custom_minimum_size = Vector2(96 if center else 72, 84 if center else 64)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 44 if center else 34)
	for cn in ["font_color", "font_hover_color", "font_pressed_color"]:
		btn.add_theme_color_override(cn, INK)
	if center:
		btn.add_theme_stylebox_override("normal", chunky(face))
		btn.add_theme_stylebox_override("hover", chunky(face.lightened(0.1)))
		btn.add_theme_stylebox_override("pressed", chunky(face, true))
	else:
		var flat := StyleBoxFlat.new()
		flat.bg_color = CLEAR
		for st in ["normal", "hover", "pressed"]:
			btn.add_theme_stylebox_override(st, flat)
	btn.pressed.connect(func(): sfx("tick"))
	return btn


## Bolinha redonda (progresso, escada de ligas): cheia (cor) ou vazia (só contorno).
static func dot_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(radius)
	return sb


## Barra de meta (preenchimento e trilho com contorno escuro).
static func bar_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = OUTLINE
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(16)
	return sb


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


static func panel(bg: Color = PURPLE_DEEP, border: Color = BLACK, pad: int = 32) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, border, 3, 4, pad))
	return p


## Painel que reage a toque (ex.: card de jogador que expande detalhe) sem trocar de
## nó — PanelContainer se auto-dimensiona certinho ao redor do conteúdo (Button não faz
## isso com filhos arbitrários, então nunca use Button só pra "ser clicável").
## Conecte o retorno de `on_tap` pra tratar o toque (recebe o próprio painel).
static func tap_panel(bg: Color = PURPLE_DEEP, border: Color = MUTED, pad: int = 10, on_tap: Callable = Callable()) -> PanelContainer:
	var p := panel(bg, border, pad)
	p.mouse_filter = Control.MOUSE_FILTER_PASS  # não engole o arrasto de quem quer rolar a lista
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
	o.add_to_group("touch_blocker")
	return o


## Toda janela de popup usa essas margens/limites (nunca 0 de margem, nunca mais que o teto de
## altura): sem eles o popup encosta na borda física da tela — onde ficam a barra de endereço do
## navegador, o notch ou a barra de gestos, ou simplesmente ocupa a tela toda num celular alto —
## e isso é o que deixava o topo (nome editável) inacessível e o rodapé (botão de fechar) cortado.
const POPUP_MARGIN_SIDE := 16.0
## Teto de altura: NENHUM popup passa disso, em fração da tela. Anchors (não pixels), então vale
## pra qualquer tamanho de tela sem precisar consultar o viewport.
const POPUP_MAX_HEIGHT_FRAC := 0.75

## Centraliza um popup na tela, sem nunca passar de `POPUP_MAX_HEIGHT_FRAC` da altura da tela —
## sobra sempre pelo menos (1 - fração)/2 de folga em cima e embaixo, então nunca encosta na
## borda física (notch, barra de gestos, chrome do navegador). Rola quando o conteúdo passa desse
## teto — NUNCA deixa o popup vazar pra fora da tela sem rolagem — e, em retrato, amplia os
## textos e botões do popup (BOOST) — no celular 720 px virtuais viram ~390 pt e o tamanho de
## desktop fica pequeno.
static func centered(child: Control) -> Control:
	var scroll := ScrollContainer.new()
	var side_frac := 0.5 * (1.0 - POPUP_MAX_HEIGHT_FRAC)
	scroll.anchor_left = 0.0
	scroll.anchor_right = 1.0
	scroll.anchor_top = side_frac
	scroll.anchor_bottom = 1.0 - side_frac
	scroll.offset_left = POPUP_MARGIN_SIDE
	scroll.offset_right = -POPUP_MARGIN_SIDE
	scroll.offset_top = 0.0
	scroll.offset_bottom = 0.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var c := CenterContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.add_child(child)
	scroll.add_child(c)
	boost_later(child)
	suppress_click_on_scroll(scroll)
	return scroll


## Registra a lista no TouchGuard (autoload): toque x arrasto tratados globalmente — rolar
## começando (ou terminando) sobre botão, campo de texto ou dropdown nunca os aciona; só um toque
## rápido interage. Toda ScrollContainer feita à mão deve chamar isto (as de `centered()` já vêm).
static func suppress_click_on_scroll(scroll: ScrollContainer) -> void:
	scroll.add_to_group("touch_scroll")


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
	node.ready.connect(func(): fit.call_deferred(node), CONNECT_ONE_SHOT)


## Garante que um popup nunca passe da largura da tela (celular): reduz larguras mínimas
## fixas e faz botões e textos longos quebrarem linha. O que passar da altura rola.
static func fit(node: Node) -> void:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree() or not node is Control:
		return
	var vw := node.get_viewport().get_visible_rect().size.x
	var root := node as Control
	var avail := vw - 32.0
	_fit_rec(root, avail - 64.0, false)
	if root.custom_minimum_size.x > avail or root.custom_minimum_size.x == 0.0:
		root.custom_minimum_size.x = minf(maxf(root.custom_minimum_size.x, 560.0), avail)
	root.reset_size()


static func _fit_rec(n: Node, max_inner: float, in_row: bool) -> void:
	if n is Control:
		var c := n as Control
		if c.custom_minimum_size.x > max_inner:
			c.custom_minimum_size.x = max_inner
		if n is Button:
			(n as Button).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			(n as Button).clip_text = false
		elif n is Label and not in_row:
			var l := n as Label
			if l.autowrap_mode == TextServer.AUTOWRAP_OFF and l.text.length() > 18:
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				if l.custom_minimum_size.x == 0.0:
					l.custom_minimum_size.x = minf(max_inner, 200.0)
	var row := n is HBoxContainer or n is GridContainer
	for ch in n.get_children():
		_fit_rec(ch, max_inner, row)


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
	ov.add_child(centered(box_p))
	boost.call_deferred(box_p)
	fit.call_deferred(box_p)
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


## Tema global aplicado à raiz (GameState): todo controle criado fora do UIKit (menus de
## opção, caixas de seleção, campos de texto, barras de rolagem, sliders) já sai no padrão.
static func build_theme() -> Theme:
	var t := Theme.new()
	t.set_color("font_color", "Label", INK)
	# Botões.
	var face := BUTTON_MUTED
	for cls in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", cls, chunky(face))
		t.set_stylebox("hover", cls, chunky(face.lightened(0.12)))
		t.set_stylebox("pressed", cls, chunky(face.darkened(0.08), true))
		t.set_stylebox("focus", cls, chunky(face.lightened(0.12)))
		t.set_stylebox("disabled", cls, chunky(Color("#3A3570")))
		for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			t.set_color(cn, cls, INK)
		t.set_color("font_disabled_color", cls, MUTED)
		t.set_font_size("font_size", cls, MIN_BUTTON_FONT)
	# Caixa de seleção / interruptor.
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(cn, "CheckButton", INK)
		t.set_color(cn, "CheckBox", INK)
	t.set_font_size("font_size", "CheckButton", MIN_FONT)
	t.set_font_size("font_size", "CheckBox", MIN_FONT)
	# Campo de texto.
	var le := box(SURFACE_DEEP, MUTED, 3, 22, 14)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", box(SURFACE_DEEP, GOLD, 3, 22, 14))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_font_size("font_size", "LineEdit", MIN_FONT)
	# Menu suspenso.
	var pm := box(PURPLE_DEEP, GOLD, 3, 16, 8)
	t.set_stylebox("panel", "PopupMenu", pm)
	t.set_stylebox("hover", "PopupMenu", box(PURPLE, GOLD, 2, 10, 6))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_font_size("font_size", "PopupMenu", MIN_FONT)
	# Slider e barras.
	var track := StyleBoxFlat.new()
	track.bg_color = OUTLINE
	track.set_corner_radius_all(8)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", track)
	var grab := StyleBoxFlat.new()
	grab.bg_color = ACTION
	grab.set_corner_radius_all(8)
	t.set_stylebox("grabber_area", "HSlider", grab)
	t.set_stylebox("grabber_area_highlight", "HSlider", grab)
	var sbg := StyleBoxFlat.new()
	sbg.bg_color = Color(0, 0, 0, 0.25)
	sbg.set_corner_radius_all(6)
	var sgr := StyleBoxFlat.new()
	sgr.bg_color = MUTED
	sgr.set_corner_radius_all(6)
	for cls in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", cls, sbg)
		t.set_stylebox("grabber", cls, sgr)
		t.set_stylebox("grabber_highlight", cls, sgr)
		t.set_stylebox("grabber_pressed", cls, sgr)
	return t
