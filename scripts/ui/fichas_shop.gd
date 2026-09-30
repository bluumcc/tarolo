class_name FichasShop
extends RefCounted
## Conteúdo do popup de fichas: saldo, recarga diária grátis e pacotes (compra SIMULADA).
## Reutilizável: `FichasShop.fill(container, on_change)` em qualquer popup.

## Abre o popup de fichas: cabeçalho e botão FECHAR fixos; só a lista rola.
static func open(host: Control, on_change: Callable = Callable()) -> Control:
	var ov := UIKit.overlay()
	host.add_child(ov)
	var box := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.BRAND, 16)
	var vp := host.get_viewport_rect().size
	box.custom_minimum_size = Vector2(minf(vp.x - 32.0, 660.0), 0)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	box.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := UIKit.label("FICHAS", 40, UIKit.BRAND, HORIZONTAL_ALIGNMENT_CENTER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := Widgets.icon_button("✕", UIKit.MUTED)
	x.pressed.connect(func(): ov.queue_free())
	head.add_child(x)
	var bal_holder := VBoxContainer.new()
	v.add_child(bal_holder)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, clampf(vp.y * 0.55, 260.0, 720.0))
	v.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	var close := UIKit.button("FECHAR", UIKit.MUTED, 30)
	close.custom_minimum_size = Vector2(0, 72)
	close.pressed.connect(func(): ov.queue_free())
	v.add_child(close)
	var wrap := CenterContainer.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(box)
	ov.add_child(wrap)
	var state := {"bal": bal_holder}
	state["render"] = func():
		for c in body.get_children():
			c.queue_free()
		for c in bal_holder.get_children():
			c.queue_free()
		_build(body, state, on_change)
	(state["render"] as Callable).call()
	UIKit.pop_in(box, GameState.anim(0.2))
	return ov


static func _build(body: VBoxContainer, state: Dictionary, on_change: Callable) -> void:
	var prof := SaveManager.section("profile")
	var bal := UIKit.label("◎ %s" % UIKit.fmt_int(int(prof["fichas"])), 52, UIKit.MONEY, HORIZONTAL_ALIGNMENT_CENTER)
	(state["bal"] as VBoxContainer).add_child(bal)
	var info := UIKit.label("Fichas só valem dentro do jogo e não podem ser sacadas.", 20, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(state["bal"] as VBoxContainer).add_child(info)

	# Recarga diária: 1 por dia, só quando as fichas não pagam nem a entrada mais barata.
	var daily := UIKit.panel(UIKit.PURPLE, UIKit.OK, 12)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 6)
	daily.add_child(dv)
	dv.add_child(UIKit.label("RECARGA DIÁRIA GRÁTIS", 26, UIKit.GAIN, HORIZONTAL_ALIGNMENT_CENTER))
	var avail := ChaosEconomy.daily_available(prof)
	var msg := "Suas fichas acabaram: colete ◎%d agora." % ChaosEconomy.DAILY_AMOUNT
	if not avail:
		if ChaosEconomy.claimed_today(prof):
			msg = "Você já coletou hoje. Volta amanhã!"
		else:
			msg = "Liberada quando você tiver menos de ◎%d (a entrada mais barata). Uma vez por dia." % ChaosEconomy.DAILY_MIN
	var ml := UIKit.label(msg, 22, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(ml)
	var claim := UIKit.button("COLETAR +◎%d" % ChaosEconomy.DAILY_AMOUNT, UIKit.OK, 30)
	claim.custom_minimum_size = Vector2(0, 72)
	claim.disabled = not avail
	claim.pressed.connect(func():
		var got := ChaosEconomy.claim_daily(prof)
		if got > 0:
			SaveManager.save_game()
			UIKit.sfx("win")
			_changed(state, on_change))
	dv.add_child(claim)
	body.add_child(daily)

	body.add_child(UIKit.label("PACOTES", 26, UIKit.MONEY, HORIZONTAL_ALIGNMENT_CENTER))
	for pk in ChaosEconomy.PACKS:
		body.add_child(_pack_row(pk, prof, state, on_change))
	var note := UIKit.label("Compra simulada: nenhum valor é cobrado por enquanto.", 18, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)


static func _pack_row(pk: Dictionary, prof: Dictionary, state: Dictionary, on_change: Callable) -> PanelContainer:
	var row := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.MUTED, 8)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	row.add_child(h)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 0)
	h.add_child(left)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	left.add_child(top)
	top.add_child(UIKit.label("◎ %s" % UIKit.fmt_int(int(pk["fichas"])), 32, UIKit.MONEY))
	top.add_child(UIKit.label(str(pk["name"]).to_upper(), 20, UIKit.INK))
	var bonus := ChaosEconomy.bonus_pct(pk)
	var sub := ("+%d%% bônus" % bonus) if bonus > 0 else "pacote base"
	if str(pk["tag"]) != "":
		sub += "  ·  " + str(pk["tag"])
	var sl := UIKit.label(sub, 18, UIKit.GAIN if bonus > 0 else UIKit.MUTED)
	left.add_child(sl)
	var buy := UIKit.button(ChaosEconomy.price_text(int(pk["price_cents"])), UIKit.ACTION, 28)
	buy.custom_minimum_size = Vector2(170, 68)
	buy.pressed.connect(func():
		var got := ChaosEconomy.buy_simulated(prof, str(pk["id"]))
		if got > 0:
			SaveManager.save_game()
			UIKit.sfx("jackpot")
			_changed(state, on_change))
	h.add_child(buy)
	return row


static func _changed(state: Dictionary, on_change: Callable) -> void:
	if on_change.is_valid():
		on_change.call()
	(state["render"] as Callable).call()
