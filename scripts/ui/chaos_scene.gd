extends Control
## ChaosScene.tscn — mesa do modo Caos: 5 rodadas curtas de 8 cartas, todo mundo joga
## pra si (sem Tomador/Defesa), com um modificador novo a cada rodada e um bônus de
## Fôlego pra quem estiver por baixo no total. Assentos: 0 = jogador (baixo), 1 =
## esquerda, 2 = topo, 3 = direita (sentido horário) — mesmo layout do Vanilla.

signal human_card_chosen(card: CardData)
signal match_finished(summary: Dictionary)

const CARD_SCENE := preload("res://scenes/Card.tscn")
const SEAT_SLOTS := [Vector2(0.5, 0.74), Vector2(0.2, 0.5), Vector2(0.5, 0.26), Vector2(0.8, 0.5)]

var engine := ChaosEngine.new()
var config: Dictionary = {}
var bot_rng := RandomNumberGenerator.new()
var human_turn := false
var finished := false
var paused := false

var hud_badges: Array = []
var hud_titles: Array = []
var hud_totals: Array = []
var hud_round_pts: Array = []
var seat_labels: Array = []
var seat_avatars: Array = []
var seat_avatar_labels: Array = []
var turn_pulse_token := 0
var table_center: Control
var table_area: Control
var hand_container: HBoxContainer
var status_label: Label
var trick_label: Label
var info_label: Label
var modifier_label: Label
var popup_layer: Control
var overlay_layer: Control
var table_views: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bot_rng.randomize()
	config = GameState.chaos_config()
	engine.setup_match(config)
	_build_ui()
	get_viewport().size_changed.connect(_on_resize)
	_refresh_hud()
	_rebuild_hand()
	await _announce_round()
	if not is_inside_tree():
		return
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
		var badge := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.MUTED, 8)
		badge.custom_minimum_size = Vector2(160, 0)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		badge.add_child(v)
		var title_label := UIKit.label(str(config["names"][p]).to_upper(), 13, UIKit.MUTED)
		v.add_child(title_label)
		var total := UIKit.label("0,0 pts", 22, UIKit.INK)
		v.add_child(total)
		var rp := UIKit.label("+0,0 na rodada", 12, UIKit.MUTED)
		v.add_child(rp)
		hud.add_child(badge)
		hud_badges.append(badge)
		hud_titles.append(title_label)
		hud_totals.append(total)
		hud_round_pts.append(rp)

	var info_box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.BLACK, 8)
	info_label = UIKit.label("", 13, UIKit.INK)
	info_box.add_child(info_label)
	hud.add_child(info_box)

	var help_btn := UIKit.button("?", UIKit.GOLD, 20)
	help_btn.custom_minimum_size = Vector2(52, 52)
	help_btn.pressed.connect(_open_help)
	hud.add_child(help_btn)

	var menu_btn := UIKit.button("☰", UIKit.MUTED, 20)
	menu_btn.custom_minimum_size = Vector2(52, 52)
	menu_btn.pressed.connect(_open_pause)
	hud.add_child(menu_btn)

	var mod_box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.OK, 10)
	modifier_label = UIKit.label("", 14, UIKit.OK, HORIZONTAL_ALIGNMENT_CENTER)
	mod_box.add_child(modifier_label)
	root.add_child(mod_box)

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
		var avatar := PanelContainer.new()
		avatar.custom_minimum_size = Vector2(60, 60)
		avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar.add_theme_stylebox_override("panel", UIKit.box(UIKit.PURPLE, UIKit.MUTED, 2, 30, 0))
		var av_label := UIKit.label(str(config["names"][p]).substr(0, 1).to_upper(), 22, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
		av_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		av_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		avatar.add_child(av_label)
		avatar.visible = p != 0
		table_area.add_child(avatar)
		seat_avatars.append(avatar)
		seat_avatar_labels.append(av_label)

		var l := UIKit.label("", 14, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		table_area.add_child(l)
		seat_labels.append(l)

	trick_label = UIKit.label("", 16, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(trick_label)

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
	var av_size := Vector2(60, 60)
	for p in range(seat_labels.size()):
		var l: Label = seat_labels[p]
		l.size = Vector2(160, 24)
		var avatar: Control = seat_avatars[p]
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
		var av_pos := pos + Vector2(80.0 - av_size.x / 2.0, -av_size.y - 6.0)
		avatar.position = av_pos
		avatar.pivot_offset = av_size / 2.0
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


func _current_turn_player() -> int:
	if engine.is_round_over():
		return -1
	return engine.current


func _refresh_hud() -> void:
	var turn_player := _current_turn_player()
	for p in range(engine.num_players):
		(hud_totals[p] as Label).text = "%s pts" % UIKit.fmt_dec(engine.totals[p], 1)
		var rp: float = engine.round_points[p] if p < engine.round_points.size() else 0.0
		(hud_round_pts[p] as Label).text = "+%s na rodada" % UIKit.fmt_dec(rp, 1)
		var turn := p == turn_player
		(hud_badges[p] as PanelContainer).modulate = Color(1, 1, 1, 1) if turn else Color(0.78, 0.76, 0.85, 1)
		var lead_accent := UIKit.GOLD if p == engine.folego_player else UIKit.MUTED
		(hud_titles[p] as Label).text = "🔥 %s" % str(config["names"][p]).to_upper() if p == engine.folego_player else str(config["names"][p]).to_upper()
		(hud_titles[p] as Label).add_theme_color_override("font_color", lead_accent)
		if p > 0:
			(seat_labels[p] as Label).text = "%s · %d cartas" % [config["names"][p], (engine.hands[p] as Array).size()]
	info_label.text = "CAOS  ·  Rodada %d/%d  ·  Vaza %d/%d" % [engine.round_index + 1, ChaosEngine.ROUNDS, mini(engine.trick_number + 1, ChaosEngine.HAND_SIZE), ChaosEngine.HAND_SIZE]
	modifier_label.text = "✦ %s — %s" % [ChaosModifiers.label(engine.modifier, engine.weak_suit), ChaosModifiers.DESCRIPTIONS[engine.modifier]]
	_update_turn_highlight(turn_player)


func _update_turn_highlight(turn_player: int) -> void:
	turn_pulse_token += 1
	var my_token := turn_pulse_token
	for p in range(1, seat_avatars.size()):
		var avatar: PanelContainer = seat_avatars[p]
		var active := p == turn_player
		var accent := UIKit.GOLD if active else UIKit.MUTED
		if p == engine.folego_player:
			accent = UIKit.OK if not active else UIKit.GOLD
		avatar.add_theme_stylebox_override("panel", UIKit.box(UIKit.PURPLE, accent, 4 if active else 2, 30, 0))
		if not active:
			avatar.scale = Vector2.ONE
	if turn_player > 0:
		_pulse_avatar(seat_avatars[turn_player], my_token)


func _pulse_avatar(avatar: PanelContainer, token: int) -> void:
	while token == turn_pulse_token and is_inside_tree():
		var tw := create_tween()
		tw.tween_property(avatar, "scale", Vector2(1.1, 1.1), 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_property(avatar, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
		await tw.finished
		if not is_inside_tree():
			return


func _speech_bubble(player: int, text: String) -> void:
	if not is_inside_tree():
		return
	var anchor_pos: Vector2
	if player == 0:
		anchor_pos = table_area.global_position - popup_layer.global_position + Vector2(table_area.size.x / 2.0, table_area.size.y - 20.0)
	else:
		var avatar: Control = seat_avatars[player]
		anchor_pos = avatar.global_position - popup_layer.global_position + avatar.size / 2.0
	var l := UIKit.label(text, 13, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UIKit.box(Color(0.03, 0.03, 0.07, 0.92), UIKit.GOLD, 2, 8, 8))
	box.add_child(l)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_layer.add_child(box)
	await get_tree().process_frame
	box.position = anchor_pos - Vector2(box.size.x / 2.0, box.size.y + 40.0)
	box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(box, "modulate:a", 1.0, GameState.anim(0.12))
	tw.tween_interval(GameState.anim(1.0))
	tw.tween_property(box, "modulate:a", 0.0, GameState.anim(0.3))
	tw.tween_callback(box.queue_free)


# ------------------------------------------------------------------ rodadas / modificador

## Banner rápido no início de cada rodada — não bloqueia (o modo é pra ser ágil), mas o
## modificador continua visível na barra de info durante toda a rodada pra consulta.
func _announce_round() -> void:
	var title := "RODADA %d/%d" % [engine.round_index + 1, ChaosEngine.ROUNDS]
	var mod_text := ChaosModifiers.label(engine.modifier, engine.weak_suit)
	var body := "Modificador: %s" % mod_text
	if engine.folego_player != -1:
		body += "\n🔥 Fôlego pra %s (pontos ×%s nessa rodada)" % [str(config["names"][engine.folego_player]), UIKit.fmt_dec(ChaosEngine.FOLEGO_MULT, 1)]
	_show_round_banner(title, body)
	_refresh_hud()
	_rebuild_hand()
	await _wait(1.6)


func _show_round_banner(title: String, body: String) -> void:
	var panel := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.GOLD, 16)
	panel.name = "RoundBanner"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	v.add_child(UIKit.label(title, 22, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var body_label := UIKit.label(body, 14, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size = Vector2(360, 0)
	v.add_child(body_label)
	popup_layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.position.y = 190
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, GameState.anim(0.15))
	tw.tween_interval(GameState.anim(1.2))
	tw.tween_property(panel, "modulate:a", 0.0, GameState.anim(0.3))
	tw.tween_callback(panel.queue_free)


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
			await _wait(0.3)
			if not is_inside_tree():
				return
			card = BotAI.choose(engine.hands[p], engine.plays, p, engine.num_players, int(config["difficulty"][p]), bot_rng, engine.louco_can_win())
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
	if not is_inside_tree():
		return
	await _show_round_summary()
	if not is_inside_tree():
		return
	if engine.round_index >= ChaosEngine.ROUNDS - 1:
		_finish_match()
	else:
		engine.advance_round()
		await _announce_round()
		if not is_inside_tree():
			return
		_run_round.call_deferred()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(GameState.anim(seconds)).timeout
	while paused and is_inside_tree():
		await get_tree().create_timer(0.1).timeout


func _wait_human() -> CardData:
	human_turn = true
	var ls := TrickRules.lead_suit(engine.plays)
	if ls == -1:
		status_label.text = "Sua vez — abra a vaza"
	elif ls == CardData.Suit.TRUNFO:
		status_label.text = "Sua vez — precisa cobrir com Trunfo maior, se tiver"
	else:
		status_label.text = "Sua vez — siga %s (ou corte com Trunfo, ou jogue O Louco)" % CardData.SUIT_NAMES[ls]
	_rebuild_hand()
	var card: CardData = await human_card_chosen
	human_turn = false
	return card


func _on_card_tapped(view: CardView) -> void:
	if not human_turn or not view.playable:
		if human_turn and not view.playable:
			status_label.text = "Jogada ilegal — você é obrigado a seguir o naipe ou cortar com Trunfo."
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
	var points: float = result["points"]
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

	var extra := ""
	if float(result.get("mult", 1.0)) > 1.0:
		extra = " (x%s!)" % UIKit.fmt_dec(float(result["mult"]), 1)
	trick_label.text = "%s venceu a vaza · +%s pts%s" % [str(config["names"][winner]).to_upper(), UIKit.fmt_dec(points, 1), extra]
	Sfx.play("chip")
	_float_points(winner, points, bool(result.get("folego_applied", false)))
	await _wait(0.7)
	if not is_inside_tree():
		return

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
	trick_label.text = ""
	_refresh_hud()


func _float_points(winner: int, points: float, folego: bool) -> void:
	var text := "+%s pts" % UIKit.fmt_dec(points, 1)
	if folego:
		text += " 🔥"
	var l := UIKit.label(text, 30, UIKit.GOLD if winner == 0 else UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UIKit.box(Color(0.03, 0.03, 0.07, 0.85), UIKit.GOLD if winner == 0 else UIKit.PURPLE, 2, 4, 10))
	box.add_child(l)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_layer.add_child(box)
	box.size = Vector2(160, 50)
	box.global_position = table_center.global_position + table_center.size / 2.0 - box.size / 2.0
	box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(box, "modulate:a", 1.0, GameState.anim(0.12))
	tw.parallel().tween_property(box, "position:y", box.position.y - 30.0, GameState.anim(0.75)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(box, "modulate:a", 0.0, GameState.anim(0.25))
	tw.tween_callback(box.queue_free)


# ------------------------------------------------------------------ resumo de rodada / fim

func _show_round_summary() -> void:
	if GameState.autoplay:
		await _wait(0.05)
		return
	var r := engine.round_result
	var ov := UIKit.overlay()
	overlay_layer.add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.GOLD, 24)
	box.custom_minimum_size = Vector2(380, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	box.add_child(v)
	v.add_child(UIKit.label("FIM DA RODADA %d/%d" % [int(r["round"]) + 1, ChaosEngine.ROUNDS], 24, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label(ChaosModifiers.label(int(r["modifier"]), int(r["weak_suit"])), 14, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(HSeparator.new())
	var order := range(engine.num_players)
	var totals: Array = r["totals"]
	order.sort_custom(func(a: int, b: int) -> bool: return float(totals[a]) > float(totals[b]))
	for p in order:
		var gained: float = (r["round_points"] as Array)[p]
		var line := "%s%s  %s pts  (+%s)" % ["👑 " if p == order[0] else "", str(config["names"][p]).to_upper(), UIKit.fmt_dec(float(totals[p]), 1), UIKit.fmt_dec(gained, 1)]
		v.add_child(UIKit.label(line, 16, UIKit.GOLD if p == 0 else UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	var btn_text := "VER RESULTADO FINAL" if int(r["round"]) >= ChaosEngine.ROUNDS - 1 else "PRÓXIMA RODADA"
	var btn := UIKit.button(btn_text)
	v.add_child(btn)
	ov.add_child(UIKit.centered(box))
	box.scale = Vector2(0.85, 0.85)
	box.pivot_offset = box.custom_minimum_size / 2.0
	create_tween().tween_property(box, "scale", Vector2.ONE, GameState.anim(0.2)).set_trans(Tween.TRANS_BACK)
	btn.grab_focus.call_deferred()
	await btn.pressed
	if is_inside_tree():
		ov.queue_free()


func _finish_match() -> void:
	if finished:
		return
	finished = true
	var summary := GameState.report_chaos_match(engine.match_result)
	Sfx.play("win" if summary["won"] else "lose")
	status_label.text = ""
	_show_results(summary)
	match_finished.emit(summary)


func _show_results(summary: Dictionary) -> void:
	var ov := UIKit.overlay()
	overlay_layer.add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.GOLD if summary["won"] else UIKit.DANGER, 24)
	box.custom_minimum_size = Vector2(400, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	var title := "%dº LUGAR" % (int(summary["placement"]) + 1)
	if summary["won"]:
		title = "VOCÊ VENCEU!"
	v.add_child(UIKit.label(title, 26, UIKit.GOLD if summary["won"] else UIKit.DANGER, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(HSeparator.new())
	var order: Array = engine.match_result["standings"]
	var totals: Array = engine.match_result["totals"]
	for i in range(order.size()):
		var p: int = order[i]
		var line := "%d. %s%s — %s pts" % [i + 1, "👑 " if i == 0 else "", str(config["names"][p]).to_upper(), UIKit.fmt_dec(float(totals[p]), 1)]
		v.add_child(UIKit.label(line, 18, UIKit.GOLD if p == 0 else UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(HSeparator.new())
	for line in summary["lines"]:
		v.add_child(UIKit.label(str(line), 16, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var again := UIKit.button("NOVA PARTIDA")
	again.pressed.connect(func(): get_tree().reload_current_scene())
	v.add_child(again)
	var btn := UIKit.button("MENU PRINCIPAL", UIKit.MUTED)
	btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	v.add_child(btn)
	ov.add_child(UIKit.centered(box))
	box.scale = Vector2(0.85, 0.85)
	box.pivot_offset = box.custom_minimum_size / 2.0
	create_tween().tween_property(box, "scale", Vector2.ONE, GameState.anim(0.25)).set_trans(Tween.TRANS_BACK)
	btn.grab_focus.call_deferred()


# ------------------------------------------------------------------ zoom / ajuda / pausa

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


func _open_help() -> void:
	var v := UIKit.modal(overlay_layer, "COMO FUNCIONA O CAOS")
	var text := """RODADAS
• 5 rodadas curtas de 8 cartas cada — sem licitação, sem talão, todo mundo joga pra si.
• Vence a partida quem somar mais pontos no total das 5 rodadas.

MODIFICADOR
• Cada rodada sorteia uma regra especial diferente, sempre visível na barra logo acima da mesa.

FÔLEGO
• A partir da 2ª rodada, quem estiver em último no total ganha Fôlego: os pontos que capturar nessa rodada valem x1,5. É a chance de virar o jogo.

CARTAS
• Mesmas regras de vaza do Vanilla: seguir naipe, cortar com Trunfo se não tiver, cobrir com Trunfo maior se alguém já cortou. O Louco nunca vence, a não ser no modificador "O Louco Vence"."""
	var l := UIKit.label(text, 13, UIKit.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(340, 0)
	v.add_child(l)
	UIKit.close_button(overlay_layer, v)


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
	var quit := UIKit.button("SAIR PARA O MENU", UIKit.DANGER)
	quit.pressed.connect(func():
		finished = true
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	v.add_child(quit)
	ov.add_child(UIKit.centered(box))
	box.scale = Vector2(0.9, 0.9)
	box.pivot_offset = box.size / 2.0
	create_tween().tween_property(box, "scale", Vector2.ONE, GameState.anim(0.2)).set_trans(Tween.TRANS_BACK)
	resume.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if overlay_layer.get_child_count() > 0 and not finished:
			overlay_layer.get_child(overlay_layer.get_child_count() - 1).queue_free()
		else:
			_open_pause()
