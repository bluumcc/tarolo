class_name RoundDots
extends Control
## Losangos de progresso (rodada X de N): feitas em dourado, a atual em rosa-neon, as demais
## só no contorno. Um único Control com `_draw` — nada de um nó por bolinha.

const DOT := 18.0
const GAP := 16.0

var total := 8
var current := 0   ## índice (0-based) da rodada atual; as anteriores contam como feitas


func set_progress(p_total: int, p_current: int) -> void:
	if p_total == total and p_current == current:
		return
	total = p_total
	current = p_current
	custom_minimum_size = Vector2(total * DOT + (total - 1) * GAP, DOT + 6.0)
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(total * DOT + (total - 1) * GAP, DOT + 6.0)


func _draw() -> void:
	var span := total * DOT + (total - 1) * GAP
	var x0 := (size.x - span) / 2.0
	var cy := size.y / 2.0
	for i in range(total):
		var c := Vector2(x0 + DOT / 2.0 + i * (DOT + GAP), cy)
		var h := DOT * 0.62
		var pts := PackedVector2Array([c + Vector2(0, -h), c + Vector2(h, 0), c + Vector2(0, h), c + Vector2(-h, 0)])
		if i < current:
			draw_colored_polygon(pts, UIKit.TR_GOLD)
		elif i == current:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h - 4), c + Vector2(h + 4, 0), c + Vector2(0, h + 4), c + Vector2(-h - 4, 0)]), Color(UIKit.TR_RED, 0.28))
			draw_colored_polygon(pts, UIKit.TR_RED_NEON)
		else:
			var ring := pts.duplicate()
			ring.append(pts[0])
			draw_polyline(ring, UIKit.TR_PURPLE_LIGHT.lightened(0.25), 2.5, true)
