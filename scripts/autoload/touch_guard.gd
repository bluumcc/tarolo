extends Node
## Separa TOQUE de ARRASTO em toda lista rolável (grupo "touch_scroll", ver
## `UIKit.suppress_click_on_scroll`). O Godot sozinho não faz essa distinção: o botão/campo sob o
## dedo dispara ao soltar, mesmo depois de um arrasto, e LineEdit/OptionButton ainda engolem o gesto.
##
## Como funciona (intercepta em `_input`, ANTES da interface):
##  1. Pressionar dentro de uma lista: o evento é engolido — nenhum botão/campo/dropdown vê nada.
##  2. Mexeu além de DEADZONE px: vira ROLAGEM. Nós mesmos movemos `scroll_vertical` (com inércia)
##     e tudo até soltar continua engolido — soltar sobre um botão/campo não interage.
##  3. Soltou rápido e sem mexer: foi um TOQUE. Reenviamos um clique (pressionar + soltar) na
##     posição original, e só então o item reage.
##  4. Segurou além de TAP_MAX_SECS sem mexer: não é toque nem rolagem — nada acontece.
## Sliders/barras dentro da lista ficam de fora (precisam de arrasto de verdade).

const DEADZONE := 14.0
const TAP_MAX_SECS := 0.6
const FRICTION := 5.0
const MIN_COAST := 40.0
const GROUP := "touch_scroll"
const BLOCKER_GROUP := "touch_blocker"

var _scroll: ScrollContainer = null
var _start := Vector2.ZERO
var _start_scroll := 0.0
var _t0 := 0.0
var _dragging := false
var _replaying := false
var _swallow_release_until := 0
var _vel := 0.0
var _last_y := 0.0
var _last_t := 0.0
var _coast_scroll: ScrollContainer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _input(event: InputEvent) -> void:
	if _replaying:
		return
	var pos := Vector2.ZERO
	var kind := ""  # "down" | "move" | "up"
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		pos = mb.position
		kind = "down" if mb.pressed else "up"
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _scroll == null or not (mm.button_mask & MOUSE_BUTTON_MASK_LEFT):
			return
		pos = mm.position
		kind = "move"
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.index != 0:
			return
		pos = st.position
		kind = "down" if st.pressed else "up"
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index != 0 or _scroll == null:
			return
		pos = sd.position
		kind = "move"
	else:
		return

	match kind:
		"down":
			_flag_keyboard(pos)
			if _scroll != null:
				# Duplicata (toque + mouse emulado) do mesmo pressionar.
				get_viewport().set_input_as_handled()
				return
			var s := _find_scroll(pos)
			if s == null:
				return
			_coast_scroll = null
			_scroll = s
			_start = pos
			_start_scroll = float(s.scroll_vertical)
			_t0 = _now()
			_last_y = pos.y
			_last_t = _t0
			_vel = 0.0
			_dragging = false
			get_viewport().set_input_as_handled()
		"move":
			get_viewport().set_input_as_handled()
			if not is_instance_valid(_scroll):
				_reset()
				return
			if not _dragging and pos.distance_to(_start) > DEADZONE:
				_dragging = true
				# Começa a rolar a partir daqui (sem "pulo" do deadzone).
				_start = pos
				_start_scroll = float(_scroll.scroll_vertical)
				_last_y = pos.y
				_last_t = _now()
			if _dragging:
				_scroll.scroll_vertical = int(round(_start_scroll - (pos.y - _start.y)))
				var t := _now()
				var dt := maxf(t - _last_t, 0.001)
				if dt > 0.0:
					var v := -(pos.y - _last_y) / dt
					_vel = lerpf(_vel, v, 0.5)
				_last_y = pos.y
				_last_t = t
		"up":
			if _scroll == null:
				# Segunda metade (mouse emulado) de um gesto que acabou de terminar.
				if Time.get_ticks_msec() < _swallow_release_until:
					get_viewport().set_input_as_handled()
				return
			get_viewport().set_input_as_handled()
			_swallow_release_until = Time.get_ticks_msec() + 120
			var s2 := _scroll
			var was_drag := _dragging
			var held := _now() - _t0
			var start := _start
			if was_drag:
				var idle := _now() - _last_t
				if is_instance_valid(s2) and absf(_vel) > MIN_COAST and idle < 0.08:
					_coast_scroll = s2
			_reset()
			if not was_drag and held <= TAP_MAX_SECS and is_instance_valid(s2):
				_replay_tap(start)


func _reset() -> void:
	_scroll = null
	_dragging = false


func _process(delta: float) -> void:
	# Inércia depois de soltar o dedo.
	if _coast_scroll == null:
		return
	if not is_instance_valid(_coast_scroll) or absf(_vel) < MIN_COAST or _scroll != null:
		_coast_scroll = null
		return
	_coast_scroll.scroll_vertical = int(round(_coast_scroll.scroll_vertical + _vel * delta))
	_vel *= maxf(0.0, 1.0 - FRICTION * delta)


func _replay_tap(pos: Vector2) -> void:
	var vp := get_viewport()
	_replaying = true
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		vp.push_input(ev, true)
	_replaying = false


## A lista rolável mais "de cima" sob `pos` (nenhum overlay em cima dela, nenhum slider no ponto).
func _find_scroll(pos: Vector2) -> ScrollContainer:
	var best: ScrollContainer = null
	for n in get_tree().get_nodes_in_group(GROUP):
		var s := n as ScrollContainer
		if s == null or not s.is_visible_in_tree():
			continue
		if not s.get_global_rect().has_point(pos):
			continue
		if _blocked(s, pos):
			continue
		# A mais funda/última na árvore ganha (lista dentro de popup vence a da página).
		if best == null or s.is_greater_than(best) or best.is_ancestor_of(s):
			best = s
	if best != null and _over_range(best, pos):
		return null
	return best


func _blocked(s: Control, pos: Vector2) -> bool:
	for b in get_tree().get_nodes_in_group(BLOCKER_GROUP):
		var c := b as Control
		if c == null or not c.is_visible_in_tree() or c.is_ancestor_of(s):
			continue
		if c.is_greater_than(s) and c.get_global_rect().has_point(pos):
			return true
	return false


func _over_range(s: Control, pos: Vector2) -> bool:
	for n in s.find_children("*", "Range", true, false):
		var r := n as Range
		if (r is Slider or r is ScrollBar) and r.is_visible_in_tree() \
				and r.mouse_filter != Control.MOUSE_FILTER_IGNORE \
				and r.get_global_rect().grow(8.0).has_point(pos):
			return true
	return false


## Web/celular: avisa o JS (web_shell.html) que este toque começou sobre um campo de texto, pra ele
## abrir o teclado virtual dentro do gesto (o navegador exige).
func _flag_keyboard(pos: Vector2) -> void:
	if not OS.has_feature("web"):
		return
	var over := false
	for n in get_tree().root.find_children("*", "LineEdit", true, false):
		var le := n as LineEdit
		if le.is_visible_in_tree() and le.editable and le.get_global_rect().has_point(pos):
			over = true
			break
	JavaScriptBridge.eval("window.__vk=%s" % ("true" if over else "false"), true)
