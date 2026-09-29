extends Control
## RankedLobby.tscn — elo atual, histórico e matchmaking por MMR.

var content: VBoxContainer
var search_btn: Button
var status: Label
var searching := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UIKit.background())
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	center.add_child(margin)
	content = VBoxContainer.new()
	content.custom_minimum_size = Vector2(360, 0)
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	_render()


func _render() -> void:
	var rk := GameState.ranked()
	var t := Ranked.tier_info(int(rk["points"]), int(rk["mmr"]))
	var color := Color(Ranked.TIER_COLORS[t["tier"]])

	content.add_child(UIKit.label("MODO RANQUEADO · TEMPORADA %d" % int(rk["season"]), 20, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var badge := UIKit.panel(UIKit.PURPLE_DEEP, color, 20)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 6)
	badge.add_child(bv)
	bv.add_child(UIKit.label(str(t["label"]).to_upper(), 55, color, HORIZONTAL_ALIGNMENT_CENTER))
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = float(t["progress"])
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	var fill := UIKit.box(color, color, 0, 2, 0)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", UIKit.box(UIKit.BLACK, UIKit.BLACK, 0, 2, 0))
	bv.add_child(bar)
	bv.add_child(UIKit.label("%d LP  ·  MMR %s  ·  %dV / %dD" % [int(t["lp"]), UIKit.fmt_int(int(rk["mmr"])), int(rk["wins"]), int(rk["losses"])], 20, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	var peak := Ranked.tier_info(int(rk["peak_points"]), int(rk["mmr"]))
	bv.add_child(UIKit.label("Pico da temporada: %s" % peak["label"], 16, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	content.add_child(badge)

	var ladder := HFlowContainer.new()
	ladder.alignment = FlowContainer.ALIGNMENT_CENTER
	ladder.add_theme_constant_override("h_separation", 6)
	for i in range(Ranked.TIERS.size()):
		var reached := i <= int(t["tier"])
		ladder.add_child(UIKit.label(Ranked.TIERS[i].to_upper(), 15, Color(Ranked.TIER_COLORS[i]) if reached else UIKit.MUTED.darkened(0.3)))
	content.add_child(ladder)

	status = UIKit.label("1º/2º lugar ganham LP · 3º/4º perdem", 18, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(status)
	search_btn = UIKit.button("BUSCAR PARTIDA", color, 28)
	search_btn.pressed.connect(_search)
	content.add_child(search_btn)
	var back := UIKit.button("VOLTAR", UIKit.MUTED, 20)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	content.add_child(back)

	content.add_child(UIKit.label("HISTÓRICO", 22, UIKit.INK))
	var hist: Array = rk["history"]
	if hist.is_empty():
		content.add_child(UIKit.label("Nenhuma partida ranqueada ainda.", 18, UIKit.MUTED))
	for h in hist:
		var lp := int(h["lp"])
		var row := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.OK if lp >= 0 else UIKit.DANGER, 8)
		row.add_child(UIKit.label("%dº  ·  %s pts  ·  %s%d LP  ·  %s" % [int(h["placement"]), UIKit.fmt_int(int(h["score"])), "+" if lp >= 0 else "", lp, h["tier"]], 18))
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
	status.add_theme_color_override("font_color", UIKit.GOLD)
	Sfx.play("combo")
	await get_tree().create_timer(GameState.anim(1.0)).timeout
	if not is_inside_tree():
		return
	GameState.mode = GameState.Mode.RANKED
	get_tree().change_scene_to_file("res://scenes/GameScene.tscn")
