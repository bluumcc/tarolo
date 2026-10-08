extends Control
## RankedLobby — arena ranqueada com visual Tarot Royale.
## Layout portrait (coluna única) e landscape (2 colunas).

var _status: Label
var _search_btn: Button
var _searching := false
var _content: VBoxContainer
var _left_col: VBoxContainer
var _right_col: VBoxContainer
var _last_wide := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UIKit.background())
	_last_wide = _is_wide()
	_build()


func _is_wide() -> bool:
	return get_viewport_rect().size.x / get_viewport_rect().size.y >= 1.3


func _build() -> void:
	# Limpa filhos além do background (índice 0).
	while get_child_count() > 1:
		get_child(1).queue_free()
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 0)
	add_child(page)

	# ── Barra de topo ─────────────────────────────────────────────────────
	var head := PanelContainer.new()
	var hsb := UIKit.box(UIKit.SURFACE, UIKit.BLACK, 3, 0, 12)
	hsb.set_corner_radius_all(0)
	hsb.corner_radius_bottom_left = 24
	hsb.corner_radius_bottom_right = 24
	hsb.content_margin_left = Widgets.MARGIN
	hsb.content_margin_right = Widgets.MARGIN
	head.add_theme_stylebox_override("panel", hsb)
	head.custom_minimum_size = Vector2(0, Widgets.TOPBAR_H)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 16)
	head.add_child(hrow)
	var back := Widgets.icon_button("◀")
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	hrow.add_child(back)
	var rk0 := GameState.ranked()
	var ttl := UIKit.label("RANQUEADO · TEMPORADA %d" % int(rk0["season"]), 30, UIKit.BRAND)
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ttl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hrow.add_child(ttl)
	page.add_child(head)

	# ── Scroll ────────────────────────────────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	UIKit.suppress_click_on_scroll(scroll)

	var margin := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, Widgets.MARGIN)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # sem isso o conteúdo encolhe pra ~2/3 da tela
	scroll.add_child(margin)

	if _is_wide():
		_build_wide(margin)
	else:
		_build_portrait(margin)

	_search_btn.grab_focus.call_deferred()


## Card do lobby: a superfície padrão do design system com a borda na cor do assunto.
func _card(accent: Color) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UIKit.rim_box(DS.surface(), accent.lightened(0.15), accent.darkened(0.3), "small", DS.R_CARD, UIKit.card_pad(), UIKit.card_pad()))
	return pc


func _build_portrait(parent: MarginContainer) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	parent.add_child(col)
	_content = col
	_fill_columns(col, col)


func _build_wide(parent: MarginContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	parent.add_child(row)

	_left_col = VBoxContainer.new()
	_left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_col.add_theme_constant_override("separation", 20)
	row.add_child(_left_col)

	_right_col = VBoxContainer.new()
	_right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_col.add_theme_constant_override("separation", 20)
	row.add_child(_right_col)

	_content = _left_col
	_fill_columns(_left_col, _right_col)


func _fill_columns(left: VBoxContainer, right: VBoxContainer) -> void:
	var rk := GameState.ranked()
	var t := Ranked.tier_info(int(rk["points"]), int(rk["mmr"]))
	var tier_color := Color(Ranked.TIER_COLORS[t["tier"]])

	# ── Cartão de liga ─────────────────────────────────────────────────
	var badge_panel := _card(tier_color)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 12)
	badge_panel.add_child(bv)
	left.add_child(badge_panel)

	# Emblema circular
	var emblem := PanelContainer.new()
	emblem.custom_minimum_size = Vector2(140, 140)
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var tn := DS.tone(tier_color)
	var esb := UIKit.rim_box(tn["bg"], tn["rim"], tn["glow"], "small", 70, 0, 0)
	emblem.add_theme_stylebox_override("panel", esb)
	var div_txt := str(t["division"]) if str(t["division"]) != "" else "★"
	var div := UIKit.label(div_txt, 60, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	div.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	div.add_theme_color_override("font_outline_color", tier_color.darkened(0.6))
	emblem.add_child(div)
	bv.add_child(emblem)

	# Nome da liga
	bv.add_child(UIKit.label(str(t["label"]).to_upper(), 50, tier_color, HORIZONTAL_ALIGNMENT_CENTER))

	# Barra de LP
	var bar := MeterBar.new()
	bar.custom_minimum_size = Vector2(0, 30)
	bar.set_colors(tier_color, UIKit.OUTLINE)
	bar.set_values(float(t["progress"]), 1.0, false)
	bv.add_child(bar)

	# LP e MMR
	bv.add_child(UIKit.label(
		"%d LP  ·  MMR %s" % [int(t["lp"]), UIKit.fmt_int(int(rk["mmr"]))],
		26, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER))

	# Vitórias / derrotas / pico
	var peak := Ranked.tier_info(int(rk["peak_points"]), int(rk["mmr"]))
	bv.add_child(UIKit.label(
		"%d vitórias · %d derrotas · pico: %s" % [int(rk["wins"]), int(rk["losses"]), peak["label"]],
		20, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	# ── Escada de ligas ────────────────────────────────────────────────
	var ladder_panel := _card(UIKit.VIOLET)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	ladder_panel.add_child(lv)
	lv.add_child(UIKit.label("LIGAS", 24, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var ladder := HBoxContainer.new()
	ladder.alignment = BoxContainer.ALIGNMENT_CENTER
	ladder.add_theme_constant_override("separation", 8)
	for i in range(Ranked.TIERS.size()):
		var reached := i <= int(t["tier"])
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(36, 36)
		var dot_color := Color(Ranked.TIER_COLORS[i]) if reached else UIKit.SURFACE
		dot.add_theme_stylebox_override("panel", UIKit.dot_style(dot_color, UIKit.OUTLINE, 18))
		if reached:
			var dot_lbl := UIKit.label(str(i + 1), 16, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
			dot_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			dot_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			dot.add_child(dot_lbl)
		ladder.add_child(dot)
	lv.add_child(ladder)
	left.add_child(ladder_panel)

	# ── Botão buscar partida ───────────────────────────────────────────
	_status = UIKit.label(
		"1º e 2º ganham LP · 3º e 4º perdem",
		22, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_status)

	_search_btn = UIKit.button("⚔  BUSCAR PARTIDA", tier_color, 36)
	_search_btn.custom_minimum_size = Vector2(0, 96)
	_search_btn.pressed.connect(_search)
	left.add_child(_search_btn)

	# ── Histórico ──────────────────────────────────────────────────────
	right.add_child(UIKit.label("HISTÓRICO", 28, UIKit.BRAND))
	var hist: Array = rk["history"]
	if hist.is_empty():
		right.add_child(UIKit.label("Nenhuma partida ranqueada ainda.", 22, UIKit.MUTED))
	for h in hist:
		var lp := int(h["lp"])
		var win := lp >= 0
		var hp := _card(UIKit.OK if win else UIKit.DANGER)
		var hl := UIKit.label(
			"%dº lugar  ·  %s pts  ·  %s%d LP  ·  %s" % [
				int(h["placement"]),
				UIKit.fmt_int(int(h["score"])),
				"+" if win else "",
				lp,
				h["tier"]
			], 22)
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hp.add_child(hl)
		right.add_child(hp)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		var wide := _is_wide()
		if wide != _last_wide:
			_last_wide = wide
			_build()


func _search() -> void:
	if _searching:
		return
	_searching = true
	_search_btn.disabled = true
	var elapsed := 0.0
	var wait := randf_range(1.2, 2.6)
	while elapsed < wait:
		_status.text = "Procurando adversários... %ds" % int(elapsed + 1.0)
		await get_tree().create_timer(GameState.anim(0.25)).timeout
		if not is_inside_tree():
			return
		elapsed += 0.25
	var lobby := GameState.find_ranked_lobby()
	var names: Array = []
	for o in lobby:
		names.append("%s (%d)" % [o["name"], int(o["mmr"])])
	_status.text = "Partida encontrada: " + ", ".join(names)
	_status.add_theme_color_override("font_color", UIKit.BRAND)
	Sfx.play("combo")
	await get_tree().create_timer(GameState.anim(1.0)).timeout
	if not is_inside_tree():
		return
	get_tree().change_scene_to_file("res://scenes/BlitzScene.tscn")
