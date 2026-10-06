class_name HandLayout
extends RefCounted
## Layout da mão de cartas — duas variantes, escolhidas em Configurações: fileira reta
## com leve sobreposição, ou leque de baralho virado em arco. As duas cabem qualquer
## mão (8 a 18 cartas) via sobreposição crescente; se ainda não for suficiente, quem
## mostra o resto é a rolagem horizontal do ScrollContainer por fora — as cartas nunca
## encolhem, só se escondem parcialmente atrás da vizinha.

const ROW_MAX_OVERLAP := 0.5    # fileira: no máximo 50% de uma carta escondida atrás da outra
const FAN_STEP_RAD := 0.036     # leque: abertura angular entre cartas vizinhas
const FAN_MAX_HALF_ANGLE := 0.40 # leque: metade da abertura máxima (rad)
const FAN_EDGE_PAD := 8.0       # leque: folga simétrica até a borda da faixa
const FAN_MAX_GAP := 0.62        # leque: distância máxima entre centros, em larguras de carta


## Altura que o leque de N cartas (tamanho exibido card_size) ocupa, sem contar o lift.
## Use pra dimensionar a zona da mão: é a mesma conta do _apply_fan.
static func fan_height(n: int, avail_w: float, card_size: Vector2) -> float:
	if n <= 1:
		return card_size.y + 6.0
	var g := _fan_geometry(n, avail_w, card_size)
	return g["drop"] + 2.0 * g["half_h"] + 4.0


## Arco de verdade: centros das cartas num círculo. Devolve raio, queda do arco e meias-caixas.
static func _fan_geometry(n: int, avail_w: float, card_size: Vector2) -> Dictionary:
	var alpha := clampf(FAN_STEP_RAD * float(n - 1), 0.12, FAN_MAX_HALF_ANGLE)
	var s := sin(alpha)
	var c := cos(alpha)
	var half_w := card_size.x / 2.0 * c + card_size.y / 2.0 * s   # meia largura da carta da ponta, já girada
	var half_h := card_size.y / 2.0 * c + card_size.x / 2.0 * s
	var span := maxf(avail_w - 2.0 * half_w - 2.0 * FAN_EDGE_PAD, card_size.x * 0.5)
	var radius := span / (2.0 * s)
	var max_gap := card_size.x * FAN_MAX_GAP   # poucas cartas: não abre demais
	var gap := radius * 2.0 * alpha / float(n - 1)
	if gap > max_gap:
		radius = max_gap * float(n - 1) / (2.0 * alpha)
	return {"alpha": alpha, "radius": radius, "drop": radius * (1.0 - c), "half_h": half_h}


## Posiciona/rotaciona cada CardView em `cards` (já filhos de `hand_container`) dentro da
## área disponível (avail_w x avail_h). Devolve a largura total de conteúdo, pro chamador
## ajustar o `custom_minimum_size` do contêiner (e o ScrollContainer saber até onde rolar).
static func apply(cards: Array, avail_w: float, avail_h: float, mode: String, card_size: Vector2) -> float:
	if cards.is_empty():
		return avail_w
	if mode == "fan":
		return _apply_fan(cards, avail_w, avail_h, card_size)
	return _apply_row(cards, avail_w, avail_h, card_size)


## Cada CardView mantém tamanho de controle = CardView.SIZE e é escalada em torno do centro:
## pivô = size/2 e posição = centro - size/2, QUALQUER que seja a escala (card_size é o tamanho
## EXIBIDO, só pra geometria). Usar o tamanho exibido no pivô desloca a carta.
static func _place(cv: CardView, center: Vector2, rot: float, z: int) -> void:
	cv.pivot_offset = cv.size / 2.0
	cv.rotation = rot
	cv.position = center - cv.size / 2.0
	cv.z_index = z


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
	var cy := avail_h - card_size.y / 2.0
	for i in range(n):
		_place(cards[i], Vector2(start_x + i * (card_w + sep) + card_w / 2.0, cy), 0.0, i)
	return maxf(total_w, avail_w)


static func _apply_fan(cards: Array, avail_w: float, avail_h: float, card_size: Vector2) -> float:
	var n := cards.size()
	var cx := avail_w / 2.0
	if n == 1:
		_place(cards[0], Vector2(cx, avail_h - card_size.y / 2.0 - 6.0), 0.0, 0)
		return avail_w
	var g := _fan_geometry(n, avail_w, card_size)
	var alpha: float = g["alpha"]
	var radius: float = g["radius"]
	var y_peak: float = avail_h - float(g["drop"]) - float(g["half_h"]) - 2.0   # centro da carta do meio
	for i in range(n):
		var t := float(i) / float(n - 1)
		var a := lerpf(-alpha, alpha, t)
		_place(cards[i], Vector2(cx + radius * sin(a), y_peak + radius * (1.0 - cos(a))), a, i)
	return avail_w
