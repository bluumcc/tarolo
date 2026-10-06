class_name SidePanel
extends Control
## Painel lateral deslizante (menu à esquerda, ajuda à direita): entra deslizando com o fundo
## escurecendo, fecha pelo X, tocando fora ou com um swipe pro lado de onde veio — sempre com
## animação de saída. Quem usa preenche `body` e escuta `closed`.

signal closed

const WIDTH := 520.0
const SWIPE_MIN := 90.0

var body: VBoxContainer
var _from_right := true
var _panel: PanelContainer
var _dim: ColorRect
var _closing := false
var _press := Vector2.ZERO
var _pressing := false


static func open(layer: Control, title: String, from_right: bool) -> SidePanel:
	var sp := SidePanel.new()
	sp._build(title, from_right)
	layer.add_child(sp)
	sp._slide_in.call_deferred()
	return sp


func _build(title: String, from_right: bool) -> void:
	_from_right = from_right
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.color = Color(UIKit.TR_BLACK, 0.0)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			close())
	_panel = PanelContainer.new()
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	_panel.anchor_left = 1.0 if from_right else 0.0
	_panel.anchor_right = 1.0 if from_right else 0.0
	_panel.offset_top = 16.0
	_panel.offset_bottom = -16.0
	_panel.add_theme_stylebox_override("panel", UIKit.rim_box(UIKit.TR_PURPLE_DARK.darkened(0.15), UIKit.TR_PURPLE_LIGHT.lightened(0.2), UIKit.TR_PURPLE, "large", 18, 20, 20))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	_set_x(_offscreen_x())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	_panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UIKit.serif_label(title, 30, UIKit.TR_GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var x := Widgets.icon_button("✕")
	x.custom_minimum_size = Vector2(64, 64)
	var sb := UIKit.box_cached(UIKit.TR_PURPLE_DARK.darkened(0.3), UIKit.TR_PURPLE_LIGHT, 2, 14, UIKit.card_pad())
	for sn in ["normal", "hover", "pressed", "focus"]:
		x.add_theme_stylebox_override(sn, sb)
	x.add_theme_color_override("font_color", UIKit.TR_WHITE)
	x.pressed.connect(close)
	head.add_child(x)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)


func _panel_w() -> float:
	return minf(WIDTH, get_viewport_rect().size.x - 80.0) if is_inside_tree() else WIDTH


func _offscreen_x() -> float:
	return 0.0 if _from_right else -_panel_w() - 40.0   # posição do canto esquerdo relativa à âncora


func _onscreen_x() -> float:
	return -_panel_w() - 16.0 if _from_right else 16.0


## Posiciona o painel (largura fixa) com o canto esquerdo em `x` relativo à âncora.
func _set_x(x: float) -> void:
	_panel.offset_left = x
	_panel.offset_right = x + _panel_w()


func _slide_in() -> void:
	if _from_right:
		_set_x(40.0)   # começa fora da tela, à direita
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_x, _panel.offset_left, _onscreen_x(), GameState.anim(0.25))
	tw.tween_property(_dim, "color:a", 0.6, GameState.anim(0.25))


func close() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_method(_set_x, _panel.offset_left, 40.0 if _from_right else -_panel_w() - 40.0, GameState.anim(0.2))
	tw.tween_property(_dim, "color:a", 0.0, GameState.anim(0.2))
	tw.chain().tween_callback(func():
		closed.emit()
		queue_free())


## Swipe pro lado de onde o painel veio fecha (lido antes dos botões, sem consumir o toque).
func _input(event: InputEvent) -> void:
	if _closing:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_pressing = _panel.get_global_rect().has_point(mb.global_position)
			_press = mb.global_position
		elif _pressing:
			_pressing = false
			var d := mb.global_position - _press
			var toward := d.x if _from_right else -d.x
			if toward >= SWIPE_MIN and absf(d.x) > absf(d.y) * 1.5:
				close()
