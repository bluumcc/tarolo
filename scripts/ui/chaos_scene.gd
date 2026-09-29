extends Control
## ChaosScene.tscn — mesa do modo Caos: 5 níveis curtos de 8 cartas, todo mundo joga
## pra si (sem Atacante/Defesa), com um modificador novo a cada nível e um bônus de
## Fôlego pra quem estiver por baixo no total. Layout pensado pra celular (retrato):
## uma pilha vertical — status dos jogadores no topo, área de jogo compacta no meio,
## sua mão embaixo — em vez de uma mesa oval espalhada, que só faz sentido em paisagem.

signal human_card_chosen(card: CardData)
signal item_chosen(item: int)
signal slides_done
signal match_finished(summary: Dictionary)

const CARD_SCENE := preload("res://scenes/Card.tscn")

## As cartas da mão têm o tamanho cheio; as da mesa ficam menores pra caber 4 lado a lado.
const TABLE_SCALE := 0.70
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
var modifier_revealed := false   # surpresa de rodada já foi revelada nesse nível
var info_label: Label
var trick_dots: HBoxContainer
var shown_totals: Array = []
var modifier_label: Label
var modifier_expanded := false
var power_btn: Button
var modal_open := false      # modal de poder/aposta aberto — o relógio da jogada pausa
var best_trick := {}         # melhor rodada do jogador na partida (pra tela final)
var popup_layer: Control
var overlay_layer: Control
var table_views: Array = []
var pot_box: PanelContainer
var pot_label: Label
var pot_sub: Label
var bet_tags: Array = []       # "◎25 · 3" por assento
var prog_tags: Array = []      # "1/3 ♨×1,5" ao vivo por assento
var my_bet_label: Label
var double_btn: Button
var shown_pot := 0.0
var bets_revealed := false     # palpites só aparecem depois do showdown
var pot_locked := false        # contador do pote rolando: o refresh não sobrescreve

const FLAME := Color("#FF9A3D")
const SEAT_W := 150.0
const POT_W := 250.0


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
	if not GameState.autoplay and not bool(SaveManager.section("tips").get("chaos_intro", false)):
		await _intro_slides()
		SaveManager.section("tips")["chaos_intro"] = true
		SaveManager.save_game()
		if not is_inside_tree():
			return
	await _announce_round()
	if not is_inside_tree():
		return
	await _pre_round()
	if not is_inside_tree():
		return
	_run_round.call_deferred()


func _show_insufficient_fichas() -> void:
	var ov := UIKit.overlay()
	overlay_layer.add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.DANGER, 24)
	box.custom_minimum_size = Vector2(664, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	box.add_child(v)
	v.add_child(UIKit.label("FICHAS INSUFICIENTES", 28, UIKit.DANGER, HORIZONTAL_ALIGNMENT_CENTER))
	var l := UIKit.label("Você precisa de %d fichas pra entrar na Mesa Caos. Jogue Vanilla ou Ranqueado, ou volte ao menu e peça um empréstimo da casa." % int(config["buy_in"]), 32, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(620, 0)
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
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	hud_badges.resize(engine.num_players)
	hud_titles.resize(engine.num_players)
	hud_totals.resize(engine.num_players)
	hud_round_pts.resize(engine.num_players)
	hud_cards.resize(engine.num_players)
	seat_avatars.resize(engine.num_players)
	bet_tags.resize(engine.num_players)
	prog_tags.resize(engine.num_players)

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
	double_btn = UIKit.button("DOBRAR", UIKit.GOLD, 30)
	double_btn.custom_minimum_size = Vector2(0, 64)
	double_btn.visible = false
	double_btn.pressed.connect(_on_double_pressed)
	topbar.add_child(double_btn)
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

	# Regra do nível — aviso fixo, sempre visível.
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
	# rodada, combos, evento surpresa. Uma mensagem por vez, sempre no mesmo lugar.
	banner_box = UIKit.panel(UIKit.PURPLE_DEEP, UIKit.MUTED, 12)
	banner_box.custom_minimum_size = Vector2(0, 112)
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

	# Mesa de jogo — só a rodada atual, cada carta numa vaga fixa por assento.
	table_center = Panel.new()
	table_center.name = "TableCenter"
	table_center.custom_minimum_size = Vector2(0, 470)
	table_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table_center.add_theme_stylebox_override("panel", UIKit.box(Color(0.10, 0.08, 0.30, 0.85), Color("#5B4FC9"), 3, 200, 0))
	table_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_col.add_child(table_center)
	_build_seats()
	_build_pot()
	table_center.resized.connect(_layout_table)

	status_label = UIKit.label("", 21, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(0, 44)
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_col.add_child(status_label)

	# Relógio da jogada: barra que esvazia — some fora da sua vez.
	turn_bar = ProgressBar.new()
	turn_bar.show_percentage = false
	turn_bar.min_value = 0.0
	turn_bar.max_value = TURN_SECONDS
	turn_bar.custom_minimum_size = Vector2(0, 18)
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
	var my_rp := UIKit.label("+0,0 no nível", 20, UIKit.MUTED)
	my_left.add_child(my_rp)
	var my_right := VBoxContainer.new()
	my_right.add_theme_constant_override("separation", 1)
	my_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	my_right.alignment = BoxContainer.ALIGNMENT_CENTER
	my_row.add_child(my_right)
	my_bet_label = UIKit.label("", 18, UIKit.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	my_bet_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	my_right.add_child(my_bet_label)
	power_btn = UIKit.button("", UIKit.OK)
	power_btn.custom_minimum_size = Vector2(0, 64)
	power_btn.pressed.connect(_on_power_pressed)
	my_right.add_child(power_btn)
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
	side_col.visible = false  # a regra do nível já fica na faixa de avisos, em repouso
	modifier_expanded = wide
	_refresh_hud()
	table_center.custom_minimum_size.y = 240 if wide else 470
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
		var bet_l := UIKit.label("", 20, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		seat.add_child(bet_l)
		var prog_l := UIKit.label("", 20, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		seat.add_child(prog_l)
		bet_tags[p] = bet_l
		prog_tags[p] = prog_l
		seat.custom_minimum_size = Vector2(SEAT_W, 0)
		table_center.add_child(seat)
		seat_nodes[p] = seat
		hud_badges[p] = seat
		hud_titles[p] = name_l
		hud_totals[p] = pts_l
		hud_round_pts[p] = Label.new()
		hud_cards[p] = Label.new()
		seat_avatars[p] = ring


## Pote no centro da mesa: total (com o acumulado) e um toque abre o painel de apostas.
func _build_pot() -> void:
	pot_box = UIKit.panel(Color("#2A1B4D"), UIKit.GOLD, 8)
	pot_box.custom_minimum_size = Vector2(POT_W, 0)
	pot_box.mouse_filter = Control.MOUSE_FILTER_STOP
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 0)
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pot_box.add_child(pv)
	pot_label = UIKit.label("POTE ◎ 0", 34, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	pot_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	pv.add_child(pot_label)
	pot_sub = UIKit.label("", 18, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	pot_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pot_sub.custom_minimum_size = Vector2(POT_W - 40.0, 0)
	pv.add_child(pot_sub)
	pot_box.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			UIKit.sfx("tick")
			_open_bets_panel())
	table_center.add_child(pot_box)
	pot_box.z_index = 2


func _seat_pos(p: int) -> Vector2:
	var sz := table_center.size
	var seat: Control = seat_nodes[p]
	var w := SEAT_W
	match p:
		1: return Vector2(26.0, sz.y * 0.14)
		2: return Vector2((sz.x - w) / 2.0, 14.0)
		_: return Vector2(sz.x - w - 26.0, sz.y * 0.14)


## Reposiciona as cartas já em jogo quando a mesa muda de tamanho (ex.: virar o celular).
func _layout_table() -> void:
	if table_center == null:
		return
	for p in range(1, engine.num_players):
		if seat_nodes.size() > p and seat_nodes[p] != null:
			(seat_nodes[p] as Control).position = _seat_pos(p)
	if pot_box:
		if table_center.size.y >= 420.0:
			pot_box.position = Vector2((table_center.size.x - POT_W) / 2.0, maxf(230.0, table_center.size.y * 0.42 - 30.0))
		else:
			# Tela larga e baixa: o pote fica à esquerda das cartas da mesa.
			pot_box.position = Vector2(maxf(_slot_pos(0).x - POT_W - 24.0, 4.0), table_center.size.y / 2.0 - 30.0)
	for v in table_views:
		var cv: CardView = v["view"]
		cv.position = _slot_pos(int(v["player"]))


## Uma vaga fixa por assento, em fileira — igual qualquer app de cartas mostra a rodada
## atual, em vez de espalhar geometricamente numa mesa oval (isso é o que fazia o jogo
## parecer preso a paisagem mesmo rodando em celular).
func _slot_pos(player: int) -> Vector2:
	var n := maxi(engine.num_players, 1)
	var card_w := CardView.SIZE.x * TABLE_SCALE
	var slot_w := card_w + 8.0
	var start := (table_center.size.x - slot_w * n) / 2.0 + 7.0 - (CardView.SIZE.x - card_w) / 2.0
	var y := table_center.size.y * 0.72 - CardView.SIZE.y / 2.0
	if table_center.size.y >= 420.0:
		y = table_center.size.y - CardView.SIZE.y * TABLE_SCALE - 14.0   # rente com a base da mesa
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
		(hud_round_pts[p] as Label).text = "+%s no nível" % UIKit.fmt_dec(rp, 1)
		if p == 0:
			(hud_round_pts[p] as Label).text += "  ·  ◎ %d" % int(SaveManager.section("profile")["fichas"])
		var turn := p == turn_player
		(hud_badges[p] as Control).modulate = Color(1, 1, 1, 1) if turn else Color(0.78, 0.76, 0.85, 1)
		var lead_accent := UIKit.GOLD if p == engine.folego_player else UIKit.MUTED
		var item_icon: String = ChaosItems.ICONS.get(engine.player_items[p], "") if p < engine.player_items.size() and not engine.power_used[p] else ""
		var prefix := ("♨ " if p == engine.folego_player else "") + (item_icon + " " if item_icon != "" else "")
		(hud_titles[p] as Label).text = "%s%s" % [prefix, str(config["names"][p]).to_upper()]
		_refresh_bet_tags(p)
		(hud_titles[p] as Label).add_theme_color_override("font_color", lead_accent)
		if p > 0:
			(hud_cards[p] as Label).text = "%d cartas" % (engine.hands[p] as Array).size()
	info_label.text = "NÍVEL %d/%d" % [engine.round_index + 1, ChaosEngine.ROUNDS]
	Widgets.progress_dots(trick_dots, ChaosEngine.HAND_SIZE, engine.trick_number)
	var rest := _rest_banner()
	modifier_label.text = "%s — %s" % [rest[0], rest[1]] if modifier_expanded else str(rest[0])
	_refresh_pot()
	_refresh_double_button()
	_update_turn_highlight(turn_player)
	_refresh_power_button()


## Palpite ao vivo no assento: "◎25 · 3" + "1/3" (cor pela situação) + chamas do combo.
func _refresh_bet_tags(p: int) -> void:
	var predict: int = engine.bet_predict[p] if p < engine.bet_predict.size() else -1
	var streak: int = engine.streak[p] if p < engine.streak.size() else 0
	var flames := ""
	if streak >= 2:
		flames = "%s ×%s" % ["♨".repeat(ChaosCombos.flame_level(streak)), UIKit.fmt_dec(ChaosCombos.streak_mult(streak), 2)]
	var tag := ""
	var prog := ""
	var col := UIKit.MUTED
	if bets_revealed and predict >= 0:
		var won := engine.tricks_won_by(p)
		tag = "◎%d · %d" % [int(engine.bet_stake[p]), predict]
		prog = "%d/%d" % [won, predict]
		match engine.bet_status(p):
			"on": col = UIKit.OK
			"chase": col = UIKit.INK
			"near": col = UIKit.GOLD
			"bust": col = UIKit.DANGER
		if bool(engine.bet_doubled[p]):
			tag += " ×2"
	if p == 0:
		var lines: Array = []
		if tag != "":
			lines.append("PALPITE %s  ·  %s" % [tag, prog])
		if flames != "":
			lines.append(flames)
		my_bet_label.text = "\n".join(lines)
		my_bet_label.add_theme_color_override("font_color", col if tag != "" else FLAME)
		return
	(bet_tags[p] as Label).add_theme_color_override("font_color", UIKit.GOLD)
	if p == 2:
		# Assento do topo: aposta e progresso na mesma linha pra não invadir o pote.
		(bet_tags[p] as Label).text = (tag + "   " + prog).strip_edges()
		(prog_tags[p] as Label).text = flames
		(prog_tags[p] as Label).visible = flames != ""
		(prog_tags[p] as Label).add_theme_color_override("font_color", FLAME)
		return
	(bet_tags[p] as Label).text = tag
	var pt := prog
	if flames != "":
		pt = (pt + "  " + flames).strip_edges()
	(prog_tags[p] as Label).text = pt
	(prog_tags[p] as Label).add_theme_color_override("font_color", col if prog != "" else FLAME)


func _refresh_pot() -> void:
	var total := engine.bet_pot() if bets_revealed else engine.bet_carry
	if not pot_locked:
		shown_pot = total
		pot_label.text = "POTE ◎ %d" % int(total)
	var sub := ""
	if engine.bet_carry > 0.0:
		sub = "inclui ◎ %d acumulados" % int(engine.bet_carry)
	elif not bets_revealed:
		sub = "toque para ver as apostas"
	pot_sub.text = sub
	pot_sub.visible = sub != ""
	pot_box.reset_size.call_deferred()


## Faz o pote rolar até o valor atual (pop dourado).
func _pot_to(total: float) -> void:
	var from := shown_pot
	shown_pot = total
	pot_locked = true
	FX.count(pot_label, from, total, func(v: float): return "POTE ◎ %d" % int(v), 0.5)
	FX.pop(pot_box, 1.18)
	get_tree().create_timer(GameState.anim(0.55)).timeout.connect(func():
		pot_locked = false
		if is_inside_tree():
			_refresh_pot())


func _refresh_double_button() -> void:
	if double_btn == null:
		return
	var stake := int(engine.bet_stake[0]) if engine.bet_predict.size() > 0 else 0
	var can := bets_revealed and human_turn and not modal_open and engine.can_double(0) \
		and int(SaveManager.section("profile")["fichas"]) >= stake
	double_btn.visible = can
	if can:
		double_btn.text = "DOBRAR ◎%d" % stake


func _global_center(c: Control) -> Vector2:
	return c.global_position + c.size / 2.0


func _seat_center(p: int) -> Vector2:
	return _global_center(seat_avatars[p] as Control)


func _plural(n: int, one: String, many: String) -> String:
	return "%d %s" % [n, one if n == 1 else many]


func _chips_for(stake: float) -> int:
	return clampi(int(stake / 10.0), 1, 7)


## Dobra a aposta do jogador (uma vez por nível): mais fichas pro pote, peso ×2.
func _on_double_pressed() -> void:
	if not human_turn or modal_open or not engine.can_double(0):
		return
	var stake := int(engine.bet_stake[0])
	var profile := SaveManager.section("profile")
	if int(profile["fichas"]) < stake:
		return
	var extra := engine.double_bet(0)
	if extra <= 0.0:
		return
	profile["fichas"] = int(profile["fichas"]) - int(extra)
	SaveManager.save_game()
	Sfx.play("boost")
	_banner("◎ VOCÊ DOBROU!", "Aposta ×2: ◎ %d no pote. Errou por 1? Metade volta. Acertou? Peso dobrado." % int(engine.bet_stake[0]), UIKit.GOLD)
	FX.fly_chips(popup_layer, _seat_center(0), _global_center(pot_box), _chips_for(extra))
	FX.shake(main_area, 0.3)
	_pot_to(engine.bet_pot())
	FX.pop(my_bet_label, 1.3)
	_refresh_hud()


## Bot dobra na vez dele (mostra o que fez).
func _bot_double(p: int) -> void:
	if not ChaosBot.maybe_double(engine, p, int(config["difficulty"][p]), bot_rng):
		return
	var extra := engine.double_bet(p)
	if extra <= 0.0:
		return
	Sfx.play("boost")
	_banner("◎ %s DOBROU A APOSTA!" % str(config["names"][p]).to_upper(), "Agora tem ◎ %d no pote." % int(engine.bet_stake[p]), UIKit.GOLD)
	FX.fly_chips(popup_layer, _seat_center(p), _global_center(pot_box), _chips_for(extra))
	_pot_to(engine.bet_pot())
	_refresh_hud()
	await _wait(1.0)


## Painel de apostas (toque no pote): todos os palpites, quanto cada um tem no pote e o
## quanto você levaria se acertasse agora.
func _open_bets_panel() -> void:
	if modal_open or not bets_revealed:
		return
	modal_open = true
	var ov := UIKit.overlay()
	overlay_layer.add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.GOLD, 24)
	box.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 40.0, 620.0), 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	v.add_child(UIKit.label("APOSTAS DO NÍVEL", 34, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("POTE ◎ %d" % int(engine.bet_pot()), 40, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	if engine.bet_carry > 0.0:
		v.add_child(UIKit.label("(◎ %d acumulados de níveis anteriores)" % int(engine.bet_carry), 24, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(HSeparator.new())
	var any := false
	for p in range(engine.num_players):
		if int(engine.bet_predict[p]) < 0:
			continue
		any = true
		var st := engine.bet_status(p)
		var col: Color = {"on": UIKit.OK, "chase": UIKit.INK, "near": UIKit.GOLD, "bust": UIKit.DANGER}.get(st, UIKit.MUTED)
		var word: String = {"on": "no alvo", "chase": "correndo atrás", "near": "por pouco", "bust": "estourou"}.get(st, "")
		var line := "%s: %d rodadas · ◎%d%s — fez %d (%s)" % [str(config["names"][p]).to_upper(), int(engine.bet_predict[p]), int(engine.bet_stake[p]), " ×2" if bool(engine.bet_doubled[p]) else "", engine.tricks_won_by(p), word]
		var l := UIKit.label(line, 26, col, HORIZONTAL_ALIGNMENT_CENTER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
		if int(engine.combo_count[p]) > 0:
			v.add_child(UIKit.label("combos: %d (peso +%d%%)" % [int(engine.combo_count[p]), int(minf(ChaosEngine.COMBO_WEIGHT * float(engine.combo_count[p]), ChaosEngine.COMBO_WEIGHT_MAX) * 100.0)], 22, FLAME, HORIZONTAL_ALIGNMENT_CENTER))
	if not any:
		v.add_child(UIKit.label("Ninguém apostou nesse nível.", 28, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	elif int(engine.bet_predict[0]) >= 0:
		var mine := UIKit.label("Se você acertar, leva até ◎ %d do pote (dividido com quem também acertar)." % int(engine.bet_pot()), 26, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		mine.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(mine)
	var close := UIKit.button("FECHAR", UIKit.MUTED)
	close.pressed.connect(func(): item_chosen.emit(-1))
	v.add_child(close)
	ov.add_child(UIKit.centered(box))
	await item_chosen
	modal_open = false
	if is_inside_tree():
		ov.queue_free()


func _refresh_power_button() -> void:
	if power_btn == null:
		return
	var item: int = engine.player_items[0]
	if item == ChaosItems.Item.NONE:
		power_btn.visible = false
		return
	power_btn.visible = true
	var used: bool = engine.power_used[0]
	power_btn.text = "%s %s%s" % [ChaosItems.ICONS[item], str(ChaosItems.NAMES[item]).to_upper(), "  ✓" if used else ""]
	power_btn.disabled = used or not human_turn
	power_btn.tooltip_text = str(ChaosItems.DESCRIPTIONS[item])


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


# ------------------------------------------------------------------ níveis / modificador

## Tela de transição de início de nível: ocupa a tela inteira, explica a regra da
## nível e o que muda, e avança sozinha (ou ao tocar). Nada de jogo por trás.
func _announce_round() -> void:
	_refresh_hud()
	_rebuild_hand()
	var final := engine.is_final_round()
	var kicker := "NÍVEL FINAL" if final else "NÍVEL %d DE %d" % [engine.round_index + 1, ChaosEngine.ROUNDS]
	var lines: Array = []
	lines.append(_intro_block())
	if final:
		lines.append({"head": "NÍVEL FINAL", "title": "PONTOS EM DOBRO", "text": "Tudo que você marcar nesse nível vale ×2. Ninguém está fora até a última rodada.", "color": UIKit.GOLD})
	if engine.folego_player != -1:
		lines.append({"head": "FÔLEGO", "title": "♨ %s" % str(config["names"][engine.folego_player]).to_upper(), "text": "Está em último e ganha ×%s nos pontos desse nível." % UIKit.fmt_dec(ChaosEngine.FOLEGO_MULT, 1), "color": UIKit.GOLD})
	await _transition(kicker, lines, 3.4 if not first_round_done else 3.0)
	first_round_done = true
	modifier_revealed = false
	_banner_clear()


## Cartão do modificador na tela de início: nível inteiro mostra a regra; rodada-surpresa
## só avisa que vem algo; rodada fixa (1ª/última) já diz qual é.
func _intro_block() -> Dictionary:
	var m := engine.modifier
	if ChaosModifiers.scope_of(m) == ChaosModifiers.Scope.ROUND:
		return {"spin": true, "head": "MODIFICADOR · NÍVEL INTEIRO", "title": "✦ %s" % ChaosModifiers.label(m, engine.weak_suit), "text": "%s %s" % [ChaosModifiers.DESCRIPTIONS[m], ChaosModifiers.TIPS[m]], "color": UIKit.OK}
	if ChaosModifiers.is_secret(m):
		return {"head": "MODIFICADOR · SURPRESA", "title": "? EM ALGUMA RODADA", "text": "Uma regra especial vai valer só em UMA rodada desse nível. Você só descobre qual e quando ela começar.", "color": UIKit.DANGER}
	return {"head": "MODIFICADOR · RODADA %d" % (engine.modifier_trick + 1), "title": "%s %s" % [ChaosModifiers.ICONS[m], ChaosModifiers.NAMES[m]], "text": "%s %s" % [ChaosModifiers.DESCRIPTIONS[m], ChaosModifiers.TIPS[m]], "color": UIKit.GOLD}


## Texto da faixa em repouso (nenhuma mensagem ativa): lembra o modificador do nível sem
## entregar a surpresa antes da hora. Retorna [título, subtítulo, cor].
func _rest_banner() -> Array:
	var m := engine.modifier
	if ChaosModifiers.scope_of(m) == ChaosModifiers.Scope.ROUND:
		return ["✦ %s" % ChaosModifiers.label(m, engine.weak_suit), str(ChaosModifiers.DESCRIPTIONS[m]), UIKit.OK]
	var known := modifier_revealed or not ChaosModifiers.is_secret(m)
	if not known:
		return ["? Surpresa em alguma rodada", "Uma regra especial vale em uma rodada só. Você descobre quando ela começar.", UIKit.DANGER]
	var when := "rodada %d" % (engine.modifier_trick + 1)
	var done := engine.trick_number > engine.modifier_trick
	var sub := "já aconteceu · %s" % when if done else "%s · %s" % [ChaosModifiers.DESCRIPTIONS[m], when]
	return ["%s %s" % [ChaosModifiers.ICONS[m], ChaosModifiers.NAMES[m]], sub, ChaosModifiers.color_of(m)]


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
	var spins: Array = []  # [título, texto] dos blocos com caça-níquel: o texto só aparece quando ele trava
	for b in blocks:
		var card := UIKit.panel(UIKit.PURPLE_DEEP, b["color"], 18)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 4)
		card.add_child(cv)
		cv.add_child(UIKit.label(b["head"], 28, b["color"], HORIZONTAL_ALIGNMENT_CENTER))
		var title_lbl := UIKit.label(b["title"], 40, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
		cv.add_child(title_lbl)
		var t := UIKit.label(b["text"], 32, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(t)
		if b.get("spin", false):
			t.modulate.a = 0.0
			spins.append([title_lbl, t, str(b["title"])])
		v.add_child(card)
	var go := UIKit.button("ENTENDI, CONTINUAR")
	v.add_child(go)
	if not spins.is_empty():
		go.disabled = true
		go.modulate.a = 0.0
	ov.add_child(UIKit.centered(v))
	go.grab_focus.call_deferred()
	ov.modulate.a = 0.0
	create_tween().tween_property(ov, "modulate:a", 1.0, GameState.anim(0.18))
	Sfx.play("chip")
	for sp in spins:
		_reveal_after_spin(sp[0], sp[1], sp[2], go)
	# Só avança quando o jogador aperta o botão — sem tempo limite, dá pra ler com calma.
	await go.pressed
	if not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_property(ov, "modulate:a", 0.0, GameState.anim(0.18))
	await tw.finished
	ov.queue_free()


## Roda o caça-níquel e só depois mostra a explicação e libera o botão.
func _reveal_after_spin(title_lbl: Label, text_lbl: Label, final_text: String, go: Button) -> void:
	await _spin_label(title_lbl, final_text)
	if not is_instance_valid(text_lbl):
		return
	await get_tree().create_timer(GameState.anim(0.35)).timeout
	if is_instance_valid(text_lbl):
		create_tween().tween_property(text_lbl, "modulate:a", 1.0, GameState.anim(0.3))
	if is_instance_valid(go):
		go.disabled = false
		create_tween().tween_property(go, "modulate:a", 1.0, GameState.anim(0.3))


## Caça-níquel do modificador: os nomes giram, desaceleram e travam no sorteado.
func _spin_label(lbl: Label, final_text: String) -> void:
	var names: Array = ChaosModifiers.ALL.map(func(m): return "✦ %s" % ChaosModifiers.NAMES[m])
	var steps := 14
	for i in range(steps):
		if not is_instance_valid(lbl):
			return
		lbl.text = names[(i * 3 + 1) % names.size()]
		Sfx.play("tick")
		await get_tree().create_timer(0.05 + 0.014 * i).timeout
	if is_instance_valid(lbl):
		lbl.text = final_text
		FX.pop(lbl, 1.35)
		Sfx.play("win")


## Mensagem na faixa reservada acima da mesa (nunca cobre nada). `color` pinta a borda.
func _banner(title: String, sub: String, color: Color) -> void:
	banner_title.text = title
	banner_title.add_theme_color_override("font_color", color)
	banner_sub.text = sub
	banner_box.add_theme_stylebox_override("panel", UIKit.box(UIKit.PURPLE_DEEP, color, 3, 4, 12))
	banner_box.modulate.a = 0.0
	create_tween().tween_property(banner_box, "modulate:a", 1.0, GameState.anim(0.12))


func _banner_clear() -> void:
	# Em repouso a faixa lembra o modificador do nível (informação útil no lugar de um vazio).
	var rest := _rest_banner()
	banner_title.text = str(rest[0])
	banner_title.add_theme_color_override("font_color", rest[2])
	banner_sub.text = str(rest[1])
	banner_box.modulate.a = 1.0
	banner_box.add_theme_stylebox_override("panel", UIKit.box(UIKit.PURPLE_DEEP, UIKit.MUTED, 3, 4, 12))


# ------------------------------------------------------------------ loop de turnos

## Começo de rodada: se o modificador de rodada (surpresa) vale agora, revela numa tela cheia
## (surpresa) ou só na faixa (1ª/última, já conhecidas); deixa o aviso fixo durante a rodada.
func _trick_start() -> void:
	var m := engine.active_modifier()
	if m == -1 or ChaosModifiers.scope_of(m) == ChaosModifiers.Scope.ROUND:
		return
	var color := ChaosModifiers.color_of(m)
	if ChaosModifiers.is_secret(m) and not modifier_revealed:
		await _transition("PLOT TWIST!", [{"head": "RODADA %d" % (engine.trick_number + 1), "title": "%s %s" % [ChaosModifiers.ICONS[m], ChaosModifiers.NAMES[m]], "text": "%s %s" % [ChaosModifiers.DESCRIPTIONS[m], ChaosModifiers.TIPS[m]], "color": color}], 2.6)
	modifier_revealed = true
	if is_inside_tree():
		_banner("%s %s" % [ChaosModifiers.ICONS[m], ChaosModifiers.NAMES[m]], str(ChaosModifiers.DESCRIPTIONS[m]), color)


func _run_round() -> void:
	while not engine.is_round_over():
		if not is_inside_tree():
			return
		if engine.plays.is_empty():
			await _trick_start()
			if not is_inside_tree():
				return
		var p := engine.current
		_refresh_hud()
		var card: CardData
		if p != 0 or GameState.autoplay:
			await _bot_power(p)
			if not is_inside_tree():
				return
			if not GameState.autoplay:
				await _bot_double(p)
				if not is_inside_tree():
					return
			else:
				if ChaosBot.maybe_double(engine, p, int(config["difficulty"][p]), bot_rng):
					engine.double_bet(p)
		if p == 0 and not GameState.autoplay:
			card = await _wait_human()
		else:
			await _wait(0.9 if p == 0 else bot_rng.randf_range(0.9, 1.5))
			if not is_inside_tree():
				return
			card = ChaosBot.choose(engine, p, int(config["difficulty"][p]), bot_rng)
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
	await _payout()
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
		await _pre_round()
		if not is_inside_tree():
			return
		_run_round.call_deferred()


## Antes de cada nível: escolha do poder (1 de 3) e o palpite (quantas rodadas você vai
## ganhar + fichas). Bots decidem na hora; os palpites só aparecem no showdown.
func _pre_round() -> void:
	bets_revealed = false
	_refresh_pot()
	for p in range(1, engine.num_players):
		engine.set_item(p, ChaosBot.choose_power(bot_rng))
		var bb := ChaosBot.choose_bet(engine.hands[p], int(config["difficulty"][p]), bot_rng)
		engine.set_bet(p, int(bb.get("predict", -1)), int(bb.get("stake", 0)))
	if GameState.autoplay:
		engine.set_item(0, ChaosBot.choose_power(bot_rng))
		var ab := ChaosBot.choose_bet(engine.hands[0], BotAI.Difficulty.NORMAL, bot_rng)
		engine.set_bet(0, int(ab.get("predict", -1)), int(ab.get("stake", 0)))
		bets_revealed = true
		return
	var powers := ChaosItems.offer(engine.rng)
	var opts: Array = []
	for it in powers:
		opts.append({"label": "%s  %s" % [ChaosItems.ICONS[it], str(ChaosItems.NAMES[it]).to_upper()], "desc": ChaosItems.DESCRIPTIONS[it], "color": UIKit.OK})
	var pick := await _modal_choice("ESCOLHA SEU PODER", "Use uma vez nesse nível, na sua vez (botão no rodapé).", opts)
	if not is_inside_tree():
		return
	engine.set_item(0, powers[pick])
	var hand: Array = engine.hands[0]
	var trunfos := hand.filter(func(c: CardData) -> bool: return c.is_trunfo() and not c.is_louco()).size()
	var kings := hand.filter(func(c: CardData) -> bool: return c.rank == 14 and not c.is_trunfo()).size()
	var fichas := int(SaveManager.section("profile")["fichas"])
	var suggestion := ChaosBot.choose_bet(hand, BotAI.Difficulty.HARD, bot_rng)
	var bet := await _bet_modal(fichas, trunfos, kings, int(suggestion.get("predict", 2)))
	if not is_inside_tree():
		return
	if not bet.is_empty():
		SaveManager.section("profile")["fichas"] = fichas - int(bet["stake"])
		SaveManager.save_game()
		engine.set_bet(0, int(bet["predict"]), int(bet["stake"]))
	else:
		engine.set_bet(0, -1, 0)
	_refresh_hud()
	await _showdown()


## Modal do palpite: quantas rodadas você vai ganhar (0 a 8) e quanto aposta. Devolve
## {predict, stake} ou {} se não apostar.
func _bet_modal(fichas: int, trunfos: int, kings: int, suggested: int) -> Dictionary:
	modal_open = true
	var ov := UIKit.overlay()
	overlay_layer.add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.GOLD, 24)
	box.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 40.0, 620.0), 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	v.add_child(UIKit.label("FAÇA SEU PALPITE", 34, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var info := UIKit.label("Cravar quantas rodadas você vai ganhar neste nível. Acertou o número exato? Você divide o pote com quem também acertou. Errou por 1? Metade da aposta volta. Errou por mais? A aposta vai pro pote. Se ninguém acertar, o pote acumula pro próximo nível.", 24, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info)
	var hand_l := UIKit.label("Sua mão: %s e %s  ·  Você tem ◎ %d%s" % [_plural(trunfos, "Trunfo", "Trunfos"), _plural(kings, "Rei", "Reis"), fichas, ("  ·  Pote acumulado ◎ %d" % int(engine.bet_carry)) if engine.bet_carry > 0.0 else ""], 24, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	hand_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hand_l)
	v.add_child(HSeparator.new())
	var st := {"predict": clampi(suggested, 0, ChaosEngine.HAND_SIZE), "stake": 25 if fichas >= 25 else 10}
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	v.add_child(body)
	var choose_done := func(result: Dictionary) -> void:
		st["result"] = result
		item_chosen.emit(1)
	var render: Callable
	render = func():
		for c in body.get_children():
			c.queue_free()
		# Stepper do palpite.
		body.add_child(UIKit.label("QUANTAS RODADAS VOCÊ VAI GANHAR?", 24, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 16)
		body.add_child(row)
		var minus := UIKit.button("−", UIKit.MUTED, 44)
		minus.custom_minimum_size = Vector2(96, 84)
		minus.disabled = int(st["predict"]) <= 0
		minus.pressed.connect(func():
			st["predict"] = int(st["predict"]) - 1
			render.call())
		row.add_child(minus)
		var num := UIKit.label(str(int(st["predict"])), 88, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		num.custom_minimum_size = Vector2(110, 0)
		row.add_child(num)
		var plus := UIKit.button("+", UIKit.MUTED, 44)
		plus.custom_minimum_size = Vector2(96, 84)
		plus.disabled = int(st["predict"]) >= ChaosEngine.HAND_SIZE
		plus.pressed.connect(func():
			st["predict"] = int(st["predict"]) + 1
			render.call())
		row.add_child(plus)
		var dif := ChaosEngine.difficulty_of(int(st["predict"]))
		var dif_l := UIKit.label("Dificuldade ×%s — quanto mais rodadas você prevê, mais peso no pote." % UIKit.fmt_dec(dif, 1), 22, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		dif_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(dif_l)
		# Fichas.
		body.add_child(UIKit.label("QUANTO APOSTAR?", 24, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		var srow := HBoxContainer.new()
		srow.add_theme_constant_override("separation", 8)
		body.add_child(srow)
		var stakes: Array = ChaosEngine.STAKES.duplicate()
		stakes.append(mini(fichas, 200))
		for i in range(stakes.size()):
			var amount: int = stakes[i]
			var is_all := i == stakes.size() - 1
			if is_all and (amount <= int(ChaosEngine.STAKES[ChaosEngine.STAKES.size() - 1])):
				continue
			var b := UIKit.button(("TUDO ◎%d" % amount) if is_all else "◎%d" % amount, UIKit.OK if int(st["stake"]) == amount else UIKit.MUTED, 30)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size = Vector2(0, 72)
			b.disabled = fichas < amount
			b.pressed.connect(func():
				st["stake"] = amount
				render.call())
			srow.add_child(b)
		var can_bet := fichas >= 10
		var ok := UIKit.button("APOSTAR ◎%d EM %s" % [int(st["stake"]), _plural(int(st["predict"]), "RODADA", "RODADAS")], UIKit.GOLD)
		ok.disabled = not can_bet or fichas < int(st["stake"])
		ok.pressed.connect(func(): choose_done.call({"predict": int(st["predict"]), "stake": int(st["stake"])}))
		body.add_child(ok)
		var skip := UIKit.button("NÃO APOSTAR", UIKit.MUTED)
		skip.pressed.connect(func(): choose_done.call({}))
		body.add_child(skip)
		if not can_bet:
			var warn := UIKit.label("Suas fichas acabaram. Toque nas fichas no menu para recarregar.", 22, UIKit.DANGER, HORIZONTAL_ALIGNMENT_CENTER)
			warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body.add_child(warn)
	render.call()
	ov.add_child(UIKit.centered(box))
	box.scale = Vector2(0.85, 0.85)
	box.pivot_offset = box.custom_minimum_size / 2.0
	create_tween().tween_property(box, "scale", Vector2.ONE, GameState.anim(0.2)).set_trans(Tween.TRANS_BACK)
	await item_chosen
	modal_open = false
	if is_inside_tree():
		ov.queue_free()
	return st.get("result", {})


## Revelação simultânea: os palpites viram um a um (do menor ao maior) e as fichas voam pro pote.
func _showdown() -> void:
	bets_revealed = true
	var order: Array = []
	for p in range(engine.num_players):
		if int(engine.bet_predict[p]) >= 0:
			order.append(p)
	order.sort_custom(func(a: int, b: int) -> bool: return int(engine.bet_predict[a]) < int(engine.bet_predict[b]))
	shown_pot = engine.bet_carry
	pot_locked = true
	pot_label.text = "POTE ◎ %d" % int(shown_pot)
	_banner("SHOWDOWN!", "Palpites na mesa.", UIKit.GOLD)
	Sfx.play("flip")
	await _wait(0.4)
	var running := engine.bet_carry
	for p in order:
		if not is_inside_tree():
			return
		running += float(engine.bet_stake[p])
		_refresh_bet_tags(p)
		var tag: Control = my_bet_label if p == 0 else bet_tags[p]
		FX.pop(tag, 1.4)
		Sfx.play("flip")
		FX.fly_chips(popup_layer, _seat_center(p), _global_center(pot_box), _chips_for(float(engine.bet_stake[p])))
		pot_locked = false
		_pot_to(running)
		await _wait(0.55)
	pot_locked = false
	if order.is_empty():
		_banner("SEM APOSTAS", "Ninguém apostou nesse nível.", UIKit.MUTED)
		await _wait(0.8)
	else:
		_banner("APOSTAS FECHADAS", "Pote de ◎ %d — boa sorte!" % int(engine.bet_pot()), UIKit.GOLD)
		await _wait(0.9)
	_banner_clear()
	_refresh_hud()


## Modal genérico de escolha: `opts` = [{label, desc, color}]. Devolve o índice tocado,
## ou -1 se `cancel` e o jogador desistiu.
func _modal_choice(title: String, sub: String, opts: Array, cancel := false) -> int:
	modal_open = true
	var ov := UIKit.overlay()
	overlay_layer.add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.GOLD, 24)
	box.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 40.0, 600.0), 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	box.add_child(v)
	v.add_child(UIKit.label(title, 32, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var sl := UIKit.label(sub, 20, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sl)
	v.add_child(HSeparator.new())
	for i in range(opts.size()):
		var o: Dictionary = opts[i]
		var btn := UIKit.button(str(o["label"]), o.get("color", UIKit.OK))
		btn.disabled = bool(o.get("disabled", false))
		btn.pressed.connect(func(): item_chosen.emit(i))
		v.add_child(btn)
		if str(o.get("desc", "")) != "":
			var desc := UIKit.label(str(o["desc"]), 30, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(desc)
	if cancel:
		var cb := UIKit.button("CANCELAR", UIKit.MUTED)
		cb.pressed.connect(func(): item_chosen.emit(-1))
		v.add_child(cb)
	ov.add_child(UIKit.centered(box))
	box.scale = Vector2(0.85, 0.85)
	box.pivot_offset = box.custom_minimum_size / 2.0
	create_tween().tween_property(box, "scale", Vector2.ONE, GameState.anim(0.2)).set_trans(Tween.TRANS_BACK)
	var chosen: int = await item_chosen
	modal_open = false
	if is_inside_tree():
		ov.queue_free()
	return chosen


func _pick_rival(title: String) -> int:
	var opts: Array = []
	var ids: Array = []
	for q in range(1, engine.num_players):
		ids.append(q)
		opts.append({"label": str(config["names"][q]).to_upper(), "desc": "", "color": UIKit.DANGER})
	var i := await _modal_choice(title, "Escolha o rival.", opts, true)
	return -1 if i < 0 else int(ids[i])


func _on_power_pressed() -> void:
	if not human_turn or modal_open or not engine.can_use_power(0):
		return
	var item: int = engine.player_items[0]
	match item:
		ChaosItems.Item.TROCA:
			var t := await _pick_rival("ROUBAR TRUNFO DE QUEM?")
			if t < 0 or not is_inside_tree():
				return
			var res := engine.use_troca(0, t)
			if res.is_empty():
				return
			Sfx.play("win")
			_rebuild_hand()
			_banner("⇅ TRUNFO ROUBADO!", "Você deu %s e levou %s de %s." % [res["given"].display_name(), res["taken"].display_name(), str(config["names"][t]).to_upper()], UIKit.OK)
		ChaosItems.Item.ESPIADA:
			var t := await _pick_rival("ESPIAR QUEM?")
			if t < 0 or not is_inside_tree():
				return
			var seen := engine.use_espiada(0, t)
			seen.sort_custom(func(a: CardData, b: CardData) -> bool:
				if a.is_trunfo() != b.is_trunfo():
					return a.is_trunfo()
				return a.rank > b.rank)
			var names: Array = seen.map(func(c: CardData) -> String: return c.display_name())
			await _modal_choice("MÃO DE %s" % str(config["names"][t]).to_upper(), ", ".join(names), [{"label": "ENTENDI", "desc": "", "color": UIKit.OK}])
		ChaosItems.Item.ARRISCAR:
			if engine.use_arriscar(0):
				Sfx.play("win")
				_banner("⚡ ARRISCAR ATIVO!", "Essa rodada: vencer = ×2, perder = −2. Jogue forte!", UIKit.GOLD)
	_refresh_hud()


## Poder do bot na vez dele: mostra o que fez, pra ninguém ficar sem entender.
func _bot_power(p: int) -> void:
	var act := ChaosBot.maybe_power(engine, p, int(config["difficulty"][p]), bot_rng)
	if act.is_empty():
		return
	var pname := str(config["names"][p]).to_upper()
	if int(act["item"]) == ChaosItems.Item.TROCA:
		var t: int = act["target"]
		var res := engine.use_troca(p, t)
		if res.is_empty():
			return
		Sfx.play("lose" if t == 0 else "chip")
		_banner("⇅ %s ROUBOU UM TRUNFO!" % pname, "Levou um Trunfo de %s%s." % [str(config["names"][t]).to_upper(), " (você!)" if t == 0 else ""], UIKit.DANGER if t == 0 else UIKit.GOLD)
		if t == 0:
			_rebuild_hand()
	else:
		engine.use_arriscar(p)
		Sfx.play("chip")
		_banner("⚡ %s ARRISCOU!" % pname, "Essa rodada vale ×2 pra ele se vencer — e −2 se perder.", UIKit.GOLD)
	_refresh_hud()
	await _wait(1.3)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(GameState.anim(seconds)).timeout
	while paused and is_inside_tree():
		await get_tree().create_timer(0.1).timeout


func _wait_human() -> CardData:
	human_turn = true
	if not engine.power_used[0] and engine.player_items[0] != ChaosItems.Item.NONE and engine.trick_number >= 1:
		await _tip("power", "SEU PODER", "Toque no botão verde no rodapé pra usar seu poder (%s). Vale uma vez por nível, só na sua vez." % str(ChaosItems.NAMES[engine.player_items[0]]))
	else:
		await _tip("turn", "SUA VEZ!", "Toque numa carta pra selecioná-la (ela sobe) e toque de novo pra jogar. Você tem 10 segundos por jogada.")
	var ls := TrickRules.lead_suit(engine.plays)
	if ls == -1:
		status_label.text = "Sua vez — abra a rodada com qualquer carta"
	elif ls == CardData.Suit.TRUNFO:
		status_label.text = "Sua vez — cubra com um Trunfo maior, se tiver"
	else:
		status_label.text = "Sua vez — siga %s (ou corte com Trunfo, ou jogue O Louco)" % CardData.SUIT_NAMES[ls]
	turn_left = TURN_SECONDS
	turn_bar.modulate.a = 1.0
	_rebuild_hand()
	_refresh_power_button()
	_refresh_double_button()
	if engine.can_double(0):
		FX.pop(double_btn, 1.2)
		await _tip("double", "VOCÊ PODE DOBRAR!", "O botão DOBRAR ◎ no topo põe mais fichas no pote e dobra o peso da sua aposta, mas só se você ainda está no alvo do seu palpite. Dá pra dobrar uma vez por nível, a partir da 4ª rodada.")
	var card: CardData = await human_card_chosen
	human_turn = false
	_refresh_power_button()
	_refresh_double_button()
	turn_bar.modulate.a = 0.0
	status_label.text = ""
	return card


func _process(delta: float) -> void:
	if not human_turn or paused or modal_open or finished or turn_bar == null:
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
	_apply_modifier_badge(cv, card, -1)  # na mesa só mostra o efeito do modificador — o item só conta se essa carta vencer a rodada
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

	if winner == 0 and points > float(best_trick.get("points", 0.0)):
		best_trick = {"points": points, "round": engine.round_index + 1}
	var wname := str(config["names"][winner]).to_upper()
	var notes: Array = []
	if bool(result.get("final", false)):
		notes.append("nível final ×2")
	match int(result.get("modifier", -1)):
		ChaosModifiers.Modifier.VAZA_DOURADA:
			notes.append("rodada dourada ×3")
		ChaosModifiers.Modifier.PRIMEIRA_DOBRO:
			notes.append("rodada relâmpago ×2")
		ChaosModifiers.Modifier.ULTIMA_TRIPLO:
			notes.append("última é tudo ×3")
	if bool(result.get("folego_applied", false)):
		notes.append("fôlego ♨")
	var sub := "Pontos da rodada: %s" % UIKit.fmt_dec(float(result["base_points"]), 1)
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
	var streak_n := int(result.get("streak", 0))
	if streak_n >= 2 and not ("MAO_QUENTE" in result.get("combos", [])):
		extras.append(["♨ SEQUÊNCIA ×%s!" % UIKit.fmt_dec(float(result.get("streak_mult", 1.0)), 2), "%s ganhou %d rodadas seguidas" % [wname, streak_n], FLAME])
	for id in result.get("combos", []):
		extras.append([str(ChaosModifiers.COMBO_NAMES[id]) + "!", "%s — %s" % [wname, ChaosModifiers.COMBO_DESCRIPTIONS[id]], UIKit.OK])
	if bool(result.get("arriscar_winner", false)):
		extras.append(["⚡ ARRISCOU E ACERTOU!", "%s dobrou os pontos da rodada" % wname, UIKit.OK])
	for q in result.get("arriscar_losers", []):
		extras.append(["⚡ ARRISCOU E ERROU!", "%s perdeu %s pts" % [str(config["names"][int(q)]).to_upper(), UIKit.fmt_dec(ChaosEngine.ARRISCAR_LOSS, 0)], UIKit.DANGER])
	if float(result.get("saque_amount", 0.0)) > 0.0:
		extras.append(["⚔ SAQUE!", "%s levou %s pts dos rivais" % [wname, UIKit.fmt_dec(float(result["saque_amount"]), 1)], UIKit.DANGER])
	if float(result.get("assalto_amount", 0.0)) > 0.0:
		extras.append(["⚔ ASSALTO AO LÍDER!", "%s roubou %s pts de quem liderava" % [wname, UIKit.fmt_dec(float(result["assalto_amount"]), 1)], UIKit.DANGER])
	if int(result.get("modifier", -1)) == ChaosModifiers.Modifier.VAZA_MALDITA:
		extras.append(["☠ RODADA MALDITA!", "%s perdeu %s pts por vencer essa rodada" % [wname, UIKit.fmt_dec(ChaosEngine.CURSE_PENALTY, 0)], UIKit.DANGER])
	if int(result.get("modifier", -1)) == ChaosModifiers.Modifier.VAZA_MAIS_UM:
		pass
	for e in extras:
		_banner(e[0], e[1], e[2])
		Sfx.play("combo")
		var flame_at := _seat_center(winner)
		FX.burst(popup_layer, flame_at - popup_layer.global_position, e[2], 18)
		FX.shake(main_area, clampf(0.25 + 0.15 * float(streak_n), 0.0, 0.8))
		FX.pop(bet_tags[winner] if winner > 0 else my_bet_label, 1.3)
		_refresh_hud()
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


# ------------------------------------------------------------------ resumo de nível / fim

## Pagamento do pote na mesa: quem acertou recebe as fichas do pote, quem errou por 1 ganha
## metade de volta, quem errou vê a aposta se perder; sem acerto, o pote vira JACKPOT.
func _payout() -> void:
	var info: Dictionary = engine.round_result.get("pot_info", {})
	var items: Array = info.get("items", [])
	# Fichas do perfil do jogador (aposta já saiu do saldo ao apostar).
	if not GameState.autoplay and not items.is_empty() and int(items[0]["predict"]) >= 0:
		var profile := SaveManager.section("profile")
		profile["fichas"] = int(profile["fichas"]) + int(float(items[0]["share"]) + float(items[0]["refund"]))
		SaveManager.save_game()
	if GameState.autoplay:
		_refresh_hud()
		return
	var pot_at := _global_center(pot_box)
	var any := false
	for p in range(engine.num_players):
		if int(items[p]["predict"]) >= 0:
			any = true
	if not any:
		_refresh_hud()
		return
	_banner("PAGANDO O POTE!", "Pote de ◎ %d" % int(info.get("pot", 0.0)), UIKit.GOLD)
	FX.pop(pot_box, 1.25)
	Sfx.play("combo")
	await _wait(0.8)
	if not is_inside_tree():
		return
	for p in range(engine.num_players):
		var it: Dictionary = items[p]
		if int(it["predict"]) < 0:
			continue
		var seat_at := _seat_center(p)
		var gain := float(it["share"]) + float(it["refund"])
		if gain > 0.0:
			FX.fly_chips(popup_layer, pot_at, seat_at, _chips_for(gain), UIKit.OK if bool(it["hit"]) else UIKit.GOLD)
			await _wait(0.55)
			FX.float_text(popup_layer, seat_at, "+◎ %d" % int(gain), UIKit.OK if bool(it["hit"]) else UIKit.GOLD)
			FX.burst(popup_layer, seat_at - popup_layer.global_position, UIKit.OK if bool(it["hit"]) else UIKit.GOLD, 16 if bool(it["hit"]) else 6)
			Sfx.play("win" if bool(it["hit"]) else "chip")
			if p == 0 and bool(it["hit"]):
				FX.shake(main_area, 0.6)
		if not bool(it["hit"]):
			var lost := float(it["stake"]) - float(it["refund"])
			FX.float_text(popup_layer, seat_at + Vector2(0, 40), "−◎ %d" % int(lost), UIKit.DANGER)
			FX.shake(seat_nodes[p] if p > 0 else my_bet_label, 0.4)
			Sfx.play("lose")
			await _wait(0.5)
		await _wait(0.4)
		if not is_inside_tree():
			return
	if bool(info.get("jackpot", false)):
		_banner("★ JACKPOT ACUMULADO!", "◎ %d ficam no pote do próximo nível." % int(info.get("carry_out", 0.0)), FLAME)
		Sfx.play("jackpot")
		FX.pop(pot_box, 1.4)
		FX.burst(popup_layer, pot_at - popup_layer.global_position, FLAME, 26)
		await _wait(1.4)
	elif bool(info.get("consolation", false)):
		_banner("PRÊMIO DE CONSOLAÇÃO", "Último nível sem acertos: o pote foi pra quem chegou mais perto.", UIKit.GOLD)
		await _wait(1.2)
	else:
		Sfx.play("jackpot")
		FX.chip_rain(popup_layer, 22)
		await _wait(0.9)
	_banner_clear()
	_refresh_hud()


func _show_round_summary() -> void:
	if GameState.autoplay:
		await _wait(0.05)
		return
	var r := engine.round_result
	var ov := UIKit.overlay()
	overlay_layer.add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.GOLD, 24)
	box.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 40.0, 664.0), 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	box.add_child(v)
	v.add_child(UIKit.label("FIM DO NÍVEL %d/%d" % [int(r["round"]) + 1, ChaosEngine.ROUNDS], 30, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label(ChaosModifiers.label(int(r["modifier"]), int(r["weak_suit"])), 30, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(HSeparator.new())
	var order := range(engine.num_players)
	var totals: Array = r["totals"]
	order.sort_custom(func(a: int, b: int) -> bool: return float(totals[a]) > float(totals[b]))
	for p in order:
		var gained: float = (r["round_points"] as Array)[p]
		var line := "%s%s  %s pts  (+%s)" % ["♛ " if p == order[0] else "", str(config["names"][p]).to_upper(), UIKit.fmt_dec(float(totals[p]), 1), UIKit.fmt_dec(gained, 1)]
		v.add_child(UIKit.label(line, 32, UIKit.GOLD if p == 0 else UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	var bets: Array = r.get("bets", [])
	var info: Dictionary = r.get("pot_info", {})
	v.add_child(HSeparator.new())
	v.add_child(UIKit.label("PALPITES · POTE ◎ %d" % int(info.get("pot", 0.0)), 34, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var any_bet := false
	for p in range(engine.num_players):
		var bd: Dictionary = bets[p]
		if int(bd["predict"]) < 0:
			continue
		any_bet = true
		var ok := bool(bd["hit"])
		var near := int(bd["err"]) == 1
		var net := int(bd["delta"])
		var mark := "✓" if ok else ("≈" if near else "✕")
		var bl := "%s  previu %d · fez %d  %s  %s◎ %d" % [str(config["names"][p]).to_upper(), int(bd["predict"]), int(bd["won"]), mark, "+" if net >= 0 else "−", absi(net)]
		var lab := UIKit.label(bl, 28, UIKit.OK if ok else (UIKit.GOLD if near else UIKit.DANGER), HORIZONTAL_ALIGNMENT_CENTER)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(lab)
	if not any_bet:
		v.add_child(UIKit.label("Ninguém apostou nesse nível.", 28, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	if bool(info.get("jackpot", false)):
		var jl := UIKit.label("★ JACKPOT ACUMULADO: ◎ %d vão pro próximo nível!" % int(info.get("carry_out", 0.0)), 28, FLAME, HORIZONTAL_ALIGNMENT_CENTER)
		jl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(jl)
	var btn_text := "VER RESULTADO FINAL" if int(r["round"]) >= ChaosEngine.ROUNDS - 1 else "PRÓXIMO NÍVEL"
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
	box.custom_minimum_size = Vector2(664, 0)
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
		var line := "%d. %s%s — %s pts" % [i + 1, "♛ " if i == 0 else "", str(config["names"][p]).to_upper(), UIKit.fmt_dec(float(totals[p]), 1)]
		v.add_child(UIKit.label(line, 34, UIKit.GOLD if p == 0 else UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(HSeparator.new())
	var chips_net := int(engine.bet_chips[0])
	if chips_net != 0:
		v.add_child(UIKit.label("◎ Apostas: %s%d fichas" % ["+" if chips_net > 0 else "−", absi(chips_net)], 32, UIKit.OK if chips_net > 0 else UIKit.DANGER, HORIZONTAL_ALIGNMENT_CENTER))
	if not best_trick.is_empty():
		v.add_child(UIKit.label("★ Sua melhor rodada: +%s pts (nível %d)" % [UIKit.fmt_dec(float(best_trick["points"]), 1), int(best_trick["round"])], 30, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	for line in summary["lines"]:
		v.add_child(UIKit.label(str(line), 30, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var again := UIKit.button("REVANCHE!")
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
	var desc := UIKit.label(view.describe(), 32, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(620, 0)
	v.add_child(desc)
	v.add_child(UIKit.label("toque para fechar", 28, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	ov.add_child(UIKit.centered(v))
	holder.scale = Vector2(0.6, 0.6)
	holder.pivot_offset = holder.custom_minimum_size / 2.0
	create_tween().tween_property(holder, "scale", Vector2.ONE, GameState.anim(0.18)).set_trans(Tween.TRANS_BACK)
	ov.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			ov.queue_free())


## Dica de uso único (salva no perfil): aparece na primeira vez que a situação acontece.
func _tip(key: String, title: String, text: String) -> void:
	var tips := SaveManager.section("tips")
	if GameState.autoplay or bool(tips.get(key, false)):
		return
	tips[key] = true
	SaveManager.save_game()
	await _modal_choice(title, text, [{"label": "ENTENDI", "desc": "", "color": UIKit.OK}])


## Tutorial de 3 telas: mostrado na primeira partida e sempre que tocar em "?".
func _intro_slides() -> void:
	var slides := [
		{"icon": "♠ ♥ ◆ ♣", "title": "GANHE RODADAS", "text": "São 5 níveis de 8 cartas. Em cada rodada todo mundo joga 1 carta: vence a maior do naipe (Trunfo corta). Quem vence leva as cartas e os pontos delas. No fim, o maior placar leva o pote de fichas."},
		{"icon": "✦ ⚡ ★", "title": "PALPITE E POTE", "text": "Todo nível sorteia UM modificador que muda as regras e você escolhe seu PODER. Depois crava seu PALPITE: quantas rodadas vai ganhar, e quantas fichas apostar. Todas as apostas vão pro POTE. Acertou o número exato? Divide o pote com quem também acertou. Errou por 1? Metade volta. Ninguém acertou? O pote acumula pro próximo nível."},
		{"icon": "♨ ≋ ⚑", "title": "COMBOS E VIRADAS", "text": "Ganhar rodadas seguidas sobe seu multiplicador (×1,25, ×1,5, ×2). Combos na mesa dão bônus: 3 Trunfos, 3 figuras ou 3 cartas seguidas do mesmo naipe. Cada combo aumenta seu peso no pote se você acertar o palpite. Quem está em último ganha Fôlego ×1,5 e a última rodada vale ×2. Você tem 10 segundos por jogada."},
	]
	modal_open = true
	var ov := UIKit.overlay()
	overlay_layer.add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.GOLD, 24)
	box.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 40.0, 620.0), 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	box.add_child(v)
	var icon_l := UIKit.label("", 72, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var title_l := UIKit.label("", 46, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var text_l := UIKit.label("", 34, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	text_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_l.custom_minimum_size = Vector2(0, 330)
	var dots := HBoxContainer.new()
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.add_theme_constant_override("separation", 10)
	var next := UIKit.button("PRÓXIMO", UIKit.OK)
	var skip := UIKit.button("PULAR", UIKit.MUTED)
	for n in [icon_l, title_l, text_l, dots, next, skip]:
		v.add_child(n)
	ov.add_child(UIKit.centered(box))
	var state := {"i": 0}
	var render := func():
		var sl: Dictionary = slides[state["i"]]
		icon_l.text = sl["icon"]
		title_l.text = sl["title"]
		text_l.text = sl["text"]
		for c in dots.get_children():
			c.queue_free()
		for k in range(slides.size()):
			dots.add_child(UIKit.label("●" if k == state["i"] else "○", 28, UIKit.GOLD if k == state["i"] else UIKit.MUTED))
		next.text = "VAMOS JOGAR!" if state["i"] == slides.size() - 1 else "PRÓXIMO"
		skip.visible = state["i"] < slides.size() - 1
		FX.pop(title_l, 1.2)
	render.call()
	next.pressed.connect(func():
		Sfx.play("tick")
		if state["i"] >= slides.size() - 1:
			slides_done.emit()
		else:
			state["i"] += 1
			render.call())
	skip.pressed.connect(func(): slides_done.emit())
	await slides_done
	modal_open = false
	if is_inside_tree():
		ov.queue_free()


func _open_help() -> void:
	var v := UIKit.modal(overlay_layer, "COMO FUNCIONA O CAOS")
	var text := """NÍVEIS
• 5 níveis curtos de 8 cartas cada — sem licitação, sem monte, todo mundo joga pra si.
• Vence a partida quem somar mais pontos no total dos 5 níveis.

MODIFICADOR DO NÍVEL
• Todo nível sorteia UM modificador (nunca repete na mesma partida). Ele pode valer no nível inteiro ou só numa rodada.
• Nível inteiro: você vê a regra logo no início (ex.: Trunfo em Dobro, Naipe Fraco, Mundo ao Contrário, Naipe Maldito).
• Uma rodada só: é surpresa. Você só descobre qual e quando ela começa, numa tela cheia (ex.: Rodada Dourada ×3, Rodada Maldita, Saque, Assalto ao Líder).
• As cartas afetadas mostram o valor real direto na carta; decida olhando esse número.

PODER (1 por nível)
• Antes de cada nível você escolhe 1 de 3 poderes e usa UMA vez, na sua vez, pelo botão no rodapé:
• ⇅ ROUBAR TRUNFO — dá sua pior carta e leva o melhor Trunfo de um rival.
• ◎ ESPIAR — vê a mão inteira de um rival.
• ⚡ ARRISCAR — na rodada em que usar: vencer = ×2 nos pontos, perder = −2.

PALPITE E POTE (como no poker)
• Antes de cada nível você crava quantas rodadas vai ganhar (0 a 8) e quanto aposta: ◎10, ◎25, ◎50 ou tudo. Os palpites só aparecem juntos, no SHOWDOWN, e as apostas vão pro pote no centro da mesa.
• Acertou o número exato? Divide o pote com quem também acertou. O peso de cada um é a aposta × dificuldade (×1,0 até 2 rodadas, ×1,5 até 4, ×2,0 acima) e sobe até ×2 com os combos que você fez.
• Errou por 1? Recebe metade da aposta de volta. Errou por mais? A aposta fica no pote.
• Ninguém acertou? O pote acumula (JACKPOT) e vai pro próximo nível.
• DOBRAR (botão no topo, a partir da 4ª rodada, uma vez por nível): põe mais fichas no pote e dobra seu peso, se você ainda está no alvo.
• Ao vivo: cada jogador mostra "◎aposta · palpite" e "feitas/palpite" (verde no alvo, dourado por pouco, vermelho estourou). Toque no pote para ver todas as apostas.

COMBOS
• SEQUÊNCIA: 2 rodadas seguidas ×1,25, 3 seguidas ×1,5 (MÃO QUENTE), 4 ou mais ×2. As chamas ♨ mostram seu nível.
• CORTADO: você quebra a sequência de 2+ vitórias de alguém — +2 pts.
• CORTE DE REI: você corta um Rei com Trunfo — +3 pts.
• CHUVA DE TRUNFOS: 3 ou mais Trunfos na mesa — ×2 pra quem leva.
• REALEZA: 3 ou mais figuras (Valete, Cavaleiro, Dama, Rei) na mesa — ×1,5.
• ESCADA: 3 cartas seguidas do mesmo naipe na mesa — +3 pts.
• Cada combo que você faz aumenta o peso do seu palpite no pote.

NÍVEL FINAL
• Todos os pontos do 5º nível valem ×2.

RELÓGIO
• Você tem 10 segundos por jogada (a barra embaixo da mesa esvazia). Estourou, jogamos sua carta mais fraca.

FÔLEGO
• A partir da 2º nível, quem estiver em último no total ganha Fôlego: os pontos que capturar nesse nível valem x1,5. É a chance de virar o jogo.

FICHAS
• Entrar na mesa custa um buy-in em fichas, que forma o pote da partida. No fim, o pote é pago por colocação: 1º leva 50%, 2º 30%, 3º 15%, 4º 5%. Seu saldo de fichas e o pote ficam sempre visíveis na barra acima da mesa.

CARTAS
• Mesmas regras de rodada do Vanilla: seguir naipe, cortar com Trunfo se não tiver, cobrir com Trunfo maior se alguém já cortou. O Louco nunca vence, a não ser no modificador "O Louco Vence"."""
	var l := UIKit.label(text, 30, UIKit.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(620, 0)
	v.add_child(l)
	var tut := UIKit.button("VER TUTORIAL (3 TELAS)", UIKit.OK)
	tut.pressed.connect(func(): _intro_slides())
	v.add_child(tut)
	UIKit.close_button(overlay_layer, v)


func _open_pause() -> void:
	if finished:
		return
	var ov := UIKit.overlay()
	overlay_layer.add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.GOLD, 24)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(620, 0)
	box.add_child(v)
	v.add_child(UIKit.label("PAUSA", 40, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("Toque numa carta para selecionar (ela sobe) e de novo para jogar, ou arraste-a pra cima e solte na mesa. Segure / botão direito = zoom.", 28, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
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
