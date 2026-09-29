extends Node
## Efeitos de "suco" (feedback em camadas, estilo Balatro/Brawl): pop de escala, contador que
## rola, tremor de tela e partículas. Tudo respeita GameState.anim() (reduzir movimento).


## Pulo de escala num Control — ganho de pontos, botão apertado, chip que mudou.
func pop(c: Control, strength: float = 1.25, secs: float = 0.28) -> void:
	if c == null or not c.is_inside_tree():
		return
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(strength, strength), GameState.anim(secs * 0.4)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, GameState.anim(secs * 0.6)).set_trans(Tween.TRANS_SINE)


## Número que rola de `from` até `to` (Label), no formato "1,5 pts" via `fmt`.
func count(label: Label, from: float, to: float, fmt: Callable, secs: float = 0.6) -> void:
	if label == null or not label.is_inside_tree():
		return
	var tw := label.create_tween()
	tw.tween_method(func(v: float): label.text = str(fmt.call(v)), from, to, GameState.anim(secs)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Tremor de tela proporcional à intensidade (0..1): treme o nó raiz passado.
func shake(target: Control, intensity: float = 0.5) -> void:
	if target == null or not target.is_inside_tree() or GameState.anim(1.0) <= 0.01:
		return
	var origin := target.position
	var amp := 6.0 + 18.0 * clampf(intensity, 0.0, 1.0)
	var tw := target.create_tween()
	for i in range(6):
		var k := 1.0 - float(i) / 6.0
		tw.tween_property(target, "position", origin + Vector2(randf_range(-amp, amp), randf_range(-amp, amp)) * k, 0.03)
	tw.tween_property(target, "position", origin, 0.03)


## Explosão de partículas (quadradinhos coloridos) num ponto do `layer`.
func burst(layer: Control, at: Vector2, color: Color, count_n: int = 14) -> void:
	if layer == null or not layer.is_inside_tree() or GameState.anim(1.0) <= 0.01:
		return
	for i in range(count_n):
		var d := ColorRect.new()
		d.color = color if i % 3 else color.lightened(0.5)
		d.size = Vector2(10, 10)
		d.pivot_offset = Vector2(5, 5)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(d)
		d.position = at
		var ang := randf() * TAU
		var dist := randf_range(60.0, 170.0)
		var tw := d.create_tween().set_parallel(true)
		tw.tween_property(d, "position", at + Vector2(cos(ang), sin(ang)) * dist, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(d, "modulate:a", 0.0, 0.6)
		tw.tween_property(d, "rotation", randf_range(-3.0, 3.0), 0.6)
		tw.chain().tween_callback(d.queue_free)


## Fichas voando de um ponto a outro (posições globais), em arco, escalonadas. Cada ficha que
## pousa toca um "chip". `on_done` roda quando a última chega.
func fly_chips(layer: Control, from: Vector2, to: Vector2, n: int = 5, color: Color = Color("#FFC933"), on_done: Callable = Callable()) -> void:
	if layer == null or not layer.is_inside_tree() or GameState.anim(1.0) <= 0.01:
		if on_done.is_valid():
			on_done.call()
		return
	var origin := layer.global_position
	var count_n := clampi(n, 1, 8)
	for i in range(count_n):
		var chip := Label.new()
		chip.text = "◎"
		chip.add_theme_font_size_override("font_size", 40)
		chip.add_theme_color_override("font_color", color)
		chip.add_theme_constant_override("outline_size", 6)
		chip.add_theme_color_override("font_outline_color", Color("#0B0626"))
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.pivot_offset = Vector2(20, 20)
		layer.add_child(chip)
		var a := from - origin + Vector2(randf_range(-14, 14), randf_range(-14, 14))
		var b := to - origin + Vector2(randf_range(-18, 18), randf_range(-12, 12))
		var mid := (a + b) / 2.0 + Vector2(randf_range(-60, 60), -90.0 - randf_range(0, 50))
		chip.position = a
		chip.modulate.a = 0.0
		var delay := 0.07 * float(i)
		var last := i == count_n - 1
		var tw := chip.create_tween()
		tw.tween_interval(GameState.anim(delay))
		tw.tween_property(chip, "modulate:a", 1.0, 0.05)
		var step := func(t: float) -> void:
			chip.position = a.lerp(mid, t).lerp(mid.lerp(b, t), t)
			chip.rotation = t * TAU
		tw.tween_method(step, 0.0, 1.0, GameState.anim(0.5)).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func():
			Sfx.play("chip", randf_range(0.95, 1.25))
			chip.queue_free()
			if last and on_done.is_valid():
				on_done.call())


## Texto que sobe e some (ex.: "+◎ 120", "−◎ 25") num ponto global.
func float_text(layer: Control, at: Vector2, text: String, color: Color, size: int = 40) -> void:
	if layer == null or not layer.is_inside_tree():
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color("#0B0626"))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(l)
	l.position = at - layer.global_position - Vector2(60, 20)
	l.pivot_offset = Vector2(60, 20)
	l.scale = Vector2(0.6, 0.6)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector2(1.15, 1.15), GameState.anim(0.2)).set_trans(Tween.TRANS_BACK)
	tw.tween_property(l, "position:y", l.position.y - 90.0, GameState.anim(1.1)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, GameState.anim(0.4)).set_delay(GameState.anim(0.8))
	tw.chain().tween_callback(l.queue_free)


## Chuva de fichas do topo da tela (jackpot).
func chip_rain(layer: Control, count_n: int = 28) -> void:
	if layer == null or not layer.is_inside_tree() or GameState.anim(1.0) <= 0.01:
		return
	var w := layer.size.x
	for i in range(count_n):
		var chip := Label.new()
		chip.text = "◎"
		chip.add_theme_font_size_override("font_size", randi_range(34, 56))
		chip.add_theme_color_override("font_color", Color("#FFC933") if i % 3 else Color("#FFE58A"))
		chip.add_theme_constant_override("outline_size", 6)
		chip.add_theme_color_override("font_outline_color", Color("#0B0626"))
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(chip)
		chip.position = Vector2(randf_range(0.0, w), -60.0)
		var tw := chip.create_tween().set_parallel(true)
		var dur := randf_range(0.9, 1.6)
		var delay := randf_range(0.0, 0.7)
		tw.tween_property(chip, "position:y", layer.size.y + 40.0, dur).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(chip, "rotation", randf_range(-6.0, 6.0), dur).set_delay(delay)
		tw.chain().tween_callback(chip.queue_free)
