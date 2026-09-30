class_name FichasShop
extends RefCounted
## Conteúdo do popup de fichas: saldo, recarga diária grátis e pacotes (compra SIMULADA).
## Reutilizável: `FichasShop.fill(container, on_change)` em qualquer popup.

static func fill(v: VBoxContainer, on_change: Callable = Callable()) -> void:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	v.add_child(body)
	var state := {}
	state["render"] = func():
		for c in body.get_children():
			c.queue_free()
		_build(body, state, on_change)
	(state["render"] as Callable).call()


static func _build(body: VBoxContainer, state: Dictionary, on_change: Callable) -> void:
	var prof := SaveManager.section("profile")
	var bal := UIKit.label("◎ %s" % UIKit.fmt_int(int(prof["fichas"])), 64, UIKit.MONEY, HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(bal)
	var info := UIKit.label("Fichas são o dinheiro do jogo: pagam a entrada das mesas e entram nas apostas. Elas só valem dentro do jogo e não podem ser sacadas.", 24, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(info)

	# Recarga diária: 1 por dia, só quando as fichas não pagam nem a entrada mais barata.
	var daily := UIKit.panel(UIKit.PURPLE, UIKit.OK, 12)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 6)
	daily.add_child(dv)
	dv.add_child(UIKit.label("RECARGA DIÁRIA GRÁTIS", 28, UIKit.GAIN, HORIZONTAL_ALIGNMENT_CENTER))
	var avail := ChaosEconomy.daily_available(prof)
	var msg := "Suas fichas acabaram: colete ◎%d agora." % ChaosEconomy.DAILY_AMOUNT
	if not avail:
		if ChaosEconomy.claimed_today(prof):
			msg = "Você já coletou hoje. Volta amanhã!"
		else:
			msg = "Liberada quando você tiver menos de ◎%d (a entrada mais barata). Uma vez por dia." % ChaosEconomy.DAILY_MIN
	var ml := UIKit.label(msg, 24, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(ml)
	var claim := UIKit.button("COLETAR +◎%d" % ChaosEconomy.DAILY_AMOUNT, UIKit.OK)
	claim.disabled = not avail
	claim.pressed.connect(func():
		var got := ChaosEconomy.claim_daily(prof)
		if got > 0:
			SaveManager.save_game()
			UIKit.sfx("win")
			_changed(state, on_change))
	dv.add_child(claim)
	body.add_child(daily)

	body.add_child(UIKit.label("PACOTES DE FICHAS", 28, UIKit.MONEY, HORIZONTAL_ALIGNMENT_CENTER))
	for pk in ChaosEconomy.PACKS:
		body.add_child(_pack_row(pk, prof, state, on_change))
	var note := UIKit.label("Compra simulada: nenhum valor é cobrado por enquanto.", 20, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)


static func _pack_row(pk: Dictionary, prof: Dictionary, state: Dictionary, on_change: Callable) -> PanelContainer:
	var row := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.MUTED, 10)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	row.add_child(h)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 0)
	h.add_child(left)
	left.add_child(UIKit.label(str(pk["name"]).to_upper(), 24, UIKit.INK))
	left.add_child(UIKit.label("◎ %s" % UIKit.fmt_int(int(pk["fichas"])), 34, UIKit.MONEY))
	var bonus := ChaosEconomy.bonus_pct(pk)
	var sub := ("+%d%% de bônus" % bonus) if bonus > 0 else "pacote base"
	if str(pk["tag"]) != "":
		sub += "  ·  " + str(pk["tag"])
	var sl := UIKit.label(sub, 18, UIKit.GAIN if bonus > 0 else UIKit.MUTED)
	left.add_child(sl)
	var buy := UIKit.button(ChaosEconomy.price_text(int(pk["price_cents"])), UIKit.ACTION, 28)
	buy.custom_minimum_size = Vector2(190, 76)
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
