extends Control
## ChaosScene.tscn — mesa do modo Caos: 5 rodadas curtas de 8 cartas, todo mundo joga
## pra si (sem Tomador/Defesa), com um modificador novo a cada rodada e um bônus de
## Fôlego pra quem estiver por baixo no total. Layout pensado pra celular (retrato):
## uma pilha vertical — status dos jogadores no topo, área de jogo compacta no meio,
## sua mão embaixo — em vez de uma mesa oval espalhada, que só faz sentido em paisagem.

signal human_card_chosen(card: CardData)
signal item_chosen(item: int)
signal match_finished(summary: Dictionary)

const CARD_SCENE := preload("res://scenes/Card.tscn")

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
var hud_cards: Array = []
var seat_avatars: Array = []
var turn_pulse_token := 0
var table_center: Panel
var hand_container: HBoxContainer
var status_label: Label
var trick_label: Label
var info_label: Label
var modifier_label: Label
var modifier_expanded := false
var wager_label: Label
var popup_layer: Control
var overlay_layer: Control
var table_views: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bot_rng.randomize()
	config = GameState.chaos_config()
	if not bool(config.get("entered", true)):
		add_child(UIKit.background())
		overlay_layer = Control.new()
		overlay_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(overlay_layer)
		_show_insufficient_fichas()
		return
	engine.setup_match(config)
	_build_ui()
	get_viewport().size_changed.connect(_on_resize)
	_refresh_hud()
	_rebuild_hand()
	await _announce_round()
	if not is_inside_tree():
		return
	_run_round.call_deferred()


func _show_insufficient_fichas() -> void:
	var ov := UIKit.overlay()
	overlay_layer.add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.DANGER, 24)
	box.custom_minimum_size = Vector2(360, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	box.add_child(v)
	v.add_child(UIKit.label("FICHAS INSUFICIENTES", 22, UIKit.DANGER, HORIZONTAL_ALIGNMENT_CENTER))
	var l := UIKit.label("Você precisa de %d fichas pra entrar na Mesa Caos. Jogue Vanilla ou Ranqueado, ou volte ao menu e peça um empréstimo da casa." % int(config["buy_in"]), 14, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(320, 0)
	v.add_child(l)
	var btn := UIKit.button("VOLTAR AO MENU", UIKit.MUTED)
	btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	v.add_child(btn)
	ov.add_child(UIKit.centered(box))
	btn.grab_focus.call_deferred()


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

	hud_badges.resize(engine.num_players)
	hud_titles.resize(engine.num_players)
	hud_totals.resize(engine.num_players)
	hud_round_pts.resize(engine.num_players)
	hud_cards.resize(engine.num_players)
	seat_avatars.resize(engine.num_players)

	# Barra de topo — título + ações, uma linha só, sempre no mesmo lugar (como o topo
	# de qualquer app) -------------------------------------------------
	var topbar := HBoxContainer.new()
	topbar.add_theme_constant_override("separation", 8)
	root.add_child(topbar)
	var info_box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.BLACK, 8)
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label = UIKit.label("", 13, UIKit.INK)
	info_box.add_child(info_label)
	topbar.add_child(info_box)
	var help_btn := UIKit.button("?", UIKit.GOLD, 20)
	help_btn.custom_minimum_size = Vector2(52, 52)
	help_btn.pressed.connect(_open_help)
	topbar.add_child(help_btn)
	var menu_btn := UIKit.button("☰", UIKit.MUTED, 20)
	menu_btn.custom_minimum_size = Vector2(52, 52)
	menu_btn.pressed.connect(_open_pause)
	topbar.add_child(menu_btn)

	# Placar dos outros 3 jogadores — uma fileira só, esticando até preencher a largura
	# toda. Sem avatar/círculo: só nome e pontos já bastam pra reconhecer quem é quem
	# numa mesa de 4 — o círculo com inicial só ocupava espaço sem ajudar em nada.
	var hud := HBoxContainer.new()
	hud.add_theme_constant_override("separation", 8)
	root.add_child(hud)
	for p in range(1, engine.num_players):
		# O card em si reage a toque — abre/fecha o detalhe (pontos da rodada, cartas
		# na mão). Por padrão só mostra o essencial: quem é, quanto tem.
		var badge := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.MUTED, 10)
		badge.mouse_filter = Control.MOUSE_FILTER_STOP
		badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var outer := VBoxContainer.new()
		outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outer.add_theme_constant_override("separation", 2)
		badge.add_child(outer)

		var top_row := HBoxContainer.new()
		top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outer.add_child(top_row)
		var title_label := UIKit.label(str(config["names"][p]).to_upper(), 13, UIKit.MUTED)
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(title_label)
		var chevron := UIKit.label("▸", 12, UIKit.MUTED)
		top_row.add_child(chevron)
		var total := UIKit.label("0,0 pts", 20, UIKit.INK)
		outer.add_child(total)

		var detail := VBoxContainer.new()
		detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail.visible = false
		detail.add_theme_constant_override("separation", 1)
		outer.add_child(detail)
		var rp := UIKit.label("+0,0 na rodada", 12, UIKit.MUTED)
		detail.add_child(rp)
		var cards_label := UIKit.label("", 12, UIKit.MUTED)
		detail.add_child(cards_label)

		badge.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				Sfx.play("tick")
				detail.visible = not detail.visible
				chevron.text = "▾" if detail.visible else "▸")

		hud.add_child(badge)
		hud_badges[p] = badge
		hud_titles[p] = title_label
		hud_totals[p] = total
		hud_round_pts[p] = rp
		hud_cards[p] = cards_label
		seat_avatars[p] = badge

	# Banner do modificador — fundo preenchido pra se destacar como um aviso de verdade,
	# não só mais um cartão igual aos outros. Compacto por padrão (nome só); a explicação
	# completa já apareceu no banner de início de rodada — toque reabre se precisar.
	var mod_box := UIKit.panel(UIKit.OK.darkened(0.75), UIKit.OK, 10)
	mod_box.mouse_filter = Control.MOUSE_FILTER_STOP
	modifier_label = UIKit.label("", 14, UIKit.OK, HORIZONTAL_ALIGNMENT_CENTER)
	modifier_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mod_box.add_child(modifier_label)
	mod_box.gui_input.connect(func(event: InputEvent):
		if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			return
		Sfx.play("tick")
		modifier_expanded = not modifier_expanded
		_refresh_hud())
	root.add_child(mod_box)

	# Espaçador — empurra a mesa (vaza atual), a mão e meu rodapé pra baixo, como um
	# bloco só, junto do polegar — em vez de deixar um vão vazio entre o placar e a mesa.
	var vspacer := Control.new()
	vspacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vspacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vspacer)

	# Mesa de jogo — só a vaza atual, uma faixa compacta e fixa (não uma mesa oval
	# espalhada): cada carta jogada aparece numa posição fixa, em ordem de assento,
	# igual qualquer jogo de cartas mobile mostra "o que já foi jogado". -----------
	table_center = Panel.new()
	table_center.name = "TableCenter"
	table_center.custom_minimum_size = Vector2(0, 190)
	table_center.add_theme_stylebox_override("panel", UIKit.box(Color(0.06, 0.05, 0.12, 0.65), UIKit.PURPLE, 3, 24, 0))
	table_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(table_center)

	trick_label = UIKit.label("", 16, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(trick_label)

	status_label = UIKit.label("", 18, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status_label)

	# Mão — cartas sempre no tamanho real (nunca encolhidas pra caber); quando não cabem
	# todas na tela, a mão rola de lado (arrasto/swipe), igual qualquer app de cartas. ---
	var hand_scroll := ScrollContainer.new()
	hand_scroll.custom_minimum_size = Vector2(0, CardView.SIZE.y + CardView.MAX_LIFT + 16)
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(hand_scroll)
	hand_scroll.resized.connect(_layout_hand)  # tamanho real só fica pronto depois do 1º sort — nunca confiar em call_deferred sozinho
	hand_container = HBoxContainer.new()
	hand_container.name = "HandContainer"
	hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
	# Fica encostada embaixo (SHRINK_END) e não esticada — a folga extra do hand_scroll
	# vira espaço LIVRE ACIMA da carta, senão o arrasto pra jogar corta na borda de cima.
	hand_container.size_flags_vertical = Control.SIZE_SHRINK_END
	hand_scroll.add_child(hand_container)

	# Meu rodapé — minhas informações (pontos, fichas, pote), embaixo da minha mão, onde
	# o olho já está depois de escolher a carta — em vez de competir lá em cima com o
	# placar dos outros 3.
	var my_box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.GOLD, 12)
	var my_row := HBoxContainer.new()
	my_row.add_theme_constant_override("separation", 16)
	my_box.add_child(my_row)
	var my_left := VBoxContainer.new()
	my_left.add_theme_constant_override("separation", 1)
	my_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	my_row.add_child(my_left)
	var my_title := UIKit.label(str(config["names"][0]).to_upper(), 13, UIKit.MUTED)
	my_left.add_child(my_title)
	var my_total := UIKit.label("0,0 pts", 26, UIKit.INK)
	my_left.add_child(my_total)
	var my_rp := UIKit.label("+0,0 na rodada", 13, UIKit.MUTED)
	my_left.add_child(my_rp)
	var my_right := VBoxContainer.new()
	my_right.add_theme_constant_override("separation", 1)
	my_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	my_right.alignment = BoxContainer.ALIGNMENT_CENTER
	my_row.add_child(my_right)
	wager_label = UIKit.label("", 13, UIKit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	wager_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	my_right.add_child(wager_label)
	root.add_child(my_box)
	hud_badges[0] = my_box
	hud_titles[0] = my_title
	hud_totals[0] = my_total
	hud_round_pts[0] = my_rp
	seat_avatars[0] = my_box

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


## Reposiciona as cartas já em jogo quando a mesa muda de tamanho (ex.: virar o celular).
func _layout_table() -> void:
	if table_center == null:
		return
	for v in table_views:
		var cv: CardView = v["view"]
		cv.position = _slot_pos(int(v["player"]))


## Uma vaga fixa por assento, em fileira — igual qualquer app de cartas mostra a vaza
## atual, em vez de espalhar geometricamente numa mesa oval (isso é o que fazia o jogo
## parecer preso a paisagem mesmo rodando em celular).
func _slot_pos(player: int) -> Vector2:
	var n := maxi(engine.num_players, 1)
	var usable_w := maxf(table_center.size.x - 24.0, CardView.SIZE.x * n)
	var slot_w := usable_w / float(n)
	var cx := 12.0 + slot_w * (player + 0.5)
	return Vector2(cx - CardView.SIZE.x / 2.0, (table_center.size.y - CardView.SIZE.y) / 2.0)


## As cartas nunca encolhem: com poucas cartas, um espaçamento normal e a mão centralizada;
## com muitas (mão cheia do Vanilla), sobrepõe em leque até um limite que ainda dá pra
## reconhecer cada carta — e se mesmo assim não couber, a rolagem horizontal cobre o resto.
func _layout_hand() -> void:
	if hand_container == null:
		return
	var n := hand_container.get_child_count()
	if n == 0:
		return
	var avail := (hand_container.get_parent() as Control).size.x - 8.0
	var card_w := CardView.SIZE.x
	var sep := 10
	if n > 1:
		var gaps := n - 1
		var natural := float(n * card_w) + gaps * sep
		if natural > avail:
			var max_overlap := card_w * 0.5
			sep = maxi(int(-max_overlap), int(floor((avail - n * card_w) / float(gaps))))
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
		_apply_modifier_badge(cv, card)
	_layout_hand.call_deferred()


## Mostra na própria carta o valor real dela sob o modificador + item ativos, pra decisão
## de qual jogar ser visível e não só matemática escondida no placar. Mantém o texto do
## mesmo tamanho do padrão ("X,Y pts") pra não esticar a carta — só o ícone e a cor mudam.
func _apply_modifier_badge(cv: CardView, card: CardData, player: int = 0) -> void:
	var base := card.points()
	var eff := engine.card_value(card, player)
	if is_equal_approx(eff, base):
		return
	var boosted := eff > base
	cv.points_label.text = "%s %s pts" % ["▲" if boosted else "▼", UIKit.fmt_dec(eff, 1)]
	cv.points_label.add_theme_color_override("font_color", UIKit.OK if boosted else UIKit.DANGER)


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
		(hud_badges[p] as Control).modulate = Color(1, 1, 1, 1) if turn else Color(0.78, 0.76, 0.85, 1)
		var lead_accent := UIKit.GOLD if p == engine.folego_player else UIKit.MUTED
		var item_icon: String = ChaosItems.ICONS.get(engine.player_items[p], "") if p < engine.player_items.size() else ""
		var prefix := ("🔥 " if p == engine.folego_player else "") + (item_icon + " " if item_icon != "" else "")
		(hud_titles[p] as Label).text = "%s%s" % [prefix, str(config["names"][p]).to_upper()]
		(hud_titles[p] as Label).add_theme_color_override("font_color", lead_accent)
		if p > 0:
			(hud_cards[p] as Label).text = "%d cartas" % (engine.hands[p] as Array).size()
	info_label.text = "CAOS  ·  Rodada %d/%d  ·  Vaza %d/%d" % [engine.round_index + 1, ChaosEngine.ROUNDS, mini(engine.trick_number + 1, ChaosEngine.HAND_SIZE), ChaosEngine.HAND_SIZE]
	var mod_name := "✦ %s" % ChaosModifiers.label(engine.modifier, engine.weak_suit)
	modifier_label.text = "%s — %s" % [mod_name, ChaosModifiers.DESCRIPTIONS[engine.modifier]] if modifier_expanded else "%s  (toque p/ detalhe)" % mod_name
	var profile := SaveManager.section("profile")
	wager_label.text = "🪙 Suas fichas: %d   ·   Pote da mesa: %d (buy-in %d)" % [int(profile["fichas"]), int(engine.pot), int(engine.buy_in)]
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
	var avatar: Control = seat_avatars[player]
	var anchor_pos: Vector2 = avatar.global_position - popup_layer.global_position + avatar.size / 2.0
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
	var body := "Modificador: %s\n%s" % [mod_text, str(ChaosModifiers.TIPS[engine.modifier])]
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
	panel.position.y = 232
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
		await _choose_items()
		if not is_inside_tree():
			return
		await _announce_round()
		if not is_inside_tree():
			return
		_run_round.call_deferred()


## Entre rodadas (a partir da 2ª): cada jogador escolhe 1 de 2 itens sorteados pra usar
## só nessa rodada — a decisão ativa que faltava, além de reagir ao modificador da vez.
func _choose_items() -> void:
	var options := ChaosItems.offer(engine.rng)
	for p in range(1, engine.num_players):
		engine.set_item(p, ChaosItems.bot_choose(options, engine.modifier, bot_rng))
	if GameState.autoplay:
		engine.set_item(0, ChaosItems.bot_choose(options, engine.modifier, bot_rng))
		return
	var choice: int = await _show_item_modal(options)
	if not is_inside_tree():
		return
	engine.set_item(0, choice)


func _show_item_modal(options: Array) -> int:
	var ov := UIKit.overlay()
	overlay_layer.add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.GOLD, 24)
	box.custom_minimum_size = Vector2(420, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	v.add_child(UIKit.label("ESCOLHA SEU ITEM", 24, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("Vale só pra você, só na Rodada %d/%d — modificador: %s" % [engine.round_index + 1, ChaosEngine.ROUNDS, ChaosModifiers.label(engine.modifier, engine.weak_suit)], 13, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(HSeparator.new())
	for item in options:
		var btn := UIKit.button("%s  %s" % [ChaosItems.ICONS[item], ChaosItems.NAMES[item]], UIKit.OK)
		btn.pressed.connect(func(): item_chosen.emit(item))
		v.add_child(btn)
		var desc := UIKit.label(ChaosItems.DESCRIPTIONS[item], 12, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(360, 0)
		v.add_child(desc)
	ov.add_child(UIKit.centered(box))
	box.scale = Vector2(0.85, 0.85)
	box.pivot_offset = box.custom_minimum_size / 2.0
	create_tween().tween_property(box, "scale", Vector2.ONE, GameState.anim(0.2)).set_trans(Tween.TRANS_BACK)
	var chosen: int = await item_chosen
	if is_inside_tree():
		ov.queue_free()
	return chosen


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
	var avatar: Control = seat_avatars[player]
	return avatar.global_position


func _animate_play(player: int, card: CardData, from: Vector2) -> void:
	var cv: CardView = CARD_SCENE.instantiate()
	cv.setup(card, true)
	cv.interactive = false
	table_center.add_child(cv)
	cv.set_playable(true)
	cv.zoom_requested.connect(_show_zoom)
	_apply_modifier_badge(cv, card, -1)  # na mesa só mostra o efeito do modificador — o item só conta se essa carta vencer a vaza
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
	if bool(result.get("roubo_applied", false)):
		var target: int = result["roubo_target"]
		_speech_bubble(winner, "🗡 roubou %s pts de %s!" % [UIKit.fmt_dec(float(result["roubo_amount"]), 1), str(config["names"][target]).to_upper()])
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
	var result := engine.match_result.duplicate()
	result["payout"] = engine.payout_for(engine.placement_of(0))
	result["buy_in"] = engine.buy_in
	var summary := GameState.report_chaos_match(result)
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
• Cada rodada sorteia uma regra especial diferente (nunca repete duas vezes na mesma partida), sempre visível na barra logo acima da mesa.
• As cartas afetadas mostram o valor real (com bônus ou penalidade) direto na carta — decida o que jogar olhando pra esse número, não só pro placar.

ITENS
• A partir da Rodada 2, antes de cada rodada você escolhe 1 de 2 itens sorteados — uma vantagem ativa só sua, só naquela rodada (Escudo, Trunfo Afiado, Fôlego Pessoal ou Roubo de Vaza). Os bots escolhem também.

FÔLEGO
• A partir da 2ª rodada, quem estiver em último no total ganha Fôlego: os pontos que capturar nessa rodada valem x1,5. É a chance de virar o jogo.

FICHAS
• Entrar na mesa custa um buy-in em fichas, que forma o pote da partida. No fim, o pote é pago por colocação: 1º leva 50%, 2º 30%, 3º 15%, 4º 5%. Seu saldo de fichas e o pote ficam sempre visíveis na barra acima da mesa.

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
