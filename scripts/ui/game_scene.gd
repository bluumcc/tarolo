extends Control
## GameScene.tscn — mesa de Tarot Vanilla (Clássico e Ranqueado usam a mesma mesa).
## Layout pensado pra celular (retrato): pilha vertical — status dos jogadores no topo,
## área de jogo compacta no meio, sua mão embaixo — em vez de uma mesa espalhada que só
## faz sentido em paisagem. Assentos: 0 = jogador, 1/2/3 = bots, em ordem de turno.

signal human_card_chosen(card: CardData)
signal human_bid_chosen(choice: int)
signal human_yesno_chosen(v: bool)
signal human_discard_chosen(cards: Array)
signal match_finished(summary: Dictionary)

const CARD_SCENE := preload("res://scenes/Card.tscn")

var engine := MatchEngine.new()
var config: Dictionary = {}
var bot_rng := RandomNumberGenerator.new()
var human_turn := false
var finished := false
var paused := false

const ARENA_SCALE := 0.66
const BID_SHORT := ["pega o monte", "vale o dobro", "monte conta pra você", "monte conta pra Defesa"]

var root_box: VBoxContainer
var hud_badges: Array = []       # painel de cada assento (0 = meu rodapé)
var hud_titles: Array = []       # Label — nome do jogador
var hud_points: Array = []       # Label — pontos capturados até agora (provisório)
var hud_tricks: Array = []       # Label — rodadas vencidas
var hud_cards: Array = []        # Label — contagem de cartas na mão (só bots)
var seat_avatars: Array = []     # painel de cada assento: destaca de quem é a vez e serve de origem das cartas
var seat_portraits: Array = []   # Portrait de cada assento
var seat_strip: BoxContainer
var main_area: BoxContainer     # coluna lateral + centro (lado a lado no PC, empilhados no celular)
var side_col: VBoxContainer
var center_col: VBoxContainer
var bidding_now := true
var bid_grid: GridContainer    # os 3 outros jogadores
var turn_pulse_token := 0        # invalida pulsos de destaque antigos quando a vez muda

var boss_panel: PanelContainer   # o Atacante como "chefe": retrato, contrato, vida
var boss_portrait: Portrait
var boss_name: Label
var boss_chip: Label
var boss_bar: MeterBar
var boss_bar_label: Label
var boss_bar_value: Label
var boss_meta: Label
var hold_boss := false           # segura a barra de vida até o "golpe" da rodada aparecer
var ticks: TrickTicks

var arena: Control               # a rodada atual: uma carta por assento, em cruz
var arena_tags: Array = []
var pot_label: Label
var pot_sub: Label
var table_views: Array = []

var bid_panel: VBoxContainer     # tela da licitação (some quando o Atacante é definido)
var bid_rows: Array = []
var bid_bubbles: Array = []      # Label de cada assento
var bid_bubble_boxes: Array = []
var bid_texts: Array = []
var bid_states: Array = []
var bid_buttons: Dictionary = {} # -1 = passar, 0..3 = contrato
var bid_msg: Label
var bid_waiting := false
var bid_base_text: Dictionary = {}
var hint_bar: MeterBar
var hint_strength: Label
var hint_suggest: Label
var hint_counts: Label

var my_portrait: Portrait
var hand_container: Control
var turn_hint: Label
var selected_view: CardView
var throw_from := Vector2.ZERO
var has_throw_from := false
var status_label: Label
var trick_label: Label           # resultado transitório da última rodada
var info_label: Label
var last_banner_done := false
var popup_layer: Control
var overlay_layer: Control

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
	_set_phase(true)
	get_viewport().size_changed.connect(_on_resize)
	_refresh_hud()
	_rebuild_hand()
	_banner.call_deferred("LICITAÇÃO", UIKit.GOLD)
	if tutorial:
		await _tutorial_modal("BEM-VINDO AO TUTORIAL", "Essa mão foi montada pra você aprender as regras principais. Antes de cada decisão nova tem uma explicação curta. Não tem pressa: a tela só avança quando você toca em ENTENDI.\n\nOlhe sua mão (embaixo da tela) e continue.")
		if not is_inside_tree():
			return
	await _run_bidding()
	if not is_inside_tree():
		return
	_set_phase(false)
	_update_taker_badge()
	_refresh_hud()
	await _show_intro()
	if is_inside_tree():
		_banner("DUELO!", UIKit.BOSS)
	if not is_inside_tree():
		return
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

## Faixa que cruza a tela e some sozinha (não trava o jogo): marca a mudança de fase.
func _banner(text: String, color: Color) -> void:
	if GameState.autoplay or not is_inside_tree():
		return
	var strip := ColorRect.new()
	strip.color = Color(0.04, 0.03, 0.06, 0.88)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_layer.add_child(strip)
	strip.size = Vector2(popup_layer.size.x, 120)
	strip.position = Vector2(0, popup_layer.size.y * 0.38)
	var l := UIKit.label(text, 52, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	strip.modulate.a = 0.0
	strip.scale = Vector2(1.0, 0.4)
	strip.pivot_offset = strip.size / 2.0
	var tw := create_tween()
	tw.tween_property(strip, "modulate:a", 1.0, GameState.anim(0.18))
	tw.parallel().tween_property(strip, "scale", Vector2.ONE, GameState.anim(0.18))
	tw.tween_interval(GameState.anim(0.7))
	tw.tween_property(strip, "modulate:a", 0.0, GameState.anim(0.25))
	tw.tween_callback(strip.queue_free)


func _build_ui() -> void:
	add_child(UIKit.background())

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	root_box = VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 6)
	margin.add_child(root_box)

	for arr in [hud_badges, hud_titles, hud_points, hud_tricks, hud_cards, seat_avatars, seat_portraits]:
		(arr as Array).resize(engine.num_players)

	_build_topbar()

	if tutorial:
		var tut_box := UIKit.panel(UIKit.OK.darkened(0.75), UIKit.OK, 10)
		tutorial_label = UIKit.label("", 16, UIKit.OK)
		tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tutorial_label.custom_minimum_size = Vector2(0, 0)
		tut_box.add_child(tutorial_label)
		root_box.add_child(tut_box)

	main_area = BoxContainer.new()
	main_area.vertical = true
	main_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_area.add_theme_constant_override("separation", 20)
	root_box.add_child(main_area)
	side_col = VBoxContainer.new()
	side_col.add_theme_constant_override("separation", 6)
	main_area.add_child(side_col)
	center_col = VBoxContainer.new()
	center_col.add_theme_constant_override("separation", 10)
	center_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_area.add_child(center_col)
	_build_boss_panel()
	ticks = TrickTicks.new()
	ticks.visible = false
	side_col.add_child(ticks)
	_build_seat_strip()
	_build_arena()
	_build_bid_panel()

	trick_label = UIKit.label("", 22, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	center_col.add_child(trick_label)
	status_label = UIKit.label("", 25, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center_col.add_child(status_label)

	# Mão — cartas sempre no tamanho real (nunca encolhidas pra caber); quando não cabem
	# todas na tela (mão cheia do Vanilla, até 18 cartas), a mão rola de lado. Duas
	# variantes (Configurações): fileira reta, ou leque em arco.
	var hand_scroll := HandScroller.new()
	hand_scroll.custom_minimum_size = Vector2(0, CardView.SIZE.y + CardView.MAX_LIFT + 6)
	root_box.add_child(hand_scroll)
	hand_scroll.resized.connect(_layout_hand)  # tamanho real só fica pronto depois do 1º sort — nunca confiar em call_deferred sozinho
	hand_container = Control.new()
	hand_container.name = "HandContainer"
	hand_container.mouse_filter = Control.MOUSE_FILTER_PASS
	hand_scroll.set_content(hand_container)

	_build_my_footer()

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

	_layout_table.call_deferred()
	_apply_orientation.call_deferred()


func _build_topbar() -> void:
	var topbar := HBoxContainer.new()
	topbar.add_theme_constant_override("separation", 8)
	root_box.add_child(topbar)
	var info_box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.BLACK, 8)
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label = UIKit.label("", 22, UIKit.INK)
	info_box.add_child(info_label)
	topbar.add_child(info_box)
	var help_btn := UIKit.button("?", UIKit.GOLD, 25)
	help_btn.custom_minimum_size = Vector2(52, 52)
	help_btn.pressed.connect(_open_help)
	topbar.add_child(help_btn)
	var menu_btn := UIKit.button("☰", UIKit.MUTED, 25)
	menu_btn.custom_minimum_size = Vector2(52, 52)
	menu_btn.pressed.connect(_open_pause)
	topbar.add_child(menu_btn)


## O Atacante vira o "chefe" do nível: quem joga sozinho contra os outros 3. A barra é a
## vida dele — os pontos que a Defesa ainda precisa somar pra derrubar o contrato. Se o
## Atacante é você, a mesma barra vira o progresso da sua meta.
func _build_boss_panel() -> void:
	boss_panel = UIKit.panel(Color(0.20, 0.07, 0.08, 0.9), UIKit.BOSS, 12)
	boss_panel.visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	boss_panel.add_child(row)
	boss_portrait = Portrait.new().setup(3, UIKit.BOSS, 84.0)
	row.add_child(boss_portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 5)
	row.add_child(col)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	col.add_child(name_row)
	boss_name = UIKit.label("", 35, UIKit.INK)
	name_row.add_child(boss_name)
	var chip := UIKit.panel(UIKit.BOSS, UIKit.BOSS, 4)
	boss_chip = UIKit.label("", 18, UIKit.BLACK)
	chip.add_child(boss_chip)
	name_row.add_child(chip)
	boss_bar = MeterBar.new()
	col.add_child(boss_bar)
	var lab_row := HBoxContainer.new()
	col.add_child(lab_row)
	boss_bar_label = UIKit.label("", 19, UIKit.MUTED)
	boss_bar_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab_row.add_child(boss_bar_label)
	boss_bar_value = UIKit.label("", 21, UIKit.INK)
	lab_row.add_child(boss_bar_value)
	boss_meta = UIKit.label("", 19, Color("#f0c7c2"))
	boss_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(boss_meta)
	side_col.add_child(boss_panel)


func _build_seat_strip() -> void:
	seat_strip = BoxContainer.new()
	seat_strip.add_theme_constant_override("separation", 8)
	seat_strip.visible = false
	side_col.add_child(seat_strip)
	for p in range(1, engine.num_players):
		var badge := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.MUTED, 8)
		badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		badge.add_child(row)
		var por := Portrait.new().setup(p, Color(0, 0, 0, 0), 50.0)
		row.add_child(por)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		row.add_child(col)
		var title_label := UIKit.label(str(config["names"][p]).to_upper(), 18, UIKit.MUTED)
		title_label.clip_text = true
		col.add_child(title_label)
		var pts := UIKit.label("0,0 pts", 28, UIKit.INK)
		col.add_child(pts)
		var sub := VBoxContainer.new()
		sub.add_theme_constant_override("separation", 0)
		col.add_child(sub)
		var tr := UIKit.label("0 rodadas", 15, UIKit.MUTED)
		sub.add_child(tr)
		var cards_label := UIKit.label("", 15, UIKit.MUTED)
		sub.add_child(cards_label)
		seat_strip.add_child(badge)
		hud_badges[p] = badge
		hud_titles[p] = title_label
		hud_points[p] = pts
		hud_tricks[p] = tr
		hud_cards[p] = cards_label
		seat_avatars[p] = badge
		seat_portraits[p] = por


## A rodada atual: uma carta por assento, em cruz (você embaixo). O total de pontos em jogo
## fica no meio, como o pote numa mesa de pôquer.
func _build_arena() -> void:
	arena = Control.new()
	arena.name = "Arena"
	arena.custom_minimum_size = Vector2(0, 380)
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena.visible = false
	arena.draw.connect(_draw_arena)
	arena.resized.connect(_layout_table)
	center_col.add_child(arena)
	var pot_box := VBoxContainer.new()
	pot_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pot_box.alignment = BoxContainer.ALIGNMENT_CENTER
	arena.add_child(pot_box)
	pot_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pot_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pot_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	pot_label = UIKit.label("", 42, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	pot_box.add_child(pot_label)
	pot_sub = UIKit.label("", 18, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	pot_box.add_child(pot_sub)
	arena_tags.resize(engine.num_players)
	for p in range(engine.num_players):
		var tag := UIKit.label(str(config["names"][p]).to_upper(), 20, UIKit.INK)
		arena.add_child(tag)
		tag.visible = false
		arena_tags[p] = tag


func _draw_arena() -> void:
	# Mesa oval, igual à do Caos: mesmo feltro e mesma borda, pra as duas telas parecerem
	# do mesmo jogo.
	var sb := UIKit.box(Color(0.10, 0.08, 0.30, 0.85), Color("#5B4FC9"), 3, 200, 0)
	arena.draw_style_box(sb, Rect2(Vector2.ZERO, arena.size))


## Tela da licitação: os 4 assentos em ordem, cada um com o que falou, e embaixo a escada
## de contratos (PASSAR + 4 lances) pra você escolher na sua vez.
func _build_bid_panel() -> void:
	bid_panel = VBoxContainer.new()
	bid_panel.add_theme_constant_override("separation", 12)
	bid_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_col.add_child(bid_panel)
	bid_panel.add_child(UIKit.label("QUEM JOGA SOZINHO?", 38, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var sub := UIKit.label("Quem dá o lance mais alto joga sozinho contra os outros três.", 21, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bid_panel.add_child(sub)
	bid_rows.resize(engine.num_players)
	bid_bubbles.resize(engine.num_players)
	bid_bubble_boxes.resize(engine.num_players)
	bid_texts.resize(engine.num_players)
	bid_states.resize(engine.num_players)
	var grid := GridContainer.new()
	bid_grid = grid
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	bid_panel.add_child(grid)
	for p in range(engine.num_players):
		var row := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.PURPLE, 8)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		row.add_child(h)
		h.add_child(Portrait.new().setup(p, UIKit.GOLD if p == 0 else Color(0, 0, 0, 0), 64.0))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 4)
		h.add_child(col)
		col.add_child(UIKit.label("Você" if p == 0 else str(config["names"][p]), 24, UIKit.INK))
		var bub_box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.PURPLE_DEEP, 6)
		var bub := UIKit.label("aguardando", 19, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		bub.clip_text = true
		bub_box.add_child(bub)
		col.add_child(bub_box)
		grid.add_child(row)
		bid_rows[p] = row
		bid_bubbles[p] = bub
		bid_bubble_boxes[p] = bub_box
	var ladder := VBoxContainer.new()
	ladder.add_theme_constant_override("separation", 6)
	bid_panel.add_child(ladder)
	var pass_btn := UIKit.button("PASSAR  ·  fica na Defesa", UIKit.MUTED, 22)
	pass_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	pass_btn.disabled = true
	pass_btn.pressed.connect(_on_bid_pressed.bind(-1))
	ladder.add_child(pass_btn)
	bid_buttons[-1] = pass_btn
	for c in range(4):
		var b := UIKit.button("%s ×%d  ·  %s" % [Scoring.CONTRACT_NAMES[c], Scoring.CONTRACT_MULT[c], BID_SHORT[c]], UIKit.GOLD, 22)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 60
		b.disabled = true
		b.pressed.connect(_on_bid_pressed.bind(c))
		ladder.add_child(b)
		bid_buttons[c] = b
		bid_base_text[c] = b.text
	bid_msg = UIKit.label("", 19, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	bid_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bid_panel.add_child(bid_msg)
	_build_hand_hint()
	_bid_reset()


## Dica da licitação: quão forte é a sua mão e qual contrato ela sugere, com os limiares
## de cada contrato marcados na barra. Sugestão, não regra: o lance é decisão sua.
func _build_hand_hint() -> void:
	var box := UIKit.panel(Color(0.10, 0.08, 0.14, 0.9), UIKit.GOLD.darkened(0.4), 8)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	box.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	hint_strength = UIKit.label("", 20, UIKit.INK)
	hint_strength.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(hint_strength)
	hint_suggest = UIKit.label("", 20, UIKit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	hint_suggest.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(hint_suggest)
	hint_bar = MeterBar.new()
	hint_bar.custom_minimum_size = Vector2(0, 14)
	hint_bar.set_colors(UIKit.GOLD, Color("#2b2413"))
	hint_bar.marks = [BotAI.STRENGTH_PETITE, BotAI.STRENGTH_GARDE, BotAI.STRENGTH_GARDE_SANS, BotAI.STRENGTH_GARDE_CONTRE]
	v.add_child(hint_bar)
	var bottom := HBoxContainer.new()
	v.add_child(bottom)
	hint_counts = UIKit.label("", 16, UIKit.MUTED)
	hint_counts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_counts.custom_minimum_size = Vector2(120, 0)
	hint_counts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(hint_counts)
	var what := UIKit.button("O QUE É BOUT?", UIKit.GOLD, 16)
	what.custom_minimum_size = Vector2(0, 56)
	what.pressed.connect(_open_bout_help)
	bottom.add_child(what)
	bid_panel.add_child(box)


func _refresh_hand_hint() -> void:
	var hand: Array = engine.hands[0]
	var strength := BotAI.hand_strength(hand)
	var bouts := 0
	var trunfos := 0
	var reis := 0
	for c in hand:
		var card: CardData = c
		if card.is_bout():
			bouts += 1
		if card.is_trunfo():
			trunfos += 1
		if not card.is_trunfo() and not card.is_louco() and card.rank == 14:
			reis += 1
	hint_strength.text = "SUA MÃO · força %s" % UIKit.fmt_dec(strength, 1)
	hint_bar.set_values(strength, 42.0, false)
	hint_counts.text = "Bouts %d/3 · Trunfos %d · Reis %d" % [bouts, trunfos, reis]
	_update_suggestion([])


## Sugestão de lance: o contrato que a força da mão pede; se ele já foi superado (ou a
## mão é fraca), passar. `opts` = contratos ainda disponíveis (vazio = só mostrar a sugestão).
func _update_suggestion(opts: Array) -> void:
	var rec := BotAI.recommended_contract(engine.hands[0])
	if not opts.is_empty() and rec != -1 and not opts.has(rec):
		rec = -1
	hint_suggest.text = "sugestão: %s" % ("PASSAR" if rec == -1 else str(Scoring.CONTRACT_NAMES[rec]).to_upper())
	for c in range(4):
		var b: Button = bid_buttons[c]
		b.text = bid_base_text[c] + ("   ★" if c == rec else "")


func _open_bout_help() -> void:
	var v := UIKit.modal(overlay_layer, "O QUE É BOUT?")
	var text := """Bout (lê-se "bu") é o nome das 3 cartas mais valiosas do jogo:
• Le Petit: o Trunfo 1
• Le Monde: o Trunfo 21
• O Louco

Cada Bout vale 4,5 pontos, o mesmo que um Rei. E mais: os Bouts que o Atacante captura baixam a meta dele. Com 0 Bouts ele precisa de 56 pontos, com 1 precisa de 51, com 2 de 41 e com 3 de 36.

Por isso, Bout na mão é um bom motivo pra licitar mais alto.

Cuidados:
• O Petit é fraco: qualquer trunfo maior o vence, então proteja-o.
• O Louco nunca vence uma rodada, mas quem o joga guarda os pontos dele.
• Bouts nunca podem ser devolvidos ao monte."""
	var l := UIKit.label(text, 18, UIKit.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(620, 0)
	v.add_child(l)
	UIKit.close_button(overlay_layer, v)


## Seu rodapé: retrato, pontos e, na sua vez, a dica de como jogar (tocar, tocar de novo).
func _build_my_footer() -> void:
	var my_box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.GOLD, 8)
	var my_row := HBoxContainer.new()
	my_row.add_theme_constant_override("separation", 14)
	my_box.add_child(my_row)
	my_portrait = Portrait.new().setup(0, UIKit.GOLD, 60.0)
	my_row.add_child(my_portrait)
	var my_left := VBoxContainer.new()
	my_left.add_theme_constant_override("separation", 0)
	my_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	my_row.add_child(my_left)
	var my_title := UIKit.label(str(config["names"][0]).to_upper(), 18, UIKit.MUTED)
	my_left.add_child(my_title)
	var my_pts := UIKit.label("0,0 pts", 32, UIKit.INK)
	my_left.add_child(my_pts)
	var my_tr := UIKit.label("0 rodadas", 16, UIKit.MUTED)
	my_left.add_child(my_tr)
	turn_hint = UIKit.label("Toque numa carta pra subir.\nToque de novo pra jogar.", 19, UIKit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	turn_hint.visible = false
	my_row.add_child(turn_hint)
	root_box.add_child(my_box)
	hud_badges[0] = my_box
	hud_titles[0] = my_title
	hud_points[0] = my_pts
	hud_tricks[0] = my_tr
	seat_avatars[0] = my_box
	seat_portraits[0] = my_portrait


## Licitação (true) x duelo (false): quem está visível em cada fase.
func _set_phase(bidding: bool) -> void:
	bidding_now = bidding
	if main_area != null:
		_apply_orientation()
	if is_inside_tree() and root_box.modulate.a > 0.5:
		root_box.modulate.a = 0.0
		create_tween().tween_property(root_box, "modulate:a", 1.0, GameState.anim(0.35))
	bid_panel.visible = bidding
	trick_label.visible = not bidding
	status_label.visible = not bidding
	seat_strip.visible = not bidding
	(hud_badges[0] as Control).visible = not bidding
	arena.visible = not bidding
	var duel := not bidding and engine.taker != -1
	boss_panel.visible = duel
	ticks.visible = duel


## Tela larga (PC): coluna do chefe/placar à esquerda e a mesa ao centro. Tela vertical
## (celular): tudo empilhado, como sempre foi.
func _is_wide() -> bool:
	var sz := get_viewport_rect().size
	return sz.x > sz.y


func _apply_orientation() -> void:
	if main_area == null:
		return
	var wide := _is_wide()
	main_area.vertical = not wide
	side_col.custom_minimum_size.x = 620.0 if wide else 0.0
	side_col.visible = not (wide and bidding_now)
	seat_strip.vertical = wide
	arena.custom_minimum_size.y = 340.0 if wide else 380.0
	for k in bid_buttons:
		(bid_buttons[k] as Button).custom_minimum_size.y = 46.0 if wide else 60.0
	bid_panel.add_theme_constant_override("separation", 8 if wide else 12)
	bid_panel.custom_minimum_size.x = 1000.0 if wide else 0.0
	bid_grid.columns = 4 if wide else 2
	bid_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if wide else Control.SIZE_FILL
	_layout_table()


func _on_resize() -> void:
	_apply_orientation()
	_layout_table()
	_layout_hand()


## Centro (no espaço da arena) da carta de cada assento: você embaixo, oeste, norte, leste.
func _side_offset() -> float:
	return clampf(arena.size.x * 0.3, 170.0, 380.0)


func _slot_center(player: int) -> Vector2:
	var s := arena.size
	var c := s / 2.0
	var half := CardView.SIZE * ARENA_SCALE / 2.0
	match player % 4:
		0:
			return Vector2(c.x, s.y - half.y - 4.0)
		1:
			return Vector2(c.x - _side_offset(), c.y)
		2:
			return Vector2(c.x, half.y + 4.0)
	return Vector2(c.x + _side_offset(), c.y)


func _slot_pos(player: int) -> Vector2:
	return _slot_center(player) - CardView.SIZE / 2.0


## Reposiciona as cartas já em jogo e os nomes quando a arena muda de tamanho.
func _layout_table() -> void:
	if arena == null or arena_tags.size() < engine.num_players:
		return
	for v in table_views:
		var cv: CardView = v["view"]
		cv.position = _slot_pos(int(v["player"]))
	var half := CardView.SIZE * ARENA_SCALE / 2.0
	for p in range(engine.num_players):
		var tag: Label = arena_tags[p]
		var ctr := _slot_center(p)
		match p % 4:
			0:
				tag.position = ctr + Vector2(-half.x - 10.0 - tag.size.x, half.y - tag.size.y)
			2:
				tag.position = ctr + Vector2(half.x + 10.0, -half.y)
			_:
				tag.position = ctr + Vector2(-half.x, half.y + 4.0)
	arena.queue_redraw()


## Encaixa a mão inteira na largura disponível, mesmo em celular: primeiro reduz o
## espaçamento até as cartas se sobreporem (efeito "leque"); se ainda faltar espaço
## As cartas nunca encolhem: com poucas cartas, um espaçamento normal e a mão centralizada;
## com muitas (mão cheia do Vanilla), sobrepõe em leque até um limite que ainda dá pra
## reconhecer cada carta — e se mesmo assim não couber, a rolagem horizontal cobre o resto.
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
	_layout_hand.call_deferred()


## Quem tem a vez agora, em qualquer fase (licitação, descarte ou rodada) — usado pra
## destacar o avatar certo na mesa, não só durante as rodadas.
func _current_turn_player() -> int:
	if not engine.bidding_done:
		return engine.bid_turn
	if engine.awaiting_discard:
		return engine.taker
	if engine.is_round_over():
		return -1
	return engine.current


func _refresh_hud() -> void:
	trick_label.visible = trick_label.text != "" and not bidding_now
	var trick_wins := []
	for p in range(engine.num_players):
		trick_wins.append(0)
	for t in engine.history:
		trick_wins[int(t["winner"])] += 1
	var turn_player := _current_turn_player()
	for p in range(engine.num_players):
		(hud_points[p] as Label).text = "%s pts" % UIKit.fmt_dec(engine.points_of(p), 1)
		(hud_tricks[p] as Label).text = "%d rodadas" % trick_wins[p]
		var turn := p == turn_player
		(hud_badges[p] as Control).modulate = Color(1, 1, 1, 1) if turn else Color(0.8, 0.78, 0.86, 1)
		if p > 0:
			(hud_cards[p] as Label).text = "%d cartas" % (engine.hands[p] as Array).size()
	_update_turn_highlight(turn_player)
	var mode_name: String = GameState.MODE_NAMES[GameState.mode]
	var extra := ""
	if GameState.mode == GameState.Mode.RANKED:
		var t := Ranked.tier_info(int(GameState.ranked()["points"]), int(GameState.ranked()["mmr"]))
		extra = "  ·  %s" % t["label"]
	var pot := 0.0
	for entry in engine.plays:
		pot += ((entry as Dictionary)["card"] as CardData).points()
	pot_label.text = UIKit.fmt_dec(pot, 1) if not engine.plays.is_empty() else ""
	pot_sub.text = "EM JOGO" if not engine.plays.is_empty() else ""
	if engine.taker == -1:
		info_label.text = "%s  ·  LICITAÇÃO" % mode_name.to_upper()
	else:
		var n := mini(engine.trick_number + 1, engine.total_tricks)
		if n == engine.total_tricks:
			info_label.text = "ÚLTIMA RODADA · fim da partida%s" % extra
		else:
			info_label.text = "RODADA %d DE %d%s" % [n, engine.total_tricks, extra]
		if not hold_boss:
			_refresh_boss(true)


## Números do duelo: a barra do chefe começa vazia e enche com os pontos que o Atacante
## captura, até a meta dele (que cai a cada Bout que ele pega). A Defesa joga pra segurar
## a barra. Se o Atacante é você, é a mesma barra: a sua meta.
func _boss_numbers() -> Dictionary:
	var t := engine.taker
	var bouts_now := 0
	for c in engine.captured[t]:
		if (c as CardData).is_bout():
			bouts_now += 1
	return {
		"target": Scoring.target_for_bouts(bouts_now),
		"current": engine.points_of(t),
	}


func _taker_display_name() -> String:
	return "Você" if engine.taker == 0 else str(config["names"][engine.taker])


func _refresh_boss(animate: bool = false) -> void:
	if engine.taker == -1:
		return
	var n := _boss_numbers()
	var mine := engine.taker == 0
	boss_panel.visible = arena.visible
	ticks.visible = arena.visible
	var winners: Array = []
	for t in engine.history:
		winners.append(1 if int(t["winner"]) == engine.taker else 0)
	ticks.set_state(engine.total_tricks, winners)
	boss_name.text = ("Você" if mine else str(config["names"][engine.taker])).to_upper()
	boss_chip.text = "%s ×%d" % [str(Scoring.CONTRACT_NAMES[engine.contract]).to_upper(), int(Scoring.CONTRACT_MULT[engine.contract])]
	boss_portrait.seat = engine.taker
	boss_portrait.queue_redraw()
	boss_bar.set_colors(UIKit.GOLD if mine else UIKit.BOSS, Color("#2b2413") if mine else Color("#2a1715"))
	boss_bar.set_values(minf(n["current"], n["target"]), n["target"], animate)
	boss_bar_label.text = "Sua meta" if mine else "Meta do chefe"
	boss_bar_value.text = "%s / %s pts" % [UIKit.fmt_dec(n["current"], 1), UIKit.fmt_dec(n["target"], 1)]
	var missing: float = maxf(0.0, n["target"] - n["current"])
	if missing <= 0.0:
		boss_meta.text = "Meta batida! O contrato está garantido." if not mine else "Meta batida!"
	elif mine:
		boss_meta.text = "Faltam %s pts pra sua meta." % UIKit.fmt_dec(missing, 1)
	else:
		boss_meta.text = "Faltam %s pts. Segure a barra!" % UIKit.fmt_dec(missing, 1)


## Destaca com borda dourada + pulso o assento de quem tem a vez agora (bots só — o
## jogador humano já vê a própria mão liberada quando é a vez dele).
func _update_turn_highlight(turn_player: int) -> void:
	turn_pulse_token += 1
	var my_token := turn_pulse_token
	for p in range(1, seat_avatars.size()):
		var avatar: PanelContainer = seat_avatars[p]
		var active := p == turn_player
		var base := UIKit.BOSS if p == engine.taker else UIKit.MUTED
		avatar.add_theme_stylebox_override("panel", UIKit.box(UIKit.PURPLE_DEEP, UIKit.GOLD if active else base, 4 if active else 2, 10, 8))
		if not active:
			avatar.scale = Vector2.ONE
	if turn_player > 0:
		_pulse_avatar(seat_avatars[turn_player], my_token)


func _pulse_avatar(avatar: PanelContainer, token: int) -> void:
	avatar.pivot_offset = avatar.size / 2.0
	while token == turn_pulse_token and is_inside_tree():
		var tw := create_tween()
		tw.tween_property(avatar, "scale", Vector2(1.06, 1.06), 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_property(avatar, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
		await tw.finished
		if not is_inside_tree():
			return


## Balão de texto curto acima do avatar de `player` (ou perto da mão, se for o humano) —
## dá pra ver ESPACIALMENTE quem fez o quê, em vez de um texto genérico no topo da tela.
func _speech_bubble(player: int, text: String) -> void:
	if not is_inside_tree():
		return
	var avatar: Control = seat_avatars[player]
	var anchor_pos: Vector2 = avatar.global_position - popup_layer.global_position + avatar.size / 2.0
	var l := UIKit.label(text, 20, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
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


## Depois da licitação: o Atacante ganha o destaque de chefe (borda vermelha no assento,
## nome vermelho na arena, retrato no painel do topo).
func _update_taker_badge() -> void:
	for p in range(engine.num_players):
		var is_taker := p == engine.taker
		var tag: Label = arena_tags[p]
		tag.text = ("♛ " if is_taker else "") + str(config["names"][p]).to_upper()
		tag.add_theme_color_override("font_color", UIKit.BOSS if is_taker else UIKit.MUTED)
		if p > 0:
			var title: Label = hud_titles[p]
			title.text = tag.text
			title.add_theme_color_override("font_color", UIKit.BOSS if is_taker else UIKit.MUTED)
	if engine.taker != -1:
		boss_portrait.set_ring(UIKit.GOLD if engine.taker == 0 else UIKit.BOSS)
		boss_panel.add_theme_stylebox_override("panel", UIKit.box(Color(0.24, 0.20, 0.08, 0.9) if engine.taker == 0 else Color(0.20, 0.07, 0.08, 0.9), UIKit.GOLD if engine.taker == 0 else UIKit.BOSS, 3, 12, 12))


# ------------------------------------------------------------------ licitação (tela)

func _bid_reset() -> void:
	for p in range(engine.num_players):
		bid_texts[p] = ""
		bid_states[p] = "idle"
		_set_bubble(p, "aguardando", "idle")
		(bid_rows[p] as PanelContainer).add_theme_stylebox_override("panel", UIKit.box(UIKit.PURPLE_DEEP, UIKit.PURPLE, 2, 10, 8))
	for k in bid_buttons:
		(bid_buttons[k] as Button).disabled = true
		(bid_buttons[k] as Button).modulate = Color.WHITE
	bid_msg.text = ""
	bid_waiting = false
	_refresh_hand_hint()


func _set_bubble(p: int, text: String, kind: String) -> void:
	var bg := UIKit.PURPLE_DEEP
	var fg := UIKit.MUTED
	match kind:
		"wait":
			fg = UIKit.GOLD
		"bid":
			bg = UIKit.GOLD
			fg = UIKit.BLACK
		"top":
			bg = UIKit.BOSS
			fg = UIKit.BLACK
		"beaten":
			fg = UIKit.MUTED.darkened(0.3)
	(bid_bubble_boxes[p] as PanelContainer).add_theme_stylebox_override("panel", UIKit.box(bg, bg, 0, 6, 6))
	var l: Label = bid_bubbles[p]
	l.text = text
	l.add_theme_color_override("font_color", fg)
	bid_states[p] = kind


func _bid_set_turn(p: int) -> void:
	for q in range(engine.num_players):
		(bid_rows[q] as PanelContainer).add_theme_stylebox_override("panel", UIKit.box(UIKit.PURPLE_DEEP, UIKit.GOLD if q == p else UIKit.PURPLE, 3 if q == p else 2, 10, 8))
	if bid_states[p] == "idle":
		_set_bubble(p, "SUA VEZ" if p == 0 else "pensando…", "wait")


func _on_bid_pressed(choice: int) -> void:
	if not bid_waiting:
		return
	bid_waiting = false
	for k in bid_buttons:
		(bid_buttons[k] as Button).disabled = true
	human_bid_chosen.emit(choice)


## Liga os botões da escada na sua vez: só os lances acima do atual (e PASSAR, exceto
## quando é obrigatório assumir um contrato). O lance atual fica marcado em vermelho.
func _enable_bid_ladder(opts: Array, forced: bool) -> void:
	bid_waiting = true
	_update_suggestion(opts)
	(bid_buttons[-1] as Button).disabled = forced
	for c in range(4):
		var b: Button = bid_buttons[c]
		b.disabled = not opts.has(c)
		var beaten := engine.highest_bid != -1 and c <= engine.highest_bid
		b.modulate = Color(1, 1, 1, 0.45) if beaten else Color.WHITE
		if c == engine.highest_bid:
			b.modulate = Color.WHITE
			b.add_theme_stylebox_override("disabled", UIKit.box(UIKit.PURPLE_DEEP, UIKit.BOSS, 3, 2, 10))
			b.add_theme_color_override("font_disabled_color", UIKit.INK)
	if forced:
		bid_msg.text = "Ninguém mais licitou. Você é obrigado a assumir um contrato."
	elif engine.highest_bid == -1:
		bid_msg.text = "Sua vez. Passe pra ficar na Defesa ou dê um lance."
	else:
		bid_msg.text = "%s cantou %s. Passe pra defender ou supere." % [config["names"][engine.highest_bidder], Scoring.CONTRACT_NAMES[engine.highest_bid]]


# ------------------------------------------------------------------ apresentação do chefe

## Antes do nível começar: quem é o chefe, o contrato, a vida dele e o time contra ele.
func _show_intro() -> void:
	if GameState.autoplay or engine.taker == -1:
		return
	var t := engine.taker
	var mine := t == 0
	var n := _boss_numbers()
	var ov := UIKit.overlay()
	ov.color = Color(0.04, 0.03, 0.06, 1.0)
	overlay_layer.add_child(ov)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size = Vector2(640, 0)
	v.add_child(UIKit.label("VOCÊ É O ATACANTE" if mine else "O CHEFE DO NÍVEL", 19, UIKit.GOLD if mine else UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var hero_box := CenterContainer.new()
	hero_box.add_child(Portrait.new().setup(t, UIKit.GOLD if mine else UIKit.BOSS, 220.0))
	v.add_child(hero_box)
	var seal_box := CenterContainer.new()
	var seal := UIKit.panel(UIKit.GOLD if mine else UIKit.BOSS, UIKit.GOLD if mine else UIKit.BOSS, 6)
	seal.add_child(UIKit.label("%s ×%d" % [str(Scoring.CONTRACT_NAMES[engine.contract]).to_upper(), int(Scoring.CONTRACT_MULT[engine.contract])], 20, UIKit.BLACK))
	seal_box.add_child(seal)
	v.add_child(seal_box)
	v.add_child(UIKit.label(_taker_display_name().to_upper(), 58, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("JOGA CONTRA OS OUTROS 3", 18, UIKit.GOLD if mine else UIKit.BOSS, HORIZONTAL_ALIGNMENT_CENTER))
	var bar := MeterBar.new()
	bar.custom_minimum_size = Vector2(0, 28)
	bar.set_colors(UIKit.GOLD if mine else UIKit.BOSS, Color("#2b2413") if mine else Color("#2a1715"))
	bar.set_values(0.0, n["target"], false)
	v.add_child(bar)
	var bar_row := HBoxContainer.new()
	var bl := UIKit.label("Sua meta" if mine else "Meta do chefe", 18, UIKit.MUTED)
	bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_row.add_child(bl)
	bar_row.add_child(UIKit.label("0,0 / %s pts" % UIKit.fmt_dec(n["target"], 1), 22, UIKit.INK))
	v.add_child(bar_row)
	var rule_text := ""
	if mine:
		rule_text = "Você precisa de %s pontos (a meta cai com cada Bout que você tiver). Encha a barra: se bater, cada um dos outros 3 te paga ×%d." % [UIKit.fmt_dec(n["target"], 1), int(Scoring.CONTRACT_MULT[engine.contract])]
	else:
		rule_text = "Precisa de %s pontos. A barra começa vazia e enche a cada rodada dele. Se a Defesa não deixar encher, o contrato cai e cada um da Defesa ganha ×%d." % [UIKit.fmt_dec(n["target"], 1), int(Scoring.CONTRACT_MULT[engine.contract])]
	var rl := UIKit.label(rule_text, 20, Color("#d6cbbb"), HORIZONTAL_ALIGNMENT_CENTER)
	rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(rl)
	v.add_child(UIKit.label("VS", 32, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var team := HBoxContainer.new()
	team.alignment = BoxContainer.ALIGNMENT_CENTER
	team.add_theme_constant_override("separation", 26)
	v.add_child(team)
	for p in range(engine.num_players):
		if p == t:
			continue
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		var pc := CenterContainer.new()
		pc.add_child(Portrait.new().setup(p, UIKit.GOLD if p == 0 else UIKit.DEF, 84.0))
		col.add_child(pc)
		col.add_child(UIKit.label("Você" if p == 0 else str(config["names"][p]), 20, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
		col.add_child(UIKit.label("DEFESA", 14, UIKit.DEF, HORIZONTAL_ALIGNMENT_CENTER))
		team.add_child(col)
	var btn := UIKit.button("COMEÇAR O NÍVEL", UIKit.GOLD, 28)
	btn.custom_minimum_size = Vector2(0, 64)
	v.add_child(btn)
	ov.add_child(UIKit.centered(v))
	btn.grab_focus.call_deferred()
	await btn.pressed
	if is_inside_tree():
		ov.queue_free()


# ------------------------------------------------------------------ licitação

func _run_bidding() -> void:
	if tutorial:
		await _tutorial_modal("COMO FUNCIONA A LICITAÇÃO", "Todo nível começa com a licitação: cada jogador, em ordem, diz se quer jogar sozinho contra os outros 3.\n\nQuem joga sozinho é o ATACANTE (o ataque). Os outros 3 formam a DEFESA.\n\nNa sua vez, você PASSA ou dá um LANCE mais alto que o anterior. O lance não custa nada: é só dizer que você confia na sua mão.\n\nO lance mais alto vira o Atacante. Cada contrato tem uma explicação curta do risco dele.")
		if not is_inside_tree():
			return
	while true:
		while not engine.bidding_done:
			if not is_inside_tree():
				return
			var p := engine.bid_turn
			_refresh_hud()
			_bid_set_turn(p)
			var choice: int
			if p == 0 and not GameState.autoplay:
				choice = await _wait_human_bid()
			else:
				status_label.text = "%s está decidindo..." % config["names"][p] if p != 0 else "Autoplay..."
				await _wait(bot_rng.randf_range(0.8, 1.4) if not tutorial else 1.0)
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
				await _tutorial_modal("TODOS PASSARAM", "Se ninguém der lance, a mão é anulada e as cartas são distribuídas de novo. Não conta como nível. Vai acontecer agora.")
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
			_bid_reset()
			continue
		break
	status_label.text = "%s é o Atacante! Contrato: %s" % [config["names"][engine.taker], Scoring.CONTRACT_NAMES[engine.contract]]
	trick_label.text = ""
	if tutorial:
		if engine.taker == 0:
			await _tutorial_modal("VOCÊ É O ATAQUE (ATACANTE)", "Você deu o maior lance: %s. %s\n\nAgora você joga sozinho contra os outros 3 (a Defesa). No fim, somam-se os pontos das cartas que você ganhou nas rodadas (e do monte, dependendo do contrato). Se chegar na meta, você ganha pontos dos outros 3. Se não chegar, você paga." % [Scoring.CONTRACT_NAMES[engine.contract], Scoring.CONTRACT_HINTS[engine.contract]])
		else:
			await _tutorial_modal("VOCÊ É DA DEFESA", "%s deu o maior lance (%s) e é o ATACANTE: joga sozinho contra os outros 3, incluindo você.\n\nVocê e mais 2 jogadores são a DEFESA. Os pontos que vocês ganharem nas rodadas ajudam a impedir %s de chegar na meta. Se ele não chegar, a Defesa ganha pontos. Se chegar, a Defesa paga." % [config["names"][engine.taker], Scoring.CONTRACT_NAMES[engine.contract], config["names"][engine.taker]])
		if not is_inside_tree():
			return
	else:
		await _wait(1.1)


func _announce_bid(player: int, choice: int) -> void:
	if choice == -1:
		bid_texts[player] = "PASSA"
		_set_bubble(player, "PASSA", "pass")
		bid_msg.text = "%s passou." % config["names"][player]
	else:
		for q in range(engine.num_players):
			if q != player and bid_states[q] == "top":
				_set_bubble(q, "%s (superado)" % bid_texts[q], "beaten")
		bid_texts[player] = "%s ×%d" % [str(Scoring.CONTRACT_NAMES[choice]).to_upper(), int(Scoring.CONTRACT_MULT[choice])]
		_set_bubble(player, bid_texts[player], "top")
		bid_msg.text = "%s deu %s." % [config["names"][player], Scoring.CONTRACT_NAMES[choice]]
	Sfx.play("tick")


func _wait_human_bid() -> int:
	var opts := engine.bid_options(0)
	var forced := engine.is_bidding_forced(0)
	status_label.text = ""
	_enable_bid_ladder(opts, forced)
	var choice: int = await human_bid_chosen
	return choice


# ------------------------------------------------------------------ descarte (écart)

## Petite/Garde: o atacante escolhe (de verdade) quais 6 cartas devolve pro talão —
## nunca automático. Garde Sans/Garde Contre nem passam por aqui (`awaiting_discard`
## fica falso pra esses contratos, já que o talão nem entra na mão do atacante).
func _run_discard() -> void:
	if not engine.awaiting_discard:
		return
	if engine.taker == 0 and not GameState.autoplay:
		if tutorial:
			await _tutorial_modal("O MONTE ENTROU NA SUA MÃO", "O monte são 6 cartas viradas no meio da mesa, que ninguém vê até a licitação acabar. Com %s, elas entraram na sua mão. Na próxima tela, as marcadas como \"monte\" são essas 6.\n\nAgora escolha 6 cartas da sua mão pra devolver. Os pontos delas ficam com você no final. Reis e Bouts não podem ser devolvidos." % Scoring.CONTRACT_NAMES[engine.contract])
			if not is_inside_tree():
				return
		var chosen: Array = await _wait_human_discard()
		if not is_inside_tree():
			return
		engine.discard(chosen)
	else:
		status_label.text = "%s está escolhendo 6 cartas pra devolver ao monte..." % config["names"][engine.taker]
		await _wait(0.5)
		if not is_inside_tree():
			return
		var legal := engine.legal_discards(engine.hands[engine.taker])
		var chosen: Array = BotAI.choose_discard(legal, Deck.CHIEN_SIZE) if int(config["difficulty"][engine.taker]) == BotAI.Difficulty.EASY else BotStrategy.choose_discard(engine.hands[engine.taker], legal, Deck.CHIEN_SIZE)
		engine.discard(chosen)


## Explica o talão pros casos que não passam pela tela de descarte: quando um bot é o
## Atacante (ele decide sozinho, sem mostrar tela), ou quando o contrato é Garde Sans/
## Garde Contre (o talão nem chega a entrar na mão de ninguém pra escolher).
func _run_talao_reveal() -> void:
	if not tutorial or engine.taker == -1:
		return
	match engine.contract:
		Scoring.Contract.PETITE, Scoring.Contract.GARDE:
			if engine.taker != 0:
				await _tutorial_modal("O MONTE (ESCOLHA DO BOT)", "%s é o Atacante, então pegou o monte (6 cartas), olhou e devolveu 6 da mão dele. Você não vê essa escolha." % config["names"][engine.taker])
		Scoring.Contract.GARDE_SANS:
			await _tutorial_modal("O MONTE (GARDE SANS)", "Com Garde Sans, %s não pegou o monte nem viu as 6 cartas. Mesmo assim, os pontos delas contam pro Atacante: %s." % [config["names"][engine.taker], _describe_cards(engine.chien)])
		Scoring.Contract.GARDE_CONTRE:
			await _tutorial_modal("O MONTE (GARDE CONTRE)", "Com Garde Contre, %s não pegou o monte nem viu as 6 cartas. Dessa vez os pontos delas vão pra Defesa: %s." % [config["names"][engine.taker], _describe_cards(engine.chien)])


func _wait_human_discard() -> Array:
	var hand: Array = engine.hands[0]
	var legal: Array = engine.legal_discards(hand)
	status_label.text = "Escolha 6 cartas da sua mão pra devolver ao monte"
	var selected: Array = []
	var panel := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.GOLD, 14)
	panel.name = "DiscardPrompt"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(UIKit.label("DEVOLVA 6 CARTAS AO MONTE", 19, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var sub_hint := "Elas contam como pontos seus no final. Reis e Bouts (em cinza) não podem ir."
	if tutorial:
		sub_hint += " As marcadas \"monte\" são as 6 que acabaram de entrar na sua mão."
	v.add_child(UIKit.label(sub_hint, 14, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var counter := UIKit.label("0 / %d selecionadas" % Deck.CHIEN_SIZE, 15, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(counter)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	flow.custom_minimum_size = Vector2(420, 0)
	v.add_child(flow)
	var confirm := UIKit.button("CONFIRMAR", UIKit.GOLD, 18)
	confirm.disabled = true
	var chien_ref: Array = engine.chien
	for c in hand:
		var card: CardData = c
		var is_legal: bool = (legal as Array).any(func(l: CardData) -> bool: return l.equals(card))
		var from_chien: bool = tutorial and (chien_ref as Array).any(func(l: CardData) -> bool: return l.equals(card))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		var b := UIKit.button("%s%s" % [card.rank_label(), card.suit_symbol()], UIKit.GOLD if is_legal else UIKit.MUTED, 16)
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
			col.add_child(UIKit.label("monte", 14, UIKit.OK, HORIZONTAL_ALIGNMENT_CENTER))
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

## Depois da licitação, o Atacante escolhe se declara Poignée (se elegível) e se anuncia
## Chelem — as duas são apostas estratégicas dele, não bônus automáticos.
func _run_declarations() -> void:
	if engine.taker == -1:
		return
	var eligible := engine.poignee_eligible()
	if engine.taker == 0 and not GameState.autoplay:
		if eligible:
			var bonus := int(Scoring.poignee_bonus(engine.taker_trump_count))
			var declare: bool = await _ask_yes_no("MOSTRAR OS TRUNFOS?", "Você tem %d trunfos. Se mostrar (Poignée), ganha +%d pontos no fim, mas os outros veem seus trunfos. Mostrar?" % [engine.taker_trump_count, bonus])
			if not is_inside_tree():
				return
			engine.declare_poignee(declare)
			if declare:
				_announce_toast("Você mostrou os trunfos (Poignée)! +%d se fechar o nível" % bonus)
				_speech_bubble(0, "Poignée!")
				await _wait(0.6)
		var chelem: bool = await _ask_yes_no("CHELEM: GANHAR TODAS AS RODADAS?", "Quer avisar que vai ganhar as 18 rodadas? Se conseguir: +400. Se falhar: -200. Sem avisar, se ganhar todas mesmo assim: +200, sem risco.")
		if not is_inside_tree():
			return
		engine.announce_chelem(chelem)
		if chelem:
			_announce_toast("Você avisou Chelem! Ganhe as 18 rodadas pro bônus.")
			_speech_bubble(0, "Chelem!")
			await _wait(0.6)
	else:
		var strength := BotAI.hand_strength(engine.hands[engine.taker])
		if eligible and BotAI.decide_poignee(engine.taker_trump_count):
			engine.declare_poignee(true)
			_announce_toast("%s mostrou os trunfos (Poignée)!" % config["names"][engine.taker])
			_speech_bubble(engine.taker, "Poignée!")
			await _wait(0.6)
			if not is_inside_tree():
				return
		if BotAI.decide_chelem(strength, int(config["difficulty"][engine.taker]), bot_rng):
			engine.announce_chelem(true)
			_announce_toast("%s avisou Chelem: vai tentar ganhar as 18 rodadas!" % config["names"][engine.taker])
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
	v.add_child(UIKit.label(title, 40, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var body_label := UIKit.label(body, 32, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size = Vector2(620, 0)
	v.add_child(body_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var no_btn := UIKit.button("NÃO", UIKit.MUTED, 18)
	no_btn.pressed.connect(func():
		panel.queue_free()
		human_yesno_chosen.emit(false))
	row.add_child(no_btn)
	var yes_btn := UIKit.button("SIM", UIKit.GOLD, 18)
	yes_btn.pressed.connect(func():
		panel.queue_free()
		human_yesno_chosen.emit(true))
	row.add_child(yes_btn)
	popup_layer.add_child(panel)
	UIKit.boost.call_deferred(panel)
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
		if engine.plays.is_empty() and engine.trick_number == engine.total_tricks - 1 and not last_banner_done:
			last_banner_done = true
			_banner("ÚLTIMA RODADA", UIKit.GOLD)
		var card: CardData
		if p == 0 and not GameState.autoplay:
			card = await _wait_human()
		else:
			status_label.text = "%s está pensando…" % config["names"][p] if p != 0 else "Autoplay..."
			await _wait(_think_time(p))
			if not is_inside_tree():
				return
			card = _bot_card(p)
		if card == null or not is_inside_tree():
			return
		var from := _source_position(p, card)
		var res := engine.play(p, card)
		if not res.get("ok", false):
			push_warning("Jogada rejeitada: %s" % res.get("error"))
			continue
		if res["trick_complete"]:
			hold_boss = true
		if p == 0:
			_rebuild_hand()
		await _animate_play(p, card, from)
		if res["trick_complete"]:
			await _resolve_trick(res["result"])
	if is_inside_tree():
		_finish_match()


## Carta do bot conforme a dificuldade: Fácil joga a regra simples (ganhar a rodada, senão a
## carta mais fraca, sem ajudar ninguém); Normal e Difícil jogam de forma estratégica
## (ver BotStrategy).
func _bot_card(p: int) -> CardData:
	var diff := int(config["difficulty"][p])
	if diff == BotAI.Difficulty.EASY:
		return BotAI.choose(engine.hands[p], engine.plays, p, engine.num_players, BotAI.Difficulty.NORMAL, bot_rng)
	return BotStrategy.choose(engine, p, diff, bot_rng)


## Quanto um bot "pensa" antes de jogar: um tempinho variável, pra dar pra acompanhar a
## mesa (e sentir que tem alguém do outro lado). Você mesmo (autoplay) joga rápido.
func _think_time(p: int) -> float:
	if p == 0:
		return 0.25
	return bot_rng.randf_range(0.9, 1.5)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(GameState.anim(seconds)).timeout
	while paused and is_inside_tree():
		await get_tree().create_timer(0.1).timeout


func _tutorial_hint(text: String) -> void:
	if not tutorial or tutorial_label == null:
		return
	tutorial_label.text = "✦ " + text


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
	var l := UIKit.label(body, 32, UIKit.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(620, 0)
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
		status_label.text = "Sua vez — abra a rodada"
	elif ls == CardData.Suit.TRUNFO:
		status_label.text = "Sua vez — precisa cobrir com Trunfo maior, se tiver"
	else:
		status_label.text = "Sua vez — siga %s (ou corte com Trunfo, ou jogue O Louco)" % CardData.SUIT_NAMES[ls]
	if tutorial:
		_check_tutorial_trick_hints(ls)
	_rebuild_hand()
	turn_hint.visible = true
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
			_tutorial_once("forced_trunfo", "Você não tem mais %s, então tem que jogar um Trunfo (ou O Louco). Isso se chama cortar." % CardData.SUIT_NAMES[ls])
			return
	var hand_trunfos := (hand as Array).filter(func(c: CardData) -> bool: return c.is_trunfo()).size()
	var legal_trunfos := (legal as Array).filter(func(c: CardData) -> bool: return c.is_trunfo()).size()
	if hand_trunfos > legal_trunfos and legal_trunfos > 0:
		_tutorial_once("forced_cover", "Já tem um Trunfo na mesa e você tem um maior, então só os Trunfos maiores podem ser jogados.")
		return
	for c in hand:
		if (c as CardData).is_louco():
			_tutorial_once("louco", "Você tem O Louco. Pode jogá-lo quando quiser: ele nunca ganha a rodada, mas você fica com ele e com os 4,5 pontos dele (só na última rodada ele vai pra quem ganhar).")
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
	turn_hint.visible = false
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
	return avatar.global_position + avatar.size / 2.0 - CardView.SIZE / 2.0


func _animate_play(player: int, card: CardData, from: Vector2) -> void:
	var cv: CardView = CARD_SCENE.instantiate()
	cv.setup(card, true)
	cv.interactive = false
	arena.add_child(cv)
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
	tw.parallel().tween_property(cv, "scale", Vector2(ARENA_SCALE, ARENA_SCALE), GameState.anim(0.28))
	_refresh_hud()
	await tw.finished


func _resolve_trick(result: Dictionary) -> void:
	var winner: int = result["winner"]
	var points: float = result["points"]
	var win_view: CardView
	for v in table_views:
		if int(v["player"]) == winner:
			win_view = v["view"]
	await _wait(0.5)
	if not is_inside_tree():
		return
	if win_view:
		win_view.z_index = 5
		var pulse := create_tween()
		pulse.tween_property(win_view, "scale", Vector2(ARENA_SCALE, ARENA_SCALE) * 1.18, GameState.anim(0.12))
		pulse.tween_property(win_view, "scale", Vector2(ARENA_SCALE, ARENA_SCALE) * 1.08, GameState.anim(0.12))

	trick_label.text = "%s venceu a rodada · +%s pts" % [str(config["names"][winner]).to_upper(), UIKit.fmt_dec(points, 1)]
	Sfx.play("chip")

	if tutorial and engine.is_round_over():
		var has_petit := false
		for entry in (result["plays"] as Array):
			if (entry["card"] as CardData).rank == CardData.PETIT and (entry["card"] as CardData).is_trunfo():
				has_petit = true
				break
		if has_petit:
			_tutorial_hint("O Trunfo 1 (Le Petit) apareceu na última rodada! Quem ganhou essa rodada leva +10 pontos.")

	# A barra do chefe só se mexe agora, junto do número que sobe da mesa.
	hold_boss = false
	_float_points(winner, points)
	_boss_scores(winner)
	_refresh_boss(true)
	await _wait(1.0)
	if not is_inside_tree():
		return

	# Recolhe as cartas em direção ao vencedor.
	var center := arena.size / 2.0
	var target := center + (_slot_center(winner) - center) * 2.2 - CardView.SIZE / 2.0
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


## Quando o chefe (bot) leva a rodada, o retrato dele dá um pulo: a barra dele acabou de encher.
func _boss_scores(winner: int) -> void:
	if engine.taker == 0 or winner != engine.taker or not boss_panel.visible:
		return
	boss_portrait.pivot_offset = boss_portrait.size / 2.0
	var tw := create_tween()
	tw.tween_property(boss_portrait, "scale", Vector2(1.14, 1.14), GameState.anim(0.08))
	tw.tween_property(boss_portrait, "scale", Vector2.ONE, GameState.anim(0.2))


## Número que sobe da mesa: "+X". Quando é o Atacante que leva a rodada, ele voa até o painel
## do chefe (é a barra dele que enche); quando é a Defesa, sobe na própria mesa.
func _float_points(winner: int, points: float) -> void:
	var to_boss := winner == engine.taker
	var l := UIKit.label("+%s" % UIKit.fmt_dec(points, 1), 70, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	var outline := UIKit.DEF
	if to_boss:
		outline = UIKit.GOLD.darkened(0.3) if winner == 0 else UIKit.BOSS
	l.add_theme_constant_override("outline_size", 12)
	l.add_theme_color_override("font_outline_color", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_layer.add_child(l)
	l.size = Vector2(260, 74)
	l.global_position = arena.global_position + arena.size / 2.0 - l.size / 2.0
	l.modulate.a = 0.0
	var end_y := l.position.y - 70.0
	if to_boss and boss_panel.visible:
		end_y = boss_panel.global_position.y + boss_panel.size.y * 0.5 - l.size.y * 0.5
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 1.0, GameState.anim(0.12))
	tw.parallel().tween_property(l, "position:y", end_y, GameState.anim(0.75)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, GameState.anim(0.25))
	tw.tween_callback(l.queue_free)


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
	if GameState.mode == GameState.Mode.CLASSIC and not tutorial:
		GameState.table_add(r["deltas"])
	Sfx.play("win" if summary["won"] else "lose")
	status_label.text = ""
	_show_results(summary, r)
	match_finished.emit(summary)


func _show_results(summary: Dictionary, r: Dictionary) -> void:
	var ov := UIKit.overlay()
	overlay_layer.add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.GOLD if summary["won"] else UIKit.DANGER, 24)
	box.custom_minimum_size = Vector2(664, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	var title := "O CHEFE VENCEU" if r["success"] else "O CHEFE CAIU!"
	if r["taker"] == 0:
		title = "VOCÊ BATEU A META" if r["success"] else "VOCÊ NÃO BATEU A META"
	if GameState.mode == GameState.Mode.RANKED:
		title = "%dº LUGAR" % (int(summary["placement"]) + 1)
	v.add_child(UIKit.label(title, 32, UIKit.GOLD if r["success"] else UIKit.DANGER, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("%s · %s · %s / %s pts (%s%s)" % [
		str(config["names"][r["taker"]]),
		Scoring.CONTRACT_NAMES[r["contract"]],
		UIKit.fmt_dec(r["taker_points"], 1),
		UIKit.fmt_dec(r["target"], 1),
		"+" if r["margin"] >= 0.0 else "",
		UIKit.fmt_dec(r["margin"], 1),
	], 18, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var bonuses: Dictionary = r.get("bonuses", {})
	var bonus_lines: Array = []
	if float(bonuses.get("poignee", 0.0)) > 0.0:
		bonus_lines.append("✦ Poignée: %s mostrou os trunfos (+%d)" % [str(config["names"][r["taker"]]), int(bonuses["poignee"])])
	var chelem: float = float(bonuses.get("chelem", 0.0))
	if chelem > 0.0 and engine.chelem_announced:
		bonus_lines.append("✦ Chelem avisado e cumprido: %s ganhou todas as rodadas (+%d)" % [str(config["names"][r["taker"]]), int(chelem)])
	elif chelem > 0.0:
		bonus_lines.append("✦ Chelem: %s ganhou todas as rodadas sem avisar (+%d)" % [str(config["names"][r["taker"]]), int(chelem)])
	elif chelem < 0.0:
		bonus_lines.append("✦ Chelem avisado e não cumprido: %s errou (%d)" % [str(config["names"][r["taker"]]), int(chelem)])
	var petit: float = float(bonuses.get("petit_au_bout", 0.0))
	if petit > 0.0:
		bonus_lines.append("✦ Petit na última rodada: ponto pro Atacante (+%d)" % int(petit))
	elif petit < 0.0:
		bonus_lines.append("✦ Petit na última rodada: ponto pra Defesa (%d)" % int(petit))
	if not bonus_lines.is_empty():
		for line in bonus_lines:
			v.add_child(UIKit.label(str(line), 28, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(HSeparator.new())
	for p in engine.standings():
		var delta := int(r["deltas"][p])
		var line := "%s%s  %s%d" % ["♛ " if p == r["taker"] else "", str(config["names"][p]).to_upper(), "+" if delta >= 0 else "", delta]
		v.add_child(UIKit.label(line, 34, UIKit.GOLD if p == 0 else UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(HSeparator.new())
	for line in summary["lines"]:
		v.add_child(UIKit.label(str(line), 30, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	if not GameState.table.is_empty() and GameState.mode == GameState.Mode.CLASSIC and not tutorial:
		v.add_child(HSeparator.new())
		v.add_child(UIKit.label("PLACAR DA MESA · %d mão(s)" % int(GameState.table["hands"]), 30, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		var order: Array = range(engine.num_players)
		order.sort_custom(func(a: int, b: int) -> bool: return float(GameState.table["totals"][a]) > float(GameState.table["totals"][b]))
		for p in order:
			var tot := int(GameState.table["totals"][p])
			v.add_child(UIKit.label("%s  %s%d" % [str(config["names"][p]).to_upper(), "+" if tot >= 0 else "", tot], 32, UIKit.GOLD if p == 0 else UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	if tutorial:
		v.add_child(HSeparator.new())
		var tut_close := UIKit.label("Tutorial concluído! Isso não afeta suas Fragmentos nem seu elo — quando quiser, jogue de verdade no Vanilla ou Ranqueado.", 30, UIKit.OK, HORIZONTAL_ALIGNMENT_CENTER)
		tut_close.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tut_close.custom_minimum_size = Vector2(620, 0)
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
		var again := UIKit.button("PRÓXIMA MÃO")
		again.pressed.connect(func(): get_tree().reload_current_scene())
		v.add_child(again)
		btn = UIKit.button("LEVANTAR DA MESA", UIKit.MUTED)
		btn.pressed.connect(func():
			GameState.leave_table()
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
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


func _open_help() -> void:
	var v := UIKit.modal(overlay_layer, "COMO FUNCIONA")
	var text := """O BÁSICO
• Uma rodada é uma jogada de 4 cartas, uma de cada jogador. Quem jogou a carta mais forte leva as 4 e os pontos delas.
• Você tem que jogar o naipe da primeira carta. Se não tiver, tem que jogar um Trunfo. Se também não tiver Trunfo, joga qualquer carta.
• O Trunfo ganha de qualquer naipe. Entre trunfos, o número maior ganha.
• Em cada naipe, do menor pro maior: Ás, 2 a 10, Valete (J), Cavaleiro (N), Rainha (Q), Rei (K).

OS BOUTS
• São as 3 cartas mais valiosas: o Trunfo 1 (Le Petit), o Trunfo 21 (Le Monde) e O Louco. Valem 4,5 pontos cada, como um Rei.
• O Louco nunca ganha a rodada. Quem o joga fica com ele (só na última rodada ele vai pra quem ganhar).

LICITAÇÃO: QUEM JOGA SOZINHO
• Cada um passa ou dá um lance. O lance mais alto vira o Atacante: ele joga sozinho contra os outros 3 (a Defesa).
• Do mais leve ao mais arriscado: Petite ×1, Garde ×2, Garde Sans ×4, Garde Contre ×6. O número é quanto você ganha ou perde.
• O lance não custa nada. É só dizer que você confia na sua mão.

O MONTE
• São 6 cartas viradas no meio da mesa.
• Petite e Garde: o Atacante pega o monte, olha e devolve 6 cartas da mão (nunca Reis nem Bouts).
• Garde Sans: não pega; os pontos do monte contam pra ele. Garde Contre: não pega; os pontos vão pra Defesa.

COMO SE GANHA
• O Atacante precisa somar estes pontos com as cartas que ganhar: 56 sem Bout, 51 com 1 Bout, 41 com 2, 36 com 3.
• Se conseguir, ganha pontos dos outros 3. Se não, paga.

BÔNUS (só o Atacante escolhe)
• Poignée: com 10 ou mais trunfos, ele pode mostrá-los pra ganhar pontos extras.
• Chelem: ganhar as 18 rodadas. Se avisar antes e conseguir: +400. Se avisar e falhar: -200. Sem avisar, se acontecer: +200.
• Petit na última rodada: quem ganhar a última rodada com o Trunfo 1 nela leva +10."""
	var l := UIKit.label(text, 32, UIKit.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(620, 0)
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
	v.custom_minimum_size = Vector2(620, 0)
	box.add_child(v)
	v.add_child(UIKit.label("PAUSA", 40, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("Toque numa carta para selecionar (ela sobe) e de novo para jogar,\nou arraste-a pra cima e solte na mesa. Segure / botão direito = zoom.", 30, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
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
