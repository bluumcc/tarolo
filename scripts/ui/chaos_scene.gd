extends Control
## ChaosScene.tscn — mesa do modo Caos: 5 rodadas curtas de 8 cartas, todo mundo joga
## pra si (sem Atacante/Defesa), com um modificador novo a cada rodada e um bônus de
## Fôlego pra quem estiver por baixo no total. Layout pensado pra celular (retrato):
## uma pilha vertical — status dos jogadores no topo, área de jogo compacta no meio,
## sua mão embaixo — em vez de uma mesa oval espalhada, que só faz sentido em paisagem.

signal human_card_chosen(card: CardData)
signal item_chosen(item: int)
signal slides_done
signal match_finished(summary: Dictionary)

const CARD_SCENE := preload("res://scenes/Card.tscn")

## As cartas da mão têm o tamanho cheio; as da mesa ficam menores pra caber 4 lado a lado.
## Relógios da mesa (um só, `_clock_start`): estourou, jogamos por você.
const TURN_SECONDS := 10.0      # jogar a carta; estourou, joga a mais fraca
const DISCARD_SECONDS := 18.0   # descarte inicial; estourou, descarta as 2 mais fracas
const PREDICT_SECONDS := 15.0   # lance de vitórias; estourou, confirma o palpite que estiver na tela
const BET_SECONDS := 12.0       # apostar/passar/pagar/aumentar/desistir; estourou, passa (ou desiste se tiver que pagar)

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
var banner_title: Label         # aviso de ação ("Fulano pagou", "Sua vez"...): linha no card do header, embaixo dos losangos
var clock_on := false          # relógio da vez rodando (card TEMPO)
var clock_left := 0.0
var clock_total := TURN_SECONDS
var clock_in_modal := false    # palpite e aposta rodam com `modal_open` ligado: o relógio não pausa por isso
var clock_timeout := Callable()
var main_area: Control
var seat_nodes: Array = []
var bet_pills: Array = []      # fichas apostadas na frente de cada jogador
var order_badges: Array = []   # 1, 2, 3... = ordem de fala / de jogada
var dealer_badges: Array = []
var phase := "idle"            # "bet" | "play" | "idle"
var bets_gathered := false     # apostas já juntadas no pote
var first_round_done := false
var round_dots: RoundDots
var prog_card: StatCard         # PALPITE (fez/palpite), no canto de baixo à esquerda
var bottom_mid: Control          # meio da barra de baixo: ações OU o card de pote/prêmio
var idle_card: PanelContainer    # PRÊMIO — ocupa o lugar dos botões enquanto não há ação
var modifier_strip: ModifierStrip   # card do modificador, em cima da barra de baixo
var banner_slot: Control
var table_players := 0           # nº de jogadores com que a mesa foi dimensionada; só é refeito entre rodadas
var discard_head: VBoxContainer  # título grande + instrução da etapa de descarte, no topo do palco (fora do card)
var chrome_discard := false      # etapa sem mesa (descarte/palpite): sem modificador na faixa
var shown_totals: Array = []
var modal_open := false      # modal de poder/aposta aberto — o relógio da jogada pausa
var best_gain := 0.0         # maior pote que o jogador levou na sessão
var total_in := 0            # fichas que o jogador pôs na mesa (buy-in + recompras)
var action_text: Array = []  # última ação de cada assento nessa jogada
var action_color: Array = []
var popup_layer: Control
var overlay_layer: Control
var table_views: Array = []
var pot_box: Control             # card do POTE (faixa do topo); some enquanto há aviso de ação
var _turn_color := UIKit.TR_CYAN.lightened(0.15)   # moldura/nome de quem joga agora
var pot_label: Label
var pot_sub: Label
var pot_prize_label: Label   # prêmio do palpite — visível quando o trick_pot está em destaque
var bet_tags: Array = []       # "◎25 · 3" por assento
var prog_tags: Array = []      # "1/3 ♨×1,5" ao vivo por assento
var hold_stacks: Array = []      # Blitz: stacks de antes da liquidação (a tela só muda depois da animação)
var hold_pot := -1.0
var blitz_revealed: Array = []  # Blitz: entrada de cada um já paga (pote), pill visível na mesa
var blitz_showdown := false     # Blitz: fim da rodada — só aí o alvo dos rivais aparece pra você
var blitz_sitting_out := false  # Blitz: jogador ficou sem fichas mid-rodada (sentado fora)
var double_btn: Button
var discard_picks: Array = []   # Blitz: cartas marcadas na mão pra descartar (até BLITZ_DISCARD_SIZE)
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
	if engine.blitz:
		_set_discard_chrome(true)
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

const HAND_RAISE := 28.0   ## o leque sobe um pouco da base da faixa da mão
const BAR_H := 96.0       ## barra de baixo (cards laterais: palpite e tempo)
const ACT_H := BAR_H * 0.75   ## botões de ação e card de pote/prêmio: 75% dos cards laterais
const HEADER_H := 82.5       ## altura dos três cards do header (menu, dots, ajuda): +10%
const POT_CARD_W := 300.0   ## largura fixa do card do pote (cabe "POTE ◎ 99999")
const BANNER_SLOT_H := 46.0   ## faixa dos avisos de ação, logo abaixo do topo
const MOD_GAP := 10.0       ## folga entre o leque e o card do modificador
const BANNER_H := 100.0    ## do topo da zona até a mão: faixa de avisos, abaixo do seu avatar
const AVATAR_TO_FAN := 38.0   ## do topo do leque (na zona) até a referência do seu avatar; dá folga entre o stack e as cartas
const MY_SEAT_RISE := 21.0 ## quanto o centro do seu avatar fica acima do topo do card roxo
const LEFT_W := 132.0     ## largura dos dois cards laterais (palpite e tempo)
const MAX_UI_W := 900.0    ## em tela larga o jogo não estica além disso

var stage: Control
var margin_box: MarginContainer
var bottom_bar: HBoxContainer
var bet_row: HBoxContainer
var timer_label: Label
var hand_scroller: HandScroller
var hand_zone: Control
var my_bet_pill: Control        # aposta da jogada: o Label do seu assento, em cima do avatar
var my_bet_label: Label


func _build_ui() -> void:
	add_child(UIKit.background())
	var dim := ColorRect.new()   # mesa de runas sobre quase-preto: escurece o fundo azulado
	dim.color = Color(UIKit.TR_BLACK, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

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

	# Topo: menu · losangos das jogadas · ajuda. Bordas neutras, como as do card do tempo.
	var topbar := HBoxContainer.new()
	topbar.add_theme_constant_override("separation", 12)
	root.add_child(topbar)
	var neutral := UIKit.box_cached(UIKit.TR_PURPLE_DARK.darkened(0.3), UIKit.TR_PURPLE_LIGHT, 2, 14, 8)
	var menu_btn := Widgets.icon_button("☰")
	menu_btn.custom_minimum_size = Vector2(HEADER_H, HEADER_H)
	for sn in ["normal", "hover", "pressed", "focus"]:
		menu_btn.add_theme_stylebox_override(sn, neutral)
	menu_btn.add_theme_color_override("font_color", UIKit.TR_WHITE)
	menu_btn.pressed.connect(_open_pause)
	topbar.add_child(menu_btn)
	var info_box := PanelContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.custom_minimum_size = Vector2(0, HEADER_H)
	info_box.add_theme_stylebox_override("panel", UIKit.box_cached(UIKit.TR_PURPLE_DARK.darkened(0.3), UIKit.TR_PURPLE_LIGHT, 2, 14, 6))
	round_dots = RoundDots.new()
	round_dots.set_progress(ChaosEngine.HAND_SIZE, 0)
	var info_v := VBoxContainer.new()
	info_v.alignment = BoxContainer.ALIGNMENT_CENTER
	info_v.add_theme_constant_override("separation", 0)
	info_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_box.add_child(info_v)
	info_v.add_child(round_dots)
	_build_banner(info_v)
	topbar.add_child(info_box)
	var help_btn := Widgets.icon_button("?")
	help_btn.custom_minimum_size = Vector2(HEADER_H, HEADER_H)
	for sn in ["normal", "hover", "pressed", "focus"]:
		help_btn.add_theme_stylebox_override(sn, neutral)
	help_btn.add_theme_color_override("font_color", UIKit.TR_WHITE)
	help_btn.pressed.connect(_open_help)
	topbar.add_child(help_btn)
	# Os dois cards laterais acompanham a altura do header e ficam sempre quadrados.
	topbar.resized.connect(func():
		for b in [menu_btn, help_btn]:
			if not is_equal_approx(b.custom_minimum_size.x, topbar.size.y):
				b.custom_minimum_size = Vector2(topbar.size.y, HEADER_H))

	# Faixa logo abaixo: o POTE (largura fixa) fica aqui e dá lugar aos avisos de ação enquanto
	# há um aviso. Altura fixa: nada se mexe quando troca.
	banner_slot = Control.new()
	banner_slot.custom_minimum_size = Vector2(0, BANNER_SLOT_H)
	banner_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner_slot)
	_build_pot_card(banner_slot)

	# Palco: a mesa de runas com os rivais sentados na borda, a distâncias iguais; você embaixo.
	stage = Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size = Vector2(0, 300)
	root.add_child(stage)
	main_area = stage
	discard_head = VBoxContainer.new()
	discard_head.anchor_right = 1.0
	discard_head.offset_top = 96.0   # respiro do header
	discard_head.offset_left = 8.0
	discard_head.offset_right = -8.0
	discard_head.add_theme_constant_override("separation", 14)
	discard_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	discard_head.visible = false
	var dt := UIKit.serif_label("ESCOLHA DUAS CARTAS PARA DESCARTAR", 46, UIKit.TR_GOLD.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER)
	dt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dt.add_theme_constant_override("outline_size", 4)
	dt.add_theme_constant_override("line_spacing", 6)
	discard_head.add_child(dt)
	var ds := UIKit.serif_label("Deslize a carta para cima ou toque nela duas vezes para descartar", 26, UIKit.muted_lilac(), HORIZONTAL_ALIGNMENT_CENTER)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	discard_head.add_child(ds)
	stage.add_child(discard_head)
	table_center = TableEllipse.new()
	table_center.name = "TableCenter"
	table_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	table_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(table_center)
	table_center.resized.connect(_layout_table)
	for p in range(engine.num_players):
		stage.add_child(_build_seat(p))
	# Sua aposta da jogada: o mesmo texto de fichas dos rivais, em cima do seu avatar.
	var me_seat := seat_nodes[0] as SeatView
	my_bet_label = me_seat.bet_label
	my_bet_pill = my_bet_label
	my_bet_label.visible = true
	my_bet_label.modulate.a = 0.0
	bet_pills[0] = my_bet_pill
	bet_tags[0] = my_bet_label

	_build_hand_zone(root)
	_build_bottom_bar(root)

	popup_layer = Control.new()
	popup_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_layer.z_index = 20
	add_child(popup_layer)

	hand_scroller.ghost_layer = popup_layer
	hand_scroller.throw_allowed = func() -> bool: return phase == "discard" or human_turn
	hand_scroller.throw_requested.connect(_on_card_thrown)
	hand_scroller.deselect_on_cancel = true
	hand_scroller.drag_cancelled.connect(func(v: CardView):
		if selected_view == v:
			selected_view = null)

	overlay_layer = Control.new()
	overlay_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_layer.z_index = 100   # por cima de tudo, inclusive do seu avatar (z 50)
	add_child(overlay_layer)

	_apply_orientation()
	_layout_table.call_deferred()


## Pote: card de largura fixa (cabe valores altos), uma linha só — "POTE ◎ 12000" — centrado na
## faixa do topo. Dá lugar aos avisos de ação enquanto houver um.
func _build_pot_card(slot: Control) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(POT_CARD_W, 0)
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.0
	card.anchor_bottom = 1.0
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", UIKit.box_cached(UIKit.TR_PURPLE_DARK.darkened(0.3), UIKit.TR_PURPLE_LIGHT, 2, 12, 6))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var cap := UIKit.serif_label("POTE", 22, UIKit.TR_GOLD.lerp(UIKit.TR_WHITE, 0.25), HORIZONTAL_ALIGNMENT_CENTER)
	cap.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(cap)
	pot_label = UIKit.label("◎ 0", 30, UIKit.TR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	pot_label.add_theme_font_size_override("font_size", 30)
	pot_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(pot_label)
	pot_sub = UIKit.label("", 18, UIKit.MUTED)   # sem lugar na tela
	pot_sub.visible = false
	row.add_child(pot_sub)
	pot_box = card
	slot.add_child(card)


## Aviso de ação: título curto, na cor do tipo de ação, numa linha dentro do card do header (embaixo dos losangos).
func _build_banner(parent: Control) -> void:
	banner_title = UIKit.serif_label("", 22, UIKit.TR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	banner_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	banner_title.custom_minimum_size = Vector2(0, 30)   # altura reservada: nada se mexe quando o aviso aparece
	banner_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(banner_title)


## Card central: a faixa de avisos fica logo abaixo do seu avatar (que cruza o topo do card), a
## mão em arco por cima do card (as cartas passam das bordas) e o prêmio no pé.
func _build_hand_zone(root: VBoxContainer) -> void:
	var hand_h := _hand_h()
	var zone := Control.new()
	hand_zone = zone
	zone.custom_minimum_size = Vector2(0, BANNER_H + hand_h + _pot_h())
	root.add_child(zone)

	# Card do modificador (nome; tocar abre a regra) na base da zona, em cima da barra de baixo.
	modifier_strip = ModifierStrip.new()
	modifier_strip.anchor_right = 1.0
	modifier_strip.anchor_top = 1.0
	modifier_strip.anchor_bottom = 1.0
	modifier_strip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	modifier_strip.tapped.connect(_show_modifier_info)
	zone.add_child(modifier_strip)

	# Mão em arco leve, sempre no tamanho real; rola de lado só se não couber.
	hand_scroller = HandScroller.new()
	hand_scroller.anchor_left = 0.0
	hand_scroller.anchor_right = 1.0
	hand_scroller.anchor_top = 0.0
	hand_scroller.anchor_bottom = 0.0
	hand_scroller.offset_top = BANNER_H + _deck_drop()
	hand_scroller.offset_bottom = BANNER_H + hand_h + _deck_drop()  # also kept in sync by _update_hand_scroller_margins
	_update_hand_scroller_margins()
	zone.add_child(hand_scroller)
	hand_scroller.resized.connect(_layout_hand)
	_update_hand_scroller_margins()
	hand_container = Control.new()
	hand_container.name = "HandContainer"
	hand_container.mouse_filter = Control.MOUSE_FILTER_PASS
	hand_scroller.set_content(hand_container)


## Barra de baixo: palpite à esquerda, ações (ou o card de pote/prêmio, quando não há ação) no
## meio, relógio à direita. Os cards laterais têm `BAR_H`; o do meio, 75% disso.
func _build_bottom_bar(root: VBoxContainer) -> void:
	bottom_bar = HBoxContainer.new()
	bottom_bar.custom_minimum_size = Vector2(0, BAR_H)
	bottom_bar.add_theme_constant_override("separation", 10)
	root.add_child(bottom_bar)

	prog_card = StatCard.new().setup("PALPITE", "–", UIKit.TR_WHITE, 34)
	prog_card.custom_minimum_size = Vector2(LEFT_W, 0)
	bottom_bar.add_child(prog_card)

	var mid := VBoxContainer.new()
	bottom_mid = mid
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_END   # base alinhada com a dos cards laterais
	mid.add_theme_constant_override("separation", 4)
	bottom_bar.add_child(mid)
	status_label = UIKit.label("", 20, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.max_lines_visible = 2
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.visible = false   # a vez e as dicas aparecem na aba de avisos, em cima desta barra
	mid.add_child(status_label)
	_build_idle_card()
	mid.add_child(idle_card)
	bet_row = HBoxContainer.new()
	bet_row.add_theme_constant_override("separation", 6)
	bet_row.custom_minimum_size = Vector2(0, ACT_H)
	bet_row.visible = false
	mid.add_child(bet_row)
	double_btn = UIKit.action_button("DOBRAR", UIKit.ActionKind.GOLD, 24)
	double_btn.custom_minimum_size = Vector2(0, ACT_H)
	double_btn.visible = false
	double_btn.pressed.connect(_on_double_pressed)
	mid.add_child(double_btn)

	var tempo := StatCard.new().setup("TEMPO", "0:10", UIKit.TR_WHITE, 34)
	tempo.custom_minimum_size = Vector2(LEFT_W, 0)   # mesma largura do card PALPITE
	timer_label = tempo.value
	timer_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	bottom_bar.add_child(tempo)


## Card do meio, de largura total: PRÊMIO numa linha só, centralizado (só quando existe).
## Fica no lugar dos botões e some quando uma ação é pedida (ver `_refresh_idle_card`).
func _build_idle_card() -> void:
	var blue := UIKit.prize_blue()
	idle_card = PanelContainer.new()
	idle_card.custom_minimum_size = Vector2(0, ACT_H)
	idle_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	idle_card.add_theme_stylebox_override("panel", UIKit.rim_box(UIKit.TR_PURPLE_DARK.darkened(0.3), blue, blue.darkened(0.4), "small", 12, 12, 6))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	idle_card.add_child(row)
	var cap := UIKit.serif_label("PRÊMIO", 22, blue.lerp(UIKit.TR_WHITE, 0.25), HORIZONTAL_ALIGNMENT_CENTER)
	cap.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(cap)
	pot_prize_label = UIKit.label("◎ 0", 32, blue, HORIZONTAL_ALIGNMENT_CENTER)
	pot_prize_label.add_theme_font_size_override("font_size", 32)
	pot_prize_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(pot_prize_label)
	pot_prize_label.visible = false
	pot_prize_label.visibility_changed.connect(func(): cap.visible = pot_prize_label.visible; _refresh_idle_card())


## Card de pote/prêmio só quando ninguém está pedindo ação (botões, dobrar) nem rolando
## descarte/palpite.
func _refresh_idle_card() -> void:
	if idle_card == null:
		return
	var asking := (bet_row != null and bet_row.visible) or (double_btn != null and double_btn.visible)
	idle_card.visible = not asking and phase != "discard" and phase != "predict" and not chrome_discard and pot_prize_label.visible


func _is_wide() -> bool:
	var sz := get_viewport_rect().size
	return sz.x > sz.y


## 75% da viewport em tela larga; largura total no mobile.
func _max_ui_w() -> float:
	return get_viewport_rect().size.x * (0.75 if _is_wide() else 1.0)


## Escala da carta na mão (ver CardView.hand_scale): cheia no celular, ~410 de altura no PC.
func _hand_scale() -> float:
	return CardView.hand_scale(_is_wide(), get_viewport_rect().size.y)


## Escala da carta jogada na mesa (altura fixa por plataforma).
func _table_scale() -> float:
	return CardView.table_scale(_is_wide())


## Altura da faixa da mão: o maior leque possível (8 a 10 cartas) + o lift. Vem do tamanho REAL
## da carta exibida — nunca de constantes soltas.
func _hand_h() -> float:
	var cs := CardView.SIZE * _hand_scale()
	var avail_w := get_viewport_rect().size.x
	var h := 0.0
	for n in [8, 9, 10]:
		h = maxf(h, HandLayout.fan_height(n, avail_w, cs))
	return h + CardView.MAX_LIFT * _hand_scale() + 8.0


## Mão usa a largura total da viewport (quebra a limitação de _max_ui_w).
## Espaço embaixo da mão: card do modificador + folga + o quanto o leque desce. Crescer isto empurra
## o leque e a mesa pra cima, mantendo as folgas.
func _pot_h() -> float:
	return ModifierStrip.HEIGHT + MOD_GAP + _deck_drop()


## Referência do seu avatar, relativa ao topo da zona da mão.
func _card_offset_top() -> float:
	return BANNER_H + _deck_drop() - AVATAR_TO_FAN   # preso ao topo do leque: a folga não depende da altura da zona


## O leque desce 10% da altura da carta (as pontas passam por trás da barra de baixo).
func _deck_drop() -> float:
	return 0.1 * CardView.SIZE.y * _hand_scale()


func _update_hand_scroller_margins() -> void:
	if hand_scroller == null:
		return
	var vp_w := get_viewport_rect().size.x
	var side := maxf(float(Widgets.MARGIN), (vp_w - _max_ui_w()) / 2.0)
	hand_scroller.offset_left = -side
	hand_scroller.offset_right = side
	var hand_h := _hand_h()
	hand_scroller.offset_top = BANNER_H + _deck_drop()
	hand_scroller.offset_bottom = BANNER_H + hand_h + _deck_drop()
	if hand_zone != null:
		hand_zone.custom_minimum_size = Vector2(0, BANNER_H + hand_h + _pot_h())


## Em tela larga o jogo fica numa coluna centralizada (não estica).
func _apply_orientation() -> void:
	var max_w := _max_ui_w()
	var side := maxf(float(Widgets.MARGIN), (get_viewport_rect().size.x - max_w) / 2.0)
	margin_box.add_theme_constant_override("margin_left", int(side))
	margin_box.add_theme_constant_override("margin_right", int(side))
	_update_hand_scroller_margins()
	_refresh_hud()
	_layout_table()


func _on_resize() -> void:
	_apply_orientation()
	_layout_table()
	_layout_hand()


## Cor da moldura do avatar em repouso, por assento (você em dourado).
func _seat_accent(p: int) -> Color:
	match p:
		0:
			return UIKit.TR_GOLD
		1:
			return UIKit.TR_RED
		2:
			return UIKit.TR_BLUE.lightened(0.45)
		_:
			return UIKit.TR_RED_GLOW


## Assento = avatar hexagonal + plaquinha com o nome (ver SeatView). Rival: tocar no avatar ou no
## nome abre o card do stack; você: nome e stack sempre à vista. Selo de vitórias no vértice de
## baixo à esquerda do avatar e o D do dealer à direita. A posição vem de `_layout_seats`.
func _build_seat(p: int) -> SeatView:
	var seat := SeatView.new().setup(p, _seat_accent(p), p == 0)
	hud_titles[p] = seat.name_label
	hud_totals[p] = seat.stack_label
	seat_avatars[p] = seat.avatar
	order_badges[p] = seat.avatar.wins_badge
	dealer_badges[p] = seat.avatar.dealer_badge
	seat_nodes[p] = seat
	hud_badges[p] = seat
	if p == 0:
		seat.z_index = 50   # cruza o topo do card roxo e fica por cima do leque
	return seat


## Rivais em volta da mesa, com ângulos iguais entre si (o centro do avatar fica a ~12 px acima
## do ponto da borda); você no centro de baixo, com o avatar cruzando o topo do card roxo.
func _layout_seats() -> void:
	if table_center == null or stage == null:
		return
	var n := engine.num_players
	var card_top := stage.size.y + 8.0 + _card_offset_top()   # referência vertical do seu avatar (sem card visível), no sistema do palco
	if table_players == 0:
		table_players = n
	table_center.seat_count = table_players   # só muda no começo de uma rodada (`_lock_table_size`)
	table_center.seat_floor = card_top - 20.0
	table_center.my_seat_y = card_top - MY_SEAT_RISE
	table_center.fit()
	for p in range(n):
		var seat := seat_nodes[p] as SeatView
		if seat == null:
			continue
		seat.layout()
		var theta := TableEllipse.seat_angle(p, n)
		var pt := table_center.border_point(theta)
		seat.position = Vector2(pt.x - SeatView.W / 2.0, pt.y - SeatView.AVATAR_CENTER_Y)   # centro do avatar NA borda



## Reposiciona assentos e cartas da mesa (ex.: ao virar o celular).
func _layout_table() -> void:
	if table_center == null:
		return
	_layout_seats()
	for v in table_views:
		var cv: CardView = v["view"]
		cv.position = _slot_pos(int(v["player"]))


## A carta de cada jogador fica do lado do avatar dele (esquerda, topo, direita, você embaixo),
## agrupadas no centro e sobrepostas. A ordem de empilhar é a da jogada (sentido horário): a carta
## que vem depois cobre a anterior. Os lados ficam bem afastados e topo/base deslocados na
## vertical pra deixar o canto superior esquerdo de cada carta aparecendo.
func _slot_pos(player: int) -> Vector2:
	var theta := TableEllipse.seat_angle(player, engine.num_players)
	var ts := _table_scale()
	var off := Vector2(cos(theta) * CardView.SIZE.x * ts * 0.75, sin(theta) * CardView.SIZE.y * ts * 0.22)
	return table_center.center_point() + off - CardView.SIZE / 2.0


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
	var hs := _hand_scale()
	var card_sz := CardView.SIZE * hs
	for c in cards:
		(c as CardView).scale = Vector2(hs, hs)
	(parent as HandScroller).ghost_scale_mult = maxf(1.0, CardView.focus_scale(_is_wide(), get_viewport_rect().size.y) / hs)
	# Altura fixa da zona. NÃO usar parent.size.y — ScrollContainer com rolagem vertical
	# desligada cresce pra caber o conteúdo, criando um loop que empurra tudo pra ~800000 px.
	var zone_h := _hand_h()
	var avail_w := get_viewport_rect().size.x
	var content_w := HandLayout.apply(cards, avail_w, zone_h - HAND_RAISE, "fan", card_sz)
	(parent as HandScroller).set_content_size(Vector2(content_w, zone_h))


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
		cv.zoom_enabled = false
	_layout_hand.call_deferred()


func _plural(n: int, one: String, many: String) -> String:
	return "%d %s" % [n, one if n == 1 else many]


# ------------------------------------------------------------------ rodadas / modificador

## Tela de transição de início de rodada: só orienta (rodada, mesa) — o modificador de cada
## jogada é anunciado à parte, na hora, por `_trick_start()`.
## Começo de rodada: é o único momento em que o tamanho da mesa se ajusta ao nº de jogadores
## (durante as 8 jogadas ela não muda, mesmo que alguém saia).
## Ganchos pro multiplayer (hoje o nº de jogadores é fixo na partida): quem chega no meio de uma
## rodada só é avisado e fica de fora até a próxima; quem sai deixa o assento onde está até a
## rodada acabar. A mesa só se refaz em `_lock_table_size`, no começo da rodada seguinte.
func notify_player_joining(player_name: String) -> void:
	_banner("%s entra na próxima rodada" % player_name.capitalize(), "", UIKit.MUTED)


func notify_player_left(player_name: String) -> void:
	_banner("%s saiu" % player_name.capitalize(), "", UIKit.LOSS)


func _lock_table_size() -> void:
	table_players = engine.num_players
	_layout_table()


func _announce_round() -> void:
	_lock_table_size()
	if engine.blitz:
		_set_discard_chrome(true)
	_refresh_hud()
	_rebuild_hand()
	var kicker := "RODADA %d%s" % [engine.round_index + 1, (" DE %d" % engine.levels) if engine.levels > 0 else ""]
	var lines: Array = []
	if engine.round_index == 0 and engine.blitz:
		lines.append({"head": "MESA %s" % str(config.get("table_name", "")).to_upper(), "title": "ENTRADA ◎%d" % int(engine.blitz_entry()), "text": "Em cada rodada você palpita quantas jogadas vai ganhar e paga a entrada. Acertou o número exato, leva o pote. Cada jogada ainda paga fichas pelos pontos das cartas. Você senta com ◎%d e leva de volta o que tiver quando sair." % engine.buy_in, "color": UIKit.MONEY})
	elif engine.round_index == 0:
		lines.append({"head": "MESA %s" % str(config.get("table_name", "")).to_upper(), "title": "BLIND ◎%d" % engine.blind, "text": "Todo mundo paga o blind a cada jogada. Você senta com ◎%d e leva de volta o que tiver quando sair." % engine.buy_in, "color": UIKit.MONEY})
	else:
		lines.append({"head": "CARTAS NOVAS", "title": "RODADA %d" % (engine.round_index + 1), "text": "Mão nova, 8 jogadas — cada uma com o seu próprio modificador, anunciado antes de começar.", "color": UIKit.MODIFIER})
	var hold := 0.0 if (engine.round_index == 0 and engine.blitz and not first_round_done) else (2.6 if not first_round_done else 2.2)
	await _transition(kicker, lines, hold)
	first_round_done = true
	_banner_clear()


## Modificador da jogada na faixa fixa do topo (nome + efeito curto, cor pela função).
func _refresh_modifier_strip() -> void:
	var m := engine.modifier
	if m == -1 or chrome_discard:
		modifier_strip.show_modifier("", UIKit.TR_RED)
		return
	modifier_strip.show_modifier(_modifier_label(m).to_upper(), _modifier_color(m))


## Cor da faixa: perigo/perda em vermelho, o resto em dourado (tokens da paleta).
func _modifier_color(m: int) -> Color:
	return UIKit.TR_RED if ChaosModifiers.color_of(m) == UIKit.LOSS else UIKit.TR_GOLD


## Toque na faixa: explicação completa do modificador.
func _show_modifier_info() -> void:
	var m := engine.modifier
	if m == -1 or overlay_layer == null:
		return
	var tone := _modifier_color(m)
	var ov := UIKit.overlay()
	overlay_layer.add_child(ov)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UIKit.rim_box(UIKit.TR_PURPLE_DARK.darkened(0.2), tone.lightened(0.15), tone.darkened(0.3), "large", 16, 24, 22))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 120.0, 560.0), 0)
	box.add_child(v)
	var cap := UIKit.serif_label("MODIFICADOR DA RODADA", 18, UIKit.muted_lilac(), HORIZONTAL_ALIGNMENT_CENTER)
	cap.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(cap)
	var title := UIKit.serif_label(_modifier_label(m).to_upper(), 34, tone, HORIZONTAL_ALIGNMENT_CENTER)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title)
	var desc := UIKit.serif_label(ChaosModifiers.desc_of(m, engine.blitz), 26, UIKit.TR_WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	var hint := UIKit.serif_label("toque para fechar", 18, UIKit.muted_lilac(), HORIZONTAL_ALIGNMENT_CENTER)
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(hint)
	ov.add_child(UIKit.centered(box))
	UIKit.pop_in(box, GameState.anim(0.18))
	ov.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			ov.queue_free())


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


## Mensagem na aba em cima da barra de baixo. `color` pinta o título.
func _banner(title: String, sub: String, color: Color) -> void:
	var tone := _tone(color)
	banner_title.text = title
	banner_title.add_theme_color_override("font_color", tone)
	banner_title.modulate.a = 0.0
	create_tween().tween_property(banner_title, "modulate:a", 1.0, GameState.anim(0.12))


## Poucas cores, cada uma com um sentido (todas legíveis sobre o roxo escuro): ciano = sua vez,
## branco = neutro (passou, pagou, venceu), dourado = fichas subindo (aumentou, dobrou), vermelho =
## perda/erro (desistiu, tempo), laranja = efeito de modificador, verde = acerto.
func _tone(c: Color) -> Color:
	if c == UIKit.TURN:
		return UIKit.TR_CYAN
	if c == UIKit.LOSS or c == UIKit.DANGER:
		return UIKit.TR_RED_NEON
	if c == UIKit.MONEY or c == UIKit.ME:
		return UIKit.TR_GOLD
	if c == UIKit.COMBO:
		return UIKit.COMBO
	if c == UIKit.OK:
		return UIKit.OK
	return UIKit.TR_WHITE


## Nome pro aviso: "Você" ou o nome do rival (só a inicial maiúscula).
func _pname(p: int) -> String:
	return "Você" if p == 0 else str(config["names"][p]).capitalize()


func _banner_clear() -> void:
	# Sem aviso: volta o pote.
	banner_title.text = ""


# ------------------------------------------------------------------ loop de turnos

## Começo de jogada: se o modificador de jogada (surpresa) vale agora, revela numa tela cheia
## (surpresa) ou só na faixa (1ª/última, já conhecidas); deixa o aviso fixo durante a jogada.
## Começo de toda jogada: sorteia o modificador dessa vaza e explica em tela cheia, sem
## distração nenhuma por trás — só o conteúdo e a contagem até começar. Sempre acontece, nunca
## é surpresa: o jogador (e, no Blitz, o palpite) sempre sabe a regra antes de decidir.
func _trick_start() -> void:
	engine.draw_trick_modifier()
	if not is_inside_tree():
		return
	var m := engine.modifier
	if m == -1:
		# Defensivo: toda jogada de Blitz/Caos sorteia modificador, sem exceção — isto nunca
		# deveria disparar, mas evita travar a tela cheia se `modifier_sequence` vier vazio.
		_banner_clear()
		return
	var color := ChaosModifiers.color_of(m)
	await _modifier_transition(m, color)
	if is_inside_tree():
		_refresh_modifier_strip()
		_banner_clear()


## Sorteio do modificador da jogada: em vez de texto trocando sozinho, um item fechado carrega,
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
	var kicker := UIKit.label("JOGADA %d DE %d" % [engine.trick_number + 1, ChaosEngine.HAND_SIZE], 26, UIKit.ACTION, HORIZONTAL_ALIGNMENT_CENTER)
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
		await _tip("double", "PODE DOBRAR!", "A partir da 4ª jogada, o botão DOBRAR paga mais uma entrada e dobra o peso do seu palpite no pote; da 6ª em diante dá pra TRIPLICAR. Vale a pena quando você já está no alvo e a mão que sobrou é fraca demais pra ganhar mais uma jogada. Só dá pra dobrar até duas vezes por rodada.")
	var ls := TrickRules.lead_suit(engine.plays)
	if ls == -1:
		_banner("Sua vez", "", UIKit.TURN)
	elif ls == CardData.Suit.TRUNFO:
		_banner("Sua vez · jogue Trunfo", "", UIKit.TURN)
	else:
		_banner("Sua vez · siga %s" % CardData.SUIT_NAMES[ls], "", UIKit.TURN)
	_clock_start(TURN_SECONDS, _on_play_timeout)
	_rebuild_hand()
	var card: CardData = await human_card_chosen
	human_turn = false
	_clock_stop()
	_banner_clear()
	return card


func _on_play_timeout() -> void:
	var legal := engine.legal_for(0)
	if not human_turn or legal.is_empty():
		return
	var weakest: CardData = legal[0]
	for c in legal:
		if (c as CardData).points() < weakest.points():
			weakest = c
	human_turn = false
	_banner("Tempo esgotado", "", UIKit.LOSS)
	human_card_chosen.emit(weakest)


func _mmss(seconds: float) -> String:
	var t := maxi(int(ceil(seconds)), 0)
	return "%d:%02d" % [t / 60, t % 60]


## Relógio único da vez: liga com `_clock_start`, desliga com `_clock_stop`. O card TEMPO mostra os
## segundos (vermelho nos últimos 3). Pausa no menu; só os modais "de tela" (tips) também
## pausam, a menos que a etapa rode dentro de um modal (palpite, aposta: `in_modal`).
func _clock_start(seconds: float, on_timeout: Callable, in_modal: bool = false) -> void:
	clock_total = seconds
	clock_left = seconds
	clock_timeout = on_timeout
	clock_in_modal = in_modal
	clock_on = true


func _clock_stop() -> void:
	clock_on = false
	clock_timeout = Callable()


func _process(delta: float) -> void:
	if timer_label == null:
		return
	timer_label.modulate.a = 1.0 if clock_on else 0.35
	timer_label.text = _mmss(clock_left if clock_on else TURN_SECONDS)
	if not clock_on or paused or finished or (modal_open and not clock_in_modal):
		return
	clock_left -= delta
	var urgent := clock_left <= 3.0
	timer_label.add_theme_color_override("font_color", UIKit.LOSS if urgent else UIKit.TR_WHITE)
	if clock_left <= 0.0:
		var cb := clock_timeout
		_clock_stop()
		timer_label.add_theme_color_override("font_color", UIKit.TR_WHITE)
		if cb.is_valid():
			cb.call()


## Tocar fora das cartas cancela a seleção (a carta volta pra mão).
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or hand_container == null:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var any_selected := false
	for c in hand_container.get_children():
		var cv := c as CardView
		if cv.selected:
			any_selected = true
		if Rect2(Vector2.ZERO, cv.body.size).has_point(cv.body.get_global_transform().affine_inverse() * mb.global_position):
			return   # o toque é numa carta: quem trata é _on_card_tapped
	if not any_selected:
		return
	for c in hand_container.get_children():
		(c as CardView).set_selected(false)
	selected_view = null


func _on_card_tapped(view: CardView) -> void:
	if phase == "discard":
		_on_discard_tapped(view)
		return
	if not human_turn or not view.playable:
		if human_turn and not view.playable:
			_banner("Siga o naipe", "", UIKit.LOSS)
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
		if is_instance_valid(view):
			view.visible = true   # arrasto recusado: a carta volta pra mão em vez de sumir
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
	cv.global_position = from
	cv.scale = Vector2(0.9, 0.9)
	cv.rotation = randf_range(-0.25, 0.25)
	cv.z_index = table_views.size()   # a carta que vem depois (sentido horário) cobre a anterior
	table_views.append({"player": player, "view": cv})
	Sfx.play("card", randf_range(0.9, 1.15))
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(cv, "position", _slot_pos(player), GameState.anim(0.28))
	tw.parallel().tween_property(cv, "rotation", randf_range(-0.06, 0.06), GameState.anim(0.28))
	tw.parallel().tween_property(cv, "scale", Vector2(_table_scale(), _table_scale()), GameState.anim(0.28))
	_refresh_hud()
	await tw.finished


# ------------------------------------------------------------------ resumo de rodada / fim

# ------------------------------------------------------------------ ajuda / pausa

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
	var ph := UIKit.label("Toque numa carta para selecionar (ela sobe) e de novo para jogar, ou arraste-a pra cima e solte na mesa. Sair da mesa devolve suas fichas da stack pra carteira.", 28, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	ph.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(ph)
	paused = true
	ov.tree_exited.connect(func(): paused = false)
	var resume := UIKit.button("CONTINUAR")
	resume.pressed.connect(ov.queue_free)
	v.add_child(resume)
	var how := UIKit.button("COMO JOGAR", UIKit.BUTTON_MUTED)
	how.pressed.connect(_open_help)
	v.add_child(how)
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

# ------------------------------------------------------------------ loop de jogadas

func _run_round() -> void:
	if engine.blitz:
		if not await _blitz_open_level():
			return
	while not engine.is_round_over():
		if not is_inside_tree() or finished:
			return
		# Quebrou? No Blitz o check só acontece no início da rodada (_blitz_open_level);
		# mid-rodada o jogador fica "sentado fora" (sem apostas, mas ainda joga cartas).
		if engine.blitz:
			if engine.stacks[0] == 0.0 and not blitz_sitting_out:
				blitz_sitting_out = true
				_refresh_hud()
				_banner("Sem fichas", "", UIKit.MUTED)
				await _wait(2.0)
				if not is_inside_tree() or finished:
					return
		else:
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
			if bool(config.get("tournament", false)):
				await _bust_broke_bots()
			continue
		await _play_cards()
		if bool(config.get("tournament", false)):
			await _bust_broke_bots()
	if not is_inside_tree() or finished:
		return
	if engine.blitz:
		await _blitz_settlement()
		if bool(config.get("tournament", false)):
			await _bust_broke_bots()
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
		if engine.blitz and (p != 0 or GameState.autoplay) and ChaosBot.wants_double(engine, p, int(config["difficulty"][p]), bot_rng):
			if p != 0 and not GameState.autoplay:
				await _wait(bot_rng.randf_range(0.5, 1.0) * ChaosBot.style_delay_mult(engine, p))
				if not is_inside_tree() or finished:
					return
			await _apply_double(p)
			if not is_inside_tree() or finished:
				return
		var card: CardData
		if p == 0 and not GameState.autoplay and not blitz_sitting_out:
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
	_banner("%s entrou" % _pname(q), "", UIKit.MUTED)
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


## Torneio: marca bots com stack zero como eliminados e exibe banner por cada um.
## O jogador (p=0) é tratado por _ensure_solvent() — aqui só mostramos os bots.
func _bust_broke_bots() -> void:
	if not is_inside_tree() or finished:
		return
	for p in engine.bust_broke():
		if p == 0:
			continue
		_banner("%s eliminado" % _pname(p), "", UIKit.DANGER)
		_refresh_hud()
		await _wait(0.9)
		if not is_inside_tree() or finished:
			return


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
	_banner("Sua vez", "", UIKit.TURN)
	var st := {"raising": false, "to": int(opt["min_to"])}
	var done := func(result: Dictionary) -> void:
		st["result"] = result
		item_chosen.emit(1)
	var mk := func(text: String, kind: int, cb: Callable) -> Button:
		var b := UIKit.action_button(text, kind, 20)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, ACT_H)
		b.pressed.connect(cb)
		return b
	st["render"] = func():
		if st.has("picker") and is_instance_valid(st["picker"]):
			(st["picker"] as Node).queue_free()
			st.erase("picker")
		for c in bet_row.get_children():
			c.queue_free()
		if not can_check:
			bet_row.add_child(mk.call("DESISTIR", UIKit.ActionKind.DANGER, func(): done.call({"action": "fold"})))
		var main_txt := "PASSAR" if can_check else ("PAGAR\n◎%d%s" % [call_amt, "\nALL-IN" if all_in_call else ""])
		bet_row.add_child(mk.call(main_txt, UIKit.ActionKind.OK, func(): done.call({"action": "check" if can_check else "call"})))
		if bool(opt["can_raise"]):
			bet_row.add_child(mk.call("APOSTAR" if can_check else "AUMENTAR", UIKit.ActionKind.GOLD, func():
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
	_refresh_idle_card()
	(st["render"] as Callable).call()
	_clock_start(BET_SECONDS, func():
		done.call({"action": "check"} if can_check else {"action": "fold"}), true)   # estourou: passa, ou desiste se tem que pagar
	await item_chosen
	_clock_stop()
	modal_open = false
	bet_row.visible = false
	_refresh_idle_card()
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
		["ALL-IN" if float(hi) >= float(engine.stacks[0] + engine.contrib[0]) else "MÁX", hi],
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
	var mine_in := int(engine.contrib[0])   # o que você já pôs nesta jogada (ante e apostas anteriores)
	var num := UIKit.label("◎ %d" % (int(st["to"]) - mine_in), 52, UIKit.MONEY, HORIZONTAL_ALIGNMENT_CENTER)
	num.custom_minimum_size = Vector2(190, 0)
	row.add_child(num)
	var plus := UIKit.button("+", UIKit.MUTED, 40)
	plus.custom_minimum_size = Vector2(96, 72)
	plus.disabled = int(st["to"]) >= hi
	plus.pressed.connect(func():
		st["to"] = mini(int(st["to"]) + blind, hi)
		(st["render"] as Callable).call())
	row.add_child(plus)
	var total_l := UIKit.label("Você coloca ◎%d agora · total seu na jogada ◎%d (já pôs ◎%d)" % [int(st["to"]) - mine_in, int(st["to"]), mine_in], 18, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	total_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(total_l)
	var ok := UIKit.button("COLOCAR ◎%d" % (int(st["to"]) - mine_in) + (" (ALL-IN)" if int(st["to"]) >= hi and hi >= int(engine.stacks[0]) + mine_in else ""), UIKit.MONEY, 30)
	ok.pressed.connect(func(): done.call({"action": "raise", "to": float(st["to"])}))
	body.add_child(ok)
	var back := UIKit.button("VOLTAR", UIKit.MUTED, 26)
	back.custom_minimum_size = Vector2(0, 64)
	back.pressed.connect(func():
		st["raising"] = false
		(st["render"] as Callable).call())
	body.add_child(back)


# ------------------------------------------------------------------ pote

# ------------------------------------------------------------------ jogada resolvida

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
		FX.win_pulse(win_view, _table_scale())

	var pot_amt := float(result["pot"])
	var prize := float(result["prize"])
	var gain := float(result.get("gain", 0.0))
	if winner == 0 and gain > best_gain:
		best_gain = gain
	var wname := str(config["names"][winner]).to_upper()
	var notes: Array = []
	if int(result.get("modifier", -1)) == ChaosModifiers.Modifier.VAZA_DOURADA:
		notes.append("jogada dourada ×3")
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
		extras.append(["♨ SEQUÊNCIA ×%s!" % UIKit.fmt_dec(float(result.get("streak_mult", 1.0)), 2), "%s ganhou %d jogadas seguidas" % [wname, streak_n], FLAME])
	for id in result.get("combos", []):
		extras.append([str(ChaosModifiers.COMBO_NAMES[id]) + "!", "%s — %s" % [wname, ChaosModifiers.COMBO_DESCRIPTIONS[id]], UIKit.COMBO])
	if float(result.get("saque_amount", 0.0)) > 0.0:
		extras.append(["⚔ SAQUE!", "%s levou ◎%d dos rivais" % [wname, int(result["saque_amount"])], UIKit.LOSS])
	if float(result.get("assalto_amount", 0.0)) > 0.0:
		extras.append(["⚔ ASSALTO!", "%s roubou ◎%d de quem tinha mais fichas" % [wname, int(result["assalto_amount"])], UIKit.LOSS])
	if int(result.get("modifier", -1)) == ChaosModifiers.Modifier.VAZA_MALDITA:
		extras.append(["☠ JOGADA MALDITA!", "%s paga aos rivais por vencer essa jogada" % wname, UIKit.LOSS])
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


# ------------------------------------------------------------------ resumo de rodada / fim

## Resumo da rodada. Devolve "continue" ou "leave" (sair da mesa levando a stack).
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
	v.add_child(UIKit.label("FIM DA RODADA %d" % (int(r["round"]) + 1), 30, UIKit.BRAND, HORIZONTAL_ALIGNMENT_CENTER))
	var stacks: Array = r["stacks"]
	var deltas: Array = r["deltas"]
	# Saldo do próprio jogador, bem grande e com sinal, antes de qualquer outra coisa — o número
	# que mais importa pra saber "ganhei ou perdi essa rodada", sem precisar ler a lista toda.
	var my_delta := int(deltas[0])
	var saldo_color := UIKit.OK if my_delta >= 0 else UIKit.LOSS
	var saldo := UIKit.label("%s◎%d" % ["+" if my_delta >= 0 else "−", absi(my_delta)], 56, saldo_color, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(saldo)
	var saldo_cap := UIKit.label("SEU SALDO NESSA RODADA", 18, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(saldo_cap)
	v.add_child(HSeparator.new())
	var won: Array = r["tricks_won"]
	var order := range(engine.num_players)
	order.sort_custom(func(a: int, b: int) -> bool: return float(stacks[a]) > float(stacks[b]))
	for p in order:
		var d := int(deltas[p])
		var line := "%s%s  ◎%d  (%s◎%d)  ·  %d jogadas" % ["♛ " if p == order[0] else "", str(config["names"][p]).to_upper(), int(stacks[p]), "+" if d >= 0 else "−", absi(d), int(won[p])]
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
		var cl := UIKit.label("Ninguém acertou: ◎%d acumulam pra próxima rodada" % int(r["blitz"]["carry_out"]), 24, UIKit.MONEY, HORIZONTAL_ALIGNMENT_CENTER)
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(cl)
	var result := {"choice": "continue"}
	var next := UIKit.button("PRÓXIMA RODADA")
	next.pressed.connect(func(): item_chosen.emit(1))
	v.add_child(next)
	var profile := SaveManager.section("profile")
	# Completar até o buy-in da sala, com o que você tem de fichas fora da mesa.
	var cap := engine.buy_in
	var missing := mini(cap - int(engine.stacks[0]), int(profile["fichas"]))
	if missing >= engine.blind * 2:
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
	_clock_stop()
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
		var go := UIKit.button("PRÓXIMA RODADA", UIKit.OK)
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
	var stat := "%d jogadas na mesa · %d potes ganhos · %d blefes vencidos · %d desistências" % [engine.hand_no, int(st["pots"]), int(st["bluffs"]), int(st["folds"])]
	if engine.blitz:
		stat = "%d rodadas · %d palpites certos · %d por 1 de diferença" % [int(st["levels"]), int(st["hits"]), int(st["near"])]
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
	return "◎ %d" % int(v)


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
		var sitting: bool = p == 0 and blitz_sitting_out and phase != "idle"
		(hud_badges[p] as Control).modulate = Color(1, 1, 1, 0.3 if sitting else (0.45 if out else 1.0))
		(hud_titles[p] as Label).text = "VOCÊ" if p == 0 else str(config["names"][p]).to_upper()
		(hud_titles[p] as Label).add_theme_color_override("font_color", _turn_color if p == turn_player else UIKit.TR_WHITE)
		(dealer_badges[p] as Control).visible = engine.hand_no > 0 and engine.button == p
		var idx := order.find(p)
		var ob := order_badges[p] as PanelContainer
		ob.visible = p != 0
		if p != 0:
			var wl := ob.get_child(0) as Label
			wl.text = str(int(engine.wins[p]))
			var fill := UIKit.PURPLE_DEEP
			var edge := UIKit.MUTED
			var ink := UIKit.INK
			if blitz_showdown and engine.blitz:
				var hit := engine.blitz_status(p) == "hit"
				edge = UIKit.OK if hit else UIKit.LOSS
				fill = edge.darkened(0.6)
				ink = edge
			ob.add_theme_stylebox_override("panel", UIKit.box_cached(fill, edge, 3, 20, 0))
			wl.add_theme_color_override("font_color", ink)
			# Aposta da jogada embaixo do nome, enquanto as apostas rolam (depois voa pro pote).
			var pile_l := (seat_nodes[p] as SeatView).bet_label
			var pile := float(engine.contrib[p]) if phase == "bet" and not bets_gathered else 0.0
			pile_l.visible = pile > 0.0
			pile_l.text = "◎ %d" % int(pile)
			pile_l.add_theme_color_override("font_color", UIKit.LOSS if engine.folded[p] else UIKit.MONEY)
		_refresh_bet_tags(p, idx)
	round_dots.set_progress(ChaosEngine.HAND_SIZE, engine.trick_number)
	_refresh_modifier_strip()
	_refresh_pot()
	_update_turn_highlight(turn_player)
	_refresh_double_button()
	_refresh_idle_card()


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
	if bet_pills[p] == null or prog_tags[p] == null:
		return   # a mesa Blitz (única em uso) não tem essa linha de situação por assento
	var streak: int = engine.streak[p] if p < engine.streak.size() else 0
	var flames := ""
	if streak >= 2:
		flames = "%s×%s" % ["♨".repeat(ChaosCombos.flame_level(streak)), UIKit.fmt_dec(ChaosCombos.streak_mult(streak), 2)]
	var pile := float(engine.contrib[p]) if not bets_gathered and phase != "idle" else 0.0
	var pill := bet_pills[p] as Control
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
	if p != 0:
		return _seat_center(p)
	return _global_center(bet_pills[p] as Control)


func _chips_for(amount: float) -> int:
	return clampi(int(ceil(amount / float(engine.blind))), 1, 7)


func _update_turn_highlight(turn_player: int) -> void:
	turn_pulse_token += 1
	var my_token := turn_pulse_token
	for p in range(seat_avatars.size()):
		var avatar: HexAvatar = seat_avatars[p]
		var active := p == turn_player
		avatar.set_active(active)
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
			if blitz_sitting_out:
				# Sentado fora: checa se possível, desiste se alguém tiver apostado.
				var opt0 := engine.bet_options(0)
				act = {"action": "check"} if bool(opt0["can_check"]) else {"action": "fold"}
			else:
				var fold_tip := "Quem desiste descarta 1 carta aleatória da mão." if engine.blitz else "Quem desiste descarta a carta mais fraca, virada."
				await _tip("bet", "SUA VEZ DE APOSTAR", "Todo mundo já pagou a ante. Você pode PASSAR, AUMENTAR, PAGAR ou DESISTIR. Só quem fica na jogada joga carta, e quem vence leva o pote. %s" % fold_tip)
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


## Mostra o que cada um fez; as fichas ficam na frente do jogador até fechar a jogada de apostas.
func _show_bet_action(p: int, r: Dictionary) -> void:
	var pname := _pname(p)
	var amount := float(r.get("amount", 0.0))
	var title := ""
	var sub := ""
	var col := UIKit.MUTED
	match str(r.get("action", "")):
		"check":
			action_text[p] = "– PASSOU"
			title = "%s passou" % pname
		"call":
			action_text[p] = "✓ PAGOU"
			title = "%s pagou" % pname
			col = UIKit.INFO
		"raise":
			action_text[p] = "▲ AUMENTOU"
			title = "%s aumentou ◎%d" % [pname, int(r["to"])]
			col = UIKit.MONEY
		"fold":
			action_text[p] = "✕ DESISTIU"
			title = "%s desistiu" % pname
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
				FX.fly_chips(popup_layer, _pill_center(p), _global_center(bottom_mid), _chips_for(float(engine.contrib[p])), UIKit.LOSS if engine.folded[p] else UIKit.MONEY)
		if any:
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
	FX.fly_chips(popup_layer, _global_center(bottom_mid), seat_at, _chips_for(total), UIKit.OK if winner == 0 else UIKit.MONEY)
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
	_banner("%s levou o pote" % _pname(winner), "", UIKit.ME if winner == 0 else UIKit.INK)
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
## avatares com nome e stack, pra não confundir com informação de uma jogada que nem começou.
func _set_discard_chrome(active: bool) -> void:
	chrome_discard = active
	if active:
		pot_box.modulate.a = 0.0   # sem pote no descarte e no palpite; volta quando as entradas entram
	table_center.visible = not active
	for p in range(engine.num_players):
		(seat_nodes[p] as Control).visible = not active   # você também: todos entram juntos, depois do descarte
	for p in range(engine.num_players):
		if p == 0:
			(bet_pills[p] as Control).visible = not active
		(order_badges[p] as PanelContainer).visible = not active
		(dealer_badges[p] as PanelContainer).visible = not active


## Começo da rodada no Blitz: garante saldo, troca bots quebrados, coleta os palpites (o seu e os
## dos bots), revela todos juntos e joga as entradas no pote. Devolve false se a mesa acabou.
func _blitz_open_level() -> bool:
	_set_discard_chrome(true)   # antes de qualquer espera: a mesa não pisca na tela
	_reset_actions()
	hold_stacks = []
	hold_pot = -1.0
	blitz_sitting_out = false
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
	phase = "predict"
	bets_gathered = true
	pot_locked = true
	shown_pot = engine.carry
	pot_label.text = _pot_text(shown_pot)
	pot_box.modulate.a = 0.0   # só aparece depois do palpite, quando as entradas de verdade entram
	_refresh_hud()
	var pick: int
	if GameState.autoplay:
		pick = ChaosBot.blitz_pick(engine, 0, int(config["difficulty"][0]), bot_rng)
	else:
		await _tip("predict", "SEU PALPITE", "Toda rodada você diz quantas jogadas vai ganhar (de 0 a 8) e paga a entrada. Quem acertar o número exato leva o pote. Errou por 1? Recebe metade da entrada de volta. A estrela ★ marca o palpite que combina com a sua mão.")
		pick = await _human_predict()
		if not is_inside_tree() or finished:
			return false
	_set_discard_chrome(false)   # mesa e avatares só aparecem depois do lance
	_refresh_hud()
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
	pot_box.modulate.a = 1.0
	var running := engine.carry
	for p in range(engine.num_players):
		blitz_revealed[p] = true
		var stake := float(engine.stakes[p])
		running += stake
		if not GameState.autoplay:
			Sfx.play("chip")
			FX.fly_chips(popup_layer, _seat_center(p), _global_center(bottom_mid), _chips_for(stake))
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
	await _wait(0.8)


## Descarte inicial: sem popup — seleciona direto da própria mão, igual escolher carta pra jogar.
## Toca numa carta pra focar (ela sobe); toca de novo nela (ou arrasta pra cima e solta, igual
## jogar) pra descartar na hora, com animação — sem botão de confirmar, sem etapa extra.
func _human_discard_play() -> void:
	phase = "discard"
	discard_picks = []
	_rebuild_hand()
	discard_head.visible = true
	_banner_clear()
	status_label.text = "0/%d descartadas" % ChaosEngine.BLITZ_DISCARD_SIZE
	_clock_start(DISCARD_SECONDS, _on_discard_timeout)
	await item_chosen
	_clock_stop()
	discard_head.visible = false
	phase = "idle"   # cartas deixam de ser clicáveis/arrastáveis fora da vez
	status_label.text = ""
	discard_picks = []
	_banner_clear()
	_rebuild_hand()


func _on_discard_timeout() -> void:
	var auto: Array = ChaosBot.wants_discard(engine, 0, BotAI.Difficulty.NORMAL, bot_rng)
	engine.apply_discard(0, auto)
	_banner("Tempo esgotado", "", UIKit.LOSS)
	item_chosen.emit(1)


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
		_clock_stop()
		engine.apply_discard(0, discard_picks)
		item_chosen.emit(1)


## Card do palpite: claro, sem fundo escurecido — vira o próprio conteúdo do card da mesa
## (table_center), que está vazio nessa etapa (nem pote nem cartas ainda). A mão continua à
## vista e interagível embaixo. Seletor de
## quantidade em −/+ com o palpite sugerido em destaque, em vez de uma fileira de botões de 0 a 8.
func _human_predict() -> int:
	modal_open = true
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	stage.add_child(holder)
	var box := UIKit.panel(UIKit.SURFACE_DEEP, UIKit.BRAND, 20)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x * 0.8, 640.0), 0)
	holder.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	box.add_child(v)
	v.add_child(UIKit.label("QUANTAS JOGADAS VOCÊ VAI GANHAR?", 26, UIKit.BRAND, HORIZONTAL_ALIGNMENT_CENTER))
	var hint := ChaosBot.suggested_predict(engine, 0)
	var info := "Entrada ◎%d  ·  Pote ◎%d  ·  Sua mão: %s" % [int(engine.blitz_entry()), int(engine.carry), _hand_label_blitz()]
	var info_l := UIKit.label(info, 19, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	info_l.modulate.a = 1.0
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
		var count_l := UIKit.label(str(int(st["pick"])), 60, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
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
		var rec_l := UIKit.label("★ RECOMENDADO PELA SUA MÃO" if is_hint else "Recomendado pela sua mão: %d" % hint, 18, UIKit.OK if is_hint else UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		rec_l.modulate.a = 1.0
		body.add_child(rec_l)
		var w := ChaosEngine.blitz_weight(int(st["pick"]))
		var legend := UIKit.label("Peso do palpite no pote: ×%s   (0–2 ×1 · 3–4 ×1,5 · 5+ ×2)" % UIKit.fmt_dec(w, 1), 18, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		legend.modulate.a = 1.0
		legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(legend)
		var go := UIKit.button("CONFIRMAR: %d %s" % [int(st["pick"]), "JOGADA" if int(st["pick"]) == 1 else "JOGADAS"], UIKit.OK, 28)
		go.pressed.connect(func(): item_chosen.emit(1))
		body.add_child(go)
	(st["render"] as Callable).call()
	UIKit.pop_in(box, GameState.anim(0.15))
	Sfx.play("chip")
	_clock_start(PREDICT_SECONDS, func(): item_chosen.emit(1), true)   # estourou: vale o palpite da tela
	await item_chosen
	_clock_stop()
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
## na hora, sem esperar a jogada). Depois de um lance próprio (não de uma cobertura), oferece a
## janela de cobertura aos outros 3.
func _apply_double(p: int, is_cover := false) -> void:
	if not (engine.cover_double(p) if is_cover else engine.double_down(p)):
		return
	var amt := engine.blitz_entry()
	var verb := "COBRIU" if is_cover else ("TRIPLICOU" if int(engine.doubles[p]) == 2 else "DOBROU")
	action_text[p] = "▲ ×%d" % (1 + int(engine.doubles[p]))
	action_color[p] = UIKit.MONEY
	if not GameState.autoplay:
		_banner("%s %s" % [_pname(p), verb.to_lower()], "", UIKit.MONEY)
		Sfx.play("combo")
		FX.fly_chips(popup_layer, _seat_center(p), _global_center(bottom_mid), 3)
		FX.burst(popup_layer, _seat_center(p) - popup_layer.global_position, UIKit.MONEY, 14)
		FX.shake(main_area, 0.3)
		_pot_to(engine.pot)
	_refresh_hud()
	if not is_cover:
		await _offer_cover(p)
	if not GameState.autoplay:
		await _wait(0.9 if p != 0 else 0.5)


## Depois que `actor` dobra ou triplica, os outros 3 podem cobrir: pagar mais uma entrada pra
## igualar o peso dele no pote (custa um dos 2 lances da rodada de quem cobre). Bots decidem na
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
	_refresh_idle_card()
	if show:
		double_btn.text = "%s ◎%d" % ["TRIPLICAR" if int(engine.doubles[0]) == 1 else "DOBRAR", int(engine.blitz_entry())]


## Seu placar ao vivo e sua aposta. Fez/palpite fica no card do topo (verde no alvo, vermelho
## estourou ou sem tempo de chegar lá, neutro enquanto ainda dá). A aposta da jogada, no card
## ao lado do seu avatar, enquanto a jogada vale. Rivais: só o selo de vitórias do avatar — o
## alvo deles é segredo até o fim da rodada.
func _refresh_blitz_tag(p: int, _idx: int) -> void:
	if p != 0:
		return
	var pile := float(engine.contrib[0]) if (phase == "bet" and not bets_gathered) else 0.0   # some quando as apostas vão pro pote, igual aos rivais
	my_bet_pill.modulate.a = 1.0 if pile > 0.0 else 0.0
	my_bet_label.text = "◎ %d" % int(pile)
	my_bet_label.add_theme_color_override("font_color", UIKit.LOSS if engine.folded[0] else UIKit.MONEY)
	var val := prog_card.value
	if not bool(blitz_revealed[0]):
		val.text = "–"
		val.add_theme_color_override("font_color", UIKit.TR_WHITE)
		return
	var tag := " ×%d" % (1 + int(engine.doubles[0])) if int(engine.doubles[0]) > 0 else ""
	val.text = "%d/%d%s" % [int(engine.wins[0]), int(engine.predicts[0]), tag]
	var col := UIKit.TR_WHITE
	var need := engine.blitz_need(0)
	if need == 0:
		col = UIKit.OK
	elif need < 0 or need > engine.tricks_left():
		col = UIKit.LOSS
	val.add_theme_color_override("font_color", col)


func _refresh_pot_blitz() -> void:
	var in_trick := phase == "bet" or (phase == "play" and bets_gathered)
	if not pot_locked:
		if hold_pot >= 0.0:
			shown_pot = hold_pot
		elif in_trick:
			shown_pot = engine.trick_pot
		else:
			shown_pot = engine.pot if engine.pot > 0.0 else engine.carry
		pot_label.text = _pot_text(shown_pot)
	# Quando o trick_pot está em destaque, mostra o prêmio do palpite abaixo como secundário.
	if in_trick and engine.pot > 0.0:
		pot_prize_label.text = "◎ %d" % int(engine.pot)
		pot_prize_label.visible = true
	else:
		pot_prize_label.visible = false
	var sub := ""
	if phase == "bet":
		sub = "aposta da jogada"
	elif phase == "play" and bets_gathered:
		sub = "aposta da jogada"
	elif phase == "predict":
		sub = "quem acertar leva"
	elif phase == "play" and engine.carry > 0.0:
		sub = "inclui ◎ %d acumulado" % int(engine.carry)
	elif phase == "play":
		sub = "quem acertar leva"
	elif engine.carry > 0.0:
		sub = "acumulado pra próxima rodada"
	pot_sub.text = sub
	_layout_table.call_deferred()


## Fim de uma jogada no Blitz: a carta vencedora pulsa, o palpite de quem venceu sobe um e a
## faixa avisa se chegou no alvo ou estourou.
func _resolve_trick_blitz(result: Dictionary) -> void:
	var winner: int = result["winner"]
	var win_view: CardView
	for v in table_views:
		if int(v["player"]) == winner:
			win_view = v["view"]
	if engine.is_round_over() and not engine.blitz_result.is_empty():
		# A rodada acabou e o motor já liquidou o pote: a tela segura os números antigos até a animação.
		var br := engine.blitz_result
		hold_stacks = []
		for p in range(engine.num_players):
			hold_stacks.append(float(engine.stacks[p]) - float(br["payouts"][p]) - float(br["refunds"][p]) - (float(br["bonus"]) if p == 0 else 0.0))
		hold_pot = float(br["pool"]) + _sum(br["refunds"])
	await _wait(0.2)
	if not is_inside_tree():
		return
	if win_view:
		FX.win_pulse(win_view, _table_scale())
	var prize_amt := float(result.get("prize", 0.0))
	var saque_amt := float(result.get("saque_amount", 0.0))
	var assalto_amt := float(result.get("assalto_amount", 0.0))
	var curse_amt := float(result.get("curse_amount", 0.0))
	var trick_gain := float(result.get("trick_gain", 0.0))
	# Uma mensagem só por jogada: quem venceu e, se o modificador mexeu em fichas, o que ele fez.
	var title := "%s venceu" % _pname(winner)
	if saque_amt > 0.0:
		title = "%s roubou de todos" % _pname(winner)
	elif assalto_amt > 0.0 and int(result.get("assalto_from", -1)) >= 0:
		title = "%s roubou de %s" % [_pname(winner), _pname(int(result["assalto_from"]))]
	elif curse_amt > 0.0:
		title = "%s pagou aos rivais" % _pname(winner)
	var modified := saque_amt > 0.0 or assalto_amt > 0.0 or curse_amt > 0.0
	_banner(title, "", UIKit.COMBO if modified else (UIKit.OK if winner == 0 else UIKit.INK))
	Sfx.play("chip")
	FX.burst(popup_layer, _seat_center(winner) - popup_layer.global_position, UIKit.ME if winner == 0 else UIKit.CHIPS, 10)
	if float(result.get("trick_pot", 0.0)) > 0.0:
		FX.fly_chips(popup_layer, _global_center(bottom_mid), _seat_center(winner), _chips_for(float(result["trick_pot"])), UIKit.OK if winner == 0 else UIKit.MONEY)
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


## Resultado da rodada: quem acertou leva o pote (fichas voam até a stack), quem errou vê as
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
	var col := UIKit.MONEY
	if hits.is_empty():
		title = "Ninguém acertou"
		col = UIKit.COMBO
	else:
		var names: Array = hits.map(func(q): return _pname(int(q)))
		title = "%s acertou" % names[0] if names.size() == 1 else "Acertaram: %s" % " e ".join(names)
		col = UIKit.OK if hits.has(0) else UIKit.INK
	_banner(title, "", col)
	Sfx.play("win" if hits.has(0) else ("lose" if hits.is_empty() else "chip"))
	var pot_at := _global_center(bottom_mid)
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
		Sfx.play("jackpot")
		FX.chip_rain(popup_layer, 26)
		FX.float_text(popup_layer, _seat_center(0), "+◎ %d" % int(br["bonus"]), UIKit.MONEY, 44)
		FX.burst(popup_layer, _seat_center(0) - popup_layer.global_position, UIKit.MONEY, 22)
		await _wait(0.9)
	_pot_to(engine.carry)
	phase = "idle"
	_refresh_hud()
	await _wait(2.2)
