class_name RoundDots
extends Control
## Losangos das jogadas da rodada (N). Cada um tem um destes estados:
## - jogada concluída: PREENCHIDO — verde se você venceu, vermelho se perdeu, DOURADO se venceu uma
##   jogada que valia por duas (resultado 2);
## - ainda por jogar e FALTANDO vencer (o palpite): vazio com borda forte e clara;
## - ainda por jogar, sem meta: vazio com borda normal.
## A meta se redistribui sozinha: `need` vitórias que faltam marcam os próximos `need` losangos.
## Um único Control com `_draw` — nada de um nó por bolinha.

const DOT := 14.0
const GAP := 26.0
const DOT_BIG := 22.0     ## desktop: o card do topo só tem os losangos, então eles crescem e se espaçam
const GAP_BIG := 52.0

var total := 8
var results: Array = []   ## uma entrada por jogada concluída: 0 perdeu, 1 venceu, 2 venceu uma jogada dobrada
var dot := DOT
var gap := GAP
var need := 0             ## vitórias que ainda faltam pro palpite (0 = sem meta / já bateu)


func set_big(on: bool) -> void:
	var d := DOT_BIG if on else DOT
	var g := GAP_BIG if on else GAP
	if is_equal_approx(d, dot) and is_equal_approx(g, gap):
		return
	dot = d
	gap = g
	_update_min()
	queue_redraw()


func _update_min() -> void:
	custom_minimum_size = Vector2(total * dot + (total - 1) * gap, dot + 8.0)


func set_state(p_total: int, p_results: Array, p_need: int) -> void:
	if p_total == total and p_results == results and p_need == need:
		return
	total = p_total
	results = p_results.duplicate()
	need = maxi(p_need, 0)
	_update_min()
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_min()


func _draw() -> void:
	var span := total * dot + (total - 1) * gap
	var x0 := (size.x - span) / 2.0
	var cy := size.y / 2.0
	var h := dot * 0.62
	for i in range(total):
		var c := Vector2(x0 + dot / 2.0 + i * (dot + gap), cy)
		var pts := PackedVector2Array([c + Vector2(0, -h), c + Vector2(h, 0), c + Vector2(0, h), c + Vector2(-h, 0)])
		var ring := pts.duplicate()
		ring.append(pts[0])
		if i < results.size():
			var r := int(results[i])
			var col := UIKit.TR_GOLD if r >= 2 else (UIKit.OK if r == 1 else UIKit.TR_RED)
			if r >= 2:
				draw_polyline(ring, Color(col, 0.35), 7.0, true)   # halo: a vitória que vale por duas se destaca
			draw_colored_polygon(pts, col)
			draw_polyline(ring, col.lightened(0.25), 2.0, true)
		elif i - results.size() < need:
			draw_polyline(ring, Color(UIKit.TR_GOLD, 0.35), 7.0, true)   # halo
			draw_polyline(ring, UIKit.TR_GOLD.lightened(0.2), 3.5, true)   # borda forte: falta vencer
		else:
			draw_polyline(ring, UIKit.TR_PURPLE_LIGHT.lightened(0.25), 2.0, true)
