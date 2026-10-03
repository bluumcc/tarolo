class_name TableEllipse
extends Control
## Mesa de jogo: elipse achatada desenhada por código (sem imagem), centro roxo claro que
## escurece até o vermelho na borda. Também dá a geometria pros assentos e cartas da mesa.

const LAYERS := 20
const POINTS := 80


func center_point() -> Vector2:
	return size / 2.0


## Raio visual da elipse.
func radii() -> Vector2:
	return Vector2(maxf(size.x / 2.0 - 16.0, 10.0), maxf(size.y / 2.0 - 10.0, 10.0))


## Raio da órbita dos assentos (os avatares ficam sobre ela, com folga pro tamanho deles).
func seat_radii() -> Vector2:
	return Vector2(maxf(size.x / 2.0 - 84.0, 10.0), maxf(size.y / 2.0 - 72.0, 10.0))


## Ângulo do assento: o jogador 0 fica embaixo e os demais se distribuem com ângulos iguais.
static func seat_angle(player: int, count: int) -> float:
	return PI / 2.0 + TAU * float(player) / float(maxi(count, 1))


func _points(r: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var c := center_point()
	for i in range(POINTS):
		var a := TAU * float(i) / float(POINTS)
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


func _draw() -> void:
	var r := radii()
	var edge := UIKit.DANGER.darkened(0.45)
	var core := UIKit.VIOLET.lightened(0.05).darkened(0.35)
	for i in range(LAYERS):
		var t := float(i) / float(LAYERS - 1)
		var col := edge.lerp(core, smoothstep(0.0, 1.0, t))
		draw_colored_polygon(_points(r * (1.0 - t * 0.9)), col)
	var ring := _points(r)
	ring.append(ring[0])
	draw_polyline(ring, Color(UIKit.DANGER, 0.9), 4.0, true)
	draw_polyline(ring, Color(UIKit.DANGER, 0.25), 12.0, true)
