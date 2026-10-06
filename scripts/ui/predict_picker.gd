class_name PredictPicker
extends PanelContainer
## Card do palpite: − / + com o número de jogadas, a sugestão da mão, o peso no pote e o botão
## CONFIRMAR. Montado uma vez; os toques só atualizam textos e estados (nada é recriado).

signal confirmed(pick: int)

const HEIGHT := 298.0
const MAX_WIDTH := 640.0

var pick := 0
var _hint := 0
var _max := 0
var _weight_of: Callable
var _minus: Button
var _plus: Button
var _count: Label
var _hint_label: Label
var _weight_label: Label
var _confirm: Button


## `weight_of(pick) -> float` dá o peso no pote daquele palpite.
func setup(hint: int, max_pick: int, weight_of: Callable, width: float) -> PredictPicker:
	_hint = hint
	pick = hint
	_max = max_pick
	_weight_of = weight_of
	add_theme_stylebox_override("panel", UIKit.rim_box(UIKit.TR_PURPLE_DARK.darkened(0.3), UIKit.TR_PURPLE_LIGHT.lightened(0.2), UIKit.TR_PURPLE, "small", 18, 20, 16))
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	custom_minimum_size = Vector2(minf(width, MAX_WIDTH), HEIGHT)
	var body := VBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 14)
	add_child(body)
	var stepper := HBoxContainer.new()
	stepper.alignment = BoxContainer.ALIGNMENT_CENTER
	stepper.add_theme_constant_override("separation", 20)
	body.add_child(stepper)
	_minus = _step_button("−", -1)
	stepper.add_child(_minus)
	_count = UIKit.serif_label("", 60, UIKit.TR_WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_count.custom_minimum_size = Vector2(110, 0)
	stepper.add_child(_count)
	_plus = _step_button("+", 1)
	stepper.add_child(_plus)
	_hint_label = UIKit.serif_label("", 20, UIKit.muted_lilac(), HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(_hint_label)
	_weight_label = UIKit.serif_label("", 18, UIKit.muted_lilac(), HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(_weight_label)
	_confirm = UIKit.action_button("", UIKit.ActionKind.OK, 28)
	_confirm.custom_minimum_size = Vector2(0, 68)
	_confirm.pressed.connect(func(): confirmed.emit(pick))
	body.add_child(_confirm)
	_refresh()
	return self


func _step_button(text: String, delta: int) -> Button:
	var b := UIKit.action_button(text, UIKit.ActionKind.GOLD, 36)
	b.custom_minimum_size = Vector2(64, 64)
	b.pressed.connect(func():
		pick = clampi(pick + delta, 0, _max)
		_refresh())
	return b


func _refresh() -> void:
	_minus.disabled = pick <= 0
	_plus.disabled = pick >= _max
	_count.text = str(pick)
	var is_hint := pick == _hint
	_hint_label.text = "★ RECOMENDADO PELA SUA MÃO" if is_hint else "Recomendado pela sua mão: %d" % _hint
	_hint_label.add_theme_color_override("font_color", UIKit.TR_CYAN if is_hint else UIKit.muted_lilac())
	_weight_label.text = "Peso no pote ×%s" % UIKit.fmt_dec(float(_weight_of.call(pick)), 1)
	_confirm.text = "CONFIRMAR: %d %s" % [pick, "JOGADA" if pick == 1 else "JOGADAS"]
