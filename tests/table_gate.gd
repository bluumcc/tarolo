extends SceneTree
## Gate da geometria da mesa Blitz: simula 4, 5 e 6 jogadores em várias áreas e confere que a mesa
## tem o MESMO tamanho/posição em todos os cenários, que nada passa das margens e que o que estiver
## mais perto da margem encosta nela. Rodar: godot --headless --path . -s res://tests/table_gate.gd

var fails := 0


func check(ok: bool, msg: String) -> void:
	print(("ok    " if ok else "FALHA ") + msg)
	if not ok:
		fails += 1


func _init() -> void:
	for area in [Vector2(672, 640), Vector2(672, 700), Vector2(600, 600), Vector2(720, 720)]:
		var base: Dictionary = {}
		var floor_y: float = area.y - 28.0 - 20.0 - 36.0   # como a cena: um pouco acima do pé do palco
		for n in [4, 5, 6]:
			var t := TableEllipse.new()
			t.size = area
			t.seat_count = n
			t.seat_floor = floor_y
			t.my_seat_y = area.y - 8.0
			t.fit()
			var half := TableEllipse.seat_half_extent()
			var left := 1e9
			var right := -1e9
			var bottom_rival := -1e9
			for p in range(n):
				var pt := t.border_point(TableEllipse.seat_angle(p, n))
				left = minf(left, pt.x - half)
				right = maxf(right, pt.x + half)
				if p > 0:
					bottom_rival = maxf(bottom_rival, pt.y + TableEllipse.SEAT_BELOW)
			var sig := [t.center_point(), t.border_point(PI / 2.0), t.border_point(-PI / 2.0), t.border_point(0.0)]
			if base.is_empty():
				base["sig"] = sig
			var tag := "área %dx%d, %d jogadores" % [int(area.x), int(area.y), n]
			check(left >= -0.01 and right <= area.x + 0.01, "%s: nada passa das margens (esq %.1f, dir %.1f de %d)" % [tag, left, right, int(area.x)])
			check(bottom_rival <= floor_y + 0.01, "%s: rivais de baixo acima do limite (%.1f ≤ %.1f)" % [tag, bottom_rival, floor_y])
			check(str(sig) == str(base["sig"]), "%s: mesma mesa (centro/topo/base/lateral) de todos os números de jogadores" % tag)
			if n == 4:
				check(absf(left) < 0.01 and absf(right - area.x) < 0.01, "%s: o que está mais perto da margem encosta nela" % tag)
	print("fails: %d" % fails)
	quit(1 if fails > 0 else 0)
