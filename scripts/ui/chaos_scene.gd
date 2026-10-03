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
const TABLE_SCALE := 0.50
const TURN_SECONDS := 10.0   # tempo pra jogar; estourou, joga a carta mais fraca
const DISCARD_SECONDS := 15.0   # tempo pro descarte inicial (10 cartas pra olhar); estourou, descarta as 2 mais fracas

var engine := ChaosEngine.new()
var config: Dictionary = {}
var bot_rng := RandomNumberGenerator.new()
var human_turn := false
var finished := false
var paused := false

var hud_badges: Array = []
var hud_titles: Array = []
var hud_totals: Array = []
var seat_avatars: Array = []
var turn_pulse_token := 0
var table_center: TableEllipse
var hand_container: Control
var selected_view: CardView
var throw_from := Vector2.ZERO
var has_throw_from := false
var status_label: Label
var banner_box: Panel
var banner_title: Label
var banner_sub: Label
var turn_bar: ProgressBar
var turn_left := 0.0
var main_area: Control
var seat_nodes: Array = []
var bet_pills: Array = []      # fichas apostadas na frente de cada jogador
var order_badges: Array = []   # 1, 2, 3... = ordem de fala / de jogada
var dealer_badges: Array = []
var phase := "idle"            # "bet" | "play" | "idle"
var bets_gathered := false     # apostas já juntadas no pote
var first_round_done := false
var info_label: Label
var trick_dots: HBoxContainer
var shown_totals: Array = []
var modal_open := false      # modal de poder/aposta aberto — o relógio da jogada pausa
var best_gain := 0.0         # maior pote que o jogador levou na sessão
var total_in := 0            # fichas que o jogador pôs na mesa (buy-in + recompras)
var action_text: Array = []  # última ação de cada assento nessa rodada
var action_color: Array = []
var popup_layer: Control
var overlay_layer: Control
var table_views: Array = []
var pot_box: PanelContainer
var pot_label: Label
var pot_sub: Label
var bet_tags: Array = []       # "◎25 · 3" por assento
var prog_tags: Array = []      # "1/3 ♨×1,5" ao vivo por assento
var hold_stacks: Array = []      # Blitz: stacks de antes da liquidação (a tela só muda depois da animação)
var hold_pot := -1.0
var blitz_revealed: Array = []  # Blitz: entrada de cada um já paga (pote), pill visível na mesa
var blitz_showdown := false     # Blitz: fim do nível — só aí o alvo dos rivais aparece pra você
var double_btn: Button
var discard_picks: Array = []   # Blitz: cartas marcadas na mão pra descartar (até BLITZ_DISCARD_SIZE)
var discarding_now := false     # relógio do descarte rodando (reaproveita turn_bar)
var discard_left := 0.0
var shown_pot := 0.0
var pot_locked := false        # contador do pote rolando: o refresh não sobrescreve

const FLAME := UIKit.COMBO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bot_rng.randomize()
	config = GameState.tournament_table_config() if not GameState.tournament.is_empty() else GameState.chaos_config()
	if not bool(config.get("entered", true)):
		add_child(UIKit.background())
		overlay_layer = Control.new()
		overlay_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(overlay_layer)
		_show_insufficient_fichas()
		return
	engine.setup_match(config)
	total_in = int(config["buy_in"])
	for p in range(engine.num_players):
		blitz_revealed.append(false)
		action_text.append("")
		action_color.append(UIKit.MUTED)
		shown_totals.append(engine.stacks[p])
	_build_ui()
	get_viewport().size_changed.connect(_on_resize)
	_refresh_hud()
	_rebuild_hand()
	var intro_key := "blitz_intro" if engine.blitz else "chaos_intro"
	if not GameState.autoplay and not bool(SaveManager.section("tips").get(intro_key, false)):
		await _intro_slides()
		SaveManager.section("tips")[intro_key] = true
		SaveManager.save_game()
		if not is_inside_tree():
			return
	await _announce_round()
	if not is_inside_tree():
		return
	_run_round.call_deferred()


func _show_insufficient_fichas() -> void:
	var ov := UIKit.overlay()
	overlay_layer.add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.LOSS, 24)
	box.custom_minimum_size = Vector2(664, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	box.add_child(v)
	v.add_child(UIKit.label("FICHAS INSUFICIENTES", 28, UIKit.LOSS, HORIZONTAL_ALIGNMENT_CENTER))
	var l := UIKit.label("Você precisa de %d fichas pra sentar na Mesa %s. Jogue Vanilla ou Ranqueado, ou volte ao menu e peça um empréstimo da casa." % [int(config["buy_in"]), "Blitz" if str(config.get("mode", "chaos")) == "blitz" else "Caos"], 32, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(620, 0)
	v.add_child(l)
	var btn := UIKit.button("VOLTAR AO MENU", UIKit.MUTED)
	btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	v.add_child(btn)
	ov.add_child(UIKit.centered(box))
	btn.grab_focus.call_deferred()


# ------------------------------------------------------------------ UI

const BAR_H := 132.0       ## barra de ações embaixo
const BANNER_H := 84.0     ## título + descrição do modificador, em cima da mão
const POT_H := 48.0        ## pote, embaixo da mão
const LEFT_W := 150.0
const RIGHT_W := 112.0
const MAX_UI_W := 900.0    ## em tela larga o jogo não estica além disso

var stage: Control
var margin_box: MarginContainer
var bottom_bar: HBoxContainer
var bet_row: HBoxContainer
var timer_label: Label
var center_card: PanelContainer


func _build_ui() -> void:
	add_child(UIKit.background())

	margin_box = MarginContainer.new()
	margin_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin_box.add_theme_constant_override("margin_" + side, Widgets.MARGIN)
	margin_box.add_theme_constant_override("margin_top", 16)
	margin_box.add_theme_constant_override("margin_bottom", 20)
	add_child(margin_box)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin_box.add_child(root)

	hud_badges.resize(engine.num_players)
	hud_titles.resize(engine.num_players)
	hud_totals.resize(engine.num_players)
	seat_avatars.resize(engine.num_players)
	bet_tags.resize(engine.num_players)
	prog_tags.resize(engine.num_players)
	bet_pills.resize(engine.num_players)
	order_badges.resize(engine.num_players)
	dealer_badges.resize(engine.num_players)
	seat_nodes.resize(engine.num_players)

	# Barra de topo — menu, nível/entrada + bolinhas das rodadas, ajuda.
	var topbar := HBoxContainer.new()
	topbar.add_theme_constant_override("separation", 12)
	root.add_child(topbar)
	var menu_btn := Widgets.icon_button("☰")
	menu_btn.pressed.connect(_open_pause)
	topbar.add_child(menu_btn)
	var info_box := UIKit.panel(UIKit.SURFACE, UIKit.BLACK, 8)
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
	var help_btn := Widgets.icon_button("?", UIKit.ACTION.darkened(0.1))
	help_btn.pressed.connect(_open_help)
	topbar.add_child(help_btn)

	# Palco: a mesa (elipse achatada) com os rivais sentados em volta, a distâncias iguais.
	stage = Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size = Vector2(0, 300)
	root.add_child(stage)
	main_area = stage
	table_center = TableEllipse.new()
	table_center.name = "TableCenter"
	table_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	table_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(table_center)
	table_center.resized.connect(_layout_table)
	for p in range(1, engine.num_players):
		stage.add_child(_build_rival_seat(p))

	_build_hand_zone(root)
	_build_bottom_bar(root)

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


## Card central (60% da largura): título e descrição do modificador em cima, a mão em arco no
## meio (por cima do card, as cartas passam das bordas) e o pote embaixo.
func _build_hand_zone(root: VBoxContainer) -> void:
	var hand_h := CardView.SIZE.y + CardView.MAX_LIFT + 60.0
	var zone := Control.new()
	zone.custom_minimum_size = Vector2(0, BANNER_H + hand_h + POT_H)
	root.add_child(zone)

	center_card = UIKit.panel(UIKit.SURFACE_DEEP, UIKit.OUTLINE, 10)
	center_card.anchor_left = 0.2
	center_card.anchor_right = 0.8
	center_card.anchor_top = 0.0
	center_card.anchor_bottom = 1.0
	center_card.offset_left = 0.0
	center_card.offset_right = 0.0
	center_card.offset_top = 0.0
	center_card.offset_bottom = 0.0
	center_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(center_card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 0)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_card.add_child(cv)

	# Faixa de avisos (altura fixa, nunca cresce com o texto): em repouso mostra o modificador.
	banner_box = Panel.new()
	banner_box.custom_minimum_size = Vector2(0, BANNER_H - 20.0)
	banner_box.clip_contents = true
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.add_theme_stylebox_override("panel", UIKit.box(UIKit.CLEAR, UIKit.CLEAR, 0, 0, 0))
	var bv := VBoxContainer.new()
	bv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.add_theme_constant_override("separation", 2)
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.add_child(bv)
	banner_title = UIKit.label("", 26, UIKit.BRAND, HORIZONTAL_ALIGNMENT_CENTER)
	banner_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	banner_title.clip_text = true
	bv.add_child(banner_title)
	banner_sub = UIKit.label("", 17, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	banner_sub.add_theme_font_size_override("font_size", 20)
	banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_sub.max_lines_visible = 2
	bv.add_child(banner_sub)
	cv.add_child(banner_box)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(spacer)

	_build_pot()
	cv.add_child(pot_box)

	# Mão em arco leve, sempre no tamanho real; rola de lado só se não couber.
	var hand_scroll := HandScroller.new()
	hand_scroll.anchor_left = 0.0
	hand_scroll.anchor_right = 1.0
	hand_scroll.anchor_top = 0.0
	hand_scroll.anchor_bottom = 0.0
	hand_scroll.offset_left = -float(Widgets.MARGIN)    # a mão vai até a borda da tela
	hand_scroll.offset_right = float(Widgets.MARGIN)
	hand_scroll.offset_top = BANNER_H
	hand_scroll.offset_bottom = BANNER_H + hand_h
	zone.add_child(hand_scroll)
	hand_scroll.resized.connect(_layout_hand)
	hand_container = Control.new()
	hand_container.name = "HandContainer"
	hand_container.mouse_filter = Control.MOUSE_FILTER_PASS
	hand_scroll.set_content(hand_container)


## Barra de baixo: stack e vazas à esquerda, ações no centro, relógio da jogada à direita.
func _build_bottom_bar(root: VBoxContainer) -> void:
	bottom_bar = HBoxContainer.new()
	bottom_bar.custom_minimum_size = Vector2(0, BAR_H)
	bottom_bar.add_theme_constant_override("separation", 10)
	root.add_child(bottom_bar)

	var left := UIKit.panel(UIKit.SURFACE_DEEP, UIKit.OUTLINE, 8)
	left.custom_minimum_size = Vector2(LEFT_W, 0)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lh := HBoxContainer.new()
	lh.add_theme_constant_override("separation", 6)
	lh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(lh)
	# Sem avatar: só o D (quando você é o dealer) e os dois números. O anel invisível serve de
	# origem pras fichas voando e pro destaque de vez.
	var ring0 := PanelContainer.new()
	ring0.custom_minimum_size = Vector2(1, 1)
	ring0.modulate.a = 0.0
	ring0.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lh.add_child(ring0)
	seat_avatars[0] = ring0
	var ord0 := _badge("", UIKit.PURPLE_DEEP, UIKit.MUTED)
	ord0.visible = false
	lh.add_child(ord0)
	order_badges[0] = ord0
	var dl0 := _badge("D", UIKit.MONEY, UIKit.BLACK)
	dl0.custom_minimum_size = Vector2(40, 40)
	dl0.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dl0.visible = false
	lh.add_child(dl0)
	dealer_badges[0] = dl0
	var info0 := _make_info(0, false)
	info0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info0.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lh.add_child(info0)
	bottom_bar.add_child(left)
	hud_badges[0] = left
	seat_nodes[0] = left

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 4)
	bottom_bar.add_child(mid)
	status_label = UIKit.label("", 20, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.max_lines_visible = 2
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.visible = false   # a vez e as dicas aparecem no card central, acima das cartas
	mid.add_child(status_label)
	bet_row = HBoxContainer.new()
	bet_row.add_theme_constant_override("separation", 6)
	bet_row.custom_minimum_size = Vector2(0, 72)
	bet_row.visible = false
	mid.add_child(bet_row)
	double_btn = UIKit.button("DOBRAR", UIKit.MONEY, 24)
	double_btn.custom_minimum_size = Vector2(0, 64)
	double_btn.visible = false
	double_btn.pressed.connect(_on_double_pressed)
	mid.add_child(double_btn)

	var right := UIKit.panel(UIKit.SURFACE_DEEP, UIKit.OUTLINE, 8)
	right.custom_minimum_size = Vector2(RIGHT_W, 0)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rv := VBoxContainer.new()
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	rv.add_theme_constant_override("separation", 4)
	rv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(rv)
	var cap := UIKit.label("TEMPO", 20, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	cap.add_theme_font_size_override("font_size", 20)
	rv.add_child(cap)
	timer_label = UIKit.label("0:10", 36, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	timer_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	rv.add_child(timer_label)
	turn_bar = ProgressBar.new()
	turn_bar.show_percentage = false
	turn_bar.min_value = 0.0
	turn_bar.max_value = TURN_SECONDS
	turn_bar.custom_minimum_size = Vector2(0, 10)
	turn_bar.modulate.a = 0.0
	turn_bar.add_theme_stylebox_override("background", UIKit.box(UIKit.PURPLE_DEEP, UIKit.PURPLE, 2, 7, 0))
	turn_bar.add_theme_stylebox_override("fill", UIKit.box(UIKit.BRAND, UIKit.BRAND, 0, 7, 0))
	rv.add_child(turn_bar)
	bottom_bar.add_child(right)


func _is_wide() -> bool:
	var sz := get_viewport_rect().size
	return sz.x > sz.y


## Em tela larga o jogo fica numa coluna centralizada (não estica).
func _apply_orientation() -> void:
	var side := maxf(float(Widgets.MARGIN), (get_viewport_rect().size.x - MAX_UI_W) / 2.0)
	margin_box.add_theme_constant_override("margin_left", int(side))
	margin_box.add_theme_constant_override("margin_right", int(side))
	_refresh_hud()
	_layout_table()


func _on_resize() -> void:
	_apply_orientation()
	_layout_table()
	_layout_hand()


## Assento de rival: avatar + card com nome, stack, vazas e situação. A posição é calculada em
## `_layout_seats` (em volta da mesa, a distâncias iguais).
func _build_rival_seat(p: int) -> Control:
	var seat := Control.new()
	seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seat.add_child(_make_avatar(p, 84.0))
	var card := UIKit.panel(UIKit.SURFACE_DEEP, UIKit.OUTLINE, 8)
	card.custom_minimum_size = Vector2(150, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(_make_info(p, true))
	seat.add_child(card)
	seat_nodes[p] = seat
	hud_badges[p] = seat
	return seat


## Avatar redondo com a bolinha de ordem (canto de cima) e o D dourado do dealer.
func _make_avatar(p: int, d: float) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(d + 16.0, d + 12.0)
	wrap.size = wrap.custom_minimum_size
	wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := PanelContainer.new()
	ring.custom_minimum_size = Vector2(d, d)
	ring.size = Vector2(d, d)
	ring.position = Vector2(8, 10)
	ring.pivot_offset = Vector2(d / 2.0, d / 2.0)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := Portrait.new().setup(p, UIKit.CLEAR, d - 16.0)
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ring.add_child(face)
	wrap.add_child(ring)
	var ord := _badge("", UIKit.PURPLE_DEEP, UIKit.MUTED)
	ord.position = Vector2(0, 0)
	wrap.add_child(ord)
	var dl := _badge("D", UIKit.MONEY, UIKit.BLACK)
	dl.custom_minimum_size = Vector2(40, 40)
	dl.position = Vector2(wrap.size.x - 40.0, wrap.size.y - 40.0)
	dl.visible = false
	wrap.add_child(dl)
	seat_avatars[p] = ring
	order_badges[p] = ord
	dealer_badges[p] = dl
	return wrap


## Nome (só rivais), stack e vazas x/y — só números, todos do mesmo tamanho e cor. A vez de
## cada um aparece na borda grossa do avatar, não em texto.
func _make_info(p: int, rival: bool) -> VBoxContainer:
	var fs := 22 if rival else 34
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_l := UIKit.label("", fs, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	name_l.add_theme_font_size_override("font_size", fs)
	name_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_l.clip_text = true
	name_l.visible = rival
	v.add_child(name_l)
	var stack_l := UIKit.label("0", fs, UIKit.INK if rival else UIKit.MONEY, HORIZONTAL_ALIGNMENT_CENTER)
	stack_l.add_theme_font_size_override("font_size", fs)
	stack_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(stack_l)
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel", UIKit.box(UIKit.CLEAR, UIKit.CLEAR, 0, 0, 0))
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 0)
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap_l := UIKit.label("", fs, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)   # sem legenda (fica escondida)
	cap_l.visible = false
	pv.add_child(cap_l)
	var bet_l := UIKit.label("", fs, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	bet_l.add_theme_font_size_override("font_size", fs)
	bet_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	pv.add_child(bet_l)
	pill.add_child(pv)
	pill.modulate.a = 0.0
	v.add_child(pill)
	var status_l := UIKit.label("", 20, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	status_l.visible = false   # a vez é mostrada pela borda do avatar e pelo card central
	v.add_child(status_l)
	hud_titles[p] = name_l
	hud_totals[p] = stack_l
	bet_tags[p] = bet_l
	bet_pills[p] = pill
	prog_tags[p] = status_l
	return v


## Rivais em volta da mesa, com ângulos iguais entre si. Nas laterais o card (stack + vazas)
## fica embaixo do avatar; em cima e embaixo da mesa, ao lado dele.
func _layout_seats() -> void:
	if table_center == null or stage == null:
		return
	var c := table_center.center_point()
	var r := table_center.seat_radii()
	var n := engine.num_players
	for p in range(1, n):
		var seat := seat_nodes[p] as Control
		if seat == null:
			continue
		var wrap := seat.get_child(0) as Control
		var card := seat.get_child(1) as Control
		card.size = card.get_combined_minimum_size()
		var theta := TableEllipse.seat_angle(p, n)
		var pt := c + Vector2(cos(theta) * r.x, sin(theta) * r.y)
		var w := 0.0
		var h := 0.0
		if absf(cos(theta)) <= 0.7:
			w = wrap.size.x + 4.0 + card.size.x
			h = maxf(wrap.size.y, card.size.y)
			wrap.position = Vector2(0.0, (h - wrap.size.y) / 2.0)
			card.position = Vector2(wrap.size.x + 4.0, (h - card.size.y) / 2.0)
		else:
			w = maxf(wrap.size.x, card.size.x)
			h = wrap.size.y + 2.0 + card.size.y
			wrap.position = Vector2((w - wrap.size.x) / 2.0, 0.0)
			card.position = Vector2((w - card.size.x) / 2.0, wrap.size.y + 2.0)
		seat.size = Vector2(w, h)
		seat.position = Vector2(
			clampf(pt.x - w / 2.0, 0.0, maxf(stage.size.x - w, 0.0)),
			clampf(pt.y - h / 2.0, 0.0, maxf(stage.size.y - h, 0.0)))


## Bolinha com uma letra/número (ordem de fala, botão do dealer).
func _badge(text: String, fill: Color, border: Color) -> PanelContainer:
	var b := PanelContainer.new()
	b.custom_minimum_size = Vector2(30, 30)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UIKit.box(fill, border, 3, 15, 0)
	sb.set_corner_radius_all(15)
	b.add_theme_stylebox_override("panel", sb)
	var l := UIKit.label(text, 20, UIKit.TEXT_ON_LIGHT if (fill == UIKit.INK or fill == UIKit.MONEY) else UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	b.add_child(l)
	return b


## Pote: só o valor em fichas, embaixo da mão, dentro do card central.
func _build_pot() -> void:
	pot_box = PanelContainer.new()
	pot_box.custom_minimum_size = Vector2(0, POT_H)
	pot_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pot_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pot_box.add_theme_stylebox_override("panel", UIKit.box(UIKit.CLEAR, UIKit.CLEAR, 0, 0, 0))
	pot_label = UIKit.label("POTE ◎ 0", 34, UIKit.MONEY, HORIZONTAL_ALIGNMENT_CENTER)
	pot_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	pot_box.add_child(pot_label)
	pot_sub = UIKit.label("", 18, UIKit.MUTED)   # sem lugar na tela: o card só mostra o valor
	pot_sub.visible = false


## Reposiciona assentos e cartas da mesa (ex.: ao virar o celular).
func _layout_table() -> void:
	if table_center == null:
		return
	_layout_seats()
	for v in table_views:
		var cv: CardView = v["view"]
		cv.position = _slot_pos(int(v["player"]))


## A carta de cada jogador fica na direção do assento dele, perto do centro da mesa.
func _slot_pos(player: int) -> Vector2:
	var c := table_center.center_point()
	var r := table_center.seat_radii()
	var theta := TableEllipse.seat_angle(player, engine.num_players)
	var center := c + Vector2(cos(theta) * r.x * 0.34, sin(theta) * r.y * 0.36)
	return center - CardView.SIZE / 2.0


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
	var avail_h := CardView.SIZE.y + CardView.MAX_LIFT + 60.0
	var content_w := HandLayout.apply(cards, avail_w, avail_h, "fan", CardView.SIZE)
	(parent as HandScroller).set_content_size(Vector2(content_w, avail_h))


func _rebuild_hand() -> void:
	for c in hand_container.get_children():
		hand_container.remove_child(c)
		c.queue_free()
	selected_view = null
	var discarding := phase == "discard"
	var legal := engine.legal_for(0) if (human_turn and not discarding) else []
	for card in engine.hands[0]:
		var cv: CardView = CARD_SCENE.instantiate()
		cv.setup(card, true)
		hand_container.add_child(cv)
		cv.set_playable(discarding or (human_turn and legal.has(card)))
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
	var good := UIKit.OK if dark_face else UIKit.GOOD_ON_LIGHT
	var bad := UIKit.LOSS if dark_face else UIKit.BAD_ON_LIGHT
	cv.points_label.add_theme_color_override("font_color", good if boosted else bad)


func _plural(n: int, one: String, many: String) -> String:
	return "%d %s" % [n, one if n == 1 else many]


# ------------------------------------------------------------------ níveis / modificador

## Tela de transição de início de nível: só orienta (nível, mesa) — o modificador de cada
## rodada é anunciado à parte, na hora, por `_trick_start()`.
func _announce_round() -> void:
	_refresh_hud()
	_rebuild_hand()
	var kicker := "NÍVEL %d%s" % [engine.round_index + 1, (" DE %d" % engine.levels) if engine.levels > 0 else ""]
	var lines: Array = []
	if engine.round_index == 0 and engine.blitz:
		lines.append({"head": "MESA %s" % str(config.get("table_name", "")).to_upper(), "title": "ENTRADA ◎%d" % int(engine.blitz_entry()), "text": "Em cada nível você palpita quantas rodadas vai ganhar e paga a entrada. Acertou o número exato, leva o pote. Cada rodada ainda paga fichas pelos pontos das cartas. Você senta com ◎%d e leva de volta o que tiver quando sair." % engine.buy_in, "color": UIKit.MONEY})
	elif engine.round_index == 0:
		lines.append({"head": "MESA %s" % str(config.get("table_name", "")).to_upper(), "title": "BLIND ◎%d" % engine.blind, "text": "Todo mundo paga o blind a cada rodada. Você senta com ◎%d e leva de volta o que tiver quando sair." % engine.buy_in, "color": UIKit.MONEY})
	else:
		lines.append({"head": "CARTAS NOVAS", "title": "NÍVEL %d" % (engine.round_index + 1), "text": "Mão nova, 8 rodadas — cada uma com o seu próprio modificador, anunciado antes de começar.", "color": UIKit.MODIFIER})
	var hold := 0.0 if (engine.round_index == 0 and engine.blitz and not first_round_done) else (2.6 if not first_round_done else 2.2)
	await _transition(kicker, lines, hold)
	first_round_done = true
	_banner_clear()


## Texto da faixa em repouso (nenhuma mensagem ativa): o modificador dessa rodada — já sempre
## conhecido, porque `_trick_start()` avisa em tela cheia antes de qualquer decisão.
func _rest_banner() -> Array:
	var m := engine.modifier
	if m == -1:
		return ["", "", UIKit.MUTED]
	return ["%s %s" % [ChaosModifiers.ICONS[m], _modifier_label(m)], ChaosModifiers.short_of(m, engine.blitz), ChaosModifiers.color_of(m)]


## Nome do modificador, incluindo o naipe sorteado quando ele tiver um (e já traduzido pro
## Blitz, quando o nome muda de mão pra lá).
func _modifier_label(m: int) -> String:
	var nm := ChaosModifiers.name_of(m, engine.blitz)
	if ChaosModifiers.has_suit(m) and engine.weak_suit != -1:
		nm = "%s (%s)" % [nm, CardData.SUIT_NAMES[engine.weak_suit]]
	return nm


## Tela cheia de transição. `blocks`: [{head, title, text, color}]. Fecha ao tocar ou
## depois de `hold` segundos. No autoplay (testes) só espera um instante.
func _transition(kicker: String, blocks: Array, hold: float) -> void:
	if GameState.autoplay or not is_inside_tree():
		await _wait(0.05)
		return
	var ov := ColorRect.new()
	ov.color = UIKit.SCRIM
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_layer.add_child(ov)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	var width := minf(get_viewport_rect().size.x - 80.0, 680.0)
	v.custom_minimum_size = Vector2(width, 0)
	v.add_child(UIKit.label(kicker, 46, UIKit.BRAND, HORIZONTAL_ALIGNMENT_CENTER))
	for b in blocks:
		var card := UIKit.panel(UIKit.PURPLE_DEEP, b["color"], 18)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 4)
		card.add_child(cv)
		cv.add_child(UIKit.label(b["head"], 28, b["color"], HORIZONTAL_ALIGNMENT_CENTER))
		cv.add_child(UIKit.label(b["title"], 40, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
		var t := UIKit.label(b["text"], 32, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(t)
		v.add_child(card)
	var go := UIKit.button("ENTENDI, CONTINUAR")
	v.add_child(go)
	var timer_lbl := UIKit.label("", 20, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(timer_lbl)
	ov.add_child(UIKit.centered(v))
	UIKit.fit.call_deferred(v)
	go.grab_focus.call_deferred()
	ov.modulate.a = 0.0
	create_tween().tween_property(ov, "modulate:a", 1.0, GameState.anim(0.18))
	Sfx.play("chip")
	# Nenhuma distração: só o conteúdo. Avança sozinha depois de `hold` segundos (com contagem
	# visível) ou na hora, se o jogador tocar antes.
	_count_down(go, timer_lbl, hold)
	await go.pressed
	if not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_property(ov, "modulate:a", 0.0, GameState.anim(0.18))
	await tw.finished
	ov.queue_free()


## Contagem visível até a tela avançar sozinha. Tocar em "ENTENDI, CONTINUAR" a qualquer
## momento pula a espera. Se `go` começa desabilitado (ex.: uma animação ainda não travou),
## espera ele liberar antes de contar.
func _count_down(go: Button, lbl: Label, hold: float) -> void:
	while is_instance_valid(go) and is_inside_tree() and go.disabled:
		await get_tree().process_frame
	if not is_instance_valid(go) or not is_inside_tree():
		return
	if hold <= 0.0:
		return  # sem auto-advance: jogador fecha na hora que quiser
	var left := hold
	while left > 0.05 and is_instance_valid(go) and is_inside_tree():
		lbl.text = "começa em %ds" % int(ceil(left))
		await get_tree().create_timer(GameState.anim(0.2), true, false, true).timeout
		left -= 0.2
	if is_instance_valid(go) and not go.disabled:
		go.pressed.emit()


## Mensagem na faixa reservada acima da mesa (nunca cobre nada). `color` pinta a borda.
func _banner(title: String, sub: String, color: Color) -> void:
	banner_title.text = title
	banner_title.add_theme_color_override("font_color", color)
	banner_sub.text = sub
	banner_box.modulate.a = 0.0
	create_tween().tween_property(banner_box, "modulate:a", 1.0, GameState.anim(0.12))


func _banner_clear() -> void:
	# Em repouso a faixa lembra o modificador do nível (informação útil no lugar de um vazio).
	var rest := _rest_banner()
	banner_title.text = str(rest[0])
	banner_title.add_theme_color_override("font_color", rest[2])
	banner_sub.text = str(rest[1])
	banner_box.modulate.a = 1.0


# ------------------------------------------------------------------ loop de turnos

## Começo de rodada: se o modificador de rodada (surpresa) vale agora, revela numa tela cheia
## (surpresa) ou só na faixa (1ª/última, já conhecidas); deixa o aviso fixo durante a rodada.
## Começo de toda rodada: sorteia o modificador dessa vaza e explica em tela cheia, sem
## distração nenhuma por trás — só o conteúdo e a contagem até começar. Sempre acontece, nunca
## é surpresa: o jogador (e, no Blitz, o palpite) sempre sabe a regra antes de decidir.
func _trick_start() -> void:
	engine.draw_trick_modifier()
	if not is_inside_tree():
		return
	var m := engine.modifier
	if m == -1:
		# Defensivo: toda rodada de Blitz/Caos sorteia modificador, sem exceção — isto nunca
		# deveria disparar, mas evita travar a tela cheia se `modifier_sequence` vier vazio.
		_banner_clear()
		return
	var color := ChaosModifiers.color_of(m)
	await _modifier_transition(m, color)
	if is_inside_tree():
		_banner("%s %s" % [ChaosModifiers.ICONS[m], _modifier_label(m)], ChaosModifiers.short_of(m, engine.blitz), color)


## Sorteio do modificador da rodada: em vez de texto trocando sozinho, um item fechado carrega,
## estoura em partículas e revela o efeito sorteado — a mesma tela cheia e o mesmo avanço
## automático/por toque de `_transition`, só que com uma animação própria no lugar do bloco.
func _modifier_transition(m: int, color: Color) -> void:
	if GameState.autoplay or not is_inside_tree():
		await _wait(0.05)
		return
	var ov := ColorRect.new()
	ov.color = UIKit.SCRIM
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_layer.add_child(ov)
	# Kicker lá no topo da tela (não no meio, junto do resto) — é só contexto, não o assunto.
	var kicker := UIKit.label("RODADA %d DE %d" % [engine.trick_number + 1, ChaosEngine.HAND_SIZE], 26, UIKit.ACTION, HORIZONTAL_ALIGNMENT_CENTER)
	kicker.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	kicker.offset_top = 56.0
	ov.add_child(kicker)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	var width := minf(get_viewport_rect().size.x - 80.0, 680.0)
	v.custom_minimum_size = Vector2(width, 0)
	var orb_hold := Control.new()
	orb_hold.custom_minimum_size = Vector2(190, 190)
	orb_hold.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var orb := PanelContainer.new()
	orb.custom_minimum_size = Vector2(170, 170)
	orb.size = Vector2(170, 170)
	orb.position = Vector2(10, 10)
	orb.pivot_offset = Vector2(85, 85)
	var sealed := UIKit.box(UIKit.MUTED.darkened(0.6), UIKit.MUTED, 5, 85, 0)
	sealed.set_corner_radius_all(85)
	orb.add_theme_stylebox_override("panel", sealed)
	var orb_icon := UIKit.label("✦", 60, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	orb_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	orb.add_child(orb_icon)
	orb_hold.add_child(orb)
	v.add_child(orb_hold)
	# Sem ícone no título: o orbe logo acima já mostra o ícone do modificador sorteado.
	var title_lbl := UIKit.label("", 40, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(title_lbl)
	# Efeito e dica em linhas separadas (não um parágrafo só) — mais fácil de ler de relance.
	var desc_lbl := UIKit.label(ChaosModifiers.desc_of(m, engine.blitz), 28, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.modulate.a = 0.0
	v.add_child(desc_lbl)
	var tip_lbl := UIKit.label(ChaosModifiers.tip_of(m, engine.blitz), 22, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_lbl.modulate.a = 0.0
	v.add_child(tip_lbl)
	var go := UIKit.button("ENTENDI, CONTINUAR")
	go.disabled = true
	go.modulate.a = 0.0
	v.add_child(go)
	var timer_lbl := UIKit.label("", 20, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(timer_lbl)
	ov.add_child(UIKit.centered(v))
	UIKit.fit.call_deferred(v)
	go.grab_focus.call_deferred()
	ov.modulate.a = 0.0
	create_tween().tween_property(ov, "modulate:a", 1.0, GameState.anim(0.18))
	Sfx.play("tick")
	_open_modifier_orb(orb, orb_icon, title_lbl, desc_lbl, tip_lbl, go, m, color)
	# +3s a mais pra realmente dar tempo de ler o modificador sorteado antes de avançar sozinho.
	_count_down(go, timer_lbl, 6.2)
	await go.pressed
	if not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_property(ov, "modulate:a", 0.0, GameState.anim(0.18))
	await tw.finished
	ov.queue_free()


## Anima o item: carrega (pulsa), estoura (partículas + tremor na cor do modificador) e revela
## o ícone+nome sorteado, só então liberando os textos e o botão de continuar.
func _open_modifier_orb(orb: PanelContainer, orb_icon: Label, title_lbl: Label, desc_lbl: Label, tip_lbl: Label, go: Button, m: int, color: Color) -> void:
	for i in range(3):
		if not is_instance_valid(orb) or not is_inside_tree():
			return
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(orb, "scale", Vector2(1.08, 1.08), 0.22)
		tw.tween_property(orb, "scale", Vector2(0.96, 0.96), 0.22)
		await tw.finished
	if not is_instance_valid(orb) or not is_inside_tree():
		return
	Sfx.play("chip")
	var punch := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.tween_property(orb, "scale", Vector2(1.35, 1.35), 0.12)
	await punch.finished
	if not is_instance_valid(orb):
		return
	var opened := UIKit.box(color.darkened(0.55), color, 6, 85, 0)
	opened.set_corner_radius_all(85)
	orb.add_theme_stylebox_override("panel", opened)
	orb_icon.text = str(ChaosModifiers.ICONS[m])
	orb_icon.add_theme_color_override("font_color", color)
	title_lbl.text = _modifier_label(m)
	FX.burst(popup_layer, orb.get_global_rect().get_center(), color, 20)
	FX.shake(self, 0.35)
	Sfx.play("win")
	var settle := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	settle.tween_property(orb, "scale", Vector2.ONE, 0.22)
	await settle.finished
	if is_instance_valid(desc_lbl):
		create_tween().tween_property(desc_lbl, "modulate:a", 1.0, GameState.anim(0.3))
	if is_instance_valid(tip_lbl):
		create_tween().tween_property(tip_lbl, "modulate:a", 1.0, GameState.anim(0.3))
	if is_instance_valid(go):
		go.disabled = false
		create_tween().tween_property(go, "modulate:a", 1.0, GameState.anim(0.3))


## Modal genérico de escolha: `opts` = [{label, desc, color}]. Devolve o índice tocado,
## ou -1 se `cancel` e o jogador desistiu.
func _modal_choice(title: String, sub: String, opts: Array, cancel := false) -> int:
	modal_open = true
	var ov := UIKit.overlay()
	overlay_layer.add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.BRAND, 24)
	box.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 40.0, 600.0), 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	box.add_child(v)
	v.add_child(UIKit.label(title, 32, UIKit.BRAND, HORIZONTAL_ALIGNMENT_CENTER))
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
	UIKit.pop_in(box, GameState.anim(0.2))
	var chosen: int = await item_chosen
	modal_open = false
	if is_inside_tree():
		ov.queue_free()
	return chosen


func _wait(seconds: float) -> void:
	await get_tree().create_timer(GameState.anim(seconds)).timeout
	while paused and is_inside_tree():
		await get_tree().create_timer(0.1).timeout


func _wait_human() -> CardData:
	human_turn = true
	await _tip("turn", "SUA VEZ!", "Toque numa carta pra selecioná-la (ela sobe) e toque de novo pra jogar. Você tem 10 segundos por jogada.")
	if engine.blitz and engine.can_double(0):
		await _tip("double", "PODE DOBRAR!", "A partir da 4ª rodada, o botão DOBRAR paga mais uma entrada e dobra o peso do seu palpite no pote; da 6ª em diante dá pra TRIPLICAR. Vale a pena quando você já está no alvo e a mão que sobrou é fraca demais pra ganhar mais uma rodada. Só dá pra dobrar até duas vezes por nível.")
	var ls := TrickRules.lead_suit(engine.plays)
	if ls == -1:
		_banner("SUA VEZ", "Abra com qualquer carta.", UIKit.TURN)
	elif ls == CardData.Suit.TRUNFO:
		_banner("SUA VEZ", "Jogue um Trunfo.", UIKit.TURN)
	else:
		_banner("SUA VEZ", "Siga %s (ou Trunfo/Louco)." % CardData.SUIT_NAMES[ls], UIKit.TURN)
	turn_left = TURN_SECONDS
	turn_bar.modulate.a = 1.0
	_rebuild_hand()
	var card: CardData = await human_card_chosen
	human_turn = false
	turn_bar.modulate.a = 0.0
	_banner_clear()
	return card


func _mmss(seconds: float) -> String:
	var t := maxi(int(ceil(seconds)), 0)
	return "%d:%02d" % [t / 60, t % 60]


func _process(delta: float) -> void:
	if timer_label != null and turn_bar != null:
		var live := turn_bar.modulate.a > 0.5
		timer_label.modulate.a = 1.0 if live else 0.35
		timer_label.text = _mmss(turn_bar.value if live else TURN_SECONDS)
	if discarding_now and not paused and not modal_open and not finished and turn_bar != null:
		discard_left -= delta
		turn_bar.value = maxf(discard_left, 0.0)
		var urgent_d := discard_left <= 3.0
		turn_bar.add_theme_stylebox_override("fill", UIKit.box(UIKit.LOSS if urgent_d else UIKit.BRAND, UIKit.BRAND, 0, 7, 0))
		if discard_left <= 0.0:
			discarding_now = false
			var auto: Array = ChaosBot.wants_discard(engine, 0, BotAI.Difficulty.NORMAL, bot_rng)
			engine.apply_discard(0, auto)
			_banner("TEMPO ESGOTADO", "Descartamos as 2 mais fracas.", UIKit.LOSS)
			item_chosen.emit(1)
		return
	if not human_turn or paused or modal_open or finished or turn_bar == null:
		return
	turn_left -= delta
	turn_bar.value = maxf(turn_left, 0.0)
	var urgent := turn_left <= 3.0
	turn_bar.add_theme_stylebox_override("fill", UIKit.box(UIKit.LOSS if urgent else UIKit.BRAND, UIKit.BRAND, 0, 7, 0))
	if turn_left <= 0.0:
		var legal := engine.legal_for(0)
		if legal.is_empty():
			return
		var weakest: CardData = legal[0]
		for c in legal:
			if (c as CardData).points() < weakest.points():
				weakest = c
		human_turn = false
		_banner("TEMPO ESGOTADO", "Jogamos sua carta mais fraca.", UIKit.LOSS)
		human_card_chosen.emit(weakest)


func _on_card_tapped(view: CardView) -> void:
	if phase == "discard":
		_on_discard_tapped(view)
		return
	if not human_turn or not view.playable:
		if human_turn and not view.playable:
			_banner("JOGADA ILEGAL", "Siga o naipe ou corte com Trunfo.", UIKit.LOSS)
		return
	if view.selected:
		_on_card_play(view)
		return
	for c in hand_container.get_children():
		(c as CardView).set_selected(c == view)
	selected_view = view
	(hand_container.get_parent() as HandScroller).reveal(view.position.x, CardView.SIZE.x)
	Sfx.play("tick")


## Carta arrastada pra cima e solta além do limite: joga (ou descarta, na etapa de descarte),
## saindo do ponto onde foi solta.
func _on_card_thrown(view: CardView, drop_global: Vector2) -> void:
	if phase == "discard":
		_commit_discard(view, drop_global)
		return
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


# ------------------------------------------------------------------ resumo de nível / fim

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
	UIKit.pop_in(holder, GameState.anim(0.18))
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


## Tutorial de 3 passos: mostrado na primeira partida e sempre que tocar em "?".
func _intro_slides() -> void:
	modal_open = true
	var m := StepsModal.open(overlay_layer, "MESA BLITZ" if engine.blitz else "MESA CAOS", HelpContent.blitz_intro() if engine.blitz else HelpContent.chaos_intro(), "VAMOS JOGAR!")
	await m.closed
	modal_open = false


func _open_help() -> void:
	if engine.blitz:
		StepsModal.open(overlay_layer, "COMO FUNCIONA O BLITZ", HelpContent.blitz(), "ENTENDI", false)
	else:
		StepsModal.open(overlay_layer, "COMO FUNCIONA O CAOS", HelpContent.chaos(), "ENTENDI", false)


func _open_pause() -> void:
	if finished:
		return
	var ov := UIKit.overlay()
	overlay_layer.add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.BRAND, 24)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(620, 0)
	box.add_child(v)
	v.add_child(UIKit.label("PAUSA", 40, UIKit.BRAND, HORIZONTAL_ALIGNMENT_CENTER))
	var ph := UIKit.label("Toque numa carta para selecionar (ela sobe) e de novo para jogar, ou arraste-a pra cima e solte na mesa. Segure / botão direito = zoom. Sair da mesa devolve suas fichas da stack pra carteira.", 28, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	ph.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(ph)
	paused = true
	ov.tree_exited.connect(func(): paused = false)
	var resume := UIKit.button("CONTINUAR")
	resume.pressed.connect(ov.queue_free)
	v.add_child(resume)
	var quit := UIKit.button("SAIR DA MESA  ◎%d" % int(engine.stacks[0]), UIKit.DANGER)
	quit.pressed.connect(func():
		paused = false
		ov.queue_free()
		modal_open = false
		human_turn = false
		_finish_match()
		item_chosen.emit(-1)
		human_card_chosen.emit(null))
	v.add_child(quit)
	ov.add_child(UIKit.centered(box))
	UIKit.pop_in(box, GameState.anim(0.2))
	resume.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if overlay_layer.get_child_count() > 0 and not finished:
			overlay_layer.get_child(overlay_layer.get_child_count() - 1).queue_free()
		else:
			_open_pause()


# ------------------------------------------------------------------ HUD (stacks, pote, ações)

# ------------------------------------------------------------------ loop de rodadas

func _run_round() -> void:
	if engine.blitz:
		if not await _blitz_open_level():
			return
	while not engine.is_round_over():
		if not is_inside_tree() or finished:
			return
		# Quebrou? O aviso vem antes da animação do modificador, não depois.
		if not await _ensure_solvent():
			return
		if not bool(config.get("tournament", false)):
			for q in engine.refill_bots():
				await _new_player_sits(q)
		await _trick_start()
		if not is_inside_tree() or finished:
			return
		engine.begin_trick()
		_reset_actions()
		_refresh_hud()
		await _betting_phase()
		if not is_inside_tree() or finished:
			return
		if engine.walkover_player() != -1:
			await _resolve_walkover(engine.resolve_walkover())
			continue
		await _play_cards()
	if not is_inside_tree() or finished:
		return
	if engine.blitz:
		await _blitz_settlement()
		if not is_inside_tree() or finished:
			return
		GameState.blitz_level_played()
	var choice := await _show_round_summary()
	if not is_inside_tree() or finished:
		return
	if choice == "leave" or engine.is_match_over():
		_finish_match()
		return
	engine.advance_round()
	await _announce_round()
	if not is_inside_tree():
		return
	_run_round.call_deferred()


func _play_cards() -> void:
	while not engine.is_round_over() and not finished:
		if not is_inside_tree():
			return
		var p := engine.current
		_refresh_hud()
		if engine.blitz and (p != 0 or GameState.autoplay) and ChaosBot.wants_double(engine, p, int(config["difficulty"][p]), bot_rng):
			if p != 0 and not GameState.autoplay:
				await _wait(bot_rng.randf_range(0.5, 1.0) * ChaosBot.style_delay_mult(engine, p))
				if not is_inside_tree() or finished:
					return
			await _apply_double(p)
			if not is_inside_tree() or finished:
				return
		var card: CardData
		if p == 0 and not GameState.autoplay:
			card = await _wait_human()
		else:
			await _wait(0.9 if p == 0 else (bot_rng.randf_range(0.55, 0.95) if engine.blitz else bot_rng.randf_range(0.9, 1.5)))
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
			return


## Bot sem fichas sai e um jogador novo senta no lugar dele.
func _new_player_sits(q: int) -> void:
	var used: Array = config["names"]
	var pool: Array = GameState.BOT_NAMES.filter(func(n): return not used.has(n))
	if not pool.is_empty():
		config["names"][q] = pool[bot_rng.randi_range(0, pool.size() - 1)]
	shown_totals[q] = engine.stacks[q]
	_refresh_hud()
	if GameState.autoplay:
		return
	Sfx.play("chip")
	_banner("NOVO JOGADOR", "%s sentou na mesa com ◎ %d." % [str(config["names"][q]).to_upper(), int(engine.stacks[q])], UIKit.MUTED)
	await _wait(0.9)


## Você ficou sem fichas pro blind: recompra ou sai da mesa.
func _ensure_solvent() -> bool:
	if bool(config.get("tournament", false)):
		# Torneio: qualquer stack > 0 ainda joga (all-in pelo que tiver — a ante já é limitada
		# ao que sobrou em begin_trick()); só stack zerada é eliminação de verdade. Sem isso,
		# quem ficasse abaixo do blind escalado travava pra sempre sem nunca ser eliminado.
		if engine.stacks[0] > 0.0:
			return true
		_finish_match()
		return false
	if engine.stacks[0] >= float(engine.blind):
		return true
	if GameState.autoplay:
		_finish_match()
		return false
	var profile := SaveManager.section("profile")
	var can := int(profile["fichas"]) >= engine.buy_in
	var opts: Array = []
	if can:
		opts.append({"label": "RECOMPRAR ◎%d" % engine.buy_in, "desc": "Volta pra mesa com uma stack nova.", "color": UIKit.OK})
	opts.append({"label": "SAIR DA MESA", "desc": "", "color": UIKit.MUTED})
	var i := await _modal_choice("VOCÊ QUEBROU!", "Suas fichas na mesa acabaram.", opts)
	if not is_inside_tree():
		return false
	if can and i == 0:
		profile["fichas"] = int(profile["fichas"]) - engine.buy_in
		SaveManager.save_game()
		engine.stacks[0] += float(engine.buy_in)
		total_in += engine.buy_in
		shown_totals[0] = engine.stacks[0]
		_refresh_hud()
		return true
	_finish_match()
	return false


# ------------------------------------------------------------------ apostas

func _hand_label() -> String:
	var s := ChaosBot.hand_strength(engine, 0)
	if s >= 0.75:
		return "FORTE ★★★"
	if s >= 0.55:
		return "BOA ★★☆"
	if s >= 0.35:
		return "MÉDIA ★☆☆"
	return "FRACA ☆☆☆"


## Ações de aposta do jogador na barra de baixo: DESISTIR / PASSAR ou PAGAR / APOSTAR ou
## AUMENTAR (este abre o seletor de valor acima da barra). Devolve {action, to}.
func _human_bet() -> Dictionary:
	modal_open = true
	var opt := engine.bet_options(0)
	var can_check := bool(opt["can_check"])
	var call_amt := int(opt["call"])
	var all_in_call := not can_check and float(call_amt) >= float(engine.stacks[0])
	var info := "Pote ◎%d · sua mão %s" % [int(engine.trick_pot), _hand_label()]
	if not bool(opt["can_raise"]):
		info += " · " + _no_raise_reason(opt)
	_banner("SUA VEZ DE APOSTAR", info, UIKit.TURN)
	var st := {"raising": false, "to": int(opt["min_to"])}
	var done := func(result: Dictionary) -> void:
		st["result"] = result
		item_chosen.emit(1)
	var mk := func(text: String, color: Color, cb: Callable) -> Button:
		var b := UIKit.button(text, color, 20)
		b.add_theme_font_size_override("font_size", 20)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 72)
		for sn in ["normal", "hover", "pressed", "focus", "disabled"]:
			var sb := b.get_theme_stylebox(sn) as StyleBoxFlat
			if sb:
				sb.content_margin_left = 4
				sb.content_margin_right = 4
		b.pressed.connect(cb)
		return b
	st["render"] = func():
		if st.has("picker") and is_instance_valid(st["picker"]):
			(st["picker"] as Node).queue_free()
			st.erase("picker")
		for c in bet_row.get_children():
			c.queue_free()
		if not can_check:
			bet_row.add_child(mk.call("DESISTIR", UIKit.DANGER, func(): done.call({"action": "fold"})))
		var main_txt := "PASSAR" if can_check else ("PAGAR\n◎%d%s" % [call_amt, "\nALL-IN" if all_in_call else ""])
		bet_row.add_child(mk.call(main_txt, UIKit.OK, func(): done.call({"action": "check" if can_check else "call"})))
		if bool(opt["can_raise"]):
			bet_row.add_child(mk.call("APOSTAR" if can_check else "AUMENTAR", UIKit.MONEY, func():
				st["raising"] = not bool(st["raising"])
				(st["render"] as Callable).call()))
		if bool(st["raising"]):
			var holder := MarginContainer.new()
			holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_theme_constant_override("margin_bottom", int(get_viewport_rect().size.y - bottom_bar.global_position.y + 8.0))
			overlay_layer.add_child(holder)
			var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.BRAND, 14)
			box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			box.size_flags_vertical = Control.SIZE_SHRINK_END
			box.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 48.0, 640.0), 0)
			holder.add_child(box)
			var body := VBoxContainer.new()
			body.add_theme_constant_override("separation", 8)
			box.add_child(body)
			_build_raise_picker(body, opt, st, done)
			st["picker"] = holder
	bet_row.visible = true
	(st["render"] as Callable).call()
	await item_chosen
	modal_open = false
	bet_row.visible = false
	for c in bet_row.get_children():
		c.queue_free()
	if st.has("picker") and is_instance_valid(st["picker"]):
		(st["picker"] as Node).queue_free()
	_banner_clear()
	return st.get("result", {"action": "check"})


## Por que o AUMENTAR não aparece — a pergunta que o jogador faria.
func _no_raise_reason(opt: Dictionary) -> String:
	if engine.raises >= ChaosEngine.MAX_RAISES:
		return "Limite de %d aumentos atingido." % ChaosEngine.MAX_RAISES
	if float(engine.stacks[0]) <= float(opt["call"]):
		return "Pagar já é seu all-in."
	return "Rivais não cobrem mais."


## Seletor de valor do aumento: atalhos (mínimo, ½ pote, pote, all-in) e − / + de 1 blind.
func _build_raise_picker(body: VBoxContainer, opt: Dictionary, st: Dictionary, done: Callable) -> void:
	var blind := engine.blind
	var lo := int(opt["min_to"])
	var hi := int(opt["max_to"])
	var pot_now := int(opt["pot"])
	var level := int(engine.bet_level)
	st["to"] = clampi(int(st["to"]), lo, hi)
	body.add_child(UIKit.label("QUANTO AUMENTAR?", 24, UIKit.BRAND, HORIZONTAL_ALIGNMENT_CENTER))
	if float(hi) < float(engine.stacks[0] + engine.contrib[0]):
		var cap_l := UIKit.label("Máximo ◎%d: é o que o rival mais forte ainda consegue cobrir." % hi, 20, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		cap_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(cap_l)
	var shortcuts := HBoxContainer.new()
	shortcuts.add_theme_constant_override("separation", 6)
	body.add_child(shortcuts)
	var presets: Array = [
		["MÍN", lo],
		["½ POTE", level + int(round(pot_now * 0.5 / blind)) * blind],
		["POTE", level + int(round(float(pot_now) / blind)) * blind],
		["ALL-IN", hi],
	]
	for pr in presets:
		var val := clampi(int(pr[1]), lo, hi)
		var b := UIKit.button(str(pr[0]), UIKit.PURPLE if int(st["to"]) != val else UIKit.OK, 26)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 64)
		b.pressed.connect(func():
			st["to"] = val
			(st["render"] as Callable).call())
		shortcuts.add_child(b)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	body.add_child(row)
	var minus := UIKit.button("−", UIKit.MUTED, 40)
	minus.custom_minimum_size = Vector2(96, 72)
	minus.disabled = int(st["to"]) <= lo
	minus.pressed.connect(func():
		st["to"] = maxi(int(st["to"]) - blind, lo)
		(st["render"] as Callable).call())
	row.add_child(minus)
	var num := UIKit.label("◎ %d" % int(st["to"]), 52, UIKit.MONEY, HORIZONTAL_ALIGNMENT_CENTER)
	num.custom_minimum_size = Vector2(190, 0)
	row.add_child(num)
	var plus := UIKit.button("+", UIKit.MUTED, 40)
	plus.custom_minimum_size = Vector2(96, 72)
	plus.disabled = int(st["to"]) >= hi
	plus.pressed.connect(func():
		st["to"] = mini(int(st["to"]) + blind, hi)
		(st["render"] as Callable).call())
	row.add_child(plus)
	var ok := UIKit.button("AUMENTAR PARA ◎%d" % int(st["to"]) + (" (ALL-IN)" if int(st["to"]) >= hi else ""), UIKit.MONEY, 30)
	ok.pressed.connect(func(): done.call({"action": "raise", "to": float(st["to"])}))
	body.add_child(ok)
	var back := UIKit.button("VOLTAR", UIKit.MUTED, 26)
	back.custom_minimum_size = Vector2(0, 64)
	back.pressed.connect(func():
		st["raising"] = false
		(st["render"] as Callable).call())
	body.add_child(back)


# ------------------------------------------------------------------ pote

# ------------------------------------------------------------------ rodada resolvida

func _resolve_trick(result: Dictionary) -> void:
	if engine.blitz:
		await _resolve_trick_blitz(result)
		return
	var winner: int = result["winner"]
	var win_view: CardView
	for v in table_views:
		if int(v["player"]) == winner:
			win_view = v["view"]
	await _wait(0.2)
	if not is_inside_tree():
		return
	if win_view:
		FX.win_pulse(win_view, TABLE_SCALE)

	var pot_amt := float(result["pot"])
	var prize := float(result["prize"])
	var gain := float(result.get("gain", 0.0))
	if winner == 0 and gain > best_gain:
		best_gain = gain
	var wname := str(config["names"][winner]).to_upper()
	var notes: Array = []
	if int(result.get("modifier", -1)) == ChaosModifiers.Modifier.VAZA_DOURADA:
		notes.append("rodada dourada ×3")
	var sub := "Pote ◎%d" % int(pot_amt)
	if absf(prize) >= 1.0:
		sub += "  ·  bônus dos rivais %s◎%d" % ["+" if prize >= 0.0 else "−", absi(int(prize))]
	var rake := float(result.get("rake", 0.0))
	if rake >= 1.0:
		sub += "  ·  taxa da casa ◎%d" % int(rake)
	if float(result.get("mult", 1.0)) > 1.0:
		sub += "  (×%s)" % UIKit.fmt_dec(float(result["mult"]), 2)
	if not notes.is_empty():
		sub += "  (%s)" % ", ".join(notes)
	_banner("%s venceu!" % wname, sub, UIKit.ME if winner == 0 else UIKit.INK)
	Sfx.play("chip")
	var punch := clampf((pot_amt + prize) / (float(engine.blind) * 16.0), 0.0, 1.0)
	if punch > 0.25:
		FX.shake(main_area, punch)
	FX.burst(popup_layer, table_center.global_position - popup_layer.global_position + table_center.size / 2.0, UIKit.ME if winner == 0 else UIKit.CHIPS, 8 + int(punch * 20))
	await _wait(1.0)
	if not is_inside_tree():
		return
	var extras: Array = []
	var streak_n := int(result.get("streak", 0))
	if streak_n >= 2 and not ("MAO_QUENTE" in result.get("combos", [])):
		extras.append(["♨ SEQUÊNCIA ×%s!" % UIKit.fmt_dec(float(result.get("streak_mult", 1.0)), 2), "%s ganhou %d rodadas seguidas" % [wname, streak_n], FLAME])
	for id in result.get("combos", []):
		extras.append([str(ChaosModifiers.COMBO_NAMES[id]) + "!", "%s — %s" % [wname, ChaosModifiers.COMBO_DESCRIPTIONS[id]], UIKit.COMBO])
	if float(result.get("saque_amount", 0.0)) > 0.0:
		extras.append(["⚔ SAQUE!", "%s levou ◎%d dos rivais" % [wname, int(result["saque_amount"])], UIKit.LOSS])
	if float(result.get("assalto_amount", 0.0)) > 0.0:
		extras.append(["⚔ ASSALTO!", "%s roubou ◎%d de quem tinha mais fichas" % [wname, int(result["assalto_amount"])], UIKit.LOSS])
	if int(result.get("modifier", -1)) == ChaosModifiers.Modifier.VAZA_MALDITA:
		extras.append(["☠ RODADA MALDITA!", "%s paga aos rivais por vencer essa rodada" % wname, UIKit.LOSS])
	for e in extras:
		_banner(e[0], e[1], e[2])
		Sfx.play("combo")
		FX.burst(popup_layer, _seat_center(winner) - popup_layer.global_position, e[2], 18)
		FX.shake(main_area, clampf(0.25 + 0.15 * float(streak_n), 0.0, 0.8))
		_refresh_hud()
		await _wait(1.3)
		if not is_inside_tree():
			return

	# O pote (com o prêmio) voa pro vencedor.
	await _collect_pot(winner, pot_amt - rake + maxf(prize, 0.0) + float(result.get("saque_amount", 0.0)) + float(result.get("assalto_amount", 0.0)), gain)
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

## Resumo do nível. Devolve "continue" ou "leave" (sair da mesa levando a stack).
func _show_round_summary() -> String:
	if GameState.autoplay:
		await _wait(0.05)
		return "continue"
	var r := engine.round_result
	var ov := UIKit.overlay()
	overlay_layer.add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.BRAND, 24)
	box.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 40.0, 664.0), 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	box.add_child(v)
	v.add_child(UIKit.label("FIM DO NÍVEL %d" % (int(r["round"]) + 1), 30, UIKit.BRAND, HORIZONTAL_ALIGNMENT_CENTER))
	var stacks: Array = r["stacks"]
	var deltas: Array = r["deltas"]
	# Saldo do próprio jogador, bem grande e com sinal, antes de qualquer outra coisa — o número
	# que mais importa pra saber "ganhei ou perdi esse nível", sem precisar ler a lista toda.
	var my_delta := int(deltas[0])
	var saldo_color := UIKit.OK if my_delta >= 0 else UIKit.LOSS
	var saldo := UIKit.label("%s◎%d" % ["+" if my_delta >= 0 else "−", absi(my_delta)], 56, saldo_color, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(saldo)
	var saldo_cap := UIKit.label("SEU SALDO NESSE NÍVEL", 18, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(saldo_cap)
	v.add_child(HSeparator.new())
	var won: Array = r["tricks_won"]
	var order := range(engine.num_players)
	order.sort_custom(func(a: int, b: int) -> bool: return float(stacks[a]) > float(stacks[b]))
	for p in order:
		var d := int(deltas[p])
		var line := "%s%s  ◎%d  (%s◎%d)  ·  %d rodadas" % ["♛ " if p == order[0] else "", str(config["names"][p]).to_upper(), int(stacks[p]), "+" if d >= 0 else "−", absi(d), int(won[p])]
		if r.has("blitz"):
			line = "%s%s  ◎%d  (%s◎%d)" % ["♛ " if p == order[0] else "", str(config["names"][p]).to_upper(), int(stacks[p]), "+" if d >= 0 else "−", absi(d)]
		var lab := UIKit.label(line, 28, (UIKit.ME if p == 0 else UIKit.INK), HORIZONTAL_ALIGNMENT_CENTER)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(lab)
		if r.has("blitz"):
			var b: Dictionary = r["blitz"]
			var hit: bool = (b["hits"] as Array).has(p)
			var near: bool = (b["near"] as Array).has(p)
			var verdict := "ACERTOU ✓" if hit else ("ERROU POR 1" if near else "ERROU ✕")
			var sub_l := UIKit.label("palpite %d · fez %d · %s%s" % [int(b["predicts"][p]), int(b["wins"][p]), verdict, " · ×%d" % (1 + int(b["doubles"][p])) if int(b["doubles"][p]) > 0 else ""], 22, UIKit.OK if hit else (UIKit.MUTED if near else UIKit.LOSS), HORIZONTAL_ALIGNMENT_CENTER)
			v.add_child(sub_l)
	if r.has("blitz") and float(r["blitz"]["bonus"]) > 0.0:
		var bl := UIKit.label("Prêmio de sequência da casa: +◎%d (%d acertos seguidos)" % [int(r["blitz"]["bonus"]), int(r["blitz"]["streak"])], 24, UIKit.MONEY, HORIZONTAL_ALIGNMENT_CENTER)
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(bl)
	if r.has("blitz") and float(r["blitz"]["carry_out"]) > 0.0:
		var cl := UIKit.label("Ninguém acertou: ◎%d acumulam pro próximo nível" % int(r["blitz"]["carry_out"]), 24, UIKit.MONEY, HORIZONTAL_ALIGNMENT_CENTER)
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(cl)
	var result := {"choice": "continue"}
	var next := UIKit.button("PRÓXIMO NÍVEL")
	next.pressed.connect(func(): item_chosen.emit(1))
	v.add_child(next)
	var profile := SaveManager.section("profile")
	var missing := engine.buy_in - int(engine.stacks[0])
	if missing >= engine.blind * 2 and int(profile["fichas"]) >= missing:
		var top := UIKit.button("COMPLETAR STACK  +◎%d" % missing, UIKit.OK)
		top.pressed.connect(func():
			profile["fichas"] = int(profile["fichas"]) - missing
			SaveManager.save_game()
			engine.stacks[0] += float(missing)
			total_in += missing
			top.disabled = true
			top.text = "STACK COMPLETA ✓"
			_refresh_hud())
		v.add_child(top)
	var leave := UIKit.button("SAIR DA MESA  ◎%d" % int(engine.stacks[0]), UIKit.MUTED)
	leave.pressed.connect(func():
		result["choice"] = "leave"
		item_chosen.emit(1))
	v.add_child(leave)
	ov.add_child(UIKit.centered(box))
	UIKit.pop_in(box, GameState.anim(0.2))
	next.grab_focus.call_deferred()
	await item_chosen
	if is_inside_tree():
		ov.queue_free()
	return str(result["choice"])


func _finish_match() -> void:
	if finished:
		return
	finished = true
	var result := engine.make_standings()
	result["payout"] = engine.stacks[0]
	result["buy_in"] = total_in
	result["hands"] = engine.hand_no
	engine.match_result = result
	var is_tournament := bool(config.get("tournament", false))
	var summary := GameState.report_tournament_table(result) if is_tournament else GameState.report_chaos_match(result)
	var lost: bool = not bool(summary["won"]) and (not is_tournament or str(summary.get("next", "")) == "eliminated")
	Sfx.play("lose" if lost else "win")
	status_label.text = ""
	if turn_bar:
		turn_bar.modulate.a = 0.0
	if is_tournament:
		_show_tournament_results(summary)
	else:
		_show_results(summary)
	match_finished.emit(summary)


## Resultado de uma mesa de torneio: sem os números de fichas reais (a mesa usa stack
## neutro), só colocação e o que acontece a seguir — avançar, ser campeão ou ser eliminado.
func _show_tournament_results(summary: Dictionary) -> void:
	var ov := UIKit.overlay()
	overlay_layer.add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.BRAND if summary["won"] else UIKit.LOSS, 24)
	box.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 40.0, 664.0), 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	var next := str(summary.get("next", "eliminated"))
	var titles := {"advance": "VOCÊ AVANÇA!", "champion": "🏆 CAMPEÃO DO TORNEIO!", "eliminated": "ELIMINADO"}
	var title: String = titles[next]
	v.add_child(UIKit.label(title, 34, UIKit.BRAND if summary["won"] else (UIKit.LOSS if next == "eliminated" else UIKit.OK), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(HSeparator.new())
	var order: Array = engine.match_result["standings"]
	for i in range(order.size()):
		var p: int = order[i]
		var line := "%d. %s%s" % [i + 1, "♛ " if i == 0 else "", str(config["names"][p]).to_upper()]
		v.add_child(UIKit.label(line, 32, UIKit.ME if p == 0 else UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(HSeparator.new())
	for line in summary["lines"]:
		var ll := UIKit.label(str(line), 30, UIKit.LOSS if next == "eliminated" else UIKit.OK, HORIZONTAL_ALIGNMENT_CENTER)
		ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(ll)
	if next == "advance":
		var go := UIKit.button("PRÓXIMO NÍVEL", UIKit.OK)
		go.pressed.connect(func(): get_tree().reload_current_scene())
		v.add_child(go)
	var btn := UIKit.button("MENU PRINCIPAL", UIKit.MUTED)
	btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	v.add_child(btn)
	ov.add_child(UIKit.centered(box))
	UIKit.pop_in(box, GameState.anim(0.25))
	btn.grab_focus.call_deferred()


func _show_results(summary: Dictionary) -> void:
	var ov := UIKit.overlay()
	overlay_layer.add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.BRAND if summary["won"] else UIKit.LOSS, 24)
	box.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 40.0, 664.0), 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	var net := int(summary["net_fichas"])
	var title := "VOCÊ SAIU NO LUCRO!" if summary["won"] else ("VOCÊ SAIU DA MESA" if net == 0 else "VOCÊ SAIU NO PREJUÍZO")
	v.add_child(UIKit.label(title, 32, UIKit.BRAND if summary["won"] else UIKit.LOSS, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(HSeparator.new())
	var order: Array = engine.match_result["standings"]
	var stacks: Array = engine.match_result["stacks"]
	for i in range(order.size()):
		var p: int = order[i]
		var line := "%d. %s%s — ◎%d" % [i + 1, "♛ " if i == 0 else "", str(config["names"][p]).to_upper(), int(stacks[p])]
		v.add_child(UIKit.label(line, 32, UIKit.ME if p == 0 else UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(HSeparator.new())
	var st: Dictionary = engine.session_stats[0]
	var stat := "%d rodadas na mesa · %d potes ganhos · %d blefes vencidos · %d desistências" % [engine.hand_no, int(st["pots"]), int(st["bluffs"]), int(st["folds"])]
	if engine.blitz:
		stat = "%d níveis · %d palpites certos · %d por 1 de diferença" % [int(st["levels"]), int(st["hits"]), int(st["near"])]
	var stat_l := UIKit.label(stat, 26, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	stat_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(stat_l)
	if best_gain > 0.0:
		v.add_child(UIKit.label("★ Maior pote seu: +◎%d" % int(best_gain), 30, UIKit.MONEY, HORIZONTAL_ALIGNMENT_CENTER))
	if engine.blitz and engine.human_bonus >= 1.0:
		v.add_child(UIKit.label("Prêmios de sequência: +◎%d" % int(engine.human_bonus), 26, UIKit.MONEY, HORIZONTAL_ALIGNMENT_CENTER))
	if engine.human_rake >= 1.0:
		v.add_child(UIKit.label("Taxa da casa nos seus potes: ◎%d" % int(engine.human_rake), 24, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	for line in summary["lines"]:
		var ll := UIKit.label(str(line), 30, UIKit.OK if net >= 0 else UIKit.LOSS, HORIZONTAL_ALIGNMENT_CENTER)
		ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(ll)
	var again := UIKit.button("NOVA MESA")
	again.pressed.connect(func(): get_tree().reload_current_scene())
	v.add_child(again)
	var btn := UIKit.button("MENU PRINCIPAL", UIKit.MUTED)
	btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	v.add_child(btn)
	ov.add_child(UIKit.centered(box))
	UIKit.pop_in(box, GameState.anim(0.25))
	btn.grab_focus.call_deferred()


# ------------------------------------------------------------------ HUD: ordem, vez e apostas na frente

func _current_turn_player() -> int:
	if phase == "bet":
		return engine.bet_actor()
	if phase == "play" and not engine.is_round_over() and engine.active_count() > 1:
		return engine.current
	return -1


## Quem ainda vai falar (aposta) ou jogar carta (cartas), em ordem: o 1º é quem age agora.
func _order_now() -> Array:
	if phase == "bet":
		return engine.to_act.duplicate()
	if phase == "play" and engine.plays.size() < engine.active_count():
		var out: Array = []
		var remaining := engine.active_count() - engine.plays.size()
		for i in range(engine.num_players):
			var q := (engine.current + i) % engine.num_players
			if not engine.folded[q] and out.size() < remaining:
				out.append(q)
		return out
	return []


func _fmt_chips(v: float) -> String:
	return "%d" % int(v)


func _pot_text(v: float) -> String:
	if engine.blitz:
		return "POTE ◎ %d" % int(v)
	return ("POTE ◎ %d" if bets_gathered else "EM JOGO ◎ %d") % int(v)


func _refresh_hud() -> void:
	var turn_player := _current_turn_player()
	var order := _order_now()
	for p in range(engine.num_players):
		var total_lbl := hud_totals[p] as Label
		var new_total: float = float(hold_stacks[p]) if not hold_stacks.is_empty() else float(engine.stacks[p])
		while shown_totals.size() <= p:
			shown_totals.append(new_total)
		if is_equal_approx(new_total, float(shown_totals[p])):
			total_lbl.text = _fmt_chips(new_total)
		else:
			FX.count(total_lbl, float(shown_totals[p]), new_total, _fmt_chips)
			FX.pop(total_lbl, 1.3)
			shown_totals[p] = new_total
		var out: bool = phase != "idle" and engine.folded[p]
		(hud_badges[p] as Control).modulate = Color(1, 1, 1, 0.45 if out else 1.0)
		(hud_titles[p] as Label).text = "VOCÊ" if p == 0 else str(config["names"][p]).to_upper()
		(hud_titles[p] as Label).add_theme_color_override("font_color", UIKit.TURN if p == turn_player else UIKit.INK)
		(dealer_badges[p] as Control).visible = engine.hand_no > 0 and engine.button == p
		# Ordem: 1 = age agora, 2 = próximo...
		var idx := order.find(p)
		var ob := order_badges[p] as PanelContainer
		ob.visible = idx >= 0 and p != 0
		if idx >= 0:
			(ob.get_child(0) as Label).text = str(idx + 1)
			ob.add_theme_stylebox_override("panel", UIKit.box_cached(UIKit.TURN if idx == 0 else UIKit.PURPLE_DEEP, UIKit.TURN if idx == 0 else UIKit.MUTED, 3, 15, 0))
			(ob.get_child(0) as Label).add_theme_color_override("font_color", UIKit.TEXT_ON_LIGHT if idx == 0 else UIKit.INK)
		_refresh_bet_tags(p, idx)
	info_label.text = "NÍVEL %d%s · %s ◎%d" % [engine.round_index + 1, ("/%d" % engine.levels) if engine.levels > 0 else "", "ENTRADA" if engine.blitz else "BLIND", int(engine.blitz_entry()) if engine.blitz else engine.blind]
	Widgets.progress_dots(trick_dots, ChaosEngine.HAND_SIZE, engine.trick_number)
	_refresh_pot()
	_update_turn_highlight(turn_player)
	_refresh_double_button()


func _reset_actions() -> void:
	for p in range(engine.num_players):
		action_text[p] = ""
		action_color[p] = UIKit.MUTED


## Fichas na frente do jogador (até juntar no pote) e a linha de situação: É A VEZ / PRÓXIMO /
## última ação / chamas da sequência.
func _refresh_bet_tags(p: int, idx: int) -> void:
	if engine.blitz:
		_refresh_blitz_tag(p, idx)
		return
	var streak: int = engine.streak[p] if p < engine.streak.size() else 0
	var flames := ""
	if streak >= 2:
		flames = "%s×%s" % ["♨".repeat(ChaosCombos.flame_level(streak)), UIKit.fmt_dec(ChaosCombos.streak_mult(streak), 2)]
	var pile := float(engine.contrib[p]) if not bets_gathered and phase != "idle" else 0.0
	var pill := bet_pills[p] as PanelContainer
	(bet_tags[p] as Label).text = "◎ %d" % int(pile)
	(bet_tags[p] as Label).add_theme_color_override("font_color", UIKit.LOSS if engine.folded[p] else UIKit.BRAND)
	pill.modulate.a = 1.0 if pile > 0.0 else 0.0
	var status := ""
	var col := UIKit.MUTED
	if idx == 0:
		status = "▶ É A VEZ" if p != 0 else "▶ SUA VEZ"
		col = UIKit.TURN
	elif idx == 1:
		status = "PRÓXIMO"
		col = UIKit.INK
	elif phase != "idle" and engine.folded[p]:
		status = "✕ DESISTIU"
		col = UIKit.LOSS
	elif str(action_text[p]) != "":
		status = str(action_text[p])
		col = action_color[p]
	elif phase == "play" and engine.plays.any(func(pl): return int(pl["player"]) == p):
		status = "✓ JOGOU"
	if flames != "":
		status = (status + " " + flames).strip_edges()
	var st := prog_tags[p] as Label
	st.text = status
	st.add_theme_color_override("font_color", col if flames == "" or status != flames else FLAME)


func _refresh_pot() -> void:
	if engine.blitz:
		_refresh_pot_blitz()
		return
	if not pot_locked:
		shown_pot = engine.pot if phase != "idle" or bets_gathered else 0.0
		pot_label.text = _pot_text(shown_pot)
	var sub := ""
	if phase == "bet" and engine.bet_level > float(engine.blind):
		sub = "aposta em ◎ %d" % int(engine.bet_level)
	elif phase == "bet":
		sub = "blind ◎ %d de cada" % engine.blind
	pot_sub.text = sub
	pot_box.reset_size.call_deferred()
	_layout_table.call_deferred()


## Faz o pote rolar até o valor atual (pop dourado).
func _pot_to(total: float) -> void:
	var from := shown_pot
	shown_pot = total
	pot_locked = true
	FX.count(pot_label, from, total, _pot_text, 0.5)
	FX.pop(pot_box, 1.18)
	get_tree().create_timer(GameState.anim(0.55)).timeout.connect(func():
		pot_locked = false
		if is_inside_tree():
			_refresh_pot())


func _global_center(c: Control) -> Vector2:
	return c.global_position + c.size / 2.0


func _seat_center(p: int) -> Vector2:
	return _global_center(seat_avatars[p] as Control)


func _pill_center(p: int) -> Vector2:
	return _global_center(bet_pills[p] as Control)


func _chips_for(amount: float) -> int:
	return clampi(int(ceil(amount / float(engine.blind))), 1, 7)


func _update_turn_highlight(turn_player: int) -> void:
	turn_pulse_token += 1
	var my_token := turn_pulse_token
	for p in range(seat_avatars.size()):
		var avatar: PanelContainer = seat_avatars[p]
		var active := p == turn_player
		avatar.add_theme_stylebox_override("panel", UIKit.box_cached(UIKit.PURPLE_DEEP, UIKit.TURN if active else UIKit.MUTED, 8 if active else 3, 42, 0))
		if not active:
			avatar.scale = Vector2.ONE
	if turn_player >= 0:
		FX.pulse_while(seat_avatars[turn_player], 1.1, func(): return my_token == turn_pulse_token)


# ------------------------------------------------------------------ apostas

func _betting_phase() -> void:
	human_turn = false
	phase = "bet"
	bets_gathered = false
	pot_locked = false
	shown_pot = 0.0
	var first := engine.bet_actor()
	_banner("APOSTAS", "Ante ◎%d · Dealer (D): %s · Fala primeiro: %s" % [int(engine.bet_level), str(config["names"][engine.button]).to_upper(), str(config["names"][first]).to_upper()], UIKit.MONEY)
	status_label.text = ""
	_refresh_hud()
	if not GameState.autoplay:
		Sfx.play("chip")
		for p in range(engine.num_players):
			FX.fly_chips(popup_layer, _seat_center(p), _pill_center(p), 1)
			FX.pop(bet_pills[p], 1.2)
	await _wait(0.7)
	var guard := 0
	while engine.betting and guard < 40:
		guard += 1
		if not is_inside_tree() or finished:
			return
		var p := engine.bet_actor()
		_refresh_hud()
		var act: Dictionary
		if p == 0 and not GameState.autoplay:
			var fold_tip := "Quem desiste descarta 1 carta aleatória da mão." if engine.blitz else "Quem desiste descarta a carta mais fraca, virada."
			await _tip("bet", "SUA VEZ DE APOSTAR", "Todo mundo já pagou a ante. Você pode PASSAR, AUMENTAR, PAGAR ou DESISTIR. Só quem fica na rodada joga carta, e quem vence leva o pote. %s" % fold_tip)
			act = await _human_bet()
			if not is_inside_tree() or finished:
				return
		else:
			await _wait(bot_rng.randf_range(0.6, 1.1))
			act = ChaosBot.bet_decision(engine, p, int(config["difficulty"][p]), bot_rng)
		var r := engine.bet_act(p, str(act["action"]), float(act.get("to", 0.0)))
		if not r.get("ok", false):
			push_warning("Aposta rejeitada: %s" % r.get("error"))
			r = engine.bet_act(p, "check")
			if not r.get("ok", false):
				r = engine.bet_act(p, "fold")
		await _show_bet_action(p, r)
	if not is_inside_tree() or finished:
		return
	await _gather_bets()
	_banner_clear()
	status_label.text = ""
	_refresh_hud()


## Mostra o que cada um fez; as fichas ficam na frente do jogador até fechar a rodada de apostas.
func _show_bet_action(p: int, r: Dictionary) -> void:
	var pname := str(config["names"][p]).to_upper()
	var amount := float(r.get("amount", 0.0))
	var title := ""
	var sub := ""
	var col := UIKit.MUTED
	match str(r.get("action", "")):
		"check":
			action_text[p] = "– PASSOU"
			title = "%s PASSOU" % pname
			sub = "Fica na rodada sem aumentar."
		"call":
			action_text[p] = "✓ PAGOU"
			title = "%s PAGOU" % pname
			sub = "Pagou ◎%d (aposta em ◎%d)." % [int(amount), int(engine.bet_level)]
			col = UIKit.INFO
		"raise":
			action_text[p] = "▲ AUMENTOU"
			title = "%s AUMENTOU!" % pname
			sub = "Aposta em ◎%d. Quem não pagar, desiste." % int(r["to"])
			col = UIKit.MONEY
		"fold":
			action_text[p] = "✕ DESISTIU"
			title = "%s DESISTIU" % pname
			sub = "Perde o que pôs e descarta 1 carta."
			if p == 0 and not engine.last_discard.is_empty():
				var dcard := (engine.last_discard["card"] as CardData).display_name()
				sub = "Você descartou %s." % dcard
			col = UIKit.LOSS
	action_color[p] = col
	_banner(title, sub, col if col != UIKit.MUTED else UIKit.INK)
	_refresh_hud()
	if amount > 0.0:
		FX.fly_chips(popup_layer, _seat_center(p), _pill_center(p), _chips_for(amount))
		Sfx.play("combo" if str(r["action"]) == "raise" else "chip")
		FX.pop(bet_pills[p], 1.3)
		_pot_to(engine.trick_pot)
		if str(r["action"]) == "raise":
			FX.shake(main_area, 0.35)
			FX.burst(popup_layer, _seat_center(p) - popup_layer.global_position, UIKit.BRAND, 14)
	elif str(r.get("action", "")) == "fold":
		Sfx.play("lose")
		if p == 0 and not engine.last_discard.is_empty():
			await _show_fold_discard(engine.last_discard["card"] as CardData)
	await _wait(0.75 if p != 0 else 0.45)


## Destaca a carta descartada pela desistência antes de sumir — foca (sobe, borda acesa), segura
## um instante pra dar tempo de ver qual foi, e só então destrói (voa pra fora e desfaz). Sem isso
## a carta só desaparecia na troca de mão seguinte, rápido demais pra notar.
func _show_fold_discard(card: CardData) -> void:
	var view: CardView = null
	for c in hand_container.get_children():
		if (c as CardView).data == card:
			view = c
			break
	if view == null:
		_rebuild_hand()
		return
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.z_index = 5
	for c in hand_container.get_children():
		if c != view:
			(c as CardView).set_selected(false)
	view.set_selected(true)
	(hand_container.get_parent() as HandScroller).reveal(view.position.x, CardView.SIZE.x)
	await get_tree().create_timer(GameState.anim(0.55), true, false, true).timeout
	if not is_inside_tree() or not is_instance_valid(view):
		_rebuild_hand()
		return
	var from := view.global_position
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(view, "global_position", from + Vector2(0.0, -260.0), GameState.anim(0.32))
	tw.parallel().tween_property(view, "rotation", randf_range(-0.35, 0.35), GameState.anim(0.32))
	tw.parallel().tween_property(view, "scale", Vector2(0.65, 0.65), GameState.anim(0.32))
	tw.parallel().tween_property(view, "modulate:a", 0.0, GameState.anim(0.32))
	await tw.finished
	if is_inside_tree():
		_rebuild_hand()


## Fim das apostas: as fichas da frente de cada jogador voam juntas pro pote.
func _gather_bets() -> void:
	var any := false
	if not GameState.autoplay:
		for p in range(engine.num_players):
			if engine.contrib[p] > 0.0:
				any = true
				FX.fly_chips(popup_layer, _pill_center(p), _global_center(pot_box), _chips_for(float(engine.contrib[p])), UIKit.LOSS if engine.folded[p] else UIKit.MONEY)
		if any:
			_banner("APOSTAS FECHADAS", "Todas as fichas vão pro pote.", UIKit.MONEY)
			Sfx.play("combo")
	await _wait(0.6)
	bets_gathered = true
	phase = "play"
	shown_pot = 0.0
	_pot_to(engine.trick_pot)
	_refresh_hud()
	await _wait(0.5)


# ------------------------------------------------------------------ pote

## Fichas do pote voam pro vencedor; o pote zera.
func _collect_pot(winner: int, total: float, gain: float) -> void:
	var seat_at := _seat_center(winner)
	FX.fly_chips(popup_layer, _global_center(pot_box), seat_at, _chips_for(total), UIKit.OK if winner == 0 else UIKit.MONEY)
	Sfx.play("win" if winner == 0 else "chip")
	await _wait(0.55)
	if not is_inside_tree():
		return
	FX.float_text(popup_layer, seat_at, "%s◎ %d" % ["+" if gain >= 0.0 else "−", absi(int(gain))], UIKit.OK if gain >= 0.0 else UIKit.LOSS)
	FX.burst(popup_layer, seat_at - popup_layer.global_position, UIKit.OK if winner == 0 else UIKit.BRAND, 16)
	if winner == 0:
		FX.shake(main_area, clampf(total / (float(engine.blind) * 20.0), 0.3, 0.9))
		if total >= float(engine.blind) * 12.0:
			Sfx.play("jackpot")
			FX.chip_rain(popup_layer, 22)
	_pot_to(0.0)
	phase = "idle"
	_refresh_hud()
	await _wait(0.5)


## Todo mundo desistiu: o último leva o pote sem jogar carta (o blefe funcionou).
func _resolve_walkover(result: Dictionary) -> void:
	var winner: int = result["winner"]
	var wname := str(config["names"][winner]).to_upper()
	_banner("%s LEVOU SEM JOGAR!" % wname, "Todo mundo desistiu. O pote é dele.", UIKit.ME if winner == 0 else UIKit.INK)
	if winner == 0:
		_rebuild_hand()
	if winner == 0 and float(result.get("gain", 0.0)) > best_gain:
		best_gain = float(result["gain"])
	var collected := float(result["trick_pot"]) if engine.blitz else float(result["pot"])
	await _collect_pot(winner, collected, float(result.get("gain", 0.0)))
	_banner_clear()
	_refresh_hud()


# ------------------------------------------------------------------ Blitz

## Descarte inicial: etapa própria, sem mesa, sem modificador, sem indicador de vez — só os
## avatares com nome e stack, pra não confundir com informação de uma rodada que nem começou.
func _set_discard_chrome(active: bool) -> void:
	table_center.visible = not active
	for p in range(engine.num_players):
		(bet_pills[p] as PanelContainer).visible = not active
		(order_badges[p] as PanelContainer).visible = not active
		(dealer_badges[p] as PanelContainer).visible = not active


## Começo do nível no Blitz: garante saldo, troca bots quebrados, coleta os palpites (o seu e os
## dos bots), revela todos juntos e joga as entradas no pote. Devolve false se a mesa acabou.
func _blitz_open_level() -> bool:
	_reset_actions()
	hold_stacks = []
	hold_pot = -1.0
	for p in range(engine.num_players):
		blitz_revealed[p] = false
	blitz_showdown = false
	if not await _ensure_solvent():
		return false
	if not bool(config.get("tournament", false)):
		# Torneio: ninguém senta no lugar de quem quebrou — a mesa só encolhe (MTT de verdade).
		for q in engine.refill_bots():
			await _new_player_sits(q)
	_set_discard_chrome(true)
	for p in range(engine.num_players):
		if not engine.can_discard(p):
			continue
		if p == 0 and not GameState.autoplay:
			await _tip("discard", "ESCOLHA 2 PRA DESCARTAR", "Você recebeu 10 cartas. Toque numa carta pra focar — ela sobe. Toque de novo nela (ou arraste pra cima e solte) pra descartar. Repita até descartar 2.")
			await _human_discard_play()
			if not is_inside_tree() or finished:
				return false
		else:
			engine.apply_discard(p, ChaosBot.wants_discard(engine, p, int(config["difficulty"][p]), bot_rng))
	_set_discard_chrome(false)
	phase = "predict"
	bets_gathered = true
	pot_locked = true
	shown_pot = engine.carry
	pot_label.text = _pot_text(shown_pot)
	pot_box.visible = false   # só aparece depois do palpite, quando as entradas de verdade entram
	var carry_txt := "  Pote acumulado: ◎%d." % int(engine.carry) if engine.carry > 0.0 else ""
	_banner("PALPITES", "Quantas rodadas cada um vai ganhar?%s" % carry_txt, UIKit.MONEY)
	_refresh_hud()
	var pick: int
	if GameState.autoplay:
		pick = ChaosBot.blitz_pick(engine, 0, int(config["difficulty"][0]), bot_rng)
	else:
		await _tip("predict", "SEU PALPITE", "Todo nível você diz quantas rodadas vai ganhar (de 0 a 8) e paga a entrada. Quem acertar o número exato leva o pote. Errou por 1? Recebe metade da entrada de volta. A estrela ★ marca o palpite que combina com a sua mão.")
		pick = await _human_predict()
		if not is_inside_tree() or finished:
			return false
	engine.blitz_place(0, pick)
	for p in range(1, engine.num_players):
		engine.blitz_place(p, ChaosBot.blitz_pick(engine, p, int(config["difficulty"][p]), bot_rng))
	await _blitz_reveal()
	if not is_inside_tree() or finished:
		return false
	phase = "play"
	pot_locked = false
	_banner_clear()
	_refresh_hud()
	return true


## Revela os palpites um a um: a entrada voa pro pote e o palpite aparece na frente do jogador.
func _blitz_reveal() -> void:
	pot_box.visible = true
	var running := engine.carry
	for p in range(engine.num_players):
		blitz_revealed[p] = true
		var stake := float(engine.stakes[p])
		running += stake
		if not GameState.autoplay:
			Sfx.play("chip")
			FX.fly_chips(popup_layer, _seat_center(p), _global_center(pot_box), _chips_for(stake))
			FX.count(pot_label, shown_pot, running, _pot_text, 0.3)
			FX.pop(pot_box, 1.1)
			FX.pop(bet_pills[p], 1.3)
		shown_pot = running
		_refresh_hud()
		await _wait(0.45)
		if not is_inside_tree():
			return
	pot_label.text = _pot_text(engine.pot)
	shown_pot = engine.pot
	if not GameState.autoplay:
		Sfx.play("combo")
		_banner("ENTRADAS PAGAS", "Palpites em segredo até o fim. Bora jogar!", UIKit.MONEY)
	await _wait(0.8)


## Descarte inicial: sem popup — seleciona direto da própria mão, igual escolher carta pra jogar.
## Toca numa carta pra focar (ela sobe); toca de novo nela (ou arrasta pra cima e solta, igual
## jogar) pra descartar na hora, com animação — sem botão de confirmar, sem etapa extra.
func _human_discard_play() -> void:
	phase = "discard"
	discard_picks = []
	_rebuild_hand()
	_banner("ESCOLHA 2 CARTAS PRA DESCARTAR", "Toque na carta pra focar, toque de novo pra descartar.", UIKit.BRAND)
	status_label.text = "0/%d descartadas" % ChaosEngine.BLITZ_DISCARD_SIZE
	discard_left = DISCARD_SECONDS
	turn_bar.max_value = DISCARD_SECONDS
	turn_bar.modulate.a = 1.0
	discarding_now = true
	await item_chosen
	discarding_now = false
	turn_bar.modulate.a = 0.0
	turn_bar.max_value = TURN_SECONDS
	status_label.text = ""
	discard_picks = []
	_banner_clear()
	_rebuild_hand()


func _on_discard_tapped(view: CardView) -> void:
	if discard_picks.has(view.data):
		return
	if view.selected:
		_commit_discard(view)
		return
	for c in hand_container.get_children():
		(c as CardView).set_selected(c == view)
	(hand_container.get_parent() as HandScroller).reveal(view.position.x, CardView.SIZE.x)
	Sfx.play("tick")


## Descarta `view` na hora: a carta voa pra fora da mão (igual uma carta jogada) e some; a mão
## reflui pro tamanho cheio assim que ela sai. Com as 2 descartadas, segue sozinho pro palpite.
func _commit_discard(view: CardView, drop_global := Vector2.ZERO) -> void:
	if discard_picks.has(view.data) or discard_picks.size() >= ChaosEngine.BLITZ_DISCARD_SIZE:
		return
	discard_picks.append(view.data)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Sfx.play("card", randf_range(0.9, 1.15))
	var from: Vector2 = drop_global if drop_global != Vector2.ZERO else view.global_position
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(view, "global_position", from + Vector2(0.0, -320.0), GameState.anim(0.3))
	tw.parallel().tween_property(view, "rotation", randf_range(-0.35, 0.35), GameState.anim(0.3))
	tw.parallel().tween_property(view, "modulate:a", 0.0, GameState.anim(0.3))
	status_label.text = "%d/%d descartadas" % [discard_picks.size(), ChaosEngine.BLITZ_DISCARD_SIZE]
	await tw.finished
	if not is_inside_tree():
		return
	if is_instance_valid(view):
		hand_container.remove_child(view)
		view.queue_free()
	_layout_hand()
	if discard_picks.size() == ChaosEngine.BLITZ_DISCARD_SIZE:
		discarding_now = false
		engine.apply_discard(0, discard_picks)
		item_chosen.emit(1)


## Card do palpite: claro, sem fundo escurecido — vira o próprio conteúdo do card da mesa
## (table_center), que está vazio nessa etapa (nem pote nem cartas ainda). A mão continua à
## vista e interagível embaixo (segurar ou botão direito numa carta ainda dá zoom). Seletor de
## quantidade em −/+ com o palpite sugerido em destaque, em vez de uma fileira de botões de 0 a 8.
func _human_predict() -> int:
	modal_open = true
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	stage.add_child(holder)
	var box := UIKit.panel(UIKit.PAPER, UIKit.BRAND, 20)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 32.0, 600.0), 0)
	holder.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	box.add_child(v)
	v.add_child(UIKit.label("QUANTAS RODADAS VOCÊ VAI GANHAR?", 26, UIKit.TEXT_ON_LIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	var hint := ChaosBot.suggested_predict(engine, 0)
	var info := "Entrada ◎%d  ·  Pote ◎%d  ·  Sua mão: %s" % [int(engine.blitz_entry()), int(engine.carry), _hand_label_blitz()]
	var info_l := UIKit.label(info, 19, UIKit.TEXT_ON_LIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	info_l.modulate.a = 0.7
	info_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info_l)
	v.add_child(HSeparator.new())
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	v.add_child(body)
	var st := {"pick": hint}
	st["render"] = func():
		for c in body.get_children():
			body.remove_child(c)
			c.queue_free()
		var stepper := HBoxContainer.new()
		stepper.alignment = BoxContainer.ALIGNMENT_CENTER
		stepper.add_theme_constant_override("separation", 20)
		body.add_child(stepper)
		var minus := UIKit.button("−", UIKit.BUTTON_MUTED, 36)
		minus.custom_minimum_size = Vector2(76, 76)
		minus.disabled = int(st["pick"]) <= 0
		minus.pressed.connect(func():
			st["pick"] = maxi(0, int(st["pick"]) - 1)
			(st["render"] as Callable).call())
		stepper.add_child(minus)
		var count_l := UIKit.label(str(int(st["pick"])), 60, UIKit.TEXT_ON_LIGHT, HORIZONTAL_ALIGNMENT_CENTER)
		count_l.custom_minimum_size = Vector2(110, 0)
		stepper.add_child(count_l)
		var plus := UIKit.button("+", UIKit.BUTTON_MUTED, 36)
		plus.custom_minimum_size = Vector2(76, 76)
		plus.disabled = int(st["pick"]) >= ChaosEngine.HAND_SIZE
		plus.pressed.connect(func():
			st["pick"] = mini(ChaosEngine.HAND_SIZE, int(st["pick"]) + 1)
			(st["render"] as Callable).call())
		stepper.add_child(plus)
		var is_hint: bool = int(st["pick"]) == hint
		var rec_l := UIKit.label("★ RECOMENDADO PELA SUA MÃO" if is_hint else "Recomendado pela sua mão: %d" % hint, 18, UIKit.GOOD_ON_LIGHT if is_hint else UIKit.TEXT_ON_LIGHT, HORIZONTAL_ALIGNMENT_CENTER)
		rec_l.modulate.a = 1.0 if is_hint else 0.6
		body.add_child(rec_l)
		var w := ChaosEngine.blitz_weight(int(st["pick"]))
		var legend := UIKit.label("Peso do palpite no pote: ×%s   (0–2 ×1 · 3–4 ×1,5 · 5+ ×2)" % UIKit.fmt_dec(w, 1), 18, UIKit.TEXT_ON_LIGHT, HORIZONTAL_ALIGNMENT_CENTER)
		legend.modulate.a = 0.65
		legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(legend)
		var go := UIKit.button("CONFIRMAR: %d %s" % [int(st["pick"]), "RODADA" if int(st["pick"]) == 1 else "RODADAS"], UIKit.OK, 28)
		go.pressed.connect(func(): item_chosen.emit(1))
		body.add_child(go)
	(st["render"] as Callable).call()
	UIKit.pop_in(box, GameState.anim(0.15))
	Sfx.play("chip")
	await item_chosen
	modal_open = false
	if is_inside_tree():
		holder.queue_free()
	return int(st["pick"])


func _hand_label_blitz() -> String:
	var ex := ChaosBot.expected_wins(engine, 0)
	if ex >= 3.5:
		return "MUITO FORTE ★★★"
	if ex >= 2.5:
		return "FORTE ★★☆"
	if ex >= 1.5:
		return "MÉDIA ★☆☆"
	return "FRACA ☆☆☆"


## Dobrar/triplicar (seu próprio lance, `is_cover = false`) ou cobrir o lance de um rival (reage
## na hora, sem esperar a rodada). Depois de um lance próprio (não de uma cobertura), oferece a
## janela de cobertura aos outros 3.
func _apply_double(p: int, is_cover := false) -> void:
	if not (engine.cover_double(p) if is_cover else engine.double_down(p)):
		return
	var amt := engine.blitz_entry()
	var verb := "COBRIU" if is_cover else ("TRIPLICOU" if int(engine.doubles[p]) == 2 else "DOBROU")
	action_text[p] = "▲ ×%d" % (1 + int(engine.doubles[p]))
	action_color[p] = UIKit.MONEY
	if not GameState.autoplay:
		var pname := "VOCÊ" if p == 0 else str(config["names"][p]).to_upper()
		_banner("%s %s!" % [pname, verb], "Pôs mais ◎%d no pote (aposta ×%d)." % [int(amt), 1 + int(engine.doubles[p])], UIKit.MONEY)
		Sfx.play("combo")
		FX.fly_chips(popup_layer, _seat_center(p), _global_center(pot_box), 3)
		FX.burst(popup_layer, _seat_center(p) - popup_layer.global_position, UIKit.MONEY, 14)
		FX.shake(main_area, 0.3)
		_pot_to(engine.pot)
	_refresh_hud()
	if not is_cover:
		await _offer_cover(p)
	if not GameState.autoplay:
		await _wait(0.9 if p != 0 else 0.5)


## Depois que `actor` dobra ou triplica, os outros 3 podem cobrir: pagar mais uma entrada pra
## igualar o peso dele no pote (custa um dos 2 lances do nível de quem cobre). Bots decidem na
## hora; você tem uma janela curta pra tocar COBRIR, senão a resposta vira DEIXAR.
func _offer_cover(actor: int) -> void:
	for q in range(engine.num_players):
		if q == actor or not is_inside_tree() or finished:
			continue
		if not engine.can_cover(q):
			continue
		if q == 0 and not GameState.autoplay:
			if await _human_cover_choice(actor):
				await _apply_double(0, true)
		elif ChaosBot.wants_cover(engine, q, int(config["difficulty"][q]), bot_rng):
			if not GameState.autoplay:
				await _wait(bot_rng.randf_range(0.3, 0.7) * ChaosBot.style_delay_mult(engine, q))
				if not is_inside_tree() or finished:
					return
			await _apply_double(q, true)


## Painel de cobertura (fica abaixo dos avatares, como o palpite e a aposta). Devolve true se
## você tocou COBRIR; passados ~5s sem resposta, devolve false (DEIXAR).
func _human_cover_choice(actor: int) -> bool:
	modal_open = true
	_refresh_double_button()   # some o DOBRAR enquanto essa decisão está pendente
	var pname := str(config["names"][actor]).to_upper()
	var vw := get_viewport_rect().size.x
	var holder := MarginContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_theme_constant_override("margin_top", int(stage.global_position.y + stage.size.y * 0.3))
	overlay_layer.add_child(holder)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.MONEY, 20)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.custom_minimum_size = Vector2(minf(vw - 32.0, 660.0), 0)
	holder.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	box.add_child(v)
	v.add_child(UIKit.label("%s %s!" % [pname, "TRIPLICOU" if int(engine.doubles[actor]) == 2 else "DOBROU"], 28, UIKit.MONEY, HORIZONTAL_ALIGNMENT_CENTER))
	var info := UIKit.label("Cobrir custa ◎%d e iguala o peso dele no pote. Se você não cobrir, ele fica com mais peso no rateio." % int(engine.blitz_entry()), 20, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var st := {"result": false}
	var pass_btn := UIKit.button("DEIXAR", UIKit.BUTTON_MUTED, 28)
	pass_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pass_btn.pressed.connect(func():
		st["result"] = false
		item_chosen.emit(1))
	row.add_child(pass_btn)
	var cover_btn := UIKit.button("COBRIR ◎%d" % int(engine.blitz_entry()), UIKit.MONEY, 28)
	cover_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cover_btn.pressed.connect(func():
		st["result"] = true
		item_chosen.emit(1))
	row.add_child(cover_btn)
	UIKit.pop_in(box, GameState.anim(0.15))
	var timed_out := {"v": false}
	get_tree().create_timer(GameState.anim(5.0)).timeout.connect(func():
		if is_inside_tree() and modal_open and not timed_out["v"]:
			timed_out["v"] = true
			item_chosen.emit(-1))
	await item_chosen
	timed_out["v"] = true
	modal_open = false
	if is_inside_tree():
		holder.queue_free()
		_refresh_double_button()
	return bool(st["result"])


func _on_double_pressed() -> void:
	if engine.blitz and phase == "play" and not finished:
		_apply_double(0)


func _refresh_double_button() -> void:
	if double_btn == null:
		return
	var show := engine.blitz and phase == "play" and not finished and not modal_open and engine.can_double(0)
	double_btn.visible = show
	if show:
		double_btn.text = "%s ◎%d" % ["TRIPLICAR" if int(engine.doubles[0]) == 1 else "DOBRAR", int(engine.blitz_entry())]


## Palpite na frente do jogador, com o progresso ao vivo: verde no alvo, vermelho estourou ou
## sem tempo de chegar lá, neutro enquanto ainda dá.
func _refresh_blitz_tag(p: int, idx: int) -> void:
	var pill := bet_pills[p] as PanelContainer
	var lbl := bet_tags[p] as Label
	var shown := bool(blitz_revealed[p])
	pill.modulate.a = 1.0 if shown else 0.0
	if not shown:
		return
	var open_book := p == 0 or blitz_showdown
	var tag := " ×%d" % (1 + int(engine.doubles[p])) if int(engine.doubles[p]) > 0 else ""
	if open_book:
		# Você (e todo mundo no fim do nível): vitórias / palpite. Só o seu muda de cor conforme o alvo.
		lbl.text = "%d/%d%s" % [int(engine.wins[p]), int(engine.predicts[p]), tag]
		var col := UIKit.INK
		if p == 0:
			var need := engine.blitz_need(p)
			if need == 0:
				col = UIKit.OK
			elif need < 0 or need > engine.tricks_left():
				col = UIKit.LOSS
		lbl.add_theme_color_override("font_color", col)
	else:
		# Rival: só as vitórias já feitas (de 8) — o alvo dele é segredo até o fim do nível.
		lbl.text = "%d/%d%s" % [int(engine.wins[p]), ChaosEngine.HAND_SIZE, tag]
		lbl.add_theme_color_override("font_color", UIKit.INK)


func _refresh_pot_blitz() -> void:
	if not pot_locked:
		if hold_pot >= 0.0:
			shown_pot = hold_pot
		else:
			shown_pot = engine.pot if engine.pot > 0.0 else engine.carry
		pot_label.text = _pot_text(shown_pot)
	var sub := ""
	if phase == "predict":
		sub = "quem acertar leva"
	elif phase == "play" and engine.carry > 0.0:
		sub = "inclui ◎ %d acumulado" % int(engine.carry)
	elif phase == "play":
		sub = "quem acertar leva"
	elif engine.carry > 0.0:
		sub = "acumulado pro próximo nível"
	pot_sub.text = sub
	pot_box.reset_size.call_deferred()
	_layout_table.call_deferred()


## Fim de uma rodada no Blitz: a carta vencedora pulsa, o palpite de quem venceu sobe um e a
## faixa avisa se chegou no alvo ou estourou.
func _resolve_trick_blitz(result: Dictionary) -> void:
	var winner: int = result["winner"]
	var win_view: CardView
	for v in table_views:
		if int(v["player"]) == winner:
			win_view = v["view"]
	if engine.is_round_over() and not engine.blitz_result.is_empty():
		# O nível acabou e o motor já liquidou o pote: a tela segura os números antigos até a animação.
		var br := engine.blitz_result
		hold_stacks = []
		for p in range(engine.num_players):
			hold_stacks.append(float(engine.stacks[p]) - float(br["payouts"][p]) - float(br["refunds"][p]) - (float(br["bonus"]) if p == 0 else 0.0))
		hold_pot = float(br["pool"]) + _sum(br["refunds"])
	await _wait(0.2)
	if not is_inside_tree():
		return
	if win_view:
		FX.win_pulse(win_view, TABLE_SCALE)
	var wname := str(config["names"][winner]).to_upper()
	var sub := "Palpite: %d de %d" % [int(engine.wins[winner]), int(engine.predicts[winner])]
	if int(result.get("value", 1)) == 2:
		sub += "  ·  Rodada Dobrada: conta 2 vitórias"
	var prize_amt := float(result.get("prize", 0.0))
	if prize_amt > 0.0:
		sub += "  ·  cartas +◎%d" % int(prize_amt)
	var saque_amt := float(result.get("saque_amount", 0.0))
	var assalto_amt := float(result.get("assalto_amount", 0.0))
	var curse_amt := float(result.get("curse_amount", 0.0))
	var trick_gain := float(result.get("trick_gain", 0.0))
	if saque_amt > 0.0:
		sub += "  ·  ⚔ saque +◎%d" % int(saque_amt)
	if assalto_amt > 0.0:
		sub += "  ·  ♛ assalto +◎%d" % int(assalto_amt)
	if curse_amt > 0.0:
		sub += "  ·  ☠ pagou ◎%d aos rivais" % int(curse_amt)
	if trick_gain > 0.0:
		sub += "  ·  aposta da rodada +◎%d" % int(trick_gain)
	_banner("%s venceu a rodada!" % wname, sub, UIKit.ME if winner == 0 else UIKit.INK)
	Sfx.play("chip")
	FX.burst(popup_layer, _seat_center(winner) - popup_layer.global_position, UIKit.ME if winner == 0 else UIKit.CHIPS, 10)
	if float(result.get("trick_pot", 0.0)) > 0.0:
		FX.fly_chips(popup_layer, _global_center(pot_box), _seat_center(winner), _chips_for(float(result["trick_pot"])), UIKit.OK if winner == 0 else UIKit.MONEY)
	if prize_amt + saque_amt + assalto_amt + trick_gain > 0.0:
		FX.float_text(popup_layer, _seat_center(winner), "+◎ %d" % int(prize_amt + saque_amt + assalto_amt + maxf(trick_gain, 0.0)), UIKit.MONEY)
	elif curse_amt > 0.0:
		FX.float_text(popup_layer, _seat_center(winner), "−◎ %d" % int(curse_amt), UIKit.LOSS)
	_refresh_hud()
	FX.pop(bet_pills[winner], 1.35)
	var need := engine.blitz_need(winner)
	if need == 0:
		Sfx.play("combo")
		FX.float_text(popup_layer, _seat_center(winner), "NO ALVO!", UIKit.OK, 34)
	elif need < 0:
		Sfx.play("lose")
		FX.float_text(popup_layer, _seat_center(winner), "ESTOUROU", UIKit.LOSS, 34)
	# Segura o vencedor e o movimento de fichas na tela: a próxima vaza já abre uma tela cheia
	# de modificador, e sem esse respiro o resultado desta some antes de dar pra ler.
	var moved := prize_amt + saque_amt + assalto_amt + curse_amt > 0.0
	await _wait(2.0 if moved else 1.6)
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
	await _wait(0.5)


func _sum(a: Array) -> float:
	var t := 0.0
	for x in a:
		t += float(x)
	return t


## Resultado do nível: quem acertou leva o pote (fichas voam até a stack), quem errou vê as
## fichas irem embora, e sem acertos o pote fica acumulado.
func _blitz_settlement() -> void:
	blitz_showdown = true
	var br := engine.blitz_result
	var hits: Array = br["hits"]
	hold_stacks = []
	hold_pot = -1.0
	if GameState.autoplay:
		phase = "idle"
		_refresh_hud()
		return
	var title := ""
	var sub := ""
	var col := UIKit.MONEY
	if hits.is_empty():
		title = "NINGUÉM ACERTOU!"
		sub = "O pote de ◎%d fica acumulado pro próximo nível." % int(br["carry_out"])
		col = UIKit.COMBO
	else:
		var names: Array = hits.map(func(q): return "VOCÊ" if int(q) == 0 else str(config["names"][q]).to_upper())
		title = "%s ACERTOU!" % names[0] if names.size() == 1 else "ACERTARAM: %s" % " E ".join(names)
		sub = "Pote de ◎%d dividido pelo peso: entrada × dificuldade do palpite." % int(br["pool"])
		if float(br["rake"]) >= 1.0:
			sub += "  Taxa da casa ◎%d." % int(br["rake"])
		col = UIKit.OK if hits.has(0) else UIKit.INK
	_banner(title, sub, col)
	Sfx.play("win" if hits.has(0) else ("lose" if hits.is_empty() else "chip"))
	var pot_at := _global_center(pot_box)
	for p in range(engine.num_players):
		var payout := float(br["payouts"][p])
		var net := float(br["net"][p])
		if payout > 0.0:
			FX.fly_chips(popup_layer, pot_at, _seat_center(p), _chips_for(payout), UIKit.OK if p == 0 else UIKit.MONEY)
			FX.burst(popup_layer, _seat_center(p) - popup_layer.global_position, UIKit.OK if p == 0 else UIKit.BRAND, 16)
			FX.float_text(popup_layer, _seat_center(p), "+◎ %d" % int(net), UIKit.OK)
			if p == 0:
				FX.shake(main_area, clampf(payout / (float(engine.blind) * 20.0), 0.3, 0.9))
				if float(br["carry_in"]) > 0.0:
					Sfx.play("jackpot")
					FX.chip_rain(popup_layer, 22)
			await _wait(0.5)
		elif net < 0.0:
			FX.float_text(popup_layer, _seat_center(p), "−◎ %d" % absi(int(net)), UIKit.LOSS)
	if float(br["net"][0]) > best_gain:
		best_gain = float(br["net"][0])
	if float(br["bonus"]) > 0.0:
		await _wait(0.4)
		_banner("SEQUÊNCIA DE %d ACERTOS! +◎%d" % [int(br["streak"]), int(br["bonus"])], "Prêmio da casa por acertos seguidos.", UIKit.MONEY)
		Sfx.play("jackpot")
		FX.chip_rain(popup_layer, 26)
		FX.float_text(popup_layer, _seat_center(0), "+◎ %d" % int(br["bonus"]), UIKit.MONEY, 44)
		FX.burst(popup_layer, _seat_center(0) - popup_layer.global_position, UIKit.MONEY, 22)
		await _wait(0.9)
	_pot_to(engine.carry)
	phase = "idle"
	_refresh_hud()
	await _wait(2.2)
