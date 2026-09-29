extends Control
## ChaosScene.tscn — mesa do modo Caos: 5 rodadas curtas de 8 cartas, todo mundo joga
## pra si (sem Atacante/Defesa), com um modificador novo a cada rodada e um bônus de
## Fôlego pra quem estiver por baixo no total. Layout pensado pra celular (retrato):
## uma pilha vertical — status dos jogadores no topo, área de jogo compacta no meio,
## sua mão embaixo — em vez de uma mesa oval espalhada, que só faz sentido em paisagem.

signal human_card_chosen(card: CardData)
signal item_chosen(item: int)
signal match_finished(summary: Dictionary)

const CARD_SCENE := preload("res://scenes/Card.tscn")

## As cartas da mão têm o tamanho cheio; as da mesa ficam menores pra caber 4 lado a lado.
const TABLE_SCALE := 0.54
const SEAT_COLORS := [Color("#F0C879"), Color("#7FD1AE"), Color("#FF7A9C"), Color("#8FA0FF")]
const TURN_SECONDS := 10.0   # tempo pra jogar; estourou, joga a carta mais fraca

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
var hand_container: Control
var selected_view: CardView
var throw_from := Vector2.ZERO
var has_throw_from := false
var status_label: Label
var banner_box: PanelContainer
var banner_title: Label
var banner_sub: Label
var turn_bar: ProgressBar
var turn_left := 0.0
var main_area: BoxContainer
var side_col: VBoxContainer
var seat_nodes: Array = []
var first_round_done := false
var info_label: Label
var trick_dots: HBoxContainer
var shown_totals: Array = []
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
	box.custom_minimum_size = Vector2(580, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	box.add_child(v)
	v.add_child(UIKit.label("FICHAS INSUFICIENTES", 28, UIKit.DANGER, HORIZONTAL_ALIGNMENT_CENTER))
	var l := UIKit.label("Você precisa de %d fichas pra entrar na Mesa Caos. Jogue Vanilla ou Ranqueado, ou volte ao menu e peça um empréstimo da casa." % int(config["buy_in"]), 18, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(520, 0)
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
	root.add_theme_constant_override("separation", 14)
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
	topbar.add_theme_constant_override("separation", 12)
	root.add_child(topbar)
	var menu_btn := Widgets.icon_button("☰")
	menu_btn.pressed.connect(_open_pause)
	topbar.add_child(menu_btn)
	var info_box := UIKit.panel(Color("#1B1258"), UIKit.BLACK, 8)
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var info_v := VBoxContainer.new()
	info_v.add_theme_constant_override("separation", 4)
	info_box.add_child(info_v)
	info_label = UIKit.label("", 28, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	info_v.add_child(info_label)
	trick_dots = HBoxContainer.new()
	trick_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	trick_dots.add_theme_constant_override("separation", 8)
	info_v.add_child(trick_dots)
	topbar.add_child(info_box)
	var help_btn := Widgets.icon_button("?", UIKit.GOLD.darkened(0.1))
	help_btn.pressed.connect(_open_help)
	topbar.add_child(help_btn)

	# Corpo: em tela larga vira duas colunas (placar à esquerda, mesa à direita); no
	# celular empilha. Cada bloco tem espaço próprio — nada flutua por cima de outro.
	main_area = BoxContainer.new()
	main_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_area.add_theme_constant_override("separation", 20)
	root.add_child(main_area)
	side_col = VBoxContainer.new()
	side_col.add_theme_constant_override("separation", 12)
	main_area.add_child(side_col)
	var center_col := VBoxContainer.new()
	center_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_col.add_theme_constant_override("separation", 12)
	main_area.add_child(center_col)

	# (Os 3 rivais ficam sentados ao redor da mesa — veja _build_seats.)

	# Regra da rodada — aviso fixo, sempre visível.
	var mod_box := UIKit.panel(UIKit.OK.darkened(0.75), UIKit.OK, 10)
	mod_box.mouse_filter = Control.MOUSE_FILTER_STOP
	modifier_label = UIKit.label("", 22, UIKit.OK, HORIZONTAL_ALIGNMENT_CENTER)
	modifier_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mod_box.add_child(modifier_label)
	mod_box.gui_input.connect(func(event: InputEvent):
		if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			return
		Sfx.play("tick")
		modifier_expanded = not modifier_expanded
		_refresh_hud())
	side_col.add_child(mod_box)


	# Faixa de avisos — espaço RESERVADO (nunca cobre carta nem placar): resultado da
	# vaza, combos, evento surpresa. Uma mensagem por vez, sempre no mesmo lugar.
	banner_box = UIKit.panel(UIKit.PURPLE_DEEP, UIKit.MUTED, 12)
	banner_box.custom_minimum_size = Vector2(0, 92)
	var bv := VBoxContainer.new()
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.add_theme_constant_override("separation", 2)
	banner_box.add_child(bv)
	banner_title = UIKit.label("", 26, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	banner_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bv.add_child(banner_title)
	banner_sub = UIKit.label("", 17, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bv.add_child(banner_sub)
	center_col.add_child(banner_box)

	# Mesa de jogo — só a vaza atual, cada carta numa vaga fixa por assento.
	table_center = Panel.new()
	table_center.name = "TableCenter"
	table_center.custom_minimum_size = Vector2(0, 400)
	table_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table_center.add_theme_stylebox_override("panel", UIKit.box(Color(0.10, 0.08, 0.30, 0.85), Color("#5B4FC9"), 3, 200, 0))
	table_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_col.add_child(table_center)
	_build_seats()
	table_center.resized.connect(_layout_table)

	status_label = UIKit.label("", 21, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(0, 56)
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_col.add_child(status_label)

	# Relógio da jogada: barra que esvazia — some fora da sua vez.
	turn_bar = ProgressBar.new()
	turn_bar.show_percentage = false
	turn_bar.min_value = 0.0
	turn_bar.max_value = TURN_SECONDS
	turn_bar.custom_minimum_size = Vector2(0, 22)
	turn_bar.modulate.a = 0.0
	turn_bar.add_theme_stylebox_override("background", UIKit.box(UIKit.PURPLE_DEEP, UIKit.PURPLE, 2, 7, 0))
	turn_bar.add_theme_stylebox_override("fill", UIKit.box(UIKit.GOLD, UIKit.GOLD, 0, 7, 0))
	center_col.add_child(turn_bar)

	# Mão — cartas sempre no tamanho real (nunca encolhidas pra caber); quando não cabem
	# todas na tela, a mão rola de lado (arrasto/swipe), igual qualquer app de cartas.
	# Duas variantes (Configurações): fileira reta, ou leque de baralho em arco. --------
	var hand_scroll := HandScroller.new()
	hand_scroll.custom_minimum_size = Vector2(0, CardView.SIZE.y + CardView.MAX_LIFT + 6)
	root.add_child(hand_scroll)
	hand_scroll.resized.connect(_layout_hand)  # tamanho real só fica pronto depois do 1º sort — nunca confiar em call_deferred sozinho
	hand_container = Control.new()
	hand_container.name = "HandContainer"
	hand_container.mouse_filter = Control.MOUSE_FILTER_PASS
	hand_scroll.set_content(hand_container)

	# Meu rodapé — minhas informações (pontos, fichas, pote), embaixo da minha mão, onde
	# o olho já está depois de escolher a carta — em vez de competir lá em cima com o
	# placar dos outros 3.
	var my_box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.GOLD, 12)
	var my_row := HBoxContainer.new()
	my_row.add_theme_constant_override("separation", 16)
	my_box.add_child(my_row)
	my_row.add_child(Portrait.new().setup(0, UIKit.GOLD, 84.0))
	var my_left := VBoxContainer.new()
	my_left.add_theme_constant_override("separation", 1)
	my_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	my_row.add_child(my_left)
	var my_title := UIKit.label(str(config["names"][0]).to_upper(), 20, UIKit.MUTED)
	my_left.add_child(my_title)
	var my_total := UIKit.label("0,0 pts", 40, UIKit.GOLD)
	my_left.add_child(my_total)
	var my_rp := UIKit.label("+0,0 na rodada", 20, UIKit.MUTED)
	my_left.add_child(my_rp)
	var my_right := VBoxContainer.new()
	my_right.add_theme_constant_override("separation", 1)
	my_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	my_right.alignment = BoxContainer.ALIGNMENT_CENTER
	my_row.add_child(my_right)
	wager_label = UIKit.label("", 16, UIKit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
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

	var hand_scroller := hand_container.get_parent() as HandScroller
	hand_scroller.ghost_layer = popup_layer
	hand_scroller.throw_requested.connect(_on_card_thrown)

	overlay_layer = Control.new()
	overlay_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_layer.z_index = 30
	add_child(overlay_layer)

	_apply_orientation()
	_layout_table.call_deferred()


func _is_wide() -> bool:
	var sz := get_viewport_rect().size
	return sz.x > sz.y


func _apply_orientation() -> void:
	var wide := _is_wide()
	main_area.vertical = not wide
	side_col.visible = false  # a regra da rodada já fica na faixa de avisos, em repouso
	modifier_expanded = wide
	_refresh_hud()
	table_center.custom_minimum_size.y = 420 if wide else 400
	_layout_table()


func _on_resize() -> void:
	_apply_orientation()
	_layout_table()
	_layout_hand()


## Rivais sentados ao redor da mesa: avatar redondo (inicial + cor), nome e pontos embaixo.
func _build_seats() -> void:
	seat_nodes.resize(engine.num_players)
	for p in range(1, engine.num_players):
		var seat := VBoxContainer.new()
		seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seat.add_theme_constant_override("separation", 2)
		seat.alignment = BoxContainer.ALIGNMENT_CENTER
		var ring := PanelContainer.new()
		ring.custom_minimum_size = Vector2(84, 84)
		ring.pivot_offset = Vector2(42, 42)
		ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var face := Portrait.new().setup(p, Color(0, 0, 0, 0), 68.0)
		face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ring.add_child(face)
		seat.add_child(ring)
		var name_l := UIKit.label("", 20, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
		seat.add_child(name_l)
		var pts_l := UIKit.label("0,0 pts", 24, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		seat.add_child(pts_l)
		seat.custom_minimum_size = Vector2(130, 0)
		table_center.add_child(seat)
		seat_nodes[p] = seat
		hud_badges[p] = seat
		hud_titles[p] = name_l
		hud_totals[p] = pts_l
		hud_round_pts[p] = Label.new()
		hud_cards[p] = Label.new()
		seat_avatars[p] = ring


func _seat_pos(p: int) -> Vector2:
	var sz := table_center.size
	var seat: Control = seat_nodes[p]
	var w := 130.0
	match p:
		1: return Vector2(10.0, sz.y * 0.5 - 20.0)
		2: return Vector2((sz.x - w) / 2.0, 6.0)
		_: return Vector2(sz.x - w - 10.0, sz.y * 0.5 - 20.0)


## Reposiciona as cartas já em jogo quando a mesa muda de tamanho (ex.: virar o celular).
func _layout_table() -> void:
	if table_center == null:
		return
	for p in range(1, engine.num_players):
		if seat_nodes.size() > p and seat_nodes[p] != null:
			(seat_nodes[p] as Control).position = _seat_pos(p)
	for v in table_views:
		var cv: CardView = v["view"]
		cv.position = _slot_pos(int(v["player"]))


## Uma vaga fixa por assento, em fileira — igual qualquer app de cartas mostra a vaza
## atual, em vez de espalhar geometricamente numa mesa oval (isso é o que fazia o jogo
## parecer preso a paisagem mesmo rodando em celular).
func _slot_pos(player: int) -> Vector2:
	var n := maxi(engine.num_players, 1)
	var card_w := CardView.SIZE.x * TABLE_SCALE
	var slot_w := card_w + 14.0
	var start := (table_center.size.x - slot_w * n) / 2.0 + 7.0 - (CardView.SIZE.x - card_w) / 2.0
	var y := table_center.size.y * 0.60 - CardView.SIZE.y / 2.0
	return Vector2(start + slot_w * player, y)


## As cartas nunca encolhem: fileira reta ou leque, escolhido em Configurações — nos dois
## casos a sobreposição cresce com a mão até um limite que ainda dá pra reconhecer cada
## carta, e se mesmo assim não couber, a rolagem horizontal cobre o resto.
func _layout_hand() -> void:
	if hand_container == null:
		return
	var cards := hand_container.get_children()
	if cards.is_empty():
		return
	var parent := hand_container.get_parent() as Control
	var avail_w := parent.size.x - 8.0
	# Nunca usar parent.size.y aqui: com rolagem vertical desligada, o ScrollContainer
	# cresce pra caber o conteúdo — usar o próprio tamanho dele como altura disponível
	# vira um loop (aumenta a altura, o que aumenta o parent, que aumenta a altura de
	# novo…) até estourar um limite interno do Godot (~800000px) e empurrar a mão e o
	# rodapé pra bem fora da tela. A altura útil é sempre a da carta + a folga do lift.
	var avail_h := CardView.SIZE.y + CardView.MAX_LIFT
	var mode := str(GameState.settings().get("hand_layout", "row"))
	var content_w := HandLayout.apply(cards, avail_w, avail_h, mode, CardView.SIZE)
	(parent as HandScroller).set_content_size(Vector2(content_w, avail_h))


func _rebuild_hand() -> void:
	for c in hand_container.get_children():
		hand_container.remove_child(c)
		c.queue_free()
	selected_view = null
	var legal := engine.legal_for(0) if human_turn else []
	for card in engine.hands[0]:
		var cv: CardView = CARD_SCENE.instantiate()
		cv.setup(card, true)
		hand_container.add_child(cv)
		cv.set_playable(human_turn and legal.has(card))
		cv.tapped.connect(_on_card_tapped)
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
	var dark_face := card.is_trunfo() or card.is_louco()
	var good := UIKit.OK if dark_face else Color("#1E8A5C")
	var bad := UIKit.DANGER if dark_face else Color("#D42A3C")
	cv.points_label.add_theme_color_override("font_color", good if boosted else bad)


func _current_turn_player() -> int:
	if engine.is_round_over():
		return -1
	return engine.current


func _refresh_hud() -> void:
	var turn_player := _current_turn_player()
	for p in range(engine.num_players):
		var total_lbl := hud_totals[p] as Label
		var new_total: float = engine.totals[p]
		while shown_totals.size() <= p:
			shown_totals.append(0.0)
		if is_equal_approx(new_total, float(shown_totals[p])):
			total_lbl.text = "%s pts" % UIKit.fmt_dec(new_total, 1)
		else:
			FX.count(total_lbl, float(shown_totals[p]), new_total, func(v: float): return "%s pts" % UIKit.fmt_dec(v, 1))
			FX.pop(total_lbl, 1.3)
			shown_totals[p] = new_total
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
	info_label.text = "RODADA %d/%d" % [engine.round_index + 1, ChaosEngine.ROUNDS]
	Widgets.progress_dots(trick_dots, ChaosEngine.HAND_SIZE, engine.trick_number)
	var mod_name := "✦ %s" % ChaosModifiers.label(engine.modifier, engine.weak_suit)
	modifier_label.text = "%s — %s" % [mod_name, ChaosModifiers.DESCRIPTIONS[engine.modifier]] if modifier_expanded else "%s" % mod_name
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
		var ring := UIKit.box(UIKit.PURPLE_DEEP, accent, 5 if active else 3, 60, 0)
		ring.set_corner_radius_all(40)
		avatar.add_theme_stylebox_override("panel", ring)
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


# ------------------------------------------------------------------ rodadas / modificador

## Tela de transição de início de rodada: ocupa a tela inteira, explica a regra da
## rodada e o que muda, e avança sozinha (ou ao tocar). Nada de jogo por trás.
func _announce_round() -> void:
	_refresh_hud()
	_rebuild_hand()
	var final := engine.is_final_round()
	var kicker := "RODADA FINAL" if final else "RODADA %d DE %d" % [engine.round_index + 1, ChaosEngine.ROUNDS]
	var lines: Array = []
	lines.append({"head": "REGRA DA RODADA", "title": "✦ %s" % ChaosModifiers.label(engine.modifier, engine.weak_suit), "text": "%s\n%s" % [ChaosModifiers.DESCRIPTIONS[engine.modifier], ChaosModifiers.TIPS[engine.modifier]], "color": UIKit.OK})
	if final:
		lines.append({"head": "RODADA FINAL", "title": "PONTOS EM DOBRO", "text": "Tudo que você marcar nessa rodada vale ×2. Ninguém está fora até a última vaza.", "color": UIKit.GOLD})
	if engine.folego_player != -1:
		lines.append({"head": "FÔLEGO", "title": "🔥 %s" % str(config["names"][engine.folego_player]).to_upper(), "text": "Está em último e ganha ×%s nos pontos dessa rodada." % UIKit.fmt_dec(ChaosEngine.FOLEGO_MULT, 1), "color": UIKit.GOLD})
	lines.append({"head": "SURPRESA", "title": "? NA VAZA %d" % (ChaosEngine.EVENT_TRICK + 1), "text": "Algo vai mudar as regras da vaza 4. Você só descobre quando chegar lá.", "color": UIKit.DANGER})
	await _transition(kicker, lines, 3.4 if not first_round_done else 3.0)
	first_round_done = true
	_banner_clear()


## Tela cheia de transição. `blocks`: [{head, title, text, color}]. Fecha ao tocar ou
## depois de `hold` segundos. No autoplay (testes) só espera um instante.
func _transition(kicker: String, blocks: Array, hold: float) -> void:
	if GameState.autoplay or not is_inside_tree():
		await _wait(0.05)
		return
	var ov := ColorRect.new()
	ov.color = Color(0.03, 0.02, 0.07, 0.97)
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_layer.add_child(ov)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	var width := minf(get_viewport_rect().size.x - 80.0, 680.0)
	v.custom_minimum_size = Vector2(width, 0)
	v.add_child(UIKit.label(kicker, 46, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	for b in blocks:
		var card := UIKit.panel(UIKit.PURPLE_DEEP, b["color"], 18)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 4)
		card.add_child(cv)
		cv.add_child(UIKit.label(b["head"], 16, b["color"], HORIZONTAL_ALIGNMENT_CENTER))
		cv.add_child(UIKit.label(b["title"], 30, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
		var t := UIKit.label(b["text"], 18, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(t)
		v.add_child(card)
	var go := UIKit.button("ENTENDI, CONTINUAR")
	v.add_child(go)
	ov.add_child(UIKit.centered(v))
	go.grab_focus.call_deferred()
	ov.modulate.a = 0.0
	create_tween().tween_property(ov, "modulate:a", 1.0, GameState.anim(0.18))
	Sfx.play("chip")
	# Só avança quando o jogador aperta o botão — sem tempo limite, dá pra ler com calma.
	await go.pressed
	if not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_property(ov, "modulate:a", 0.0, GameState.anim(0.18))
	await tw.finished
	ov.queue_free()


## Mensagem na faixa reservada acima da mesa (nunca cobre nada). `color` pinta a borda.
func _banner(title: String, sub: String, color: Color) -> void:
	banner_title.text = title
	banner_title.add_theme_color_override("font_color", color)
	banner_sub.text = sub
	banner_box.add_theme_stylebox_override("panel", UIKit.box(UIKit.PURPLE_DEEP, color, 3, 4, 12))
	banner_box.modulate.a = 0.0
	create_tween().tween_property(banner_box, "modulate:a", 1.0, GameState.anim(0.12))


func _banner_clear() -> void:
	# Em repouso a faixa lembra a regra da rodada (informação útil no lugar de um vazio).
	banner_title.text = "✦ %s" % ChaosModifiers.label(engine.modifier, engine.weak_suit)
	banner_title.add_theme_color_override("font_color", UIKit.OK)
	banner_sub.text = str(ChaosModifiers.DESCRIPTIONS[engine.modifier])
	banner_box.modulate.a = 1.0
	banner_box.add_theme_stylebox_override("panel", UIKit.box(UIKit.PURPLE_DEEP, UIKit.MUTED, 3, 4, 12))


# ------------------------------------------------------------------ loop de turnos

## Vaza 4: revela o evento surpresa numa tela cheia e deixa um aviso fixo durante a vaza.
func _reveal_event() -> void:
	var ev := engine.event
	await _transition("PLOT TWIST!", [{"head": "VAZA %d" % (ChaosEngine.EVENT_TRICK + 1), "title": "%s %s" % [ChaosEvents.ICONS[ev], ChaosEvents.NAMES[ev]], "text": ChaosEvents.DESCRIPTIONS[ev], "color": ChaosEvents.COLORS[ev]}], 2.6)
	if is_inside_tree():
		_banner("%s %s" % [ChaosEvents.ICONS[ev], ChaosEvents.NAMES[ev]], ChaosEvents.DESCRIPTIONS[ev], ChaosEvents.COLORS[ev])


func _run_round() -> void:
	while not engine.is_round_over():
		if not is_inside_tree():
			return
		if engine.plays.is_empty() and engine.trick_number == ChaosEngine.EVENT_TRICK:
			await _reveal_event()
			if not is_inside_tree():
				return
		var p := engine.current
		_refresh_hud()
		var card: CardData
		if p == 0 and not GameState.autoplay:
			card = await _wait_human()
		else:
			await _wait(0.9 if p == 0 else bot_rng.randf_range(0.9, 1.5))
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
	box.custom_minimum_size = Vector2(580, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	v.add_child(UIKit.label("ESCOLHA SEU ITEM", 30, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("Vale só pra você, só na Rodada %d/%d — modificador: %s" % [engine.round_index + 1, ChaosEngine.ROUNDS, ChaosModifiers.label(engine.modifier, engine.weak_suit)], 16, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(HSeparator.new())
	for item in options:
		var btn := UIKit.button("%s  %s" % [ChaosItems.ICONS[item], ChaosItems.NAMES[item]], UIKit.OK)
		btn.pressed.connect(func(): item_chosen.emit(item))
		v.add_child(btn)
		var desc := UIKit.label(ChaosItems.DESCRIPTIONS[item], 15, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(520, 0)
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
		status_label.text = "Sua vez — abra a vaza com qualquer carta"
	elif ls == CardData.Suit.TRUNFO:
		status_label.text = "Sua vez — cubra com um Trunfo maior, se tiver"
	else:
		status_label.text = "Sua vez — siga %s (ou corte com Trunfo, ou jogue O Louco)" % CardData.SUIT_NAMES[ls]
	turn_left = TURN_SECONDS
	turn_bar.modulate.a = 1.0
	_rebuild_hand()
	var card: CardData = await human_card_chosen
	human_turn = false
	turn_bar.modulate.a = 0.0
	status_label.text = ""
	return card


func _process(delta: float) -> void:
	if not human_turn or paused or finished or turn_bar == null:
		return
	turn_left -= delta
	turn_bar.value = maxf(turn_left, 0.0)
	var urgent := turn_left <= 3.0
	turn_bar.add_theme_stylebox_override("fill", UIKit.box(UIKit.DANGER if urgent else UIKit.GOLD, UIKit.GOLD, 0, 7, 0))
	if turn_left <= 0.0:
		var legal := engine.legal_for(0)
		if legal.is_empty():
			return
		var weakest: CardData = legal[0]
		for c in legal:
			if (c as CardData).points() < weakest.points():
				weakest = c
		human_turn = false
		_banner("TEMPO ESGOTADO", "Jogamos sua carta mais fraca por você.", UIKit.DANGER)
		human_card_chosen.emit(weakest)


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
	selected_view = view
	(hand_container.get_parent() as HandScroller).reveal(view.position.x, CardView.SIZE.x)
	Sfx.play("tick")


## Carta arrastada pra cima e solta além do limite: joga, saindo do ponto onde foi solta.
func _on_card_thrown(view: CardView, drop_global: Vector2) -> void:
	if not human_turn or not view.playable:
		return
	throw_from = drop_global
	has_throw_from = true
	_on_card_play(view)


func _on_card_play(view: CardView) -> void:
	if not human_turn or not view.playable:
		return
	human_turn = false
	selected_view = null
	human_card_chosen.emit(view.data)


func _source_position(player: int, card: CardData) -> Vector2:
	if player == 0:
		if has_throw_from:
			has_throw_from = false
			return throw_from
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
	tw.parallel().tween_property(cv, "scale", Vector2(TABLE_SCALE, TABLE_SCALE), GameState.anim(0.28))
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
		pulse.tween_property(win_view, "scale", Vector2(TABLE_SCALE, TABLE_SCALE) * 1.18, GameState.anim(0.12))
		pulse.tween_property(win_view, "scale", Vector2(TABLE_SCALE, TABLE_SCALE) * 1.08, GameState.anim(0.12))

	var wname := str(config["names"][winner]).to_upper()
	var notes: Array = []
	if bool(result.get("final", false)):
		notes.append("rodada final ×2")
	if int(result.get("event", 0)) == ChaosEvents.Event.DOURADA:
		notes.append("vaza dourada ×3")
	if bool(result.get("folego_applied", false)):
		notes.append("fôlego 🔥")
	var sub := "Pontos da vaza: %s" % UIKit.fmt_dec(float(result["base_points"]), 1)
	if float(result.get("mult", 1.0)) > 1.0:
		sub += " ×%s" % UIKit.fmt_dec(float(result["mult"]), 2)
	if not notes.is_empty():
		sub += "  (%s)" % ", ".join(notes)
	_banner("%s venceu · +%s pts" % [wname, UIKit.fmt_dec(points, 1)], sub, UIKit.GOLD if winner == 0 else UIKit.INK)
	Sfx.play("chip")
	var punch := clampf(points / 24.0, 0.0, 1.0)
	if punch > 0.25:
		FX.shake(main_area, punch)
	FX.burst(popup_layer, table_center.global_position - popup_layer.global_position + table_center.size / 2.0, UIKit.GOLD if winner == 0 else UIKit.CHIPS, 8 + int(punch * 20))
	await _wait(1.0)
	if not is_inside_tree():
		return
	var extras: Array = []
	for id in result.get("combos", []):
		extras.append([str(ChaosEvents.COMBO_NAMES[id]) + "!", "%s — %s" % [wname, ChaosEvents.COMBO_DESCRIPTIONS[id]], UIKit.OK])
	if bool(result.get("roubo_applied", false)):
		extras.append(["🗡 ROUBO DE VAZA!", "%s roubou %s pts de %s" % [wname, UIKit.fmt_dec(float(result["roubo_amount"]), 1), str(config["names"][int(result["roubo_target"])]).to_upper()], UIKit.DANGER])
	if float(result.get("saque_amount", 0.0)) > 0.0:
		extras.append(["🗡 SAQUE!", "%s levou %s pts dos rivais" % [wname, UIKit.fmt_dec(float(result["saque_amount"]), 1)], UIKit.DANGER])
	for e in extras:
		_banner(e[0], e[1], e[2])
		Sfx.play("win")
		await _wait(1.3)
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
	_banner_clear()
	_refresh_hud()


# ------------------------------------------------------------------ resumo de rodada / fim

func _show_round_summary() -> void:
	if GameState.autoplay:
		await _wait(0.05)
		return
	var r := engine.round_result
	var ov := UIKit.overlay()
	overlay_layer.add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.GOLD, 24)
	box.custom_minimum_size = Vector2(580, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	box.add_child(v)
	v.add_child(UIKit.label("FIM DA RODADA %d/%d" % [int(r["round"]) + 1, ChaosEngine.ROUNDS], 30, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label(ChaosModifiers.label(int(r["modifier"]), int(r["weak_suit"])), 18, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(HSeparator.new())
	var order := range(engine.num_players)
	var totals: Array = r["totals"]
	order.sort_custom(func(a: int, b: int) -> bool: return float(totals[a]) > float(totals[b]))
	for p in order:
		var gained: float = (r["round_points"] as Array)[p]
		var line := "%s%s  %s pts  (+%s)" % ["👑 " if p == order[0] else "", str(config["names"][p]).to_upper(), UIKit.fmt_dec(float(totals[p]), 1), UIKit.fmt_dec(gained, 1)]
		v.add_child(UIKit.label(line, 20, UIKit.GOLD if p == 0 else UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
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
	box.custom_minimum_size = Vector2(580, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	var title := "%dº LUGAR" % (int(summary["placement"]) + 1)
	if summary["won"]:
		title = "VOCÊ VENCEU!"
	v.add_child(UIKit.label(title, 32, UIKit.GOLD if summary["won"] else UIKit.DANGER, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(HSeparator.new())
	var order: Array = engine.match_result["standings"]
	var totals: Array = engine.match_result["totals"]
	for i in range(order.size()):
		var p: int = order[i]
		var line := "%d. %s%s — %s pts" % [i + 1, "👑 " if i == 0 else "", str(config["names"][p]).to_upper(), UIKit.fmt_dec(float(totals[p]), 1)]
		v.add_child(UIKit.label(line, 22, UIKit.GOLD if p == 0 else UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(HSeparator.new())
	for line in summary["lines"]:
		v.add_child(UIKit.label(str(line), 20, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
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
	var desc := UIKit.label(view.describe(), 22, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(520, 0)
	v.add_child(desc)
	v.add_child(UIKit.label("toque para fechar", 15, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
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
• 5 rodadas curtas de 8 cartas cada — sem licitação, sem monte, todo mundo joga pra si.
• Vence a partida quem somar mais pontos no total das 5 rodadas.

MODIFICADOR
• Cada rodada sorteia uma regra especial diferente (nunca repete duas vezes na mesma partida), sempre visível na barra logo acima da mesa.
• As cartas afetadas mostram o valor real (com bônus ou penalidade) direto na carta — decida o que jogar olhando pra esse número, não só pro placar.

ITENS
• A partir da Rodada 2, antes de cada rodada você escolhe 1 de 2 itens sorteados — uma vantagem ativa só sua, só naquela rodada (Escudo, Trunfo Afiado, Fôlego Pessoal ou Roubo de Vaza). Os bots escolhem também.

PLOT TWIST (VAZA 4)
• Em toda rodada, na vaza 4, acontece um evento surpresa que você só descobre na hora: VAZA DOURADA (pontos ×3), VAZA INVERTIDA (vence a MENOR carta do naipe) ou SAQUE (quem vencer rouba 2 pts de cada rival). A tela avisa antes da vaza começar.

COMBOS (aparecem no aviso acima da mesa)
• MÃO QUENTE: 3 vazas seguidas na rodada — pontos ×1,5.
• CORTADO: você quebra a sequência de 2+ vitórias de alguém — +2 pts.
• CORTE DE REI: você corta um Rei com Trunfo — +3 pts.

RODADA FINAL
• Todos os pontos da 5ª rodada valem ×2.

RELÓGIO
• Você tem 10 segundos por jogada (a barra embaixo da mesa esvazia). Estourou, jogamos sua carta mais fraca.

FÔLEGO
• A partir da 2ª rodada, quem estiver em último no total ganha Fôlego: os pontos que capturar nessa rodada valem x1,5. É a chance de virar o jogo.

FICHAS
• Entrar na mesa custa um buy-in em fichas, que forma o pote da partida. No fim, o pote é pago por colocação: 1º leva 50%, 2º 30%, 3º 15%, 4º 5%. Seu saldo de fichas e o pote ficam sempre visíveis na barra acima da mesa.

CARTAS
• Mesmas regras de vaza do Vanilla: seguir naipe, cortar com Trunfo se não tiver, cobrir com Trunfo maior se alguém já cortou. O Louco nunca vence, a não ser no modificador "O Louco Vence"."""
	var l := UIKit.label(text, 16, UIKit.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(520, 0)
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
	v.custom_minimum_size = Vector2(520, 0)
	box.add_child(v)
	v.add_child(UIKit.label("PAUSA", 40, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("Toque numa carta para selecionar (ela sobe) e de novo para jogar,\nou arraste-a pra cima e solte na mesa. Segure / botão direito = zoom.", 16, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
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
