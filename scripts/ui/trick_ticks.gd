class_name TrickTicks
extends Control
## Linha com uma marca por rodada do nível, pintada pela cor de quem levou: vermelho pro
## Ataque (Atacante), azul pra Defesa. A rodada atual fica branca.

var total := 18
var winners: Array = []   # 1 = Ataque levou, 0 = Defesa levou
var attack_color := UIKit.BOSS
var defense_color := UIKit.DEF


func _init() -> void:
	custom_minimum_size = Vector2(0, 12)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_state(p_total: int, p_winners: Array) -> void:
	total = maxi(p_total, 1)
	winners = p_winners
	queue_redraw()


func _draw() -> void:
	var gap := 4.0
	var w := (size.x - gap * float(total - 1)) / float(total)
	for i in range(total):
		var col := UIKit.TICK_EMPTY
		if i < winners.size():
			col = attack_color if int(winners[i]) == 1 else defense_color
		elif i == winners.size():
			col = UIKit.PAPER
		draw_rect(Rect2(float(i) * (w + gap), 0.0, w, size.y), col)
