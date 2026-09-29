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
