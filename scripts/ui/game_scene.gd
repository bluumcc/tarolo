extends Control
## GameScene.tscn — mesa polivalente (Clássico, Arcade e Ranqueado).
## Assentos: 0 = jogador (baixo), 1 = esquerda, 2 = topo, 3 = direita (sentido horário).

signal human_card_chosen(card: CardData)
signal match_finished(summary: Dictionary)

const CARD_SCENE := preload("res://scenes/Card.tscn")
const SEAT_SLOTS := [Vector2(0.5, 0.74), Vector2(0.2, 0.5), Vector2(0.5, 0.26), Vector2(0.8, 0.5)]

var engine := MatchEngine.new()
var config: Dictionary = {}
var bot_rng := RandomNumberGenerator.new()
var human_turn := false
var finished := false
var paused := false

var hud_badges: Array = []       # PanelContainer por jogador
var hud_scores: Array = []       # Label
var hud_tricks: Array = []       # Label
var seat_labels: Array = []      # Label de mão dos bots (contagem de cartas)
var table_center: Control
var table_area: Control
var hand_container: HBoxContainer
var status_label: Label
var combo_label: Label
var info_label: Label
var joker_bar: HBoxContainer
var popup_layer: Control
var overlay_layer: Control
var table_views: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bot_rng.randomize()
	config = GameState.match_config()
	engine.setup(config)
	_build_ui()
	get_viewport().size_changed.connect(_on_resize)
	_refresh_hud()
	_rebuild_hand()
	_run_round.call_deferred()


# ------------------------------------------------------------------ UI

func _build_ui() -> void:
	add_child(UIKit.background())

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	# HUD --------------------------------------------------------------
	var hud := HFlowContainer.new()
	hud.add_theme_constant_override("h_separation", 8)
	hud.add_theme_constant_override("v_separation", 8)
	root.add_child(hud)
	for p in range(engine.num_players):
		var accent := UIKit.GOLD if p == 0 else (UIKit.DANGER if p == config["boss_seat"] else UIKit.MUTED)
		var badge := UIKit.panel(UIKit.PURPLE_DEEP, accent, 8)
		badge.custom_minimum_size = Vector2(150, 0)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		badge.add_child(v)
		var title := str(config["names"][p])
		if p == config["boss_seat"]:
			title = "☠ " + title
		v.add_child(UIKit.label(title.to_upper(), 13, accent))
		var sc := UIKit.label("0", 24, UIKit.INK)
		v.add_child(sc)
		var tr := UIKit.label("0 vazas", 12, UIKit.MUTED)
		v.add_child(tr)
		hud.add_child(badge)
		hud_badges.append(badge)
		hud_scores.append(sc)
		hud_tricks.append(tr)

	var info_box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.BLACK, 8)
	info_label = UIKit.label("", 14, UIKit.INK)
	info_box.add_child(info_label)
	hud.add_child(info_box)

	var menu_btn := UIKit.button("☰", UIKit.MUTED, 20)
	menu_btn.custom_minimum_size = Vector2(52, 52)
	menu_btn.pressed.connect(_open_pause)
	hud.add_child(menu_btn)

	# Curingas (Arcade) ------------------------------------------------
	joker_bar = HBoxContainer.new()
	joker_bar.add_theme_constant_override("separation", 6)
	root.add_child(joker_bar)
	for id in config["jokers"]:
		var j := Jokers.info(id)
		var chip := UIKit.panel(UIKit.PURPLE, UIKit.GOLD, 6)
		chip.add_child(UIKit.label("🃏 " + str(j["name"]), 12, UIKit.GOLD))
		chip.tooltip_text = str(j["desc"])
		joker_bar.add_child(chip)
	joker_bar.visible = joker_bar.get_child_count() > 0

	# Mesa -------------------------------------------------------------
	table_area = Control.new()
	table_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table_area.custom_minimum_size = Vector2(0, 260)
	table_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(table_area)

	table_center = Panel.new()
	table_center.name = "TableCenter"
	table_center.add_theme_stylebox_override("panel", UIKit.box(Color(0.06, 0.05, 0.12, 0.65), UIKit.PURPLE, 3, 180, 0))
	table_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table_area.add_child(table_center)

	for p in range(engine.num_players):
		var l := UIKit.label("", 14, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		table_area.add_child(l)
		seat_labels.append(l)

	combo_label = UIKit.label("", 16, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(combo_label)

	status_label = UIKit.label("", 18, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(status_label)

	# Mão --------------------------------------------------------------
	var hand_scroll := Control.new()
	hand_scroll.custom_minimum_size = Vector2(0, CardView.SIZE.y + 30)
	hand_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hand_scroll)
	hand_container = HBoxContainer.new()
	hand_container.name = "HandContainer"
	hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hand_container.offset_top = -CardView.SIZE.y
	hand_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_scroll.add_child(hand_container)

	popup_layer = Control.new()
	popup_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_layer.z_index = 20
	add_child(popup_layer)

	overlay_layer = Control.new()
	overlay_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_layer.z_index = 30
	add_child(overlay_layer)

	_layout_table.call_deferred()


func _on_resize() -> void:
	_layout_table()
	_layout_hand()


func _layout_table() -> void:
	if table_area == null:
		return
	var area := table_area.size
	var portrait := area.y > area.x
	var w := minf(area.x - 40.0, 560.0)
	var h := minf(area.y - 4.0, 460.0 if portrait else 340.0)
	table_center.size = Vector2(maxf(w, 280.0), maxf(h, 200.0))
	table_center.position = (area - table_center.size) / 2.0
	var anchors := [Vector2(0.5, 1.0), Vector2(0.0, 0.5), Vector2(0.5, 0.0), Vector2(1.0, 0.5)]
	for p in range(seat_labels.size()):
		var l: Label = seat_labels[p]
		l.size = Vector2(160, 24)
		if p == 0:
			l.visible = false
			continue
		var a: Vector2 = anchors[p]
		var pos := table_center.position + table_center.size * a
		if p == 1:
			pos.x = maxf(pos.x - 170.0, 0.0)
		elif p == 3:
			pos.x = minf(pos.x + 10.0, area.x - 160.0)
		elif p == 2:
			pos.x -= 80.0
			pos.y = maxf(pos.y - 26.0, 0.0)
		l.position = pos - Vector2(0, 12)
	for v in table_views:
		var cv: CardView = v["view"]
		cv.position = _slot_pos(int(v["player"]))


func _slot_pos(player: int) -> Vector2:
	return table_center.size * (SEAT_SLOTS[player] as Vector2) - CardView.SIZE / 2.0


func _layout_hand() -> void:
	if hand_container == null:
		return
	var n := hand_container.get_child_count()
	if n == 0:
		return
	var avail := (hand_container.get_parent() as Control).size.x - 8.0
	var needed := n * CardView.SIZE.x
	var sep := 6
	if needed + (n - 1) * sep > avail:
		sep = int(floor((avail - needed) / maxf(n - 1, 1)))
	hand_container.add_theme_constant_override("separation", sep)


func _rebuild_hand() -> void:
	for c in hand_container.get_children():
		hand_container.remove_child(c)
		c.queue_free()
	var legal := engine.legal_for(0) if human_turn else []
	for card in engine.hands[0]:
		var cv: CardView = CARD_SCENE.instantiate()
		cv.setup(card, true)
		hand_container.add_child(cv)
		cv.set_playable(human_turn and legal.has(card))
		cv.tapped.connect(_on_card_tapped)
		cv.play_requested.connect(_on_card_play)
		cv.zoom_requested.connect(_show_zoom)
	_layout_hand.call_deferred()


func _refresh_hud() -> void:
	var standings := engine.standings()
	for p in range(engine.num_players):
		(hud_scores[p] as Label).text = UIKit.fmt_int(int(engine.scores[p]))
		(hud_tricks[p] as Label).text = "%d vazas · %dº" % [engine.tricks_won[p], standings.find(p) + 1]
		var turn := p == engine.current and not engine.is_round_over()
		(hud_badges[p] as PanelContainer).modulate = Color(1, 1, 1, 1) if turn else Color(0.78, 0.76, 0.85, 1)
		if p > 0:
			(seat_labels[p] as Label).text = "%s · %d cartas" % [config["names"][p], (engine.hands[p] as Array).size()]
	var mode_name: String = GameState.MODE_NAMES[GameState.mode]
	var extra := ""
	if GameState.mode == GameState.Mode.ARCADE:
		var r := GameState.run()
		extra = "  ·  Fase %d  ·  Ouro %d (+%d)" % [int(r["stage"]), int(r["gold"]), engine.gold_earned]
	elif GameState.mode == GameState.Mode.RANKED:
		var t := Ranked.tier_info(int(GameState.ranked()["points"]), int(GameState.ranked()["mmr"]))
		extra = "  ·  %s" % t["label"]
	info_label.text = "%s  ·  Vaza %d/%d%s" % [mode_name.to_upper(), mini(engine.trick_number + 1, engine.total_tricks), engine.total_tricks, extra]


# ------------------------------------------------------------------ loop de turnos

func _run_round() -> void:
	while not engine.is_round_over():
		if not is_inside_tree():
			return
		var p := engine.current
		_refresh_hud()
		var card: CardData
		if p == 0 and not GameState.autoplay:
			card = await _wait_human()
		else:
			status_label.text = "Vez de %s..." % config["names"][p] if p != 0 else "Autoplay..."
			await _wait(0.45 if p != 0 else 0.25)
			if not is_inside_tree():
				return
			card = BotAI.choose(engine.hands[p], engine.plays, p, engine.num_players, int(config["difficulty"][p]), bot_rng)
		if card == null or not is_inside_tree():
			return
		var from := _source_position(p, card)
		var res := engine.play(p, card)
		if not res.get("ok", false):
			push_warning("Jogada rejeitada: %s" % res.get("error"))
			continue
		if p == 0:
			_rebuild_hand()
		await _animate_play(p, card, from)
		if res["trick_complete"]:
			await _resolve_trick(res["result"])
	if is_inside_tree():
		_finish_match()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(GameState.anim(seconds)).timeout
	while paused and is_inside_tree():
		await get_tree().create_timer(0.1).timeout


func _wait_human() -> CardData:
	human_turn = true
	var ls := TrickRules.lead_suit(engine.plays)
	if ls == -1:
		status_label.text = "Sua vez — abra a vaza"
	else:
		status_label.text = "Sua vez — siga %s (ou jogue um Arcano)" % CardData.SUIT_NAMES[ls]
	_rebuild_hand()
	var card: CardData = await human_card_chosen
	human_turn = false
	return card


func _on_card_tapped(view: CardView) -> void:
	if not human_turn or not view.playable:
		if human_turn and not view.playable:
			status_label.text = "Você precisa seguir o naipe líder."
		return
	if view.selected:
		_on_card_play(view)
		return
	for c in hand_container.get_children():
		(c as CardView).set_selected(c == view)
	Sfx.play("tick")


func _on_card_play(view: CardView) -> void:
	if not human_turn or not view.playable:
		return
	human_turn = false
	human_card_chosen.emit(view.data)


func _source_position(player: int, card: CardData) -> Vector2:
	if player == 0:
		for c in hand_container.get_children():
			if (c as CardView).data == card:
				return (c as CardView).body.global_position
		return hand_container.global_position
	var l: Label = seat_labels[player]
	return l.global_position


func _animate_play(player: int, card: CardData, from: Vector2) -> void:
	var cv: CardView = CARD_SCENE.instantiate()
	cv.setup(card, true)
	cv.interactive = false
	table_center.add_child(cv)
	cv.set_playable(true)
	cv.zoom_requested.connect(_show_zoom)
	cv.global_position = from
	cv.scale = Vector2(0.9, 0.9)
	cv.rotation = randf_range(-0.25, 0.25)
	table_views.append({"player": player, "view": cv})
	Sfx.play("card", randf_range(0.9, 1.15))
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(cv, "position", _slot_pos(player), GameState.anim(0.28))
	tw.parallel().tween_property(cv, "rotation", randf_range(-0.06, 0.06), GameState.anim(0.28))
	tw.parallel().tween_property(cv, "scale", Vector2.ONE, GameState.anim(0.28))
	_refresh_hud()
	await tw.finished


func _resolve_trick(result: Dictionary) -> void:
	var winner: int = result["winner"]
	var ev: Dictionary = result["eval"]
	var win_view: CardView
	for v in table_views:
		if int(v["player"]) == winner:
			win_view = v["view"]
	await _wait(0.2)
	if not is_inside_tree():
		return
	if win_view:
		win_view.z_index = 5
		var pulse := create_tween()
		pulse.tween_property(win_view, "scale", Vector2(1.18, 1.18), GameState.anim(0.12))
		pulse.tween_property(win_view, "scale", Vector2(1.08, 1.08), GameState.anim(0.12))

	var syn: Array = ev["synergies"]
	if not syn.is_empty():
		combo_label.text = "✶ " + "  +  ".join(syn).to_upper() + " ✶"
		Sfx.play("combo")
		var flash := create_tween()
		combo_label.scale = Vector2(1.3, 1.3)
		combo_label.pivot_offset = combo_label.size / 2.0
		flash.tween_property(combo_label, "scale", Vector2.ONE, GameState.anim(0.3)).set_trans(Tween.TRANS_BACK)
	else:
		combo_label.text = ""

	_float_score(winner, ev)
	await _count_up(winner, int(engine.scores[winner]) - int(ev["total"]), int(engine.scores[winner]))
	await _wait(0.55)
	if not is_inside_tree():
		return

	# Recolhe as cartas em direção ao vencedor.
	var target := _slot_pos(winner) + (_slot_pos(winner) - table_center.size / 2.0 + CardView.SIZE / 2.0) * 0.8
	var tw := create_tween().set_parallel(true)
	for v in table_views:
		var cv: CardView = v["view"]
		tw.tween_property(cv, "position", target, GameState.anim(0.3))
		tw.tween_property(cv, "modulate:a", 0.0, GameState.anim(0.3))
	await tw.finished
	for v in table_views:
		(v["view"] as CardView).queue_free()
	table_views.clear()
	_refresh_hud()


func _float_score(winner: int, ev: Dictionary) -> void:
	var l := UIKit.label("+%s" % UIKit.fmt_int(int(ev["total"])), 34, UIKit.GOLD if winner == 0 else UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	var detail := UIKit.label("%s Fichas × %s Mult" % [UIKit.fmt_int(int(ev["chips"])), UIKit.fmt_dec(float(ev["mult"]), 1)], 15, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UIKit.box(Color(0.03, 0.03, 0.07, 0.85), UIKit.GOLD if winner == 0 else UIKit.PURPLE, 2, 4, 8))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.add_child(l)
	col.add_child(detail)
	box.add_child(col)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_layer.add_child(box)
	box.size = Vector2(260, 80)
	box.global_position = table_center.global_position + table_center.size / 2.0 - box.size / 2.0
	box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(box, "modulate:a", 1.0, GameState.anim(0.12))
	tw.parallel().tween_property(box, "position:y", box.position.y - 40.0, GameState.anim(0.9)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(box, "modulate:a", 0.0, GameState.anim(0.3))
	tw.tween_callback(box.queue_free)


## Contador de pontos rolando (batidas de ficha de cassino).
func _count_up(player: int, from: int, to: int) -> void:
	var steps := 8
	for i in range(1, steps + 1):
		if not is_inside_tree():
			return
		(hud_scores[player] as Label).text = UIKit.fmt_int(from + (to - from) * i / steps)
		if i % 2 == 0:
			Sfx.play("chip", 1.0 + i * 0.03)
		await _wait(0.035)


# ------------------------------------------------------------------ fim de partida

func _finish_match() -> void:
	if finished:
		return
	finished = true
	_refresh_hud()
	var placement := engine.placement_of(0)
	var result := {
		"placement": placement,
		"scores": engine.scores.duplicate(),
		"tricks_won": engine.tricks_won.duplicate(),
		"gold_earned": engine.gold_earned,
	}
	var boss := int(config["boss_seat"])
	if boss >= 0:
		result["beat_boss"] = int(engine.scores[0]) > int(engine.scores[boss])
	var summary := GameState.report_match(result)
	Sfx.play("win" if summary["won"] else "lose")
	status_label.text = ""
	_show_results(summary)
	match_finished.emit(summary)


func _show_results(summary: Dictionary) -> void:
	var ov := UIKit.overlay()
	overlay_layer.add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.GOLD if summary["won"] else UIKit.DANGER, 24)
	box.custom_minimum_size = Vector2(380, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	var title := "VITÓRIA" if summary["won"] else "DERROTA"
	if GameState.mode == GameState.Mode.ARCADE:
		title = "FASE SUPERADA" if summary["won"] else "RUN ENCERRADA"
	elif GameState.mode == GameState.Mode.RANKED:
		title = "%dº LUGAR" % (int(summary["placement"]) + 1)
	v.add_child(UIKit.label(title, 40, UIKit.GOLD if summary["won"] else UIKit.DANGER, HORIZONTAL_ALIGNMENT_CENTER))
	for p in engine.standings():
		var line := "%s  %s" % [str(config["names"][p]).to_upper(), UIKit.fmt_int(int(engine.scores[p]))]
		v.add_child(UIKit.label(line, 18, UIKit.GOLD if p == 0 else UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(HSeparator.new())
	for line in summary["lines"]:
		v.add_child(UIKit.label(str(line), 16, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var next: String = summary["next"]
	var btn: Button
	match next:
		"shop":
			btn = UIKit.button("LOJA ARCANA  →")
			btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Shop.tscn"))
		"ranked":
			btn = UIKit.button("VOLTAR AO LOBBY")
			btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/RankedLobby.tscn"))
		_:
			if GameState.mode == GameState.Mode.CLASSIC:
				var again := UIKit.button("JOGAR NOVAMENTE")
				again.pressed.connect(func(): get_tree().reload_current_scene())
				v.add_child(again)
			btn = UIKit.button("MENU PRINCIPAL", UIKit.MUTED)
			btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	v.add_child(btn)
	ov.add_child(UIKit.centered(box))
	box.scale = Vector2(0.85, 0.85)
	box.pivot_offset = box.custom_minimum_size / 2.0
	create_tween().tween_property(box, "scale", Vector2.ONE, GameState.anim(0.25)).set_trans(Tween.TRANS_BACK)
	btn.grab_focus.call_deferred()


# ------------------------------------------------------------------ zoom / pausa

func _show_zoom(view: CardView) -> void:
	if view == null or view.data == null:
		return
	var ov := UIKit.overlay()
	overlay_layer.add_child(ov)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	var holder := Control.new()
	holder.custom_minimum_size = CardView.SIZE * 2.2
	var big: CardView = CARD_SCENE.instantiate()
	big.setup(view.data, true)
	big.interactive = false
	holder.add_child(big)
	big.scale = Vector2(2.2, 2.2)
	big.pivot_offset = Vector2.ZERO
	v.add_child(holder)
	var desc := UIKit.label(view.describe(), 18, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(340, 0)
	v.add_child(desc)
	v.add_child(UIKit.label("toque para fechar", 12, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	ov.add_child(UIKit.centered(v))
	holder.scale = Vector2(0.6, 0.6)
	holder.pivot_offset = holder.custom_minimum_size / 2.0
	create_tween().tween_property(holder, "scale", Vector2.ONE, GameState.anim(0.18)).set_trans(Tween.TRANS_BACK)
	ov.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			ov.queue_free())


func _open_pause() -> void:
	if finished:
		return
	var ov := UIKit.overlay()
	overlay_layer.add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.GOLD, 24)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(320, 0)
	box.add_child(v)
	v.add_child(UIKit.label("PAUSA", 32, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("Toque numa carta para selecionar e de novo para jogar,\nou arraste-a para cima. Segure / botão direito = zoom.", 13, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	paused = true
	ov.tree_exited.connect(func(): paused = false)
	var resume := UIKit.button("CONTINUAR")
	resume.pressed.connect(ov.queue_free)
	v.add_child(resume)
	var quit_label := "ABANDONAR (conta como 4º)" if GameState.mode == GameState.Mode.RANKED else "SAIR PARA O MENU"
	var quit := UIKit.button(quit_label, UIKit.DANGER)
	quit.pressed.connect(_abandon)
	v.add_child(quit)
	ov.add_child(UIKit.centered(box))
	resume.grab_focus.call_deferred()


func _abandon() -> void:
	finished = true
	match GameState.mode:
		GameState.Mode.RANKED:
			GameState.report_match({"placement": engine.num_players - 1, "scores": engine.scores.duplicate(), "tricks_won": engine.tricks_won.duplicate(), "gold_earned": 0})
			get_tree().change_scene_to_file("res://scenes/RankedLobby.tscn")
		_:
			# No Arcade a run fica salva e pode ser continuada do início da fase.
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if overlay_layer.get_child_count() > 0 and not finished:
			overlay_layer.get_child(overlay_layer.get_child_count() - 1).queue_free()
		else:
			_open_pause()
