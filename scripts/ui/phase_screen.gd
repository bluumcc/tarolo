class_name PhaseScreen
extends VBoxContainer
## Cabeçalho das etapas sem mesa (descarte, palpite): título, subtítulo e o seu avatar grande com o
## anel do relógio, mais um espaço (`content`) pro que a etapa precisar embaixo.
## Vive numa camada ACIMA da mão e da mesa (o dono cria a camada): tudo aqui ignora o toque, menos o
## que entra em `content` (ex.: o seletor do palpite), que assim nunca fica sob as cartas.
## Todas as etapas compartilham `TOP_GAP` e `TITLE_H`: o título e o que vem depois começam sempre
## na mesma altura.

const TOP_GAP := 84.0          ## folga entre o fim do header e o título (única, vale pra todas as etapas)
const TITLE_H := 177.0         ## faixa do título: 3 linhas a 46 px
const AVATAR_SCALE := 1.95
const HOLDER_H := 212.0

var title: Label
var subtitle: Label
var avatar: HexAvatar
var name_label: Label
var content: VBoxContainer
var _holder: Control


func _init() -> void:
	anchor_right = 1.0
	offset_left = 8.0
	offset_right = -8.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	add_theme_constant_override("separation", 8)
	title = UIKit.serif_label("", 46, UIKit.TR_GOLD.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_constant_override("line_spacing", 6)
	title.custom_minimum_size.y = TITLE_H
	title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_child(title)
	subtitle = UIKit.serif_label("", 26, UIKit.muted_lilac(), HORIZONTAL_ALIGNMENT_CENTER)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(subtitle)
	_holder = Control.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)
	avatar = HexAvatar.new().setup(0)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.set_active(true)
	avatar.wins_badge.visible = false
	avatar.set_anchors_preset(Control.PRESET_CENTER)
	avatar.offset_left = -HexAvatar.SIZE_PX.x / 2.0
	avatar.offset_right = HexAvatar.SIZE_PX.x / 2.0
	avatar.offset_top = -HexAvatar.SIZE_PX.y / 2.0
	avatar.offset_bottom = HexAvatar.SIZE_PX.y / 2.0
	_holder.add_child(avatar)
	name_label = UIKit.serif_label("", 34, UIKit.TR_WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(name_label)
	content = VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)


## Posiciona abaixo do header: `header_bottom` é o y (na camada) onde o palco começa.
func place(header_bottom: float) -> void:
	offset_top = header_bottom + TOP_GAP


## Abre a etapa. `player_name` vazio esconde o nome (a etapa precisa do espaço).
func present(p_title: String, p_subtitle: String, p_name := "", avatar_scale := AVATAR_SCALE, holder_h := HOLDER_H) -> void:
	title.text = p_title
	subtitle.text = p_subtitle
	name_label.text = p_name
	name_label.visible = p_name != ""
	_holder.custom_minimum_size.y = holder_h
	avatar.scale = Vector2(avatar_scale, avatar_scale)
	avatar.set_timer(-1.0)
	visible = true


func dismiss() -> void:
	visible = false
	clear_content()


func clear_content() -> void:
	for c in content.get_children():
		c.queue_free()


## Anel do relógio no avatar grande (1 → 0; −1 apaga).
func set_timer(fraction: float) -> void:
	avatar.set_timer(fraction)
