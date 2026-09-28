extends Control
## GameScene.tscn — mesa de Tarot Vanilla (Clássico e Ranqueado usam a mesma mesa).
## Assentos: 0 = jogador (baixo), 1 = esquerda, 2 = topo, 3 = direita (sentido horário).

signal human_card_chosen(card: CardData)
signal human_bid_chosen(choice: int)
signal human_yesno_chosen(v: bool)
signal human_discard_chosen(cards: Array)
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
var hud_titles: Array = []       # Label — nome do jogador (atualizado quando o tomador é definido)
var hud_points: Array = []       # Label — pontos capturados até agora (provisório)
var hud_tricks: Array = []       # Label — vazas vencidas / colocação
var seat_labels: Array = []      # Label de mão dos bots (contagem de cartas)
var seat_avatars: Array = []     # PanelContainer circular por assento (destaca de quem é a vez)
var seat_avatar_labels: Array = []
var turn_pulse_token := 0        # invalida pulsos de destaque antigos quando a vez muda
var table_center: Control
var table_area: Control
var hand_container: HBoxContainer
var status_label: Label
var trick_label: Label           # resultado transitório da última vaza
var info_label: Label
var popup_layer: Control
var overlay_layer: Control
var table_views: Array = []

var tutorial := false
var tutorial_label: Label
var tutorial_seen: Dictionary = {}    # dicas de uso único já mostradas nesta partida


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bot_rng.randomize()
	config = GameState.match_config()
	tutorial = bool(config.get("tutorial", false))
	if tutorial:
		engine.setup_tutorial()
	else:
		engine.setup(config)
	_build_ui()
	get_viewport().size_changed.connect(_on_resize)
	_refresh_hud()
	_rebuild_hand()
	if tutorial:
		await _tutorial_modal("BEM-VINDO AO TUTORIAL", "Essa mão foi montada pra você passar pelas principais regras do Vanilla, com uma explicação antes de cada decisão nova. Não tem pressa — cada tela só avança quando você clicar em ENTENDI ou escolher uma opção.\n\nDá uma olhada na sua mão (embaixo da tela) antes de continuar.")
		if not is_inside_tree():
			return
	await _run_bidding()
	if not is_inside_tree():
		return
	_update_taker_badge()
	_refresh_hud()
	await _run_discard()
	if not is_inside_tree():
		return
	_rebuild_hand()
	await _run_talao_reveal()
	if not is_inside_tree():
		return
	await _run_declarations()
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
		var pts := UIKit.label("0,0 pts", 22, UIKit.INK)
		v.add_child(pts)
		var tr := UIKit.label("0 vazas", 12, UIKit.MUTED)
		v.add_child(tr)
		hud.add_child(badge)
		hud_badges.append(badge)
		hud_titles.append(title_label)
		hud_points.append(pts)
		hud_tricks.append(tr)

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

	if tutorial:
		var tut_box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.OK, 10)
		tutorial_label = UIKit.label("", 13, UIKit.OK)
		tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tutorial_label.custom_minimum_size = Vector2(0, 0)
		tut_box.add_child(tutorial_label)
		root.add_child(tut_box)

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
		avatar.visible = p != 0   # o jogador humano já vê a própria mão embaixo
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


## Quem tem a vez agora, em qualquer fase (licitação, descarte ou vaza) — usado pra
## destacar o avatar certo na mesa, não só durante as vazas.
func _current_turn_player() -> int:
	if not engine.bidding_done:
		return engine.bid_turn
	if engine.awaiting_discard:
		return engine.taker
	if engine.is_round_over():
		return -1
	return engine.current


func _refresh_hud() -> void:
	var trick_wins := []
	for p in range(engine.num_players):
		trick_wins.append(0)
	for t in engine.history:
		trick_wins[int(t["winner"])] += 1
	var turn_player := _current_turn_player()
	for p in range(engine.num_players):
		(hud_points[p] as Label).text = "%s pts" % UIKit.fmt_dec(engine.points_of(p), 1)
		(hud_tricks[p] as Label).text = "%d vazas" % trick_wins[p]
		var turn := p == turn_player
		(hud_badges[p] as PanelContainer).modulate = Color(1, 1, 1, 1) if turn else Color(0.78, 0.76, 0.85, 1)
		if p > 0:
			(seat_labels[p] as Label).text = "%s · %d cartas" % [config["names"][p], (engine.hands[p] as Array).size()]
	_update_turn_highlight(turn_player)
	var mode_name: String = GameState.MODE_NAMES[GameState.mode]
	var extra := ""
	if engine.taker != -1:
		var bouts_now := 0
		for c in engine.captured[engine.taker]:
			if (c as CardData).is_bout():
				bouts_now += 1
		var target := Scoring.target_for_bouts(bouts_now)
		extra = "  ·  Tomador: %s (%s)  ·  Meta: %s pts" % [config["names"][engine.taker], Scoring.CONTRACT_NAMES[engine.contract], UIKit.fmt_dec(target, 1)]
	if GameState.mode == GameState.Mode.RANKED:
		var t := Ranked.tier_info(int(GameState.ranked()["points"]), int(GameState.ranked()["mmr"]))
		extra += "  ·  %s" % t["label"]
	if engine.taker == -1:
		info_label.text = "%s  ·  Licitação" % mode_name.to_upper()
	else:
		info_label.text = "%s  ·  Vaza %d/%d%s" % [mode_name.to_upper(), mini(engine.trick_number + 1, engine.total_tricks), engine.total_tricks, extra]


## Destaca com borda dourada + pulso o avatar de quem tem a vez agora (bots só — o
## jogador humano já vê a própria mão liberada quando é a vez dele).
func _update_turn_highlight(turn_player: int) -> void:
	turn_pulse_token += 1
	var my_token := turn_pulse_token
	for p in range(1, seat_avatars.size()):
		var avatar: PanelContainer = seat_avatars[p]
		var active := p == turn_player
		avatar.add_theme_stylebox_override("panel", UIKit.box(UIKit.PURPLE, UIKit.GOLD if active else UIKit.MUTED, 4 if active else 2, 30, 0))
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


## Balão de texto curto acima do avatar de `player` (ou perto da mão, se for o humano) —
## dá pra ver ESPACIALMENTE quem fez o quê, em vez de um texto genérico no topo da tela.
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
	tw.tween_interval(GameState.anim(1.1))
	tw.tween_property(box, "modulate:a", 0.0, GameState.anim(0.3))
	tw.tween_callback(box.queue_free)


func _update_taker_badge() -> void:
	for p in range(engine.num_players):
		var accent := UIKit.GOLD if p == engine.taker else UIKit.MUTED
		(hud_badges[p] as PanelContainer).add_theme_stylebox_override("panel", UIKit.box(UIKit.PURPLE_DEEP, accent, 3, 4, 8))
		var title: Label = hud_titles[p]
		var base_name := str(config["names"][p]).to_upper()
		title.text = "♛ " + base_name if p == engine.taker else base_name
		title.add_theme_color_override("font_color", accent)


# ------------------------------------------------------------------ licitação

func _run_bidding() -> void:
	if tutorial:
		await _tutorial_modal("COMO FUNCIONA A LICITAÇÃO", "Toda rodada começa com uma licitação: os 4 jogadores decidem, em ordem, quem vai virar o ATAQUE (Tomador) — quem joga sozinho contra os outros 3, que viram a DEFESA.\n\nNa sua vez, você PASSA (desiste dessa rodada) ou dá um LANCE: um dos 4 contratos, sempre mais alto que o lance de quem já jogou. O lance não custa fichas nem nada — é só uma declaração de quão confiante você está na sua mão.\n\nQuem der o lance mais alto vira o Tomador. Cada contrato abaixo tem uma explicação curta de qual é o risco dele.")
		if not is_inside_tree():
			return
	while true:
		while not engine.bidding_done:
			if not is_inside_tree():
				return
			var p := engine.bid_turn
			_refresh_hud()
			var choice: int
			if p == 0 and not GameState.autoplay:
				choice = await _wait_human_bid()
			else:
				status_label.text = "%s está decidindo..." % config["names"][p] if p != 0 else "Autoplay..."
				await _wait(0.35 if not tutorial else 0.7)
				if not is_inside_tree():
					return
				var opts := engine.bid_options(p)
				var forced := engine.is_bidding_forced(p)
				choice = BotAI.bid_choice(engine.hands[p], opts, forced, int(config["difficulty"][p]), bot_rng)
			var res := engine.place_bid(p, choice)
			if not res.get("ok", false):
				continue
			_announce_bid(p, choice)
			await _wait(0.45 if not tutorial else 0.9)
			if not is_inside_tree():
				return
		if engine.bidding_void:
			status_label.text = "Todos passaram — nova mão."
			trick_label.text = ""
			if tutorial:
				await _tutorial_modal("TODOS PASSARAM", "Quando ninguém dá lance, a mão é anulada e as cartas são redistribuídas do zero — não conta como rodada jogada. Vai acontecer de novo agora.")
				if not is_inside_tree():
					return
			else:
				await _wait(1.0)
				if not is_inside_tree():
					return
			if tutorial:
				engine.setup_tutorial()
			else:
				engine.setup(config)
			_rebuild_hand()
			continue
		break
	status_label.text = "%s é o Tomador! Contrato: %s" % [config["names"][engine.taker], Scoring.CONTRACT_NAMES[engine.contract]]
	trick_label.text = ""
	if tutorial:
		if engine.taker == 0:
			await _tutorial_modal("VOCÊ É O ATAQUE (TOMADOR)", "Você venceu a licitação com %s. %s\n\nAgora você joga sozinho contra os outros 3 (a Defesa). No fim da rodada, todos os pontos que as SUAS cartas capturarem nas vazas (mais o talão, dependendo do contrato) são somados — se bater a meta, você ganha pontos dos outros 3; se não bater, você paga." % [Scoring.CONTRACT_NAMES[engine.contract], Scoring.CONTRACT_HINTS[engine.contract]])
		else:
			await _tutorial_modal("VOCÊ É DA DEFESA", "%s venceu a licitação com %s e virou o ATAQUE (Tomador) — joga sozinho contra a mesa toda, incluindo você.\n\nVocê e os outros 2 são a DEFESA: tudo que vocês capturarem nas vazas ajuda a impedir %s de bater a meta dele. Se ele não bater, todo mundo da Defesa ganha pontos; se ele bater, todo mundo da Defesa paga." % [config["names"][engine.taker], Scoring.CONTRACT_NAMES[engine.contract], config["names"][engine.taker]])
		if not is_inside_tree():
			return
	else:
		await _wait(1.1)


func _announce_bid(player: int, choice: int) -> void:
	var text := "Passou" if choice == -1 else "%s!" % Scoring.CONTRACT_NAMES[choice]
	trick_label.text = "%s passou." % config["names"][player] if choice == -1 else "%s deu %s!" % [config["names"][player], Scoring.CONTRACT_NAMES[choice]]
	_speech_bubble(player, text)
	Sfx.play("tick")


func _wait_human_bid() -> int:
	var opts := engine.bid_options(0)
	var forced := engine.is_bidding_forced(0)
	status_label.text = "Sua vez de licitar — olhe sua mão antes de decidir"
	_show_bid_prompt(opts, forced)
	var choice: int = await human_bid_chosen
	return choice


func _show_bid_prompt(opts: Array, forced: bool) -> void:
	var panel := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.GOLD, 14)
	panel.name = "BidPrompt"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(UIKit.label("SUA VEZ DE LICITAR", 15, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var bid_sub := UIKit.label("PASSAR = fica na Defesa. Qualquer contrato = você tenta virar o ATAQUE (Tomador), jogando sozinho contra os outros 3.", 11, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	bid_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bid_sub.custom_minimum_size = Vector2(420, 0)
	v.add_child(bid_sub)
	if forced:
		v.add_child(UIKit.label("Ninguém mais licitou — você é obrigado a assumir um contrato", 12, UIKit.DANGER, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var first_btn: Button
	if not forced:
		var pass_col := VBoxContainer.new()
		pass_col.add_theme_constant_override("separation", 2)
		row.add_child(pass_col)
		var pass_btn := UIKit.button("PASSAR", UIKit.MUTED, 14)
		pass_btn.pressed.connect(func():
			panel.queue_free()
			human_bid_chosen.emit(-1))
		pass_col.add_child(pass_btn)
		pass_col.add_child(UIKit.label("Desiste dessa rodada", 10, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		first_btn = pass_btn
	for c in opts:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.custom_minimum_size = Vector2(150, 0)
		row.add_child(col)
		var b := UIKit.button(Scoring.CONTRACT_NAMES[c], UIKit.GOLD, 14)
		b.pressed.connect(func(cc = c):
			panel.queue_free()
			human_bid_chosen.emit(cc))
		col.add_child(b)
		var hint := UIKit.label(str(Scoring.CONTRACT_HINTS[c]), 10, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD
		col.add_child(hint)
		if first_btn == null:
			first_btn = b
	popup_layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.position.y = 130
	if first_btn:
		first_btn.grab_focus.call_deferred()


# ------------------------------------------------------------------ descarte (écart)

## Petite/Garde: o tomador escolhe (de verdade) quais 6 cartas devolve pro talão —
## nunca automático. Garde Sans/Garde Contre nem passam por aqui (`awaiting_discard`
## fica falso pra esses contratos, já que o talão nem entra na mão do tomador).
func _run_discard() -> void:
	if not engine.awaiting_discard:
		return
	if engine.taker == 0 and not GameState.autoplay:
		if tutorial:
			await _tutorial_modal("O TALÃO ENTROU NA SUA MÃO", "O talão são 6 cartas que ficam escondidas até a licitação acabar. Com %s, elas entraram direto na sua mão — na próxima tela, as cartas com borda roxa são exatamente essas 6.\n\nAgora você escolhe 6 cartas (de qualquer origem) pra devolver ao talão — elas somam pontos pra você no final, mas nunca podem ser Reis ou Bouts." % Scoring.CONTRACT_NAMES[engine.contract])
			if not is_inside_tree():
				return
		var chosen: Array = await _wait_human_discard()
		if not is_inside_tree():
			return
		engine.discard(chosen)
	else:
		status_label.text = "%s está escolhendo o descarte..." % config["names"][engine.taker]
		await _wait(0.5)
		if not is_inside_tree():
			return
		var legal := engine.legal_discards(engine.hands[engine.taker])
		var chosen := BotAI.choose_discard(legal, Deck.CHIEN_SIZE)
		engine.discard(chosen)


## Explica o talão pros casos que não passam pela tela de descarte: quando um bot é o
## Tomador (ele decide sozinho, sem mostrar tela), ou quando o contrato é Garde Sans/
## Garde Contre (o talão nem chega a entrar na mão de ninguém pra escolher).
func _run_talao_reveal() -> void:
	if not tutorial or engine.taker == -1:
		return
	match engine.contract:
		Scoring.Contract.PETITE, Scoring.Contract.GARDE:
			if engine.taker != 0:
				await _tutorial_modal("O TALÃO (DESCARTE DO BOT)", "%s era o Tomador, então o talão (6 cartas escondidas) entrou na mão dele e ele escolheu sozinho o que devolver — você não vê essa escolha, só o resultado final na pontuação." % config["names"][engine.taker])
		Scoring.Contract.GARDE_SANS:
			await _tutorial_modal("O TALÃO (GARDE SANS)", "Com Garde Sans, %s nem chegou a ver o talão — ninguém escolhe nada. Mas as 6 cartas dele já contam a favor do Tomador mesmo assim: %s." % [config["names"][engine.taker], _describe_cards(engine.chien)])
		Scoring.Contract.GARDE_CONTRE:
			await _tutorial_modal("O TALÃO (GARDE CONTRE)", "Com Garde Contre, %s nem chegou a ver o talão — e dessa vez essas 6 cartas nem contam pra ninguém, ficam fora da rodada: %s." % [config["names"][engine.taker], _describe_cards(engine.chien)])


func _wait_human_discard() -> Array:
	var hand: Array = engine.hands[0]
	var legal: Array = engine.legal_discards(hand)
	status_label.text = "Escolha 6 cartas pra descartar no talão"
	var selected: Array = []
	var panel := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.GOLD, 14)
	panel.name = "DiscardPrompt"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(UIKit.label("ESCOLHA 6 CARTAS PRO DESCARTE", 15, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var sub_hint := "Elas contam como pontos seus no final. Reis e Bouts (em cinza) não podem ir."
	if tutorial:
		sub_hint += " As marcadas \"talão\" são as 6 que acabaram de entrar na sua mão."
	v.add_child(UIKit.label(sub_hint, 11, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var counter := UIKit.label("0 / %d selecionadas" % Deck.CHIEN_SIZE, 12, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(counter)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	flow.custom_minimum_size = Vector2(420, 0)
	v.add_child(flow)
	var confirm := UIKit.button("CONFIRMAR", UIKit.GOLD, 14)
	confirm.disabled = true
	var chien_ref: Array = engine.chien
	for c in hand:
		var card: CardData = c
		var is_legal: bool = (legal as Array).any(func(l: CardData) -> bool: return l.equals(card))
		var from_chien: bool = tutorial and (chien_ref as Array).any(func(l: CardData) -> bool: return l.equals(card))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		var b := UIKit.button("%s%s" % [card.rank_label(), card.suit_symbol()], UIKit.GOLD if is_legal else UIKit.MUTED, 13)
		b.custom_minimum_size = Vector2(52, 52)
		b.disabled = not is_legal
		b.toggle_mode = true
		if from_chien:
			b.add_theme_stylebox_override("normal", UIKit.box(UIKit.PURPLE, UIKit.OK, 3, 2, 6))
			b.add_theme_stylebox_override("disabled", UIKit.box(UIKit.PURPLE_DEEP, UIKit.OK, 3, 2, 6))
		b.pressed.connect(func():
			if selected.has(card):
				selected.erase(card)
				b.button_pressed = false
			else:
				if selected.size() >= Deck.CHIEN_SIZE:
					b.button_pressed = false
					return
				selected.append(card)
			counter.text = "%d / %d selecionadas" % [selected.size(), Deck.CHIEN_SIZE]
			confirm.disabled = selected.size() != Deck.CHIEN_SIZE)
		col.add_child(b)
		if from_chien:
			col.add_child(UIKit.label("talão", 8, UIKit.OK, HORIZONTAL_ALIGNMENT_CENTER))
		flow.add_child(col)
	confirm.pressed.connect(func():
		panel.queue_free()
		human_discard_chosen.emit(selected.duplicate()))
	v.add_child(confirm)
	popup_layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.position.y = 90
	var chosen: Array = await human_discard_chosen
	return chosen


# ------------------------------------------------------------------ declarações (Poignée / Chelem)

## Depois da licitação, o Tomador escolhe se declara Poignée (se elegível) e se anuncia
## Chelem — as duas são apostas estratégicas dele, não bônus automáticos.
func _run_declarations() -> void:
	if engine.taker == -1:
		return
	var eligible := engine.poignee_eligible()
	if engine.taker == 0 and not GameState.autoplay:
		if eligible:
			var bonus := int(Scoring.poignee_bonus(engine.taker_trump_count))
			var declare: bool = await _ask_yes_no("POIGNÉE", "Você tem %d trunfos na mão — pode declarar Poignée e ganhar +%d pontos no final, mas isso mostra seus trunfos pros outros jogadores. Declarar?" % [engine.taker_trump_count, bonus])
			if not is_inside_tree():
				return
			engine.declare_poignee(declare)
			if declare:
				_announce_toast("Você declarou Poignée! (+%d se a rodada fechar)" % bonus)
				_speech_bubble(0, "Poignée!")
				await _wait(0.6)
		var chelem: bool = await _ask_yes_no("CHELEM", "Quer anunciar Chelem — apostar que vai vencer as 18 vazas sozinho? Se conseguir: +400. Se falhar: -200. Sem anunciar, ainda ganha +200 de bônus se vencer todas por acaso, sem risco.")
		if not is_inside_tree():
			return
		engine.announce_chelem(chelem)
		if chelem:
			_announce_toast("Você anunciou Chelem! Vença as 18 vazas pra garantir o bônus.")
			_speech_bubble(0, "Chelem!")
			await _wait(0.6)
	else:
		var strength := BotAI.hand_strength(engine.hands[engine.taker])
		if eligible and BotAI.decide_poignee(engine.taker_trump_count):
			engine.declare_poignee(true)
			_announce_toast("%s declarou Poignée!" % config["names"][engine.taker])
			_speech_bubble(engine.taker, "Poignée!")
			await _wait(0.6)
			if not is_inside_tree():
				return
		if BotAI.decide_chelem(strength, int(config["difficulty"][engine.taker]), bot_rng):
			engine.announce_chelem(true)
			_announce_toast("%s anunciou Chelem!" % config["names"][engine.taker])
			_speech_bubble(engine.taker, "Chelem!")
			await _wait(0.6)
			if not is_inside_tree():
				return


func _announce_toast(text: String) -> void:
	trick_label.text = text
	Sfx.play("tick")


func _ask_yes_no(title: String, body: String) -> bool:
	var panel := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.GOLD, 14)
	panel.name = "YesNoPrompt"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(UIKit.label(title, 15, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var body_label := UIKit.label(body, 12, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size = Vector2(340, 0)
	v.add_child(body_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var no_btn := UIKit.button("NÃO", UIKit.MUTED, 14)
	no_btn.pressed.connect(func():
		panel.queue_free()
		human_yesno_chosen.emit(false))
	row.add_child(no_btn)
	var yes_btn := UIKit.button("SIM", UIKit.GOLD, 14)
	yes_btn.pressed.connect(func():
		panel.queue_free()
		human_yesno_chosen.emit(true))
	row.add_child(yes_btn)
	popup_layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.position.y = 130
	no_btn.grab_focus.call_deferred()
	var v_result: bool = await human_yesno_chosen
	return v_result


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


func _tutorial_hint(text: String) -> void:
	if not tutorial or tutorial_label == null:
		return
	tutorial_label.text = "💡 " + text


## Dica de uso único (não repete depois de mostrada nesta partida).
func _tutorial_once(key: String, text: String) -> void:
	if not tutorial or tutorial_seen.get(key, false):
		return
	tutorial_seen[key] = true
	_tutorial_hint(text)


## Modal bloqueante (só no tutorial): a partida só continua quando o jogador clicar em
## ENTENDI. Existe porque um banner de texto que já vai sendo coberto pelo próximo popup
## não dá tempo de ler nada — aqui ninguém avança sem confirmar que leu.
func _tutorial_modal(title: String, body: String, button_text: String = "ENTENDI, PRÓXIMO") -> void:
	if not tutorial or GameState.autoplay:
		return
	var v := UIKit.modal(overlay_layer, title, 380.0)
	var l := UIKit.label(body, 14, UIKit.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(340, 0)
	v.add_child(l)
	var btn := UIKit.button(button_text, UIKit.OK)
	v.add_child(btn)
	var ov: Control = overlay_layer.get_child(overlay_layer.get_child_count() - 1)
	btn.grab_focus.call_deferred()
	await btn.pressed
	if is_inside_tree():
		ov.queue_free()


## Descreve uma lista de cartas em texto corrido, tipo "Rei de Ouros, 7 de Copas e Ás de Paus".
func _describe_cards(cards: Array) -> String:
	var names: Array = []
	for c in cards:
		names.append((c as CardData).display_name())
	if names.size() <= 1:
		return ", ".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " e " + str(names[names.size() - 1])


func _wait_human() -> CardData:
	human_turn = true
	var ls := TrickRules.lead_suit(engine.plays)
	if ls == -1:
		status_label.text = "Sua vez — abra a vaza"
	elif ls == CardData.Suit.TRUNFO:
		status_label.text = "Sua vez — precisa cobrir com Trunfo maior, se tiver"
	else:
		status_label.text = "Sua vez — siga %s (ou corte com Trunfo, ou jogue O Louco)" % CardData.SUIT_NAMES[ls]
	if tutorial:
		_check_tutorial_trick_hints(ls)
	_rebuild_hand()
	var card: CardData = await human_card_chosen
	human_turn = false
	return card


## Detecta, na vez do jogador, situações que valem explicar: sem o naipe líder (obrigado
## a cortar), obrigado a cobrir com Trunfo maior, e a chance de jogar O Louco.
func _check_tutorial_trick_hints(ls: int) -> void:
	var hand: Array = engine.hands[0]
	var legal: Array = engine.legal_for(0)
	if ls != -1 and ls != CardData.Suit.TRUNFO:
		var has_suit := false
		for c in hand:
			if (c as CardData).suit == ls:
				has_suit = true
				break
		if not has_suit:
			_tutorial_once("forced_trunfo", "Você não tem mais %s — por isso é obrigado a jogar Trunfo (ou O Louco). Essa é a regra de corte obrigatório." % CardData.SUIT_NAMES[ls])
			return
	var hand_trunfos := (hand as Array).filter(func(c: CardData) -> bool: return c.is_trunfo()).size()
	var legal_trunfos := (legal as Array).filter(func(c: CardData) -> bool: return c.is_trunfo()).size()
	if hand_trunfos > legal_trunfos and legal_trunfos > 0:
		_tutorial_once("forced_cover", "Já tem Trunfo jogado nessa vaza e você tem um maior — por isso só os Trunfos mais altos aparecem jogáveis. É a regra de cobrir o corte.")
		return
	for c in hand:
		if (c as CardData).is_louco():
			_tutorial_once("louco", "Você tem O Louco na mão — pode jogá-lo quando quiser, ele nunca vence a vaza mas você guarda os pontos dele (conta como um Rei).")
			return


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

	trick_label.text = "%s venceu a vaza · +%s pts" % [str(config["names"][winner]).to_upper(), UIKit.fmt_dec(points, 1)]
	Sfx.play("chip")

	if tutorial and engine.is_round_over():
		var has_petit := false
		for entry in (result["plays"] as Array):
			if (entry["card"] as CardData).rank == CardData.PETIT and (entry["card"] as CardData).is_trunfo():
				has_petit = true
				break
		if has_petit:
			_tutorial_hint("Le Petit apareceu na última vaza! Quem venceu essa vaza leva um bônus extra de 10 pontos — é o Petit au bout.")

	_float_points(winner, points)
	await _wait(0.75)
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
	trick_label.text = ""
	_refresh_hud()


func _float_points(winner: int, points: float) -> void:
	var l := UIKit.label("+%s pts" % UIKit.fmt_dec(points, 1), 30, UIKit.GOLD if winner == 0 else UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
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


# ------------------------------------------------------------------ fim de partida

func _finish_match() -> void:
	if finished:
		return
	finished = true
	_refresh_hud()
	var r := engine.result
	var placement := engine.placement_of(0)
	var result := {
		"placement": placement,
		"taker": r["taker"],
		"contract": r["contract"],
		"success": r["success"],
		"deltas": r["deltas"],
	}
	var summary := GameState.report_match(result)
	Sfx.play("win" if summary["won"] else "lose")
	status_label.text = ""
	_show_results(summary, r)
	match_finished.emit(summary)


func _show_results(summary: Dictionary, r: Dictionary) -> void:
	var ov := UIKit.overlay()
	overlay_layer.add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.GOLD if summary["won"] else UIKit.DANGER, 24)
	box.custom_minimum_size = Vector2(400, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	var title := "TOMADOR BATEU A META" if r["success"] else "TOMADOR NÃO BATEU A META"
	if GameState.mode == GameState.Mode.RANKED:
		title = "%dº LUGAR" % (int(summary["placement"]) + 1)
	v.add_child(UIKit.label(title, 26, UIKit.GOLD if r["success"] else UIKit.DANGER, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("%s · %s · %s / %s pts (%s%s)" % [
		str(config["names"][r["taker"]]),
		Scoring.CONTRACT_NAMES[r["contract"]],
		UIKit.fmt_dec(r["taker_points"], 1),
		UIKit.fmt_dec(r["target"], 1),
		"+" if r["margin"] >= 0.0 else "",
		UIKit.fmt_dec(r["margin"], 1),
	], 14, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var bonuses: Dictionary = r.get("bonuses", {})
	var bonus_lines: Array = []
	if float(bonuses.get("poignee", 0.0)) > 0.0:
		bonus_lines.append("✦ Poignée declarado — %s tinha muitos trunfos (+%d)" % [str(config["names"][r["taker"]]), int(bonuses["poignee"])])
	var chelem: float = float(bonuses.get("chelem", 0.0))
	if chelem > 0.0 and engine.chelem_announced:
		bonus_lines.append("✦ Chelem anunciado e cumprido — %s venceu todas as vazas (+%d)" % [str(config["names"][r["taker"]]), int(chelem)])
	elif chelem > 0.0:
		bonus_lines.append("✦ Chelem — %s venceu todas as vazas sem anunciar (+%d)" % [str(config["names"][r["taker"]]), int(chelem)])
	elif chelem < 0.0:
		bonus_lines.append("✦ Chelem anunciado e não cumprido — %s errou a aposta (%d)" % [str(config["names"][r["taker"]]), int(chelem)])
	var petit: float = float(bonuses.get("petit_au_bout", 0.0))
	if petit > 0.0:
		bonus_lines.append("✦ Petit au bout a favor do Tomador (+%d)" % int(petit))
	elif petit < 0.0:
		bonus_lines.append("✦ Petit au bout a favor da Defesa (%d)" % int(petit))
	if not bonus_lines.is_empty():
		for line in bonus_lines:
			v.add_child(UIKit.label(str(line), 12, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(HSeparator.new())
	for p in engine.standings():
		var delta := int(r["deltas"][p])
		var line := "%s%s  %s%d" % ["♛ " if p == r["taker"] else "", str(config["names"][p]).to_upper(), "+" if delta >= 0 else "", delta]
		v.add_child(UIKit.label(line, 18, UIKit.GOLD if p == 0 else UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(HSeparator.new())
	for line in summary["lines"]:
		v.add_child(UIKit.label(str(line), 16, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	if tutorial:
		v.add_child(HSeparator.new())
		var tut_close := UIKit.label("Tutorial concluído! Isso não afeta suas Fragmentos nem seu elo — quando quiser, jogue de verdade no Vanilla ou Ranqueado.", 13, UIKit.OK, HORIZONTAL_ALIGNMENT_CENTER)
		tut_close.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tut_close.custom_minimum_size = Vector2(340, 0)
		v.add_child(tut_close)
	var next: String = summary["next"]
	var btn: Button
	if next == "ranked":
		btn = UIKit.button("VOLTAR AO LOBBY")
		btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/RankedLobby.tscn"))
	elif tutorial:
		btn = UIKit.button("MENU PRINCIPAL")
		btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	else:
		var again := UIKit.button("NOVA RODADA")
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


func _open_help() -> void:
	var v := UIKit.modal(overlay_layer, "COMO FUNCIONA")
	var text := """CARTAS
• 78 cartas: 4 naipes de 14 (Ás a Rei), 21 Trunfos e O Louco.
• Trunfo sempre vence naipe comum. Entre trunfos, vence o maior número.
• Bouts (as 3 cartas mais valiosas): Le Petit (trunfo 1), Le Monde (trunfo 21) e O Louco.

LICITAÇÃO
• Na sua vez: PASSAR ou dar um lance mais alto que o anterior.
• O lance não custa nada — é só uma declaração de confiança na sua mão.
• Petite (x1) → Garde (x2) → Garde Sans (x4, não vê o talão mas ele ainda conta) → Garde Contre (x6, não vê e ele vira ponto da defesa).
• Quem der o lance mais alto vira o Tomador e joga sozinho contra os outros 3.

DESCARTE (só Petite/Garde)
• O talão (6 cartas escondidas) entra na sua mão e você escolhe 6 pra devolver.
• Nunca pode descartar Reis ou Bouts — só cartas comuns (e Trunfo comum, se faltar carta comum).

META
• O Tomador soma os pontos que capturou. Precisa bater: 56 pts com 0 Bouts, 51 com 1, 41 com 2, 36 com 3.

BÔNUS (o Tomador escolhe se arrisca)
• Poignée: com 10+ trunfos, pode declarar — mostra suas cartas de trunfo, mas ganha pontos extras se a rodada fechar.
• Chelem: pode anunciar que vai vencer as 18 vazas sozinho — anunciado rende mais (+400) mas pune se falhar (-200); sem anunciar, ainda rende +200 se acontecer, sem risco.
• Petit au bout: automático — quem vence a última vaza com Le Petit dentro leva +10."""
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
			var taker_seat := maxi(engine.taker, 0)
			var deltas := Scoring.distribute(-25.0, taker_seat, engine.num_players)
			GameState.report_match({"placement": engine.num_players - 1, "taker": taker_seat, "contract": maxi(engine.contract, 0), "success": false, "deltas": deltas})
			get_tree().change_scene_to_file("res://scenes/RankedLobby.tscn")
		_:
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if overlay_layer.get_child_count() > 0 and not finished:
			overlay_layer.get_child(overlay_layer.get_child_count() - 1).queue_free()
		else:
			_open_pause()
