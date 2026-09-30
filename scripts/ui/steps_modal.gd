class_name StepsModal
extends Control
## Popup em passos (ajuda e tutorial): ícone, título e um parágrafo por passo, pontos de
## progresso e VOLTAR / PRÓXIMO. Texto longo rola dentro do passo. Componente reutilizável:
##   var m := StepsModal.open(host, "COMO JOGAR", HelpContent.vanilla())
##   await m.closed
## Cada passo: {icon, title, text, color (opcional)}.

signal closed

var kicker := ""
var steps: Array = []
var done_text := "ENTENDI"
var allow_skip := true
var index := 0

var _icon: Label
var _title: Label
var _text: Label
var _dots: HBoxContainer
var _back: Button
var _next: Button
var _skip: Button
var _scroll: ScrollContainer
var _kicker_l: Label


static func open(host: Control, kicker_text: String, steps_data: Array, done := "ENTENDI", skip := true) -> StepsModal:
	var m := StepsModal.new()
	m.kicker = kicker_text
	m.steps = steps_data
	m.done_text = done
	m.allow_skip = skip
	host.add_child(m)
	return m


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var ov := UIKit.overlay()
	add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.GOLD, 24)
	var vw := get_viewport_rect().size.x
	box.custom_minimum_size = Vector2(minf(vw - 40.0, 640.0), 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	_kicker_l = UIKit.label("", 24, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_kicker_l)
	_icon = UIKit.label("", 64, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_icon)
	_title = UIKit.label("", 40, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_title)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(0, clampf(get_viewport_rect().size.y * 0.32, 240.0, 460.0))
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text = UIKit.label("", 28, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_text)
	v.add_child(_scroll)
	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 10)
	v.add_child(_dots)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	_back = UIKit.button("VOLTAR", UIKit.MUTED)
	_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back.pressed.connect(func(): _go(index - 1))
	row.add_child(_back)
	_next = UIKit.button("PRÓXIMO", UIKit.ACTION)
	_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next.pressed.connect(func(): _go(index + 1))
	row.add_child(_next)
	_skip = UIKit.button("PULAR", UIKit.MUTED, 26)
	_skip.custom_minimum_size = Vector2(0, 64)
	_skip.pressed.connect(close)
	v.add_child(_skip)
	ov.add_child(UIKit.centered(box))
	UIKit.pop_in(box, GameState.anim(0.2))
	_render()
	_next.grab_focus.call_deferred()


func _go(i: int) -> void:
	if i >= steps.size():
		close()
		return
	index = clampi(i, 0, steps.size() - 1)
	Sfx.play("tick")
	_render()


func _render() -> void:
	var st: Dictionary = steps[index]
	var col: Color = st.get("color", UIKit.GOLD)
	_kicker_l.text = "%s  ·  %d/%d" % [kicker, index + 1, steps.size()]
	_icon.text = str(st.get("icon", ""))
	_icon.add_theme_color_override("font_color", col)
	_title.text = str(st["title"])
	_title.add_theme_color_override("font_color", col)
	_text.text = str(st["text"])
	_scroll.scroll_vertical = 0
	for c in _dots.get_children():
		c.queue_free()
	for k in range(steps.size()):
		_dots.add_child(UIKit.label("●" if k == index else "○", 28, col if k == index else UIKit.MUTED))
	var last := index == steps.size() - 1
	_next.text = done_text if last else "PRÓXIMO"
	_back.visible = index > 0
	_skip.visible = allow_skip and not last
	FX.pop(_title, 1.15)


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
