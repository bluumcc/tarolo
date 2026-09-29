class_name HandLayout
extends RefCounted
## Layout da mão de cartas — duas variantes, escolhidas em Configurações: fileira reta
## com leve sobreposição, ou leque de baralho virado em arco. As duas cabem qualquer
## mão (8 a 18 cartas) via sobreposição crescente; se ainda não for suficiente, quem
## mostra o resto é a rolagem horizontal do ScrollContainer por fora — as cartas nunca
## encolhem, só se escondem parcialmente atrás da vizinha.

const ROW_MAX_OVERLAP := 0.5    # fileira: no máximo 50% de uma carta escondida atrás da outra
const FAN_MAX_OVERLAP := 0.82   # leque: bem mais fechado, cabe mão grande sem precisar rolar tanto
const FAN_MAX_ANGLE_DEG := 24.0 # inclinação total do leque (das pontas ao centro)
const FAN_ARC := 18.0           # o quanto a carta do meio sobe em relação às pontas


## Posiciona/rotaciona cada CardView em `cards` (já filhos de `hand_container`) dentro da
## área disponível (avail_w x avail_h). Devolve a largura total de conteúdo, pro chamador
## ajustar o `custom_minimum_size` do contêiner (e o ScrollContainer saber até onde rolar).
static func apply(cards: Array, avail_w: float, avail_h: float, mode: String, card_size: Vector2) -> float:
	if cards.is_empty():
		return avail_w
	if mode == "fan":
		return _apply_fan(cards, avail_w, avail_h, card_size)
	return _apply_row(cards, avail_w, avail_h, card_size)


static func _apply_row(cards: Array, avail_w: float, avail_h: float, card_size: Vector2) -> float:
	var n := cards.size()
	var card_w := card_size.x
	var sep := 10.0
	if n > 1:
		var natural := n * card_w + (n - 1) * sep
		if natural > avail_w:
			var max_overlap := card_w * ROW_MAX_OVERLAP
			sep = maxf(-max_overlap, (avail_w - n * card_w) / float(n - 1))
	var total_w := n * card_w + (n - 1) * sep
	var start_x := maxf((avail_w - total_w) / 2.0, 0.0)
	var y := avail_h - card_size.y
	for i in range(n):
		var cv: CardView = cards[i]
		cv.position = Vector2(start_x + i * (card_w + sep), y)
		cv.rotation = 0.0
		cv.pivot_offset = card_size / 2.0
		cv.z_index = i
	return maxf(total_w, avail_w)


static func _apply_fan(cards: Array, avail_w: float, avail_h: float, card_size: Vector2) -> float:
	var n := cards.size()
	var card_w := card_size.x
	var sep := card_w * (1.0 - FAN_MAX_OVERLAP)
	if n > 1:
		var natural := card_w + (n - 1) * sep
		if natural > avail_w:
			sep = maxf(card_w * 0.1, (avail_w - card_w) / float(n - 1))
	var total_w := card_w + (n - 1) * sep
	var start_x := maxf((avail_w - total_w) / 2.0, 0.0)
	var max_angle := deg_to_rad(FAN_MAX_ANGLE_DEG) * clampf(float(n) / 12.0, 0.4, 1.0)
	var base_y := avail_h - card_size.y - FAN_ARC
	var pivot := Vector2(card_size.x / 2.0, card_size.y * 1.35)  # abaixo da carta — gira feito leque de baralho de verdade
	for i in range(n):
		var cv: CardView = cards[i]
		var t := 0.5 if n == 1 else float(i) / float(n - 1)
		var angle := lerpf(-max_angle, max_angle, t)
		var arc := sin(t * PI) * FAN_ARC  # desce um pouco nas pontas, sobe no meio
		cv.position = Vector2(start_x + i * sep, base_y + arc)
		cv.rotation = angle
		cv.pivot_offset = pivot
		cv.z_index = i
	return maxf(total_w, avail_w)
