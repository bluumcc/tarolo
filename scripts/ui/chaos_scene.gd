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
var my_bet_label: Label
var shown_pot := 0.0
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
	total_in = int(config["buy_in"])
	for p in range(engine.num_players):
		action_text.append("")
		action_color.append(UIKit.MUTED)
		shown_totals.append(engine.stacks[p])
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
	var l := UIKit.label("Você precisa de %d fichas pra sentar na Mesa Caos. Jogue Vanilla ou Ranqueado, ou volte ao menu e peça um empréstimo da casa." % int(config["buy_in"]), 32, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
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
	var my_total := UIKit.label("◎ 0", 40, UIKit.GOLD)
	my_left.add_child(my_total)
	var my_rp := UIKit.label("+◎0 no nível", 20, UIKit.MUTED)
	my_left.add_child(my_rp)
	var my_right := VBoxContainer.new()
	my_right.add_theme_constant_override("separation", 1)
	my_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	my_right.alignment = BoxContainer.ALIGNMENT_CENTER
	my_row.add_child(my_right)
	my_bet_label = UIKit.label("", 18, UIKit.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	my_bet_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	my_right.add_child(my_bet_label)
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
		var pts_l := UIKit.label("◎ 0", 24, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
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


## Pote da rodada no centro da mesa.
func _build_pot() -> void:
	pot_box = UIKit.panel(Color("#2A1B4D"), UIKit.GOLD, 8)
	pot_box.custom_minimum_size = Vector2(POT_W, 0)
	pot_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func _plural(n: int, one: String, many: String) -> String:
	return "%d %s" % [n, one if n == 1 else many]


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
	var kicker := "NÍVEL %d%s" % [engine.round_index + 1, (" DE %d" % engine.levels) if engine.levels > 0 else ""]
	var lines: Array = []
	lines.append(_intro_block())
	if engine.round_index == 0:
		lines.append({"head": "MESA %s" % str(config.get("table_name", "")).to_upper(), "title": "BLIND ◎%d" % engine.blind, "text": "Todo mundo paga o blind a cada rodada. Você senta com ◎%d e leva de volta o que tiver quando sair." % engine.buy_in, "color": UIKit.GOLD})
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


func _wait(seconds: float) -> void:
	await get_tree().create_timer(GameState.anim(seconds)).timeout
	while paused and is_inside_tree():
		await get_tree().create_timer(0.1).timeout


func _wait_human() -> CardData:
	human_turn = true
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
	var card: CardData = await human_card_chosen
	human_turn = false
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
		{"icon": "♠ ♥ ◆ ♣", "title": "GANHE RODADAS", "text": "Cada nível tem 8 cartas e um modificador sorteado que muda as regras. Em cada rodada todo mundo joga 1 carta: vence a maior do naipe (Trunfo corta). Quem vence leva o pote."},
		{"icon": "◎ ♨ ◎", "title": "APOSTE, PASSE OU DESISTA", "text": "Antes de cada rodada todo mundo paga o blind. Aí, na sua vez, você pode PASSAR, AUMENTAR, PAGAR ou DESISTIR. Só quem fica joga carta. Aumente com uma mão fraca e, se todo mundo desistir, o pote é seu sem mostrar nada: isso é um blefe."},
		{"icon": "✦ ⚡ ★", "title": "BÔNUS E COMBOS", "text": "Cartas fortes, modificadores e combos rendem um prêmio extra da banca, tipo 3 Trunfos, 3 figuras ou 3 cartas seguidas do mesmo naipe. Ganhar rodadas seguidas multiplica o prêmio. Suas fichas na mesa são seu placar: saia quando quiser levando a stack."},
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
	var text := """MESA
• Você senta com uma stack (20 blinds) e joga sem fim: a cada 8 rodadas as cartas são distribuídas de novo e um novo modificador é sorteado. Suas fichas na mesa são seu placar. Saia quando quiser e leve a stack de volta pra sua carteira.
• Ficou sem fichas pro blind? Recompre ou saia da mesa. Rivais que quebram são trocados por jogadores novos.

APOSTAS EM CADA RODADA
• Todo mundo paga o blind (a aposta mínima da mesa) pro pote. O botão (D) gira a cada rodada e fala por último.
• Na sua vez: PASSAR (se ninguém aumentou), AUMENTAR (no mínimo mais 1 blind, até o all-in), PAGAR (igualar) ou DESISTIR (perde o que pôs e não joga carta).
• Cada rodada permite até 2 aumentos. Todo mundo que aumentou ou pagou põe o mesmo valor.
• Só quem ficou joga carta. Quem vence leva o pote. Se todo mundo desistir, o último leva o pote sem jogar: o blefe funcionou.
• Quem desistiu guarda a carta pra próxima rodada.
• Sua mão: o painel mostra se ela está fraca, média, boa ou forte pra essa rodada. Um Trunfo alto ou um Rei costumam vencer.

MODIFICADOR DO NÍVEL
• Todo nível sorteia UM modificador. Ele pode valer no nível inteiro ou só numa rodada.
• Nível inteiro: você vê a regra logo no início (ex.: Trunfo em Dobro, Naipe Fraco, Mundo ao Contrário, Naipe Maldito).
• Uma rodada só: é surpresa, revelada quando começa e antes das apostas (ex.: Rodada Dourada ×3, Rodada Maldita, Saque, Assalto ao Líder).
• As cartas afetadas mostram o valor real direto na carta.

PRÊMIO DA BANCA
• Os pontos das cartas da rodada viram fichas extras pagas pela banca a quem vence: cada ponto vale ¼ do blind. Modificadores e combos aumentam esse prêmio.

COMBOS
• SEQUÊNCIA: 2 rodadas seguidas ×1,25, 3 seguidas ×1,5 (MÃO QUENTE), 4 ou mais ×2. As chamas ♨ mostram seu nível.
• CORTADO: você quebra a sequência de 2+ vitórias de alguém.
• CORTE DE REI: você corta um Rei com Trunfo.
• CHUVA DE TRUNFOS: 3 ou mais Trunfos na mesa, ×2.
• REALEZA: 3 ou mais figuras (Valete, Cavaleiro, Dama, Rei) na mesa, ×1,5.
• ESCADA: 3 cartas seguidas do mesmo naipe na mesa.

RELÓGIO
• Você tem 10 segundos pra jogar a carta (a barra embaixo da mesa esvazia). Estourou, jogamos sua carta mais fraca.

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


# ------------------------------------------------------------------ HUD (stacks, pote, ações)

func _current_turn_player() -> int:
	if engine.betting:
		return engine.bet_actor()
	if engine.is_round_over() or engine.active_count() <= 1:
		return -1
	return engine.current


func _fmt_chips(v: float) -> String:
	return "◎ %d" % int(v)


func _refresh_hud() -> void:
	var turn_player := _current_turn_player()
	for p in range(engine.num_players):
		var total_lbl := hud_totals[p] as Label
		var new_total: float = engine.stacks[p]
		while shown_totals.size() <= p:
			shown_totals.append(new_total)
		if is_equal_approx(new_total, float(shown_totals[p])):
			total_lbl.text = _fmt_chips(new_total)
		else:
			FX.count(total_lbl, float(shown_totals[p]), new_total, _fmt_chips)
			FX.pop(total_lbl, 1.3)
			shown_totals[p] = new_total
		var delta: float = engine.stacks[p] - engine.level_start_stacks[p]
		(hud_round_pts[p] as Label).text = "%s◎%d no nível" % ["+" if delta >= 0.0 else "−", absi(int(delta))]
		if p == 0:
			(hud_round_pts[p] as Label).text += "  ·  carteira ◎%d" % int(SaveManager.section("profile")["fichas"])
		var out: bool = engine.folded[p] and (engine.betting or engine.plays.size() > 0 or engine.active_count() < engine.num_players)
		(hud_badges[p] as Control).modulate = Color(1, 1, 1, 1) if p == turn_player else Color(0.78, 0.76, 0.85, 0.45 if out else 1.0)
		var dealer := "(D) " if engine.button == p else ""
		(hud_titles[p] as Label).text = "%s%s" % [dealer, str(config["names"][p]).to_upper()]
		(hud_titles[p] as Label).add_theme_color_override("font_color", UIKit.GOLD if engine.button == p else UIKit.MUTED)
		_refresh_bet_tags(p)
		if p > 0:
			(hud_cards[p] as Label).text = "%d cartas" % (engine.hands[p] as Array).size()
	info_label.text = "NÍVEL %d%s · BLIND ◎%d" % [engine.round_index + 1, ("/%d" % engine.levels) if engine.levels > 0 else "", engine.blind]
	Widgets.progress_dots(trick_dots, ChaosEngine.HAND_SIZE, engine.trick_number)
	var rest := _rest_banner()
	modifier_label.text = "%s — %s" % [rest[0], rest[1]] if modifier_expanded else str(rest[0])
	_refresh_pot()
	_update_turn_highlight(turn_player)


func _reset_actions() -> void:
	for p in range(engine.num_players):
		action_text[p] = ""
		action_color[p] = UIKit.MUTED


## Tag do assento: última ação da rodada (PASSOU / AUMENTOU / PAGOU / DESISTIU), quanto já pôs
## e as chamas da sequência.
func _refresh_bet_tags(p: int) -> void:
	var streak: int = engine.streak[p] if p < engine.streak.size() else 0
	var flames := ""
	if streak >= 2:
		flames = "%s ×%s" % ["♨".repeat(ChaosCombos.flame_level(streak)), UIKit.fmt_dec(ChaosCombos.streak_mult(streak), 2)]
	var act: String = action_text[p]
	var col: Color = action_color[p]
	var put := ("◎%d no pote" % int(engine.contrib[p])) if engine.pot > 0.0 and not engine.folded[p] and not act.contains("◎") else ""
	if p == 0:
		var lines: Array = []
		if act != "":
			lines.append(act)
		if put != "":
			lines.append(put)
		if flames != "":
			lines.append(flames)
		my_bet_label.text = "\n".join(lines)
		my_bet_label.add_theme_color_override("font_color", col if act != "" else (FLAME if flames != "" else UIKit.MUTED))
		return
	(bet_tags[p] as Label).add_theme_color_override("font_color", col)
	if p == 2:
		# Assento do topo: tudo em uma linha pra não invadir o pote.
		(bet_tags[p] as Label).text = (act + "  " + put).strip_edges()
		(prog_tags[p] as Label).text = flames
		(prog_tags[p] as Label).visible = flames != ""
		(prog_tags[p] as Label).add_theme_color_override("font_color", FLAME)
		return
	(bet_tags[p] as Label).text = act
	(prog_tags[p] as Label).text = (put + "  " + flames).strip_edges()
	(prog_tags[p] as Label).add_theme_color_override("font_color", FLAME if put == "" else UIKit.MUTED)


func _refresh_pot() -> void:
	if not pot_locked:
		shown_pot = engine.pot
		pot_label.text = "POTE ◎ %d" % int(engine.pot)
	var sub := ""
	if engine.betting and engine.bet_level > float(engine.blind):
		sub = "aposta em ◎ %d" % int(engine.bet_level)
	elif engine.pot <= 0.0:
		sub = "blind ◎ %d por rodada" % engine.blind
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


func _global_center(c: Control) -> Vector2:
	return c.global_position + c.size / 2.0


func _seat_center(p: int) -> Vector2:
	return _global_center(seat_avatars[p] as Control)


func _chips_for(amount: float) -> int:
	return clampi(int(ceil(amount / float(engine.blind))), 1, 7)


func _update_turn_highlight(turn_player: int) -> void:
	turn_pulse_token += 1
	var my_token := turn_pulse_token
	for p in range(1, seat_avatars.size()):
		var avatar: PanelContainer = seat_avatars[p]
		var active := p == turn_player
		var accent := UIKit.GOLD if active else UIKit.MUTED
		var ring := UIKit.box(UIKit.PURPLE_DEEP, accent, 5 if active else 3, 60, 0)
		ring.set_corner_radius_all(40)
		avatar.add_theme_stylebox_override("panel", ring)
		if not active:
			avatar.scale = Vector2.ONE
	if turn_player > 0:
		_pulse_avatar(seat_avatars[turn_player], my_token)


# ------------------------------------------------------------------ loop de rodadas

func _run_round() -> void:
	while not engine.is_round_over():
		if not is_inside_tree() or finished:
			return
		await _trick_start()
		if not is_inside_tree() or finished:
			return
		if not await _ensure_solvent():
			return
		for q in engine.refill_bots():
			await _new_player_sits(q)
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
		var card: CardData
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

func _betting_phase() -> void:
	human_turn = false
	_banner("APOSTAS", "Blind ◎%d de cada um. Passe, aumente, pague ou desista." % engine.blind, UIKit.GOLD)
	if not GameState.autoplay:
		for p in range(engine.num_players):
			FX.fly_chips(popup_layer, _seat_center(p), _global_center(pot_box), 1)
		Sfx.play("chip")
	_pot_to(engine.pot)
	await _wait(0.6)
	var guard := 0
	while engine.betting and guard < 40:
		guard += 1
		if not is_inside_tree() or finished:
			return
		var p := engine.bet_actor()
		_refresh_hud()
		var act: Dictionary
		if p == 0 and not GameState.autoplay:
			await _tip("bet", "SUA VEZ DE APOSTAR", "Todo mundo já pagou o blind. Você pode PASSAR, AUMENTAR, PAGAR ou DESISTIR. Só quem fica na rodada joga carta, e quem vence leva o pote.")
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
	_banner_clear()
	_refresh_hud()


## Mostra o que cada um fez (passou, pagou, aumentou, desistiu) e move as fichas pro pote.
func _show_bet_action(p: int, r: Dictionary) -> void:
	var pname := str(config["names"][p]).to_upper()
	var amount := float(r.get("amount", 0.0))
	var title := ""
	var sub := ""
	var col := UIKit.MUTED
	match str(r.get("action", "")):
		"check":
			action_text[p] = "PASSOU"
			title = "%s PASSOU" % pname
			sub = "Fica na rodada sem aumentar."
		"call":
			action_text[p] = "PAGOU"
			title = "%s PAGOU" % pname
			sub = "Pagou ◎ %d pra igualar em ◎ %d." % [int(amount), int(engine.bet_level)]
			col = UIKit.OK
		"raise":
			action_text[p] = "AUMENTOU ◎%d" % int(r["to"])
			title = "%s AUMENTOU!" % pname
			sub = "Aposta agora em ◎ %d. Quem não pagar, desiste." % int(r["to"])
			col = UIKit.GOLD
		"fold":
			action_text[p] = "DESISTIU"
			title = "%s DESISTIU" % pname
			sub = "Fora da rodada: perde o que pôs."
			col = UIKit.DANGER
	action_color[p] = col
	_banner(title, sub, col if col != UIKit.MUTED else UIKit.INK)
	if amount > 0.0:
		FX.fly_chips(popup_layer, _seat_center(p), _global_center(pot_box), _chips_for(amount))
		Sfx.play("combo" if str(r["action"]) == "raise" else "chip")
		_pot_to(engine.pot)
		if str(r["action"]) == "raise":
			FX.shake(main_area, 0.35)
			FX.burst(popup_layer, _seat_center(p) - popup_layer.global_position, UIKit.GOLD, 14)
	elif str(r.get("action", "")) == "fold":
		Sfx.play("lose")
	_refresh_hud()
	await _wait(0.75 if p != 0 else 0.45)


func _hand_label() -> String:
	var s := ChaosBot.hand_strength(engine, 0)
	if s >= 0.75:
		return "FORTE ★★★"
	if s >= 0.55:
		return "BOA ★★☆"
	if s >= 0.35:
		return "MÉDIA ★☆☆"
	return "FRACA ☆☆☆"


## Painel de aposta do jogador (fica acima da sua mão, que continua à vista). Devolve
## {action, to}.
func _human_bet() -> Dictionary:
	modal_open = true
	var opt := engine.bet_options(0)
	var vw := get_viewport_rect().size.x
	var holder := MarginContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_theme_constant_override("margin_top", 96 if not _is_wide() else 16)
	overlay_layer.add_child(holder)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.GOLD, 20)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.custom_minimum_size = Vector2(minf(vw - 32.0, 660.0), 0)
	holder.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	box.add_child(v)
	v.add_child(UIKit.label("SUA VEZ DE APOSTAR", 32, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var stack := int(engine.stacks[0])
	var call_amt := int(opt["call"])
	var info := "Pote ◎%d  ·  Sua stack ◎%d  ·  Sua mão: %s" % [int(engine.pot), stack, _hand_label()]
	var info_l := UIKit.label(info, 26, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	info_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info_l)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	v.add_child(body)
	var st := {"raising": false, "to": int(opt["min_to"])}
	var done := func(result: Dictionary) -> void:
		st["result"] = result
		item_chosen.emit(1)
	st["render"] = func():
		for c in body.get_children():
			c.queue_free()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		body.add_child(row)
		if not bool(opt["can_check"]):
			var fold := UIKit.button("DESISTIR", UIKit.DANGER, 30)
			fold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fold.pressed.connect(func(): done.call({"action": "fold"}))
			row.add_child(fold)
		var main_txt := "PASSAR" if bool(opt["can_check"]) else "PAGAR ◎%d" % call_amt
		var main := UIKit.button(main_txt, UIKit.OK, 30)
		main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main.pressed.connect(func(): done.call({"action": "check" if bool(opt["can_check"]) else "call"}))
		row.add_child(main)
		if bool(opt["can_raise"]) and not bool(st["raising"]):
			var rb := UIKit.button("AUMENTAR", UIKit.GOLD, 30)
			rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rb.pressed.connect(func():
				st["raising"] = true
				(st["render"] as Callable).call())
			row.add_child(rb)
		if bool(st["raising"]):
			_build_raise_picker(body, opt, st, done)
	(st["render"] as Callable).call()
	box.scale = Vector2(0.9, 0.9)
	box.pivot_offset = Vector2(box.custom_minimum_size.x / 2.0, 0)
	create_tween().tween_property(box, "scale", Vector2.ONE, GameState.anim(0.15)).set_trans(Tween.TRANS_BACK)
	await item_chosen
	modal_open = false
	if is_inside_tree():
		holder.queue_free()
	return st.get("result", {"action": "check"})


## Seletor de valor do aumento: atalhos (mínimo, ½ pote, pote, all-in) e − / + de 1 blind.
func _build_raise_picker(body: VBoxContainer, opt: Dictionary, st: Dictionary, done: Callable) -> void:
	var blind := engine.blind
	var lo := int(opt["min_to"])
	var hi := int(opt["max_to"])
	var pot_now := int(opt["pot"])
	var level := int(engine.bet_level)
	st["to"] = clampi(int(st["to"]), lo, hi)
	body.add_child(UIKit.label("QUANTO AUMENTAR?", 24, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
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
	var num := UIKit.label("◎ %d" % int(st["to"]), 52, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	num.custom_minimum_size = Vector2(190, 0)
	row.add_child(num)
	var plus := UIKit.button("+", UIKit.MUTED, 40)
	plus.custom_minimum_size = Vector2(96, 72)
	plus.disabled = int(st["to"]) >= hi
	plus.pressed.connect(func():
		st["to"] = mini(int(st["to"]) + blind, hi)
		(st["render"] as Callable).call())
	row.add_child(plus)
	var ok := UIKit.button("AUMENTAR PARA ◎%d" % int(st["to"]) + (" (ALL-IN)" if int(st["to"]) >= hi else ""), UIKit.GOLD, 30)
	ok.pressed.connect(func(): done.call({"action": "raise", "to": float(st["to"])}))
	body.add_child(ok)
	var back := UIKit.button("VOLTAR", UIKit.MUTED, 26)
	back.custom_minimum_size = Vector2(0, 64)
	back.pressed.connect(func():
		st["raising"] = false
		(st["render"] as Callable).call())
	body.add_child(back)


# ------------------------------------------------------------------ pote

## Fichas do pote voam pro vencedor; o pote zera.
func _collect_pot(winner: int, total: float, gain: float) -> void:
	var seat_at := _seat_center(winner)
	FX.fly_chips(popup_layer, _global_center(pot_box), seat_at, _chips_for(total), UIKit.OK if winner == 0 else UIKit.GOLD)
	Sfx.play("win" if winner == 0 else "chip")
	await _wait(0.55)
	if not is_inside_tree():
		return
	FX.float_text(popup_layer, seat_at, "%s◎ %d" % ["+" if gain >= 0.0 else "−", absi(int(gain))], UIKit.OK if gain >= 0.0 else UIKit.DANGER)
	FX.burst(popup_layer, seat_at - popup_layer.global_position, UIKit.OK if winner == 0 else UIKit.GOLD, 16)
	if winner == 0:
		FX.shake(main_area, clampf(total / (float(engine.blind) * 20.0), 0.3, 0.9))
		if total >= float(engine.blind) * 12.0:
			Sfx.play("jackpot")
			FX.chip_rain(popup_layer, 22)
	_pot_to(0.0)
	_refresh_hud()
	await _wait(0.5)


## Todo mundo desistiu: o último leva o pote sem jogar carta (o blefe funcionou).
func _resolve_walkover(result: Dictionary) -> void:
	var winner: int = result["winner"]
	var wname := str(config["names"][winner]).to_upper()
	_banner("%s LEVOU SEM JOGAR!" % wname, "Todo mundo desistiu. O pote é dele e ninguém viu as cartas.", UIKit.GOLD if winner == 0 else UIKit.INK)
	if winner == 0 and float(result.get("gain", 0.0)) > best_gain:
		best_gain = float(result["gain"])
	await _collect_pot(winner, float(result["pot"]), float(result.get("gain", 0.0)))
	_banner_clear()
	_refresh_hud()


# ------------------------------------------------------------------ rodada resolvida

func _resolve_trick(result: Dictionary) -> void:
	var winner: int = result["winner"]
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

	var pot_amt := float(result["pot"])
	var prize := float(result["prize"])
	var gain := float(result.get("gain", 0.0))
	if winner == 0 and gain > best_gain:
		best_gain = gain
	var wname := str(config["names"][winner]).to_upper()
	var notes: Array = []
	match int(result.get("modifier", -1)):
		ChaosModifiers.Modifier.VAZA_DOURADA:
			notes.append("rodada dourada ×3")
		ChaosModifiers.Modifier.PRIMEIRA_DOBRO:
			notes.append("rodada relâmpago ×2")
		ChaosModifiers.Modifier.ULTIMA_TRIPLO:
			notes.append("última é tudo ×3")
	var sub := "Pote ◎%d" % int(pot_amt)
	if absf(prize) >= 1.0:
		sub += "  ·  prêmio das cartas %s◎%d" % ["+" if prize >= 0.0 else "−", absi(int(prize))]
	if float(result.get("mult", 1.0)) > 1.0:
		sub += "  (×%s)" % UIKit.fmt_dec(float(result["mult"]), 2)
	if not notes.is_empty():
		sub += "  (%s)" % ", ".join(notes)
	_banner("%s venceu!" % wname, sub, UIKit.GOLD if winner == 0 else UIKit.INK)
	Sfx.play("chip")
	var punch := clampf((pot_amt + prize) / (float(engine.blind) * 16.0), 0.0, 1.0)
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
	if float(result.get("saque_amount", 0.0)) > 0.0:
		extras.append(["⚔ SAQUE!", "%s levou ◎%d dos rivais" % [wname, int(result["saque_amount"])], UIKit.DANGER])
	if float(result.get("assalto_amount", 0.0)) > 0.0:
		extras.append(["⚔ ASSALTO!", "%s roubou ◎%d de quem tinha mais fichas" % [wname, int(result["assalto_amount"])], UIKit.DANGER])
	if int(result.get("modifier", -1)) == ChaosModifiers.Modifier.VAZA_MALDITA:
		extras.append(["☠ RODADA MALDITA!", "%s paga à banca por vencer essa rodada" % wname, UIKit.DANGER])
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
	await _collect_pot(winner, pot_amt + maxf(prize, 0.0) + float(result.get("saque_amount", 0.0)) + float(result.get("assalto_amount", 0.0)), gain)
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
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.GOLD, 24)
	box.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 40.0, 664.0), 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	box.add_child(v)
	v.add_child(UIKit.label("FIM DO NÍVEL %d" % (int(r["round"]) + 1), 30, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label(ChaosModifiers.label(int(r["modifier"]), int(r["weak_suit"])), 28, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(HSeparator.new())
	var stacks: Array = r["stacks"]
	var deltas: Array = r["deltas"]
	var won: Array = r["tricks_won"]
	var order := range(engine.num_players)
	order.sort_custom(func(a: int, b: int) -> bool: return float(stacks[a]) > float(stacks[b]))
	for p in order:
		var d := int(deltas[p])
		var line := "%s%s  ◎%d  (%s◎%d)  ·  %d rodadas" % ["♛ " if p == order[0] else "", str(config["names"][p]).to_upper(), int(stacks[p]), "+" if d >= 0 else "−", absi(d), int(won[p])]
		var lab := UIKit.label(line, 28, (UIKit.GOLD if p == 0 else UIKit.INK), HORIZONTAL_ALIGNMENT_CENTER)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(lab)
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
	box.scale = Vector2(0.85, 0.85)
	box.pivot_offset = box.custom_minimum_size / 2.0
	create_tween().tween_property(box, "scale", Vector2.ONE, GameState.anim(0.2)).set_trans(Tween.TRANS_BACK)
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
	var summary := GameState.report_chaos_match(result)
	Sfx.play("win" if summary["won"] else "lose")
	status_label.text = ""
	if turn_bar:
		turn_bar.modulate.a = 0.0
	_show_results(summary)
	match_finished.emit(summary)


func _show_results(summary: Dictionary) -> void:
	var ov := UIKit.overlay()
	overlay_layer.add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.GOLD if summary["won"] else UIKit.DANGER, 24)
	box.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 40.0, 664.0), 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	var net := int(summary["net_fichas"])
	var title := "VOCÊ SAIU NO LUCRO!" if summary["won"] else ("VOCÊ SAIU DA MESA" if net == 0 else "VOCÊ SAIU NO PREJUÍZO")
	v.add_child(UIKit.label(title, 32, UIKit.GOLD if summary["won"] else UIKit.DANGER, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(HSeparator.new())
	var order: Array = engine.match_result["standings"]
	var stacks: Array = engine.match_result["stacks"]
	for i in range(order.size()):
		var p: int = order[i]
		var line := "%d. %s%s — ◎%d" % [i + 1, "♛ " if i == 0 else "", str(config["names"][p]).to_upper(), int(stacks[p])]
		v.add_child(UIKit.label(line, 32, UIKit.GOLD if p == 0 else UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(HSeparator.new())
	var st: Dictionary = engine.session_stats[0]
	var stat := "%d rodadas na mesa · %d potes ganhos · %d blefes vencidos · %d desistências" % [engine.hand_no, int(st["pots"]), int(st["bluffs"]), int(st["folds"])]
	var stat_l := UIKit.label(stat, 26, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	stat_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(stat_l)
	if best_gain > 0.0:
		v.add_child(UIKit.label("★ Maior pote seu: +◎%d" % int(best_gain), 30, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	for line in summary["lines"]:
		var ll := UIKit.label(str(line), 30, UIKit.OK if net >= 0 else UIKit.DANGER, HORIZONTAL_ALIGNMENT_CENTER)
		ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(ll)
	var again := UIKit.button("NOVA MESA")
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
