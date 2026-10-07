class_name CardView
extends Control
## Carta reutilizável (Card.tscn). A raiz ocupa o espaço no container; o "Body" é o visual
## que se move (hover, arrasto), sem brigar com o layout do HBoxContainer.

signal tapped(view: CardView)
signal zoom_requested(view: CardView)

## Proporção da arte (PNGs 540x900). O tamanho da carta SEMPRE deriva dela: nunca esticar nem cortar.
const ART_ASPECT := 540.0 / 900.0
## Tamanho base da carta (escala 1.0): largura 188, altura pela proporção da arte (188x313).
const SIZE := Vector2(188.0, 188.0 / ART_ASPECT)
const TABLE_H_MOBILE := 218.5   ## altura da carta jogada na mesa (celular)
const TABLE_H_WIDE := 190.0     ## idem em tela larga (PC)
const HAND_SCALE_MOBILE := 1.1   ## carta da mão no celular (+10% sobre o tamanho base)
const HAND_H_WIDE := 320.0      ## altura máxima da carta na mão em tela larga
const FOCUS_H_WIDE := 410.0     ## altura da carta destacada (arrastada no swipe) em tela larga
const FOCUS_MOBILE := 1.15      ## carta arrastada no celular = mão +15%
const MAX_LIFT := 44.0  ## até onde a carta sobe visualmente ao selecionar/passar o mouse
const LONG_PRESS := 0.45


## Escala da carta na mão: 1.0 no celular; em tela larga, altura-alvo limitada a 25% da viewport
## (a zona da mão tem que caber junto com a barra de baixo).
static func hand_scale(wide: bool, vp_h: float) -> float:
	if not wide:
		return HAND_SCALE_MOBILE
	return minf(HAND_H_WIDE, vp_h * 0.25) / SIZE.y


## Escala da carta destacada (a que acompanha o dedo no swipe).
static func focus_scale(wide: bool, vp_h: float) -> float:
	if not wide:
		return FOCUS_MOBILE
	return minf(FOCUS_H_WIDE, vp_h * 0.34) / SIZE.y


## Escala da carta jogada na mesa (altura fixa, independente do modo).
static func table_scale(wide: bool) -> float:
	return (TABLE_H_WIDE if wide else TABLE_H_MOBILE) / SIZE.y

signal hover_changed(view: CardView, on: bool)

var data: CardData
var face_up := true
var playable := false
var selected := false
var interactive := true
var hover_zoom := false   ## desktop (mão): o mouse em cima mostra a carta ampliada (a cena desenha)
var _hovered := false
## Desktop: a arte original (540×900) encolhe ~2×; o filtro em tempo real (bilinear + mipmap) ou borra ou
## serrilha. Então o desktop usa `assets/cards_md/` (360×600, reduzida offline com Lanczos), exibida quase 1:1.
var _use_md := false
var zoom_enabled := true   ## segurar / botão direito abre o zoom (a mesa Blitz desliga)

var _pressing := false
var _press_pos := Vector2.ZERO
var _press_time := 0.0
var _moved := false
var _long_fired := false
var _lift_tween: Tween
var _card_tex: TextureRect  ## textura custom (assets/cards/); null = sem imagem carregada

@onready var body: PanelContainer = $Body
@onready var rank_label: Label = $Body/Margin/VBox/Top/Rank
@onready var suit_small: Label = $Body/Margin/VBox/Top/Suit
@onready var center_label: Label = $Body/Margin/VBox/Center
@onready var name_label: Label = $Body/Margin/VBox/Name
@onready var points_label: Label = $Body/Margin/VBox/Bottom/Points
@onready var bout_label: Label = $Body/Margin/VBox/Bottom/Bout


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = SIZE / 2.0
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.pivot_offset = SIZE / 2.0
	for n in [rank_label, suit_small, center_label, name_label, points_label, bout_label]:
		(n as Label).mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	_card_tex = TextureRect.new()
	_card_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  ## NUNCA KEEP_SIZE: o PNG (540x900) inflaria a carta
	_card_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_card_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS   # a arte (540×900) encolhe até 5×: sem mipmap fica chiada
	_card_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_tex.clip_contents = true
	_card_tex.visible = false
	var vp := get_viewport_rect().size
	_use_md = vp.x > vp.y   # desktop: versões pré-reduzidas com Lanczos (nítidas e sem serrilhado)
	body.add_child(_card_tex)
	body.move_child(_card_tex, 0)
	_refresh()


func setup(card: CardData, p_face_up: bool = true) -> CardView:
	data = card
	face_up = p_face_up
	if is_node_ready():
		_refresh()
	return self


func set_playable(value: bool) -> void:
	playable = value
	if not value:
		set_selected(false)
	modulate = Color(1, 1, 1, 1) if value or not interactive else Color(0.55, 0.52, 0.62, 1)


func _on_hover(on: bool) -> void:
	if not hover_zoom or not interactive or _hovered == on:
		return
	_hovered = on
	hover_changed.emit(self, on)   # quem desenha a ampliação é a cena (camada acima de tudo, sem mexer nesta carta)


func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	body.z_index = 50 if value else 0   # a carta focada fica acima das vizinhas do leque
	_lift(-32.0 if value else 0.0)
	_refresh_border()


func _refresh() -> void:
	if data == null:
		return
	if not face_up:
		var back_id := str(SaveManager.section("cosmetics")["equipped"])
		var back_def: Dictionary = UIKit.CARD_BACKS.get(back_id, UIKit.CARD_BACKS["noite"])
		var cover_name: String = back_def.get("cover", "")
		var cover_tex: Texture2D = null
		if cover_name != "":
			var path := _art_dir() + "%s.png" % cover_name
			if ResourceLoader.exists(path):
				cover_tex = load(path) as Texture2D
		if cover_tex != null:
			_card_tex.texture = cover_tex
			_card_tex.visible = true
			body.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0), UIKit.BRAND.darkened(0.35), 3, 6, 6))
		else:
			_card_tex.visible = false
			var back_col := Color(back_def["color"])
			body.add_theme_stylebox_override("panel", UIKit.box(back_col, UIKit.BRAND.darkened(0.35), 3, 6, 6))
		rank_label.visible = false
		suit_small.visible = false
		center_label.visible = cover_tex == null
		if cover_tex == null:
			center_label.text = "✶"
			center_label.add_theme_color_override("font_color", UIKit.BRAND)
		name_label.visible = false
		points_label.text = ""
		bout_label.text = ""
		return
	_refresh_border()
	var has_art := _load_card_texture()
	_card_tex.visible = has_art
	# Quando há arte, esconde os labels de texto (rank/naipe/centro).
	# Mantém points e bout visíveis mesmo com arte para info rápida.
	rank_label.visible = not has_art
	suit_small.visible = not has_art
	center_label.visible = not has_art
	name_label.visible = not has_art
	if has_art:
		points_label.text = ""
		bout_label.text = ""
		return
	var color := _ink_color()
	rank_label.text = data.rank_label()
	rank_label.add_theme_color_override("font_color", color)
	suit_small.text = data.suit_symbol()
	suit_small.add_theme_color_override("font_color", color)
	center_label.text = data.suit_symbol()
	center_label.add_theme_color_override("font_color", color)
	name_label.text = data.display_name() if (data.is_louco() or (data.is_trunfo() and data.is_bout())) else ""
	points_label.text = "%s pts" % UIKit.fmt_dec(data.points(), 1)
	points_label.add_theme_color_override("font_color", UIKit.MUTED if _dark_face() else Color("#5B5670"))
	bout_label.text = "BOUT" if data.is_bout() else ""
	bout_label.add_theme_color_override("font_color", UIKit.BRAND if _dark_face() else Color("#B8860B"))


## Caminho do PNG customizado para esta carta (convenção: assets/cards/).
## Maiores: 0.png (Louco), 1–21.png (Trunfos).
## Menores: o/p/c/e + rank. Ex.: e2.png, c9.png, o12.png.
func _art_dir() -> String:
	return "res://assets/cards_md/" if _use_md else "res://assets/cards/"


func _asset_path() -> String:
	if data.is_louco():
		return _art_dir() + "0.png"
	if data.is_trunfo():
		return _art_dir() + "%d.png" % data.rank
	const PREFIXES := ["o", "p", "c", "e"]
	return _art_dir() + "%s%d.png" % [PREFIXES[data.suit], data.rank]


func _load_card_texture() -> bool:
	var path := _asset_path()
	if not ResourceLoader.exists(path):
		return false
	_card_tex.texture = load(path) as Texture2D
	return _card_tex.texture != null


## Trunfos e O Louco têm a face escura roxa; as demais cartas são brancas com tinta
## vermelha (Ouros, Copas) ou preta (Paus, Espadas).
func _dark_face() -> bool:
	return data.is_trunfo() or data.is_louco()


func _ink_color() -> Color:
	if data.is_trunfo():
		return UIKit.SUIT_COLORS[CardData.Suit.TRUNFO]
	if data.is_louco():
		return UIKit.SUIT_COLORS[CardData.Suit.LOUCO]
	if data.suit == CardData.Suit.OUROS or data.suit == CardData.Suit.COPAS:
		return Color("#D42A3C")
	return Color("#14121F")


func _refresh_border() -> void:
	if data == null or not face_up:
		return
	var border := Color("#B9B4D6")
	var bg := Color("#FAF8FF")
	if data.is_louco():
		border = UIKit.SUIT_COLORS[CardData.Suit.LOUCO]
		bg = Color("#241a33")
	elif data.is_trunfo():
		border = Color("#2A1E50")  ## neutro escuro — borda roxa sumiria com a arte
		bg = Color("#221436")
	if data.is_bout():
		border = UIKit.BRAND if _dark_face() else Color("#D9A21B")
	if selected:
		border = UIKit.BRAND
	var sb := UIKit.box(bg, border, 4 if selected else 2, 6, 6)
	sb.set_corner_radius_all(14)
	body.add_theme_stylebox_override("panel", sb)


# ------------------------------------------------------------------ input
#
# Jogar é sempre por toque: toca pra selecionar (a carta sobe), toca de novo pra jogar.
# Não tem efeito ao passar o dedo/mouse: no celular ele grudava e a carta ficava meio
# levantada sem fazer nada. Não existe mais arrastar a carta pra jogar — isso competia com o
# gesto de arrastar a mão inteira pra rolar (o toque na carta "comia" o arrasto antes
# dele chegar ao ScrollContainer, e a rolagem nunca disparava de verdade). Aqui só
# medimos se o dedo/mouse SE MOVEU (`_moved`) pra distinguir toque de "só passando",
# sem tentar interpretar a direção do arrasto — quem faz isso agora é o próprio
# ScrollContainer, que recebe o mesmo evento (mouse_filter = PASS no Card.tscn).

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if zoom_enabled:
				zoom_requested.emit(self)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressing = true
				_moved = false
				_long_fired = false
				_press_pos = mb.global_position
				_press_time = 0.0
			else:
				_release()
			accept_event()
	elif event is InputEventMouseMotion and _pressing:
		var delta: Vector2 = (event as InputEventMouseMotion).global_position - _press_pos
		if delta.length() > 14.0:
			_moved = true


func is_pressing() -> bool:
	return _pressing


## Chamado pela rolagem da mão quando o arrasto começa: esse toque vira rolagem, não jogada.
func cancel_press() -> void:
	_pressing = false
	_moved = true


func _release() -> void:
	if not _pressing:
		return
	_pressing = false
	if not _long_fired and not _moved:
		tapped.emit(self)
	_moved = false


func _process(delta: float) -> void:
	if zoom_enabled and _pressing and not _moved and not _long_fired:
		_press_time += delta
		if _press_time >= LONG_PRESS:
			_long_fired = true
			zoom_requested.emit(self)


func _lift(y: float) -> void:
	if _lift_tween:
		_lift_tween.kill()
	_lift_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_lift_tween.tween_property(body, "position", Vector2(0, y), GameState.anim(0.15))
	_lift_tween.parallel().tween_property(body, "rotation", 0.0, GameState.anim(0.15))


## Texto descritivo para o zoom de carta.
func describe() -> String:
	if data == null:
		return ""
	var lines: Array = [data.display_name()]
	lines.append("%s pontos" % UIKit.fmt_dec(data.points(), 1))
	if data.is_bout():
		lines.append("Bout — uma das 3 cartas mais valiosas do jogo.")
	elif data.is_trunfo():
		lines.append("Trunfo — sempre vence carta de naipe comum.")
	return "\n".join(lines)
