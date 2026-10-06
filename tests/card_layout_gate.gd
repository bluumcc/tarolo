extends Node
## Gate de layout das cartas: o corpo da carta tem de ter exatamente CardView.SIZE (a arte de
## 540x900 nunca pode inflar a carta) e o leque tem de caber, inteiro e centralizado, na zona
## da mão — nos dois tamanhos (compact/large) e em celular/PC.
## Uso: godot --headless --path . res://tests/card_layout_gate.tscn

const CARD_SCENE := preload("res://scenes/Card.tscn")
var failures := 0


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		printerr("FALHA: " + msg)


func _ready() -> void:
	SaveManager.persist = false
	for mode in ["compact", "large"]:
		CardView.apply_size_mode(mode)
		for vp in [Vector2(720, 1280), Vector2(799, 1280), Vector2(720, 1565), Vector2(1920, 1226)]:
			for n in [8, 10]:
				await _case(mode, vp, n)
	print("CARD LAYOUT GATE: %s" % ("OK" if failures == 0 else "%d falhas" % failures))
	get_tree().quit(1 if failures > 0 else 0)


func _case(mode: String, vp: Vector2, n: int) -> void:
	var wide := vp.x > vp.y
	var hs := CardView.hand_scale(wide, vp.y)
	var cs := CardView.SIZE * hs
	var avail_w := vp.x
	var zone_h := 0.0
	for k in [8, 9, 10]:
		zone_h = maxf(zone_h, HandLayout.fan_height(k, avail_w, cs))
	zone_h += CardView.MAX_LIFT * hs + 8.0
	var holder := Control.new()
	add_child(holder)
	var cards := []
	for i in range(n):
		var cv: CardView = CARD_SCENE.instantiate()
		cv.setup(CardData.make(CardData.Suit.TRUNFO, i + 1), true)
		holder.add_child(cv)
		cv.scale = Vector2(hs, hs)
		cards.append(cv)
	await get_tree().process_frame
	await get_tree().process_frame
	HandLayout.apply(cards, avail_w, zone_h, "fan", cs)
	var tag := "%s vp=%s n=%d" % [mode, vp, n]
	var minx := 1e9; var maxx := -1e9; var miny := 1e9; var maxy := -1e9
	for cv in cards:
		check(cv.body.size.distance_to(CardView.SIZE) < 0.6, "%s: corpo %s != SIZE %s" % [tag, cv.body.size, CardView.SIZE])
		var t: Transform2D = cv.get_global_transform()
		for corner in [Vector2.ZERO, Vector2(cv.size.x, 0), Vector2(0, cv.size.y), cv.size]:
			var p: Vector2 = t * corner
			minx = minf(minx, p.x); maxx = maxf(maxx, p.x)
			miny = minf(miny, p.y); maxy = maxf(maxy, p.y)
	check(minx >= -1.0 and maxx <= vp.x + 1.0, "%s: leque sai da tela em x [%.0f..%.0f]" % [tag, minx, maxx])
	check(miny >= -1.0 and maxy <= zone_h + 1.0, "%s: leque sai da zona em y [%.0f..%.0f] zona=%.0f" % [tag, miny, maxy, zone_h])
	check(absf((minx + maxx) / 2.0 - vp.x / 2.0) < 3.0, "%s: leque descentralizado (centro %.0f, tela %.0f)" % [tag, (minx + maxx) / 2.0, vp.x / 2.0])
	holder.queue_free()
