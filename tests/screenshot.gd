extends Node
## Captura de tela para revisão visual (requer display/GPU, ex.: xvfb-run).
## "game" roda em autoplay (mesa em vazas). "bid" para no início, com o humano no
## controle, pra fotografar a tela de licitação.

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	SaveManager.persist = false
	var scene: String = str(args.get("scene", "menu"))
	var lookup := {"menu": "res://scenes/MainMenu.tscn", "game": "res://scenes/GameScene.tscn", "bid": "res://scenes/GameScene.tscn", "tutorial": "res://scenes/GameScene.tscn", "ranked": "res://scenes/RankedLobby.tscn", "chaos": "res://scenes/ChaosScene.tscn"}  # "tutorial" reusa a mesa, só troca a mão/dicas
	var path: String = lookup[scene]
	GameState.autoplay = scene == "game"
	if args.has("hand_layout"):
		SaveManager.section("settings")["hand_layout"] = str(args["hand_layout"])
	if scene == "tutorial":
		GameState.start_tutorial()
	var inst: Node = load(path).instantiate()
	add_child(inst)
	if args.has("bid"):
		await get_tree().create_timer(0.6).timeout
		inst.human_bid_chosen.emit(int(args["bid"]))
	await get_tree().create_timer(float(args.get("wait", "1.0"))).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(str(args.get("out", "/tmp/shot.png")))
	get_tree().quit()
