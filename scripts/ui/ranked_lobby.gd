extends Control
## RankedLobby.tscn — elo atual, histórico e matchmaking por MMR.

var content: VBoxContainer
var search_btn: Button
var status: Label
var searching := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UIKit.background())
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 0)
	add_child(page)

	# Cabeçalho fixo: voltar + título.
	var head := PanelContainer.new()
	var hsb := UIKit.box(UIKit.SURFACE, UIKit.BLACK, 3, 0, 12)
	hsb.set_corner_radius_all(0)
	hsb.corner_radius_bottom_left = 28
	hsb.corner_radius_bottom_right = 28
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
	var ttl := UIKit.label("RANQUEADO · TEMPORADA %d" % int(rk0["season"]), 30, UIKit.INK)
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ttl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hrow.add_child(ttl)
	page.add_child(head)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	UIKit.suppress_click_on_scroll(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Widgets.MARGIN)
	center.add_child(margin)
	content = VBoxContainer.new()
	content.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - Widgets.MARGIN * 2.0, 672.0), 0)
	content.add_theme_constant_override("separation", 18)
	margin.add_child(content)
	_render()


func _render() -> void:
	var rk := GameState.ranked()
	var t := Ranked.tier_info(int(rk["points"]), int(rk["mmr"]))
	var color := Color(Ranked.TIER_COLORS[t["tier"]])

	# Cartão da liga: emblema, nome, barra de LP e números.
	var badge := UIKit.panel(UIKit.PURPLE_DEEP, color, 24)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 10)
	badge.add_child(bv)
	var emblem := PanelContainer.new()
	emblem.custom_minimum_size = Vector2(150, 150)
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var esb := UIKit.chunky(color)
	esb.set_corner_radius_all(75)
	esb.content_margin_left = 0
	esb.content_margin_right = 0
	emblem.add_theme_stylebox_override("panel", esb)
	var div := UIKit.label(str(t["division"]) if str(t["division"]) != "" else "★", 64, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	div.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	div.add_theme_color_override("font_outline_color", color.darkened(0.6))
	emblem.add_child(div)
	bv.add_child(emblem)
	bv.add_child(UIKit.label(str(t["label"]).to_upper(), 56, color, HORIZONTAL_ALIGNMENT_CENTER))
	var bar := MeterBar.new()
	bar.custom_minimum_size = Vector2(0, 34)
	bar.set_colors(color, UIKit.OUTLINE)
	bar.set_values(float(t["progress"]), 1.0, false)
	bv.add_child(bar)
	bv.add_child(UIKit.label("%d LP  ·  MMR %s" % [int(t["lp"]), UIKit.fmt_int(int(rk["mmr"]))], 28, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	var peak := Ranked.tier_info(int(rk["peak_points"]), int(rk["mmr"]))
	bv.add_child(UIKit.label("%d vitórias · %d derrotas · pico: %s" % [int(rk["wins"]), int(rk["losses"]), peak["label"]], 20, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	content.add_child(badge)

	# Escada de ligas: uma bolinha por liga, as alcançadas coloridas.
	var ladder := HBoxContainer.new()
	ladder.alignment = BoxContainer.ALIGNMENT_CENTER
	ladder.add_theme_constant_override("separation", 10)
	for i in range(Ranked.TIERS.size()):
		var reached := i <= int(t["tier"])
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(40, 40)
		dot.add_theme_stylebox_override("panel", UIKit.dot_style(Color(Ranked.TIER_COLORS[i]) if reached else UIKit.PURPLE_DEEP, UIKit.OUTLINE, 20))
		ladder.add_child(dot)
	content.add_child(ladder)

	status = UIKit.label("1º e 2º lugar ganham LP · 3º e 4º perdem", 22, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status)
	search_btn = UIKit.button("BUSCAR PARTIDA", color, 36)
	search_btn.custom_minimum_size = Vector2(0, 100)
	search_btn.pressed.connect(_search)
	content.add_child(search_btn)

	content.add_child(UIKit.label("HISTÓRICO", 30, UIKit.INK))
	var hist: Array = rk["history"]
	if hist.is_empty():
		content.add_child(UIKit.label("Nenhuma partida ranqueada ainda.", 22, UIKit.MUTED))
	for h in hist:
		var lp := int(h["lp"])
		var row := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.OK if lp >= 0 else UIKit.DANGER, 14)
		var rl := UIKit.label("%dº lugar  ·  %s pts  ·  %s%d LP  ·  %s" % [int(h["placement"]), UIKit.fmt_int(int(h["score"])), "+" if lp >= 0 else "", lp, h["tier"]], 22)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(rl)
		content.add_child(row)
	search_btn.grab_focus.call_deferred()


func _search() -> void:
	if searching:
		return
	searching = true
	search_btn.disabled = true
	var elapsed := 0.0
	var wait := randf_range(1.2, 2.6)
	while elapsed < wait:
		status.text = "Procurando adversários... %ds" % int(elapsed + 1.0)
		await get_tree().create_timer(GameState.anim(0.25)).timeout
		if not is_inside_tree():
			return
		elapsed += 0.25
	var lobby := GameState.find_ranked_lobby()
	var names: Array = []
	for o in lobby:
		names.append("%s (%d)" % [o["name"], int(o["mmr"])])
	status.text = "Partida encontrada: " + ", ".join(names)
	status.add_theme_color_override("font_color", UIKit.BRAND)
	Sfx.play("combo")
	await get_tree().create_timer(GameState.anim(1.0)).timeout
	if not is_inside_tree():
		return
	GameState.mode = GameState.Mode.RANKED
	get_tree().change_scene_to_file("res://scenes/GameScene.tscn")
