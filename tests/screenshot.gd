extends Node
## Captura de tela para revisão visual (requer display/GPU, ex.: xvfb-run).
## godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/Screenshot.tscn -- --scene=game --out=/tmp/x.png --wait=3.0

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	SaveManager.persist = false
	var scene := str(args.get("scene", "menu"))
	var path: String = {"menu": "res://scenes/MainMenu.tscn", "game": "res://scenes/GameScene.tscn", "shop": "res://scenes/Shop.tscn", "ranked": "res://scenes/RankedLobby.tscn"}[scene]
	if scene == "game" or scene == "shop":
		GameState.start_arcade_run()
		GameState.run()["stage"] = 3
		GameState.run()["gold"] = 14
		GameState.run()["jokers"] = ["louco", "prisma", "caos"]
		GameState.autoplay = true
	add_child(load(path).instantiate())
	await get_tree().create_timer(float(args.get("wait", "1.0"))).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(str(args.get("out", "/tmp/shot.png")))
	get_tree().quit()
