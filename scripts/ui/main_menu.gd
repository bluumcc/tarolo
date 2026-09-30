extends Control
## MainMenu.tscn — navegação para os modos, Loja de Cosméticos e Configurações.

var overlay_layer: Control
var top_bar: PanelContainer



func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UIKit.background())
	_spawn_stars()

	# Estrutura da tela: barra superior fixa · conteúdo rolável · navegação inferior fixa.
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 0)
	add_child(page)

	var prof := SaveManager.section("profile")
	top_bar = Widgets.top_bar(str(prof["name"]), "%d vitórias · %d partidas" % [int(prof["wins"]), int(prof["matches"])], UIKit.fmt_int(int(prof["fichas"])), UIKit.fmt_int(int(prof["fragments"])))
	top_bar.custom_minimum_size = Vector2(0, Widgets.TOPBAR_H)
	page.add_child(top_bar)
	var chips_pill := top_bar.find_child("ChipsPill", true, false) as Control
	chips_pill.mouse_filter = Control.MOUSE_FILTER_STOP
	chips_pill.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			UIKit.sfx("tick")
			_open_fichas())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	UIKit.suppress_click_on_scroll(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - Widgets.MARGIN * 2.0, 1040.0 if get_viewport_rect().size.x > get_viewport_rect().size.y else 672.0), 0)
	col.add_theme_constant_override("separation", 18)
	center.add_child(col)

	# Herói: logo + leque de cartas de enfeite.
	col.add_child(_hero())

	var rk := GameState.ranked()
	var tier := Ranked.tier_info(int(rk["points"]), int(rk["mmr"]))
	var chaos := Widgets.mode_card("MODO CAOS", "Poker de rodadas: aposte, blefe e leve o pote. Com modificadores e combos!", UIKit.DANGER, 176 if get_viewport_rect().size.y > get_viewport_rect().size.x else 150, "⚡", _open_chaos_confirm, 46)
	col.add_child(chaos)
	var blitz := Widgets.mode_card("MODO BLITZ", "Dê o palpite: quantas rodadas você vai ganhar? Acertou, leva o pote!", UIKit.INFO, 150 if get_viewport_rect().size.y > get_viewport_rect().size.x else 132, "❖", _open_blitz_confirm, 40)
	col.add_child(blitz)
	var wide := get_viewport_rect().size.x > get_viewport_rect().size.y
	var grid := GridContainer.new()
	grid.columns = 3 if wide else 1
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	col.add_child(grid)
	var h := 150 if wide else 132
	var cards := [
		Widgets.mode_card("VANILLA", "Tarot clássico: 78 cartas, trunfo e O Louco.", UIKit.BRAND.darkened(0.12), h, "♛", func():
			GameState.mode = GameState.Mode.CLASSIC
			GameState.leave_table()
			get_tree().change_scene_to_file("res://scenes/GameScene.tscn"), 34),
		Widgets.mode_card("RANQUEADO", "Temporada %d · %s · %d LP" % [int(rk["season"]), tier["label"], int(tier["lp"])], Color(Ranked.TIER_COLORS[tier["tier"]]).darkened(0.1), h, "⚔", func(): get_tree().change_scene_to_file("res://scenes/RankedLobby.tscn"), 34),
		Widgets.mode_card("TUTORIAL", "Primeira vez? Uma mão guiada, com dicas.", UIKit.OK.darkened(0.15), h, "?", func():
			GameState.start_tutorial()
			get_tree().change_scene_to_file("res://scenes/GameScene.tscn"), 34),
	]
	for c in cards:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(c)
	col.add_child(_spacer(8))

	var nav := Widgets.bottom_nav([
		{"icon": "★", "label": "Cosméticos", "cb": _open_cosmetics},
		{"icon": "?", "label": "Como jogar", "cb": _open_rules},
		{"icon": "⚡", "label": "CAOS", "cb": _open_chaos_confirm, "center": true},
		{"icon": "⚙", "label": "Ajustes", "cb": _open_settings},
		{"icon": "♚", "label": "Ranking", "cb": func(): get_tree().change_scene_to_file("res://scenes/RankedLobby.tscn")},
	])
	nav.custom_minimum_size = Vector2(0, Widgets.NAV_H)
	page.add_child(nav)

	overlay_layer = Control.new()
	overlay_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay_layer)
	chaos.grab_focus.call_deferred()


## Logo do jogo com três cartas em leque (as mesmas do jogo, só de enfeite).
func _hero() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var fan := Control.new()
	fan.custom_minimum_size = Vector2(0, 210 if get_viewport_rect().size.y > get_viewport_rect().size.x else 150)
	fan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(fan)
	var wide := get_viewport_rect().size.x > get_viewport_rect().size.y
	var cx := 520.0 if wide else 336.0
	var sc := 0.5 if wide else 0.62
	var specs := [[CardData.Suit.COPAS, 14, -14.0, -110.0], [CardData.Suit.TRUNFO, 21, 0.0, 0.0], [CardData.Suit.ESPADAS, 12, 14.0, 110.0]]
	for sp in specs:
		var cv: CardView = preload("res://scenes/Card.tscn").instantiate()
		cv.setup(CardData.make(sp[0], sp[1]), true)
		cv.interactive = false
		cv.scale = Vector2(sc, sc)
		cv.rotation_degrees = sp[2]
		fan.add_child(cv)
		cv.position = Vector2(cx + sp[3] * (sc / 0.62) - CardView.SIZE.x / 2.0, 10.0 - abs(sp[2]) * 1.2)
	var title := UIKit.label("TAROLO", 88, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_outline_color", UIKit.TITLE_OUTLINE)
	title.add_theme_constant_override("outline_size", 14)
	box.add_child(title)
	var sub := UIKit.label("JOGO DE RODADAS", 26, UIKit.BRAND, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(sub)
	return box


## Popup das fichas: saldo, recarga diária grátis e pacotes (compra simulada).
func _open_fichas() -> void:
	FichasShop.open(overlay_layer, _refresh_fragments)


func _refresh_fragments() -> void:
	var prof := SaveManager.section("profile")
	if top_bar:
		Widgets.set_pill_value(top_bar.find_child("ChipsPill", true, false), UIKit.fmt_int(int(prof["fichas"])))
		Widgets.set_pill_value(top_bar.find_child("FragsPill", true, false), UIKit.fmt_int(int(prof["fragments"])))


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _caption(text: String) -> Label:
	var l := UIKit.label(text, 16, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _spawn_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var vp := get_viewport_rect().size
	for i in range(14):
		var s := UIKit.label("✶" if i % 3 else "♦", rng.randi_range(12, 30), UIKit.PURPLE.lightened(0.25))
		s.position = Vector2(rng.randf() * vp.x, rng.randf() * vp.y)
		s.modulate.a = rng.randf_range(0.15, 0.5)
		add_child(s)
		var tw := s.create_tween().set_loops()
		tw.tween_property(s, "position:y", s.position.y - 30.0, rng.randf_range(3.0, 6.0)).set_trans(Tween.TRANS_SINE)
		tw.tween_property(s, "position:y", s.position.y, rng.randf_range(3.0, 6.0)).set_trans(Tween.TRANS_SINE)


## Popup com cabeçalho (título) e rodapé fixos; só o meio rola, como o popup de Fichas e o de
## Ajuda em passos — nunca deixa o popup crescer sem fim. Devolve o corpo (rolável): tudo que o
## chamador adiciona nele fica dentro da área que rola. Pra um botão fixo no rodapé (ex.: FECHAR),
## use `_close_button` ou pegue o rodapé com `body.get_meta("modal_footer")`.
func _modal(title: String) -> VBoxContainer:
	var ov := UIKit.overlay()
	overlay_layer.add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.BRAND, 24)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	outer.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 96.0, 580.0), 0)
	box.add_child(outer)
	outer.add_child(UIKit.label(title, 38, UIKit.BRAND, HORIZONTAL_ALIGNMENT_CENTER))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Folga generosa: título + rodapé (até 2 botões) + esse teto sempre cabem dentro do teto de
	# 75% do UIKit.centered() que envolve o popup — assim só existe UM scroll (esse aqui dentro),
	# nunca dois competindo (o de fora nunca precisa entrar em ação).
	scroll.custom_minimum_size = Vector2(0, clampf(get_viewport_rect().size.y * 0.42, 220.0, 480.0))
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
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


func _close_button(body: VBoxContainer) -> void:
	var footer: Node = body.get_meta("modal_footer", body)
	var close := UIKit.button("FECHAR", UIKit.MUTED)
	close.pressed.connect(func():
		overlay_layer.get_child(overlay_layer.get_child_count() - 1).queue_free())
	footer.add_child(close)
	close.grab_focus.call_deferred()


func _open_settings() -> void:
	var v := _modal("CONFIGURAÇÕES")
	var profile := SaveManager.section("profile")
	v.add_child(UIKit.label("Seu nome", 20))
	var name_edit := LineEdit.new()
	name_edit.text = str(profile["name"])
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(0, 40)
	name_edit.add_theme_stylebox_override("normal", UIKit.box(UIKit.PURPLE_DEEP, UIKit.MUTED, 2, 6, 10))
	name_edit.add_theme_stylebox_override("focus", UIKit.box(UIKit.PURPLE_DEEP, UIKit.BRAND, 2, 6, 10))
	name_edit.add_theme_color_override("font_color", UIKit.INK)
	name_edit.add_theme_color_override("font_placeholder_color", UIKit.MUTED)
	name_edit.placeholder_text = "Arcanista"
	name_edit.text_submitted.connect(func(_t: String): name_edit.release_focus())
	name_edit.focus_exited.connect(func():
		var clean := name_edit.text.strip_edges()
		profile["name"] = clean if not clean.is_empty() else "Arcanista"
		name_edit.text = str(profile["name"])
		SaveManager.save_game()
		_refresh_fragments())
	v.add_child(name_edit)
	var s := GameState.settings()
	v.add_child(UIKit.label("Como ver sua mão de cartas", 20))
	var hand_row := HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 10)
	v.add_child(hand_row)
	var hand_row_btn := UIKit.button("FILEIRA", UIKit.OK if str(s["hand_layout"]) == "row" else UIKit.MUTED, 19)
	hand_row_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_row_btn.pressed.connect(func():
		s["hand_layout"] = "row"
		SaveManager.save_game()
		_reopen_settings())
	hand_row.add_child(hand_row_btn)
	var hand_fan_btn := UIKit.button("LEQUE", UIKit.OK if str(s["hand_layout"]) == "fan" else UIKit.MUTED, 19)
	hand_fan_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_fan_btn.pressed.connect(func():
		s["hand_layout"] = "fan"
		SaveManager.save_game()
		_reopen_settings())
	hand_row.add_child(hand_fan_btn)
	v.add_child(UIKit.label("Dificuldade dos bots", 20))
	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 10)
	v.add_child(diff_row)
	for d in range(3):
		var db := UIKit.button(str(BotAI.DIFFICULTY_NAMES[d]).to_upper(), UIKit.OK if int(s["difficulty"]) == d else UIKit.MUTED, 19)
		db.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		db.pressed.connect(func():
			s["difficulty"] = d
			SaveManager.save_game()
			_reopen_settings())
		diff_row.add_child(db)
	for entry in [["Música", "music_volume"], ["Efeitos", "sfx_volume"]]:
		v.add_child(UIKit.label(entry[0], 20))
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = float(s[entry[1]])
		sl.custom_minimum_size = Vector2(0, 32)
		var key: String = entry[1]
		sl.value_changed.connect(func(val: float):
			s[key] = val
			GameState.apply_settings())
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
		fs.toggled.connect(func(on: bool):
			s["fullscreen"] = on
			GameState.apply_settings())
		v.add_child(fs)
	var footer: Node = v.get_meta("modal_footer", v)
	var reset := UIKit.button("APAGAR PROGRESSO", UIKit.DANGER, 18)
	reset.pressed.connect(func():
		SaveManager.reset()
		get_tree().reload_current_scene())
	footer.add_child(reset)
	var close := UIKit.button("SALVAR E FECHAR")
	close.pressed.connect(func():
		SaveManager.save_game()
		overlay_layer.get_child(overlay_layer.get_child_count() - 1).queue_free())
	footer.add_child(close)


func _reopen_settings() -> void:
	for c in overlay_layer.get_children():
		c.queue_free()
	_open_settings()


func _open_cosmetics() -> void:
	var v := _modal("LOJA DE COSMÉTICOS")
	var cos := SaveManager.section("cosmetics")
	var prof := SaveManager.section("profile")
	var rk := GameState.ranked()
	var peak_tier := int(Ranked.tier_info(int(rk["peak_points"]), int(rk["mmr"]))["tier"])
	v.add_child(UIKit.label("◆ %s Fragmentos" % UIKit.fmt_int(int(prof["fragments"])), 20, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	for id in UIKit.CARD_BACKS.keys():
		var back: Dictionary = UIKit.CARD_BACKS[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var swatch := Panel.new()
		swatch.custom_minimum_size = Vector2(36, 50)
		swatch.add_theme_stylebox_override("panel", UIKit.box(Color(back["color"]), UIKit.BRAND.darkened(0.35), 3, 4, 0))
		row.add_child(swatch)
		var name_l := UIKit.label(str(back["name"]), 22)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		var owned: Array = cos["owned"]
		var btn: Button
		if str(cos["equipped"]) == id:
			btn = UIKit.button("EQUIPADO", UIKit.OK, 18)
			btn.disabled = true
		elif owned.has(id):
			btn = UIKit.button("EQUIPAR", UIKit.OK, 18)
			btn.pressed.connect(func():
				cos["equipped"] = id
				SaveManager.save_game()
				_reopen_cosmetics())
		elif back.has("requires_tier"):
			var req := int(back["requires_tier"])
			btn = UIKit.button("DESBLOQUEAR" if peak_tier >= req else "REQ. %s" % Ranked.TIERS[req].to_upper(), UIKit.ACTION, 18)
			btn.disabled = peak_tier < req
			btn.pressed.connect(func():
				owned.append(id)
				Sfx.play("buy")
				SaveManager.save_game()
				_reopen_cosmetics())
		else:
			var price := int(back["price"])
			btn = UIKit.button("◆ %d" % price, UIKit.ACTION, 18)
			btn.disabled = int(prof["fragments"]) < price
			btn.pressed.connect(func():
				prof["fragments"] = int(prof["fragments"]) - price
				owned.append(id)
				Sfx.play("buy")
				SaveManager.save_game()
				_refresh_fragments()
				_reopen_cosmetics())
		btn.custom_minimum_size = Vector2(130, 44)
		row.add_child(btn)
		v.add_child(row)
	_close_button(v)


func _reopen_cosmetics() -> void:
	for c in overlay_layer.get_children():
		c.queue_free()
	_open_cosmetics()


func _open_chaos_confirm() -> void:
	_open_table_select("chaos")


func _open_blitz_confirm() -> void:
	_open_table_select("blitz")


## Escolha da mesa (blind + entrada) pros dois modos de mesa: Caos e Blitz.
func _open_table_select(mode: String) -> void:
	var blitz := mode == "blitz"
	var v := _modal("MESA BLITZ" if blitz else "MESA CAOS")
	var profile := SaveManager.section("profile")
	var fichas := int(profile["fichas"])
	v.add_child(UIKit.label("Você tem %d fichas" % fichas, 22, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var txt := "Escolha a mesa. Você senta com uma stack de 40 blinds, palpita quantas rodadas vai ganhar em cada nível (acertou o número exato, leva o pote) e leva de volta a stack quando sair." if blitz else "Escolha a mesa. Você senta com uma stack de 40 blinds, aposta a cada rodada (passar, aumentar, pagar ou desistir) e leva de volta a stack quando sair."
	var info := UIKit.label(txt, 20, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(620, 0)
	v.add_child(info)
	var cheapest := GameState.chaos_buy_in(0)
	if fichas < cheapest:
		v.add_child(UIKit.label("Fichas insuficientes pra entrar.", 22, UIKit.LOSS, HORIZONTAL_ALIGNMENT_CENTER))
		var shop := UIKit.button("RECARGA E PACOTES", UIKit.OK)
		shop.pressed.connect(func():
			overlay_layer.get_child(overlay_layer.get_child_count() - 1).queue_free()
			_open_fichas())
		v.add_child(shop)
		_close_button(v)
		return
	for i in range(GameState.CHAOS_TABLES.size()):
		var t: Dictionary = GameState.CHAOS_TABLES[i]
		var cost := GameState.chaos_buy_in(i)
		var entry_txt := "entrada ◎%d" % (int(t["blind"]) * 2) if blitz else "blind ◎%d" % int(t["blind"])
		var b := UIKit.button("%s · %s · stack ◎%d" % [str(t["name"]).to_upper(), entry_txt, cost], (UIKit.INFO if blitz else UIKit.DANGER) if i == 0 else UIKit.PURPLE, 26)
		b.disabled = fichas < cost
		b.pressed.connect(func():
			GameState.chaos_table = i
			GameState.chaos_mode = mode
			get_tree().change_scene_to_file("res://scenes/ChaosScene.tscn"))
		v.add_child(b)
	_close_button(v)


func _open_rules() -> void:
	StepsModal.open(overlay_layer, "COMO JOGAR", HelpContent.vanilla(), "ENTENDI", false)
