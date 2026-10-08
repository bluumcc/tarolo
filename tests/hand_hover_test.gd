extends Node
## Com 10 cartas na mão (sacrifício), o mouse tem que "ver" cada carta, inclusive as das pontas do leque.
## Uso: godot --headless --path . res://tests/HandHoverTest.tscn
const BLITZ := preload("res://scenes/BlitzScene.tscn")
var failures := 0

func check(ok: bool, msg: String) -> void:
	if not ok:
		failures += 1
		print("FALHA: ", msg)

## Aproxima o que o Godot faz pra decidir quem recebe o mouse: de cima pra baixo (último filho primeiro), respeitando
## visibilidade, filtro do mouse e o recorte (clip_contents) dos pais.
func _pick(node: Node, pt: Vector2) -> Control:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return null
	var c := node as Control
	if c != null:
		var local := c.get_global_transform().affine_inverse() * pt
		var inside := Rect2(Vector2.ZERO, c.size).has_point(local)
		if c.clip_contents and not inside:
			return null
		var kids := c.get_children()
		for i in range(kids.size() - 1, -1, -1):
			var hit := _pick(kids[i], pt)
			if hit != null:
				return hit
		if inside and c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return c
		return null
	var ks := node.get_children()
	for i in range(ks.size() - 1, -1, -1):
		var h := _pick(ks[i], pt)
		if h != null:
			return h
	return null


func _ready() -> void:
	SaveManager.persist = false
	SaveManager.data = SaveManager.defaults()
	SaveManager.section("profile")["fichas"] = 1000000
	for k in ["blitz_intro", "turn", "double", "bet", "predict", "discard"]:
		SaveManager.section("tips")[k] = true
	GameState.fast = true
	for size in [Vector2i(1280, 720), Vector2i(390, 844)]:
		get_tree().root.size = size
		await get_tree().process_frame
		var scene: Node = BLITZ.instantiate()
		add_child(scene)
		for i in range(60):
			await get_tree().process_frame
		var cards: Array = scene.hand_container.get_children()
		print("tela ", size, " cartas ", cards.size(), " fase ", scene.phase)
		var vp := get_viewport().get_visible_rect()
		var bad := 0
		var seen := 0
		for i in range(cards.size()):
			var cv := cards[i] as CardView
			var lost := []
			for gx in range(1, 6):
				for gy in range(1, 8):
					var local := Vector2(CardView.SIZE.x * gx / 6.0, CardView.SIZE.y * gy / 8.0)
					var pt: Vector2 = cv.get_global_transform() * local
					if not vp.has_point(pt):
						continue
					# a carta mais de cima entre as que cobrem esse ponto (a de índice maior fica por cima)
					var top := -1
					for j in range(cards.size()):
						var other := cards[j] as CardView
						if Rect2(Vector2.ZERO, CardView.SIZE).has_point(other.get_global_transform().affine_inverse() * pt):
							top = j
					if top != i:
						continue
					seen += 1
					var h := _pick(get_tree().root, pt)
					if not (h != null and (h == cv or cv.is_ancestor_of(h))):
						bad += 1
						lost.append("(%d,%d)->%s" % [pt.x, pt.y, str(h.name) if h != null else "nada"])
			if not lost.is_empty():
				check(false, "tela %s: carta %d/%d tem pontos visíveis que não recebem o mouse: %s" % [str(size), i + 1, cards.size(), ", ".join(lost.slice(0, 4))])
		print("  pontos visíveis testados: ", seen, " sem mouse: ", bad)
		scene.queue_free()
		await get_tree().process_frame
	print("HAND HOVER: ", "OK" if failures == 0 else "%d falhas" % failures)
	get_tree().quit(failures)
