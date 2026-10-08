extends Control
## Hub principal — TAROLO logo, abas RANQUEADA / CLÁSSICO / LOJA / MENU.
## Portrait (coluna única) e landscape (top bar unificada) com rebuild no cruzamento do limiar.

var _overlay: Control        ## camada de modais (filha mais alta)
var _wallet: HBoxContainer   ## pílulas de fichas/gemas (para refresh)
var _content_col: VBoxContainer
var _action_bar: VBoxContainer  ## botão de ação fixo fora do scroll (aba RANQUEADA)

var _active_tab := "RANQUEADA"
var _last_wide  := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_last_wide = _is_wide()
	_build()


func _is_wide() -> bool:
	return get_viewport_rect().size.x / get_viewport_rect().size.y >= 1.3


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		var wide := _is_wide()
		if wide != _last_wide:
			_last_wide = wide
			_build()


# ── Layout principal ─────────────────────────────────────────────────────────

func _build() -> void:
	for c in get_children():
		c.queue_free()

	# Fundo roxo escuro unificado (sem divisão header/conteúdo)
	var bg := ColorRect.new()
	bg.color = UIKit.TR_PURPLE_DARK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/background_lobby.gdshader")
	bg.material = mat
	add_child(bg)

	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 0)
	add_child(page)

	var wide := _is_wide()
	page.add_child(_build_topbar(wide))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	UIKit.suppress_click_on_scroll(scroll)

	var mg := MarginContainer.new()
	mg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mg.custom_minimum_size   = Vector2(get_viewport_rect().size.x, 0)
	mg.add_theme_constant_override("margin_left",   Widgets.MARGIN)
	mg.add_theme_constant_override("margin_right",  Widgets.MARGIN)
	mg.add_theme_constant_override("margin_top",    Widgets.MARGIN)
	mg.add_theme_constant_override("margin_bottom", Widgets.MARGIN)
	scroll.add_child(mg)

	_content_col = VBoxContainer.new()
	_content_col.add_theme_constant_override("separation", 24)
	_content_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mg.add_child(_content_col)

	_action_bar = VBoxContainer.new()
	_action_bar.add_theme_constant_override("separation", 0)
	page.add_child(_action_bar)

	if not wide:
		page.add_child(_build_tabbar_portrait())  # portrait: nav bar no BOTTOM

	_populate_tab(wide)

	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)


# ── Barra superior ────────────────────────────────────────────────────────────

func _build_topbar(wide: bool) -> MarginContainer:
	# Header transparente — fundo único para a página toda, sem divisão visual.
	var head := MarginContainer.new()
	head.add_theme_constant_override("margin_top",    28)
	head.add_theme_constant_override("margin_bottom", 20)
	head.add_theme_constant_override("margin_left",   Widgets.MARGIN)
	head.add_theme_constant_override("margin_right",  Widgets.MARGIN)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(row)

	# Logo esquerda
	var logo := UIKit.label("TAROLO", 36, UIKit.TR_GOLD)
	logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo.add_theme_color_override("font_outline_color", UIKit.TR_PURPLE)
	logo.add_theme_constant_override("outline_size", 5)
	row.add_child(logo)

	if wide:
		var gap1 := Control.new()
		gap1.custom_minimum_size = Vector2(56, 0)
		row.add_child(gap1)

		var btn_row := _make_topbar_nav()
		btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(btn_row)

		var gap2 := Control.new()
		gap2.custom_minimum_size = Vector2(56, 0)
		row.add_child(gap2)
	else:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)

	_wallet = _build_wallet()
	row.add_child(_wallet)

	return head


## Botões de navegação embutidos na topbar (só no wide/PC).
func _make_topbar_nav() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	for tab in ["RANQUEADA", "CLÁSSICO", "LOJA", "AJUSTES"]:
		var btn := _topbar_nav_btn(tab, tab == _active_tab)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(btn)
	return row


func _topbar_nav_btn(tab: String, active: bool) -> Button:
	var is_ranked := tab == "RANQUEADA"
	var text_col := UIKit.TR_GOLD if is_ranked else UIKit.TR_WHITE
	var base_bg  := UIKit.TR_RED_DARK if is_ranked else (UIKit.TR_PURPLE_LIGHT if active else UIKit.TR_PURPLE)

	var b := UIKit.button(tab, base_bg, 32)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 96)

	var mk: Callable
	if is_ranked:
		# Padrão borda grande: vermelho-claro + glow vermelho-normal esparso
		mk = func(c: Color) -> StyleBoxFlat:
			var sb := UIKit.rim_box(c, UIKit.TR_RED_LIGHT, UIKit.TR_RED, "large", 10, 16)
			if not active:
				sb.shadow_size = 6
				sb.shadow_color = Color(UIKit.TR_RED.r, UIKit.TR_RED.g, UIKit.TR_RED.b, 0.18)
			sb.content_margin_top    = 24
			sb.content_margin_bottom = 24
			return sb
	else:
		# Flat: roxo-normal, borda roxo-claro, sem glow
		mk = func(c: Color) -> StyleBoxFlat:
			var sb := UIKit.box(c, UIKit.TR_PURPLE_LIGHT, 2, 10, 16)
			sb.content_margin_top    = 24
			sb.content_margin_bottom = 24
			return sb

	b.add_theme_stylebox_override("normal",  mk.call(base_bg))
	b.add_theme_stylebox_override("hover",   mk.call(base_bg.lightened(0.10)))
	b.add_theme_stylebox_override("pressed", mk.call(base_bg.darkened(0.08)))
	b.add_theme_stylebox_override("focus",   mk.call(base_bg))
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(cn, text_col)
	b.pressed.connect(func(): _switch_tab(tab))
	return b


func _build_tabbar_portrait() -> Control:
	var bar := PanelContainer.new()
	var sb := UIKit.box(Color(0.05, 0.02, 0.10, 1.0), UIKit.TR_PURPLE_LIGHT, 0, 0, 0)
	sb.border_width_top = 1
	bar.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	bar.add_child(row)
	const _NAV := [["RANQUEADA","⚔","RANKED"],["CLÁSSICO","♠","CLÁSSICOS"],["LOJA","◈","LOJA"],["AJUSTES","⚙","CONFIG"]]
	for td: Array in _NAV:
		var item := _nav_tab_item(str(td[0]), str(td[1]), str(td[2]), str(td[0]) == _active_tab)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(item)
	return bar


func _nav_tab_item(tab_id: String, icon: String, short_lbl: String, active: bool) -> Control:
	var accent := _tab_accent(tab_id)
	var fg := accent if active else UIKit.MUTED
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, 88)
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	wrap.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			UIKit.sfx("tick")
			_switch_tab(tab_id))
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(accent.r, accent.g, accent.b, 0.10) if active else Color.TRANSPARENT
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(bg)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(vbox)
	var icon_lbl := UIKit.label(icon, 28, fg, HORIZONTAL_ALIGNMENT_CENTER)
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon_lbl)
	var text_lbl := UIKit.label(short_lbl, 14, fg, HORIZONTAL_ALIGNMENT_CENTER)
	text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(text_lbl)
	return wrap


func _make_tab_buttons(expand: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	for name in ["RANQUEADA", "CLÁSSICO", "LOJA", "AJUSTES"]:
		var btn := _tab_btn(name, name == _active_tab, expand)
		if expand:
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(btn)
	return row


func _tab_btn(tab: String, active: bool, tall: bool = false) -> Button:
	var accent := _tab_accent(tab)
	var face   := accent.darkened(0.78) if active else UIKit.SURFACE_DEEP
	var b      := UIKit.button(tab, face, 22)
	b.focus_mode      = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 120 if tall else 60)
	if tall:
		b.add_theme_font_size_override("font_size", 19)
	b.add_theme_constant_override("outline_size", 3 if active else 0)
	b.add_theme_color_override("font_outline_color", accent.darkened(0.5))
	for cn in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(cn, accent if active else UIKit.MUTED)
	# Replace chunky 3D styleboxes with flat tab style
	var mk := func(bg: Color) -> StyleBoxFlat:
		var sb := UIKit.box(bg, accent if active else UIKit.SURFACE, 2, 0, 0)
		sb.set_corner_radius_all(0)
		sb.set_border_width_all(0)
		sb.border_width_bottom = 3 if active else 1
		sb.content_margin_left  = 12
		sb.content_margin_right = 12
		return sb
	b.add_theme_stylebox_override("normal",  mk.call(face))
	b.add_theme_stylebox_override("hover",   mk.call(accent.darkened(0.7) if active else UIKit.SURFACE))
	b.add_theme_stylebox_override("pressed", mk.call(face))
	b.add_theme_stylebox_override("focus",   mk.call(face))
	b.pressed.connect(func(): _switch_tab(tab))
	return b


func _tab_accent(tab: String) -> Color:
	match tab:
		"RANQUEADA": return UIKit.TR_RED
		_:          return UIKit.TR_CYAN


func _switch_tab(tab: String) -> void:
	if tab == _active_tab:
		return
	_active_tab = tab
	UIKit.sfx("tick")
	_build()


# ── Carteira (fichas + gemas) ─────────────────────────────────────────────────

func _build_wallet() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var prof := SaveManager.section("profile")

	var chip_p := _pill("◎ " + UIKit.fmt_int(int(prof["fichas"])), UIKit.TR_CYAN, "ChipsLabel")
	chip_p.mouse_filter = Control.MOUSE_FILTER_STOP
	chip_p.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			UIKit.sfx("tick")
			_open_fichas())
	row.add_child(chip_p)

	row.add_child(_pill("◆ " + UIKit.fmt_int(int(prof["gems"])), UIKit.TR_GOLD, "GemsLabel"))

	return row


func _pill(text: String, color: Color, label_name: String) -> PanelContainer:
	var bg  := UIKit.TR_PURPLE.lightened(0.08)
	var p   := UIKit.panel(bg, color.darkened(0.1), 2)
	var sb  := p.get_theme_stylebox("panel") as StyleBoxFlat
	sb.set_corner_radius_all(24)
	sb.content_margin_left  = 16
	sb.content_margin_right = 20
	sb.content_margin_top   = 6
	sb.content_margin_bottom = 6
	p.custom_minimum_size = Vector2(0, 48)
	var lbl := UIKit.label(text, 22, color)
	lbl.name = label_name
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(lbl)
	return p


func _refresh_wallet() -> void:
	if not is_instance_valid(_wallet):
		return
	var prof := SaveManager.section("profile")
	var cl   := _wallet.find_child("ChipsLabel", true, false) as Label
	var gl   := _wallet.find_child("GemsLabel",  true, false) as Label
	if cl:
		cl.text = "◎ " + UIKit.fmt_int(int(prof["fichas"]))
	if gl:
		gl.text = "◆ " + UIKit.fmt_int(int(prof["gems"]))


# ── Conteúdo de cada aba ──────────────────────────────────────────────────────

func _populate_tab(wide: bool) -> void:
	match _active_tab:
		"RANQUEADA": _build_ranked(wide)
		"CLÁSSICO": _build_classic(wide)
		"LOJA":     _build_shop(wide)
		"AJUSTES":  _build_menu(wide)


func _build_ranked(wide: bool) -> void:
	var rk   := GameState.ranked()
	var t    := Ranked.tier_info(int(rk["points"]), int(rk["mmr"]))
	var tc   := Color(Ranked.TIER_COLORS[int(t["tier"])])
	var wins := int(rk["wins"])
	var loss := int(rk["losses"])

	# Espaçamento 3× entre header e emblema
	var top_gap := Control.new()
	top_gap.custom_minimum_size = Vector2(0, Widgets.MARGIN * 2)   # +48 → total ~72 do topo
	_content_col.add_child(top_gap)

	# Conteúdo principal: 2 colunas no PC, coluna única no mobile
	var fichas := int(SaveManager.section("profile")["fichas"])
	if wide:
		var cols := HBoxContainer.new()
		cols.add_theme_constant_override("separation", Widgets.MARGIN)
		cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content_col.add_child(cols)

		# Coluna esquerda (60%): badge + tier + métricas
		var left := VBoxContainer.new()
		left.add_theme_constant_override("separation", 16)
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.size_flags_stretch_ratio = 0.6
		cols.add_child(left)
		_ranked_badge_block(left, t, tc, 72, UIKit.TR_WHITE)
		_ranked_stats_block(left, rk, wins, loss, true)
		# Botão na coluna esquerda, empurrado para o bottom pelo spacer
		var spacer_fill := Control.new()
		spacer_fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
		left.add_child(spacer_fill)
		var pb_wide := _make_ranked_play_btn()
		pb_wide.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pb_wide.custom_minimum_size.x = get_viewport_rect().size.x * 0.6 * 0.75
		left.add_child(pb_wide)

		# Coluna direita (40%): torneios ocupa a coluna inteira
		var right := VBoxContainer.new()
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.size_flags_stretch_ratio = 0.4
		cols.add_child(right)
		_ranked_tournament_block(right, fichas, true)
	else:
		_ranked_badge_block(_content_col, t, tc, 48, UIKit.BROWN)
		_ranked_stats_block(_content_col, rk, wins, loss, false)
		_ranked_tournament_block(_content_col, fichas, false)
		# Portrait: botão fixo no bottom
		var ab_mg := MarginContainer.new()
		ab_mg.add_theme_constant_override("margin_left",   32)
		ab_mg.add_theme_constant_override("margin_right",  32)
		ab_mg.add_theme_constant_override("margin_top",    12)
		ab_mg.add_theme_constant_override("margin_bottom", 32)
		_action_bar.add_child(ab_mg)
		ab_mg.add_child(_make_ranked_play_btn())


func _ranked_badge_block(col: VBoxContainer, t: Dictionary, tc: Color, tier_size: int, tier_color: Color) -> void:
	var circle := Panel.new()
	circle.custom_minimum_size   = Vector2(250, 250)
	circle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var csb := UIKit.box(tc.darkened(0.1), tc.lightened(0.15), 6, 125, 0)
	csb.set_border_width_all(6)
	# Glow roxo-claro grande e suave atrás do emblema
	csb.shadow_color  = Color(UIKit.TR_PURPLE_LIGHT.r, UIKit.TR_PURPLE_LIGHT.g, UIKit.TR_PURPLE_LIGHT.b, 0.75)
	csb.shadow_size   = 90
	csb.shadow_offset = Vector2.ZERO
	circle.add_theme_stylebox_override("panel", csb)
	var div_txt := str(t["division"]) if str(t["division"]) != "" else "★"
	var div_lbl := UIKit.label(div_txt, 100, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	div_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	div_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	div_lbl.add_theme_color_override("font_outline_color", tc.darkened(0.6))
	div_lbl.add_theme_constant_override("outline_size", 8)
	circle.add_child(div_lbl)
	col.add_child(circle)
	var tier_lbl := UIKit.label(str(t["label"]).to_upper(), tier_size, tier_color, HORIZONTAL_ALIGNMENT_CENTER)
	tier_lbl.add_theme_color_override("font_outline_color", UIKit.OUTLINE)
	tier_lbl.add_theme_constant_override("outline_size", 6)
	col.add_child(tier_lbl)


func _ranked_stats_block(col: VBoxContainer, rk: Dictionary, wins: int, loss: int, wide: bool) -> void:
	var ratio := float(wins) / float(maxi(loss, 1))
	var stat_rows: Array[Array] = [
		["MMR",  UIKit.fmt_int(int(rk["mmr"]))],
		["LP",   "%d / 100" % int(Ranked.tier_info(int(rk["points"]), int(rk["mmr"]))["lp"])],
		["V/D", UIKit.fmt_dec(ratio, 2)],
	]
	var mp := UIKit.panel(UIKit.TR_PURPLE, UIKit.TR_PURPLE_LIGHT, 24)
	if wide:
		mp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		mp.custom_minimum_size = Vector2(get_viewport_rect().size.x * 0.28, 0)
	else:
		mp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 12)
	mp.add_child(mv)
	for sr in stat_rows:
		var mrow := HBoxContainer.new()
		var mk := UIKit.label(str(sr[0]), 26, UIKit.TR_GOLD)
		mk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mrow.add_child(mk)
		mrow.add_child(UIKit.label(str(sr[1]), 26, UIKit.TR_WHITE))
		mv.add_child(mrow)
	col.add_child(mp)


func _ranked_tournament_block(col: VBoxContainer, fichas: int, fill_height: bool) -> void:
	var tp := UIKit.panel(UIKit.TR_PURPLE, UIKit.TR_PURPLE_LIGHT, 24)
	tp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if fill_height:
		tp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 16)
	tp.add_child(tv)
	tv.add_child(UIKit.label("TORNEIOS", 32, UIKit.BROWN, HORIZONTAL_ALIGNMENT_CENTER))
	var tscroll := ScrollContainer.new()
	tscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if not fill_height:
		tscroll.custom_minimum_size = Vector2(0, clampf(get_viewport_rect().size.y * 0.38, 260.0, 480.0))
	UIKit.suppress_click_on_scroll(tscroll)
	tv.add_child(tscroll)
	var tlist := VBoxContainer.new()
	tlist.add_theme_constant_override("separation", 12)
	tlist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tscroll.add_child(tlist)
	for ev in Tournament.OPEN_EVENTS:
		var buy: int = int(ev["buy_in"])
		var item := UIKit.panel(UIKit.TR_PURPLE.lightened(0.06), UIKit.TR_PURPLE.lightened(0.18), 20)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ir := HBoxContainer.new()
		ir.add_theme_constant_override("separation", 12)
		item.add_child(ir)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ev_title := UIKit.label("%s (%d jogadores)" % [str(ev["name"]), Tournament.FIELD_SIZE], 24, UIKit.TR_GOLD)
		ev_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(ev_title)
		var ev_info := UIKit.label("Buy-in ◎%s · Stack ◎%s · Blind %d" % [UIKit.fmt_int(buy), UIKit.fmt_int(int(ev["stack"])), int(ev["blind_base"])], 20, UIKit.TR_WHITE)
		ev_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(ev_info)
		var prizes := UIKit.label("1º ◎%s · 2º ◎%s · 3º ◎%s" % [
			UIKit.fmt_int(Tournament.payout_for(0, buy)), UIKit.fmt_int(Tournament.payout_for(1, buy)),
			UIKit.fmt_int(Tournament.payout_for(2, buy))], 20, UIKit.TR_WHITE)
		prizes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(prizes)
		ir.add_child(info)
		var eb := UIKit.button("ENTRAR", UIKit.ENTER_BLUE, 24)
		eb.focus_mode = Control.FOCUS_NONE
		eb.custom_minimum_size = Vector2(150, 64)
		eb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		eb.add_theme_constant_override("outline_size", 0)
		for cn in ["font_color", "font_hover_color", "font_pressed_color"]:
			eb.add_theme_color_override(cn, UIKit.BROWN)
		eb.add_theme_color_override("font_disabled_color", UIKit.MUTED)
		eb.add_theme_stylebox_override("normal",   UIKit.soft_box(UIKit.ENTER_BLUE, UIKit.ENTER_BLUE_EDGE))
		eb.add_theme_stylebox_override("hover",    UIKit.soft_box(UIKit.ENTER_BLUE.lightened(0.1), UIKit.ENTER_BLUE_EDGE))
		eb.add_theme_stylebox_override("pressed",  UIKit.soft_box(UIKit.ENTER_BLUE.darkened(0.1), UIKit.ENTER_BLUE_EDGE))
		eb.add_theme_stylebox_override("disabled", UIKit.soft_box(UIKit.ENTER_BLUE.darkened(0.35), UIKit.ENTER_BLUE_EDGE))
		eb.add_theme_stylebox_override("focus",    UIKit.soft_box(UIKit.ENTER_BLUE, UIKit.ENTER_BLUE_EDGE))
		eb.disabled = fichas < buy
		eb.pressed.connect(_open_tournament.bind(buy, str(ev["name"])))
		ir.add_child(eb)
		tlist.add_child(item)
	col.add_child(tp)

func _make_ranked_play_btn() -> Button:
	# Padrão borda grande: fundo vermelho-escuro, borda vermelho-claro, glow vermelho-normal esparso
	var b := UIKit.button("JOGAR RANQUEADA", UIKit.TR_RED_DARK, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 112)
	var mk := func(bg: Color) -> StyleBoxFlat:
		var sb := UIKit.rim_box(bg, UIKit.TR_RED_LIGHT, UIKit.TR_RED, "large", 10, 20)
		sb.content_margin_top    = 0
		sb.content_margin_bottom = 0
		return sb
	b.add_theme_stylebox_override("normal",   mk.call(UIKit.TR_RED_DARK))
	b.add_theme_stylebox_override("hover",    mk.call(UIKit.TR_RED_DARK.lightened(0.10)))
	b.add_theme_stylebox_override("pressed",  mk.call(UIKit.TR_RED_DARK.darkened(0.08)))
	b.add_theme_stylebox_override("focus",    mk.call(UIKit.TR_RED_DARK))
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(cn, UIKit.TR_GOLD)
	b.add_theme_constant_override("outline_size", 0)
	b.pressed.connect(_start_ranked_matchmaking)
	return b


func _build_classic(wide: bool) -> void:
	var h := 150 if not wide else 132
	var trk := GameState.tournaments()

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	_content_col.add_child(grid)

	var torneio := Widgets.mode_card(
			"TORNEIO",
			"Mesas de %d-%d · 🏆 %d" % [Tournament.MIN_TABLE, Tournament.MAX_TABLE, int(trk.get("trophies", 0))],
			UIKit.MONEY.darkened(0.5), h, "🏆", _open_tournament, 28)
	var classico := Widgets.mode_card(
			"CLÁSSICO",
			"Tarot tradicional, 78 cartas.",
			UIKit.PURPLE, h, "♛",
			func():
				GameState.mode = GameState.Mode.CLASSIC
				GameState.leave_table()
				get_tree().change_scene_to_file("res://scenes/GameScene.tscn"), 28)
	for c in [torneio, classico]:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(c)

	var tutorial := Widgets.mode_card(
			"TUTORIAL",
			"Primeira vez? Mão guiada, com dicas.",
			UIKit.OK.darkened(0.4), h, "?",
			func():
				GameState.start_tutorial()
				get_tree().change_scene_to_file("res://scenes/GameScene.tscn"), 38)
	_content_col.add_child(tutorial)



func _build_shop(_wide: bool) -> void:
	_content_col.add_child(UIKit.label("COSMÉTICOS", 34, UIKit.BRAND))

	var prof     := SaveManager.section("profile")
	var cos      := SaveManager.section("cosmetics")
	var rk       := GameState.ranked()
	var peak_t   := int(Ranked.tier_info(int(rk["peak_points"]), int(rk["mmr"]))["tier"])

	_content_col.add_child(UIKit.label("◆ %s Gemas" % UIKit.fmt_int(int(prof["gems"])), 24, UIKit.MUTED))

	for id in UIKit.CARD_BACKS.keys():
		var back: Dictionary = UIKit.CARD_BACKS[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var swatch := Panel.new()
		swatch.custom_minimum_size = Vector2(44, 64)
		swatch.add_theme_stylebox_override("panel",
				UIKit.box(Color(back["color"]), UIKit.BRAND.darkened(0.35), 3, 6, 0))
		row.add_child(swatch)

		var name_l := UIKit.label(str(back["name"]), 24)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_l)

		var owned: Array = cos["owned"]
		var btn: Button
		if str(cos["equipped"]) == id:
			btn = UIKit.button("EQUIPADO", UIKit.OK, 20)
			btn.disabled = true
		elif owned.has(id):
			btn = UIKit.button("EQUIPAR", UIKit.OK, 20)
			btn.pressed.connect(func():
				cos["equipped"] = id
				SaveManager.save_game()
				_switch_tab("LOJA"))
		elif back.has("requires_tier"):
			var req := int(back["requires_tier"])
			var lbl := "DESBLOQUEAR" if peak_t >= req else "REQ. %s" % Ranked.TIERS[req].to_upper()
			btn = UIKit.button(lbl, UIKit.ACTION, 20)
			btn.disabled = peak_t < req
			btn.pressed.connect(func():
				owned.append(id)
				Sfx.play("buy")
				SaveManager.save_game()
				_switch_tab("LOJA"))
		else:
			var price := int(back["price"])
			btn = UIKit.button("◆ %d" % price, UIKit.ACTION, 20)
			btn.disabled = int(prof["gems"]) < price
			btn.pressed.connect(func():
				prof["gems"] = int(prof["gems"]) - price
				owned.append(id)
				Sfx.play("buy")
				SaveManager.save_game()
				_refresh_wallet()
				_switch_tab("LOJA"))
		btn.custom_minimum_size = Vector2(144, 56)
		row.add_child(btn)
		_content_col.add_child(row)


func _build_menu(_wide: bool) -> void:
	_content_col.add_child(UIKit.label("MENU", 34, UIKit.BRAND))

	var items: Array[Array] = [
		["CONTA · %s" % Accounts.display_name().to_upper(), UIKit.BRAND, _open_account],
		["COMO JOGAR",      UIKit.INFO,   _open_rules],
		["CONFIGURAÇÕES",   UIKit.MUTED,  _open_settings],
		["LOJA DE FICHAS",  UIKit.MONEY,  _open_fichas],
	]
	for item in items:
		var btn := UIKit.button(item[0], item[1] as Color)
		btn.pressed.connect(item[2] as Callable)
		_content_col.add_child(btn)

	var reset := UIKit.button("APAGAR PROGRESSO", UIKit.DANGER)
	reset.pressed.connect(func():
		SaveManager.reset()
		get_tree().reload_current_scene())
	_content_col.add_child(reset)

	var ver := UIKit.label("v1.0 · Tarolo", 20, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_content_col.add_child(ver)


# ── Modais ────────────────────────────────────────────────────────────────────

func _open_fichas() -> void:
	FichasShop.open(_overlay, _refresh_wallet)


func _modal(title: String) -> VBoxContainer:
	var ov  := UIKit.overlay()
	_overlay.add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.BRAND, 24)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	outer.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 96.0, 580.0), 0)
	box.add_child(outer)
	outer.add_child(UIKit.label(title, 38, UIKit.BRAND, HORIZONTAL_ALIGNMENT_CENTER))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, clampf(get_viewport_rect().size.y * 0.42, 220.0, 480.0))
	scroll.size_flags_vertical  = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	UIKit.suppress_click_on_scroll(scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	body.set_meta("modal_footer", outer)
	ov.add_child(UIKit.centered(box))
	UIKit.fit.call_deferred(box)
	return body


func _close_modal() -> void:
	if _overlay.get_child_count() > 0:
		_overlay.get_child(_overlay.get_child_count() - 1).queue_free()


func _open_tournament(buy_in: int = Tournament.BUY_IN, ev_name: String = "TORNEIO") -> void:
	var v   := _modal(ev_name.to_upper())
	var prof := SaveManager.section("profile")
	var trk := GameState.tournaments()
	v.add_child(UIKit.label("16 jogadores · mesas de %d a %d, preenchidas com bots." % [Tournament.MIN_TABLE, Tournament.MAX_TABLE], 20, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("Entrada ◎%d  ·  Bolão ◎%d" % [buy_in, Tournament.prize_pool(buy_in)], 26, UIKit.MONEY, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("Stack inicial ◎%d · blind começa em ◎%d" % [int(Tournament.event_for(buy_in)["stack"]), int(Tournament.event_for(buy_in)["blind_base"])], 20, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("1º ◎%d · 2º ◎%d · 3º ◎%d · 4º ◎%d" % [Tournament.payout_for(0, buy_in), Tournament.payout_for(1, buy_in), Tournament.payout_for(2, buy_in), Tournament.payout_for(3, buy_in)], 20, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(HSeparator.new())
	v.add_child(UIKit.label("🏆 %d troféu(s)" % int(trk.get("trophies", 0)), 24, UIKit.BRAND, HORIZONTAL_ALIGNMENT_CENTER))
	var hist: Array = trk.get("history", [])
	if hist.is_empty():
		v.add_child(UIKit.label("Nenhum torneio disputado ainda.", 20, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	for h in hist.slice(0, mini(5, hist.size())):
		v.add_child(UIKit.label(str(h["result"]).capitalize(), 20, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	var footer: Node = v.get_meta("modal_footer", v)
	var enter := UIKit.button("ENTRAR (◎%d)" % buy_in, UIKit.ACTION)
	enter.disabled = int(prof["fichas"]) < buy_in
	enter.pressed.connect(func():
		var t := GameState.start_tournament(buy_in)
		if t.is_empty():
			return
		get_tree().change_scene_to_file("res://scenes/BlitzScene.tscn"))
	footer.add_child(enter)
	var close := UIKit.button("FECHAR", UIKit.MUTED)
	close.pressed.connect(_close_modal)
	footer.add_child(close)


func _open_settings() -> void:
	var v := _modal("CONFIGURAÇÕES")
	v.add_child(UIKit.label("Conta", 20))
	var who := "%s · %s" % [Accounts.display_name(), "convidado" if Accounts.is_guest() else "@" + Accounts.username()]
	v.add_child(UIKit.label(who, 22, UIKit.INK))
	var manage := UIKit.button("GERENCIAR CONTA", UIKit.MUTED, 22)
	manage.pressed.connect(func():
		_close_modal()
		_open_account())
	v.add_child(manage)
	var s := GameState.settings()
	v.add_child(UIKit.label("Dificuldade dos bots", 20))
	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 10)
	v.add_child(diff_row)
	for d in range(3):
		var db := UIKit.button(str(BotAI.DIFFICULTY_NAMES[d]).to_upper(), UIKit.OK if int(s["difficulty"]) == d else UIKit.MUTED, 19)
		db.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		db.pressed.connect(func(): s["difficulty"] = d; SaveManager.save_game(); _reopen_settings())
		diff_row.add_child(db)
	for entry in [["Música", "music_volume"], ["Efeitos", "sfx_volume"]]:
		v.add_child(UIKit.label(entry[0], 20))
		var sl := HSlider.new()
		sl.min_value = 0.0; sl.max_value = 1.0; sl.step = 0.05
		sl.value     = float(s[entry[1]])
		sl.custom_minimum_size = Vector2(0, 32)
		var key: String = entry[1]
		sl.value_changed.connect(func(val: float): s[key] = val; GameState.apply_settings())
		v.add_child(sl)
	v.add_child(UIKit.label("Velocidade das animações", 20))
	var speed := OptionButton.new()
	var speeds := [0.75, 1.0, 1.5, 2.0]
	for sp in speeds:
		speed.add_item("%sx" % UIKit.fmt_dec(sp, 2 if sp == 0.75 else 1))
	speed.selected = maxi(speeds.find(float(s["anim_speed"])), 1)
	speed.item_selected.connect(func(i: int): s["anim_speed"] = speeds[i])
	v.add_child(speed)
	if not OS.has_feature("mobile"):
		var fs := CheckButton.new()
		fs.text = "Tela cheia"
		fs.button_pressed = bool(s["fullscreen"])
		fs.toggled.connect(func(on: bool): s["fullscreen"] = on; GameState.apply_settings())
		v.add_child(fs)
	var footer: Node = v.get_meta("modal_footer", v)
	var save_btn := UIKit.button("SALVAR E FECHAR")
	save_btn.pressed.connect(func(): SaveManager.save_game(); _close_modal())
	footer.add_child(save_btn)


## Conta do jogador (perfil, entrar, criar conta, trocar nome). Cada tela reabre o modal na tela seguinte.
func _open_account(mode: String = "") -> void:
	var v := _modal(AccountForms.title_for(mode))
	var reopen := func(next_mode: String):
		_close_modal()
		_open_account(next_mode)
	AccountForms.build(v, v.get_meta("modal_footer", v), _close_modal, reopen, mode)


func _reopen_settings() -> void:
	_close_modal()
	_open_settings()


## Ranqueada = Blitz, numa fila única com 5 níveis. Você escolhe o nível num popup de cards (o saldo
## precisa pagar o buy-in de 80 blinds), o jogo procura uma mesa dele e você escolhe ENTRAR, PROCURAR
## OUTRA ou SAIR. Os pontos valem igual em todos os níveis.
func _start_ranked_matchmaking() -> void:
	var fichas := int(SaveManager.section("profile")["fichas"])
	if GameState.ranked_rooms_open(fichas).is_empty():
		_ranked_no_funds()
		return
	_ranked_pick_level(fichas)


func _ranked_no_funds() -> void:
	var cheapest := GameState.ranked_room_buy_in(GameState.RANKED_ROOMS[0])
	var v := _modal("FICHAS INSUFICIENTES")
	var msg := UIKit.label("O nível mais barato pede ◎%s pra sentar." % UIKit.fmt_int(cheapest), 22, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(msg)
	var shop := UIKit.button("RECARGA E PACOTES", UIKit.OK)
	shop.pressed.connect(func(): _close_modal(); _open_fichas())
	v.add_child(shop)
	var cl := UIKit.button("FECHAR", UIKit.MUTED)
	cl.pressed.connect(_close_modal)
	v.get_meta("modal_footer", v).add_child(cl)


## Popup com os 5 níveis. Os que o saldo não paga ficam apagados e mostram quanto falta.
func _ranked_pick_level(fichas: int) -> void:
	var v := _modal("RANQUEADA")
	var hint := UIKit.label("Escolha o nível da mesa. Buy-in de %d blinds." % GameState.RANKED_STACK_BLINDS, 22, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	for room in GameState.RANKED_ROOMS:
		var blind := int(room["blind"])
		var cost := GameState.ranked_room_buy_in(room)
		var ok := fichas >= cost
		var b := UIKit.button("%s  %s" % [str(room["numeral"]), str(room["name"])], UIKit.ACTION if ok else UIKit.MUTED, 28)
		b.custom_minimum_size = Vector2(0, 76)
		b.disabled = not ok
		b.pressed.connect(func():
			_close_modal()
			_ranked_search(blind))
		v.add_child(b)
		var info := "Blind ◎%s  ·  Buy-in ◎%s" % [UIKit.fmt_int(blind), UIKit.fmt_int(cost)]
		if not ok:
			info += "  ·  faltam ◎%s" % UIKit.fmt_int(cost - fichas)
		v.add_child(UIKit.label(info, 20, UIKit.MONEY if ok else UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var cl := UIKit.button("FECHAR", UIKit.MUTED)
	cl.pressed.connect(_close_modal)
	v.get_meta("modal_footer", v).add_child(cl)


## Procura uma mesa do nível `level_blind` e mostra o resultado.
func _ranked_search(level_blind: int) -> void:
	var fichas := int(SaveManager.section("profile")["fichas"])
	var level := GameState.ranked_room_for_blind(level_blind)

	var ov := UIKit.overlay()
	_overlay.add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.DANGER, 24)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 20)
	bv.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 96.0, 520.0), 0)
	box.add_child(bv)
	bv.add_child(UIKit.label("%s  %s" % [str(level["numeral"]), str(level["name"])], 38, UIKit.DANGER, HORIZONTAL_ALIGNMENT_CENTER))
	var status_lbl := UIKit.label("Procurando mesa...", 26, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bv.add_child(status_lbl)
	var cancel_btn := UIKit.button("CANCELAR", UIKit.MUTED, 24)
	cancel_btn.custom_minimum_size = Vector2(0, 64)
	cancel_btn.pressed.connect(func(): ov.queue_free())
	bv.add_child(cancel_btn)
	ov.add_child(UIKit.centered(box))
	UIKit.fit.call_deferred(box)

	var elapsed := 0.0
	var wait := randf_range(1.2, 2.6)
	while elapsed < wait:
		if not is_instance_valid(ov):
			return
		status_lbl.text = "Procurando mesa...  %ds" % (int(elapsed) + 1)
		await get_tree().create_timer(GameState.anim(0.25)).timeout
		elapsed += 0.25
	if not is_instance_valid(ov):
		return

	var room := GameState.find_ranked_room(fichas, level_blind)
	var lobby := GameState.find_ranked_lobby()
	var names := ", ".join(lobby.map(func(p: Dictionary) -> String: return str(p["name"])))
	UIKit.sfx("combo")
	for c in bv.get_children():
		c.queue_free()
	var blind := int(room["blind"])
	var n_found: int = int(room.get("players", 4))
	var affordable: bool = bool(room.get("affordable", true))
	var rounds_left: int = int(room.get("rounds_left", 0))
	bv.add_child(UIKit.label("MESA ENCONTRADA", 34, UIKit.DANGER, HORIZONTAL_ALIGNMENT_CENTER))
	var info_color := UIKit.MONEY if affordable else UIKit.MUTED
	bv.add_child(UIKit.label("Buy-in ◎%s  ·  Blind ◎%s  ·  %d jogadores" % [UIKit.fmt_int(GameState.ranked_room_buy_in(room)), UIKit.fmt_int(blind), n_found], 26, info_color, HORIZONTAL_ALIGNMENT_CENTER))
	if rounds_left > 0:
		bv.add_child(UIKit.label("Partida em andamento — entra na próxima (%d rituais)" % rounds_left, 22, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		bv.add_child(UIKit.label("Aguardando jogadores", 22, UIKit.OK, HORIZONTAL_ALIGNMENT_CENTER))
	var who := UIKit.label("Com %s" % names, 20, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bv.add_child(who)
	var buy_in_cost := GameState.ranked_room_buy_in(room)
	var enter := UIKit.button("ENTRAR", UIKit.OK if affordable else UIKit.MUTED, 34)
	enter.custom_minimum_size = Vector2(0, 88)
	enter.disabled = not affordable
	enter.pressed.connect(func():
		GameState.ranked_table = {"blind": blind, "stack_blinds": GameState.RANKED_STACK_BLINDS, "players": int(room.get("players", 4))}
		get_tree().change_scene_to_file("res://scenes/BlitzScene.tscn"))
	bv.add_child(enter)
	if not affordable:
		bv.add_child(UIKit.label("Saldo insuficiente — precisa de ◎%s" % UIKit.fmt_int(buy_in_cost), 20, UIKit.DANGER, HORIZONTAL_ALIGNMENT_CENTER))
		var add_btn := UIKit.button("ADICIONAR FICHAS", UIKit.ACTION, 26)
		add_btn.custom_minimum_size = Vector2(0, 64)
		add_btn.pressed.connect(func():
			FichasShop.open(ov, func():
				_refresh_wallet()
				var new_fichas: int = int(SaveManager.section("profile")["fichas"])
				if new_fichas >= buy_in_cost:
					enter.disabled = false
					enter.add_theme_color_override("font_color", UIKit.OK)
					if is_instance_valid(add_btn):
						add_btn.queue_free()))
		bv.add_child(add_btn)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bv.add_child(row)
	var other := UIKit.button("PROCURAR OUTRA", UIKit.PURPLE, 22)
	other.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	other.custom_minimum_size = Vector2(0, 64)
	other.pressed.connect(func():
		ov.queue_free()
		_ranked_search(blind))
	row.add_child(other)
	var leave := UIKit.button("SAIR", UIKit.MUTED, 22)
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.custom_minimum_size = Vector2(0, 64)
	leave.pressed.connect(func(): ov.queue_free())
	row.add_child(leave)
	UIKit.fit.call_deferred(box)


func _open_rules() -> void:
	StepsModal.open(_overlay, "COMO JOGAR", HelpContent.vanilla(), "ENTENDI", false)
