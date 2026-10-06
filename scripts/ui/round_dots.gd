class_name RoundDots
extends Control
## Losangos das jogadas da rodada (N). Cada um tem um destes estados:
## - jogada concluída: PREENCHIDO — verde se você venceu, vermelho se perdeu;
## - ainda por jogar e FALTANDO vencer (o palpite): vazio com borda forte e clara;
## - ainda por jogar, sem meta: vazio com borda normal.
## A meta se redistribui sozinha: `need` vitórias que faltam marcam os próximos `need` losangos.
## Um único Control com `_draw` — nada de um nó por bolinha.

const DOT := 14.0
const GAP := 26.0

var total := 8
var results: Array = []   ## uma entrada por jogada concluída: true = você venceu
var need := 0             ## vitórias que ainda faltam pro palpite (0 = sem meta / já bateu)


func set_state(p_total: int, p_results: Array, p_need: int) -> void:
	if p_total == total and p_results == results and p_need == need:
		return
	total = p_total
	results = p_results.duplicate()
	need = maxi(p_need, 0)
	custom_minimum_size = Vector2(total * DOT + (total - 1) * GAP, DOT + 8.0)
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(total * DOT + (total - 1) * GAP, DOT + 8.0)


func _draw() -> void:
	var span := total * DOT + (total - 1) * GAP
	var x0 := (size.x - span) / 2.0
	var cy := size.y / 2.0
	var h := DOT * 0.62
	for i in range(total):
		var c := Vector2(x0 + DOT / 2.0 + i * (DOT + GAP), cy)
		var pts := PackedVector2Array([c + Vector2(0, -h), c + Vector2(h, 0), c + Vector2(0, h), c + Vector2(-h, 0)])
		var ring := pts.duplicate()
		ring.append(pts[0])
		if i < results.size():
			var col := UIKit.OK if bool(results[i]) else UIKit.TR_RED
			draw_colored_polygon(pts, col)
			draw_polyline(ring, col.lightened(0.25), 2.0, true)
		elif i - results.size() < need:
			draw_polyline(ring, Color(UIKit.TR_GOLD, 0.35), 7.0, true)   # halo
			draw_polyline(ring, UIKit.TR_GOLD.lightened(0.2), 3.5, true)   # borda forte: falta vencer
		else:
			draw_polyline(ring, UIKit.TR_PURPLE_LIGHT.lightened(0.25), 2.0, true)
