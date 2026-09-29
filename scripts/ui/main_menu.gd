extends Control
## MainMenu.tscn — navegação para os modos, Loja de Cosméticos e Configurações.

var overlay_layer: Control
var fragments_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UIKit.background())
	_spawn_stars()

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x * 0.9, 480.0), 0)
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	var title := UIKit.label("TAROLO", 64, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(title)
	var sub := UIKit.label("— JOGO DE VAZAS —", 20, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(sub)
	col.add_child(_spacer(16))

	var tut := UIKit.button("TUTORIAL", UIKit.OK, 22)
	tut.pressed.connect(func():
		GameState.start_tutorial()
		get_tree().change_scene_to_file("res://scenes/GameScene.tscn"))
	col.add_child(tut)
	col.add_child(_caption("Primeira vez? Uma mão guiada, com dicas em cada regra nova."))

	var classic := UIKit.button("MODO VANILLA", UIKit.GOLD, 22)
	classic.pressed.connect(func():
		GameState.mode = GameState.Mode.CLASSIC
		get_tree().change_scene_to_file("res://scenes/GameScene.tscn"))
	col.add_child(classic)
	col.add_child(_caption("Tarot clássico: baralho de 78 cartas, trunfo e O Louco."))

	var chaos := UIKit.button("MODO CAOS", UIKit.DANGER, 22)
	chaos.pressed.connect(_open_chaos_confirm)
	col.add_child(chaos)
	col.add_child(_caption("5 rodadas relâmpago, item novo por rodada, fichas na mesa, Fôlego pra quem tá por baixo."))

	var rk := GameState.ranked()
	var tier := Ranked.tier_info(int(rk["points"]), int(rk["mmr"]))
	var ranked := UIKit.button("MODO RANQUEADO", Color(Ranked.TIER_COLORS[tier["tier"]]), 22)
	ranked.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/RankedLobby.tscn"))
	col.add_child(ranked)
	col.add_child(_caption("Temporada %d · %s · %d LP" % [int(rk["season"]), tier["label"], int(tier["lp"])]))

	col.add_child(_spacer(8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var cosm := UIKit.button("COSMÉTICOS", UIKit.MUTED, 17)
	cosm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cosm.pressed.connect(_open_cosmetics)
	row.add_child(cosm)
	var sett := UIKit.button("CONFIGURAÇÕES", UIKit.MUTED, 17)
	sett.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sett.pressed.connect(_open_settings)
	row.add_child(sett)
	var rules := UIKit.button("COMO JOGAR", UIKit.MUTED, 17)
	rules.pressed.connect(_open_rules)
	col.add_child(rules)
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		var quit := UIKit.button("SAIR", UIKit.DANGER, 17)
		quit.pressed.connect(func(): get_tree().quit())
		col.add_child(quit)

	fragments_label = UIKit.label("", 14, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(fragments_label)
	_refresh_fragments()

	overlay_layer = Control.new()
	overlay_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay_layer)

	classic.grab_focus.call_deferred()
	title.pivot_offset = Vector2(170, 30)
	title.modulate.a = 0.0
	create_tween().tween_property(title, "modulate:a", 1.0, GameState.anim(0.6))


func _refresh_fragments() -> void:
	var prof := SaveManager.section("profile")
	fragments_label.text = "%s · %d partidas · %d vitórias · ◆ %s Fragmentos · 🪙 %s Fichas" % [prof["name"], int(prof["matches"]), int(prof["wins"]), UIKit.fmt_int(int(prof["fragments"])), UIKit.fmt_int(int(prof["fichas"]))]


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _caption(text: String) -> Label:
	var l := UIKit.label(text, 13, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
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


func _modal(title: String) -> VBoxContainer:
	var ov := UIKit.overlay()
	overlay_layer.add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.GOLD, 24)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(360, 0)
	box.add_child(v)
	v.add_child(UIKit.label(title, 30, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(box)
	scroll.add_child(center)
	ov.add_child(scroll)
	return v


func _close_button(v: VBoxContainer) -> void:
	var close := UIKit.button("FECHAR", UIKit.MUTED)
	close.pressed.connect(func():
		overlay_layer.get_child(overlay_layer.get_child_count() - 1).queue_free())
	v.add_child(close)
	close.grab_focus.call_deferred()


func _open_settings() -> void:
	var v := _modal("CONFIGURAÇÕES")
	var profile := SaveManager.section("profile")
	v.add_child(UIKit.label("Seu nome", 16))
	var name_edit := LineEdit.new()
	name_edit.text = str(profile["name"])
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(0, 40)
	name_edit.add_theme_stylebox_override("normal", UIKit.box(UIKit.PURPLE_DEEP, UIKit.MUTED, 2, 6, 10))
	name_edit.add_theme_stylebox_override("focus", UIKit.box(UIKit.PURPLE_DEEP, UIKit.GOLD, 2, 6, 10))
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
	v.add_child(UIKit.label("Como ver sua mão de cartas", 16))
	var hand_row := HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 10)
	v.add_child(hand_row)
	var hand_row_btn := UIKit.button("FILEIRA", UIKit.OK if str(s["hand_layout"]) == "row" else UIKit.MUTED, 15)
	hand_row_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_row_btn.pressed.connect(func():
		s["hand_layout"] = "row"
		SaveManager.save_game()
		_reopen_settings())
	hand_row.add_child(hand_row_btn)
	var hand_fan_btn := UIKit.button("LEQUE", UIKit.OK if str(s["hand_layout"]) == "fan" else UIKit.MUTED, 15)
	hand_fan_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_fan_btn.pressed.connect(func():
		s["hand_layout"] = "fan"
		SaveManager.save_game()
		_reopen_settings())
	hand_row.add_child(hand_fan_btn)
	v.add_child(_caption("Fileira: cartas em linha reta, rola de lado se não couber tudo. Leque: cartas em arco, como segurar um baralho de verdade."))
	for entry in [["Música", "music_volume"], ["Efeitos", "sfx_volume"]]:
		v.add_child(UIKit.label(entry[0], 16))
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
	v.add_child(UIKit.label("Velocidade das animações", 16))
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
	var reset := UIKit.button("APAGAR PROGRESSO", UIKit.DANGER, 14)
	reset.pressed.connect(func():
		SaveManager.reset()
		get_tree().reload_current_scene())
	v.add_child(reset)
	var close := UIKit.button("SALVAR E FECHAR")
	close.pressed.connect(func():
		SaveManager.save_game()
		overlay_layer.get_child(overlay_layer.get_child_count() - 1).queue_free())
	v.add_child(close)


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
	v.add_child(UIKit.label("◆ %s Fragmentos" % UIKit.fmt_int(int(prof["fragments"])), 16, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	for id in UIKit.CARD_BACKS.keys():
		var back: Dictionary = UIKit.CARD_BACKS[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var swatch := Panel.new()
		swatch.custom_minimum_size = Vector2(36, 50)
		swatch.add_theme_stylebox_override("panel", UIKit.box(Color(back["color"]), UIKit.GOLD.darkened(0.35), 3, 4, 0))
		row.add_child(swatch)
		var name_l := UIKit.label(str(back["name"]), 18)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		var owned: Array = cos["owned"]
		var btn: Button
		if str(cos["equipped"]) == id:
			btn = UIKit.button("EQUIPADO", UIKit.OK, 14)
			btn.disabled = true
		elif owned.has(id):
			btn = UIKit.button("EQUIPAR", UIKit.OK, 14)
			btn.pressed.connect(func():
				cos["equipped"] = id
				SaveManager.save_game()
				_reopen_cosmetics())
		elif back.has("requires_tier"):
			var req := int(back["requires_tier"])
			btn = UIKit.button("DESBLOQUEAR" if peak_tier >= req else "REQ. %s" % Ranked.TIERS[req].to_upper(), UIKit.GOLD, 14)
			btn.disabled = peak_tier < req
			btn.pressed.connect(func():
				owned.append(id)
				Sfx.play("buy")
				SaveManager.save_game()
				_reopen_cosmetics())
		else:
			var price := int(back["price"])
			btn = UIKit.button("◆ %d" % price, UIKit.GOLD, 14)
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
	var v := _modal("MESA CAOS")
	var profile := SaveManager.section("profile")
	var buy_in := int(ChaosEngine.BUY_IN)
	var fichas := int(profile["fichas"])
	v.add_child(UIKit.label("Buy-in: %d fichas" % buy_in, 18, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("Você tem %d fichas" % fichas, 14, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var pot_text := "Pote da mesa (4 jogadores): %d fichas\n1º leva 50%% · 2º 30%% · 3º 15%% · 4º 5%%" % (buy_in * 4)
	var pot_l := UIKit.label(pot_text, 13, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	pot_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pot_l.custom_minimum_size = Vector2(320, 0)
	v.add_child(pot_l)
	if fichas < buy_in:
		v.add_child(UIKit.label("Fichas insuficientes pra entrar.", 14, UIKit.DANGER, HORIZONTAL_ALIGNMENT_CENTER))
		var loan := UIKit.button("EMPRÉSTIMO DA CASA (%d fichas)" % buy_in, UIKit.GOLD)
		loan.pressed.connect(func():
			profile["fichas"] = buy_in
			SaveManager.save_game()
			_refresh_fragments()
			overlay_layer.get_child(overlay_layer.get_child_count() - 1).queue_free()
			_open_chaos_confirm())
		v.add_child(loan)
		_close_button(v)
		return
	var enter := UIKit.button("ENTRAR NA MESA", UIKit.DANGER)
	enter.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ChaosScene.tscn"))
	v.add_child(enter)
	_close_button(v)


func _open_rules() -> void:
	var v := _modal("COMO JOGAR")
	var text := """• Baralho de 78 cartas: 4 naipes de 14 (Ás a Rei, com Cavaleiro entre Valete e Rainha), 21 Trunfos e O Louco.
• Dentro do naipe, Ás é a carta mais baixa; sobe até Rei. Trunfo sempre vence naipe comum; entre trunfos, vence o maior número.
• Obrigado a seguir o naipe líder. Sem ele, é obrigado a jogar Trunfo — e se alguém já cortou, precisa cobrir com um Trunfo maior, se tiver.
• O Louco pode ser jogado a qualquer momento, nunca vence a vaza, mas o dono guarda os pontos dele.
• Le Petit (trunfo 1), Le Monde (trunfo 21) e O Louco são os 3 Bouts — as cartas mais valiosas do jogo.
• Licitação: cada jogador, na sua vez, passa ou dá um lance mais alto (Petite x1, Garde x2, Garde Sans x4, Garde Contre x6). O lance não custa fichas — é só a declaração de quão confiante você está. Quem der o maior lance vira o Tomador e joga sozinho contra os outros 3.
• Com Petite ou Garde, o talão (6 cartas escondidas) entra na sua mão e você mesmo escolhe 6 cartas pra devolver — nunca Reis ou Bouts, só cartas comuns (Trunfo comum só se faltar carta comum).
• No fim, o Tomador some os pontos que capturou: precisa de 56 pts com 0 Bouts, 51 com 1, 41 com 2 ou 36 com 3 pra vencer a rodada.
• Depois da licitação, o Tomador escolhe: declarar Poignée (mostra os trunfos, ganha pontos extras se tiver 10+) e/ou anunciar Chelem (apostar que vence as 18 vazas — rende mais se anunciado, mas pune se falhar). Petit au bout (vencer a última vaza com Le Petit) é automático.
• Ranqueado: sua colocação entre 4 jogadores define LP e MMR.
• Primeira vez? Joga o TUTORIAL — uma mão guiada com dicas em cada regra nova."""
	var l := UIKit.label(text, 15, UIKit.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(420, 0)
	v.add_child(l)
	_close_button(v)
