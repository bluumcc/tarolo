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
	if args.has("speed"):
		Engine.time_scale = float(args["speed"])   # acelera timers/tweens (a jogada do humano estoura sozinha)
	if args.has("notips"):
		for k in ["chaos_intro", "blitz_intro", "turn", "power", "double", "bet", "predict", "discard"]:
			SaveManager.section("tips")[k] = true
	var lookup := {"menu": "res://scenes/MainMenu.tscn", "game": "res://scenes/GameScene.tscn", "bid": "res://scenes/GameScene.tscn", "tutorial": "res://scenes/GameScene.tscn", "ranked": "res://scenes/RankedLobby.tscn", "chaos": "res://scenes/ChaosScene.tscn"}  # "tutorial" reusa a mesa, só troca a mão/dicas
	var path: String = lookup[scene]
	GameState.chaos_mode = str(args.get("mode", "blitz"))
	GameState.autoplay = scene == "game" or args.has("auto")
	if args.has("players"):
		GameState.ranked_table = {"blind": 10, "stack_blinds": 40, "players": int(args["players"])}   # mesa rankeada de N lugares
	if args.has("hand_layout"):
		SaveManager.section("settings")["hand_layout"] = str(args["hand_layout"])
	if scene == "tutorial":
		GameState.start_tutorial()
	var inst: Node = load(path).instantiate()
	# Direto na raiz, como o jogo real (o tema global não atravessa um Node comum).
	get_tree().root.add_child.call_deferred(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	if args.has("bid"):
		await get_tree().create_timer(0.6).timeout
		inst.human_bid_chosen.emit(int(args["bid"]))
	if args.has("call"):
		await get_tree().create_timer(0.6).timeout
		inst.call(str(args["call"]))
	if args.has("press"):
		# Vários botões em sequência: press=PULAR,ENTENDI,APOSTAR (espera entre cada um).
		for token in str(args["press"]).split(","):
			await get_tree().create_timer(float(args.get("pw", "0.9")) + (2.6 if token.begins_with("ENTENDI") else 0.0), true, false, true).timeout
			for b in inst.find_children("*", "Button", true, false):
				if (b as Button).visible and not (b as Button).disabled and (b as Button).text.contains(token):
					(b as Button).pressed.emit()
					break
	await get_tree().create_timer(float(args.get("wait", "1.0")), true, false, true).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(str(args.get("out", "/tmp/shot.png")))
	get_tree().quit()
