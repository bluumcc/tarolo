extends Control
## Shop.tscn — Loja Arcana entre fases do Arcade: Curingas passivos e cartas modificadas.

const REROLL_BASE := 2
const UPGRADE_PRICES := {CardData.Modifier.FOIL: 4, CardData.Modifier.POLYCHROME: 7}

var rng := RandomNumberGenerator.new()
var offers_jokers: Array = []
var offers_cards: Array = []   # [{key, modifier, price}]
var content: VBoxContainer
var gold_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UIKit.background())
	var r := GameState.run()
	rng.seed = int(r["seed"]) + int(r["stage"]) * 104729 + int(r["rerolls"]) * 31
	_roll_offers()

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(margin)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)
	_render()


func _roll_offers() -> void:
	var r := GameState.run()
	var owned: Array = r["jokers"]
	var pool := Jokers.all_ids().filter(func(id): return not owned.has(id))
	Deck.shuffle(pool, rng)
	offers_jokers = pool.slice(0, 3)
	offers_cards = []
	for i in range(2):
		var suit := rng.randi_range(0, 3)
		var rank := rng.randi_range(1, 13)
		var mod := CardData.Modifier.POLYCHROME if rng.randf() < 0.3 else CardData.Modifier.FOIL
		offers_cards.append({"key": "%d:%d" % [suit, rank], "modifier": mod, "price": UPGRADE_PRICES[mod]})


func _render() -> void:
	for c in content.get_children():
		c.queue_free()
	var r := GameState.run()
	var gold := int(r["gold"])

	var header := HBoxContainer.new()
	content.add_child(header)
	var title := UIKit.label("LOJA ARCANA", 40, UIKit.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	gold_label = UIKit.label("◉ %d Ouro" % gold, 26, UIKit.GOLD)
	header.add_child(gold_label)
	var boss := GameState.arcade_boss(int(r["stage"]))
	content.add_child(UIKit.label("Próxima: Fase %d · Chefe %s (x%s Mult, %s)" % [int(r["stage"]), boss["name"], UIKit.fmt_dec(boss["mult"], 1), BotAI.DIFFICULTY_NAMES[boss["difficulty"]]], 16, UIKit.MUTED))

	# Curingas à venda --------------------------------------------------
	content.add_child(UIKit.label("CURINGAS", 20, UIKit.INK))
	var jflow := HFlowContainer.new()
	jflow.add_theme_constant_override("h_separation", 12)
	jflow.add_theme_constant_override("v_separation", 12)
	content.add_child(jflow)
	var full := (r["jokers"] as Array).size() >= Jokers.MAX_SLOTS
	for id in offers_jokers:
		var j := Jokers.info(id)
		var price := int(j["price"])
		var btn := UIKit.button("COMPRAR ◉ %d" % price, UIKit.GOLD, 15)
		btn.disabled = gold < price or full
		btn.pressed.connect(_buy_joker.bind(id, price))
		jflow.add_child(_offer_card(str(j["name"]), "%s\n[%s]" % [j["desc"], j["rarity"]], btn))
	if offers_jokers.is_empty():
		jflow.add_child(UIKit.label("Você já possui todos os Curingas.", 14, UIKit.MUTED))

	# Cartas modificadas ------------------------------------------------
	content.add_child(UIKit.label("CARTAS MODIFICADAS (permanentes nesta run)", 20, UIKit.INK))
	var cflow := HFlowContainer.new()
	cflow.add_theme_constant_override("h_separation", 12)
	content.add_child(cflow)
	for i in range(offers_cards.size()):
		var o: Dictionary = offers_cards[i]
		var mod_name: String = CardData.MODIFIER_NAMES[o["modifier"]]
		var btn := UIKit.button("COMPRAR ◉ %d" % int(o["price"]), UIKit.GOLD, 15)
		btn.disabled = gold < int(o["price"])
		btn.pressed.connect(_buy_card.bind(i))
		var desc := "+%d Fichas" % CardData.FOIL_CHIPS if o["modifier"] == CardData.Modifier.FOIL else "x%s Mult" % UIKit.fmt_dec(CardData.POLY_XMULT, 1)
		cflow.add_child(_offer_card("%s %s" % [CardData.key_to_name(o["key"]), mod_name.to_upper()], desc, btn))

	# Seus curingas -----------------------------------------------------
	content.add_child(UIKit.label("SEUS CURINGAS (%d/%d)" % [(r["jokers"] as Array).size(), Jokers.MAX_SLOTS], 20, UIKit.INK))
	var owned := HFlowContainer.new()
	owned.add_theme_constant_override("h_separation", 12)
	content.add_child(owned)
	for id in r["jokers"]:
		var j := Jokers.info(id)
		var sell := UIKit.button("VENDER ◉ %d" % Jokers.sell_value(id), UIKit.DANGER, 14)
		sell.pressed.connect(_sell_joker.bind(id))
		owned.add_child(_offer_card(str(j["name"]), str(j["desc"]), sell))
	var ups: Dictionary = r["upgrades"]
	if not ups.is_empty():
		var names: Array = []
		for k in ups.keys():
			names.append("%s (%s)" % [CardData.key_to_name(k), CardData.MODIFIER_NAMES[int(ups[k])]])
		var l := UIKit.label("Cartas melhoradas: " + ", ".join(names), 14, UIKit.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(l)

	# Ações -------------------------------------------------------------
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 12)
	actions.add_theme_constant_override("v_separation", 12)
	content.add_child(actions)
	var reroll_price := REROLL_BASE + int(r["rerolls"])
	var reroll := UIKit.button("REROLAR ◉ %d" % reroll_price, UIKit.MUTED, 16)
	reroll.custom_minimum_size = Vector2(200, 52)
	reroll.disabled = gold < reroll_price
	reroll.pressed.connect(_reroll.bind(reroll_price))
	actions.add_child(reroll)
	var next := UIKit.button("PRÓXIMA FASE  →", UIKit.OK, 18)
	next.custom_minimum_size = Vector2(240, 52)
	next.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/GameScene.tscn"))
	actions.add_child(next)
	var menu := UIKit.button("SALVAR E SAIR", UIKit.MUTED, 16)
	menu.custom_minimum_size = Vector2(200, 52)
	menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	actions.add_child(menu)
	next.grab_focus.call_deferred()


func _offer_card(title: String, desc: String, action: Button) -> Control:
	var p := UIKit.panel(UIKit.PURPLE_DEEP, UIKit.PURPLE.lightened(0.2), 12)
	p.custom_minimum_size = Vector2(230, 170)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(UIKit.label(title, 18, UIKit.GOLD))
	var d := UIKit.label(desc, 14, UIKit.INK)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(d)
	v.add_child(action)
	return p


func _spend(amount: int) -> bool:
	var r := GameState.run()
	if int(r["gold"]) < amount:
		return false
	r["gold"] = int(r["gold"]) - amount
	return true


func _buy_joker(id: String, price: int) -> void:
	var r := GameState.run()
	if (r["jokers"] as Array).size() >= Jokers.MAX_SLOTS or not _spend(price):
		return
	(r["jokers"] as Array).append(id)
	offers_jokers.erase(id)
	Sfx.play("buy")
	SaveManager.save_game()
	_render()


func _buy_card(i: int) -> void:
	var o: Dictionary = offers_cards[i]
	if not _spend(int(o["price"])):
		return
	var r := GameState.run()
	(r["upgrades"] as Dictionary)[o["key"]] = int(o["modifier"])
	offers_cards.remove_at(i)
	Sfx.play("buy")
	SaveManager.save_game()
	_render()


func _sell_joker(id: String) -> void:
	var r := GameState.run()
	(r["jokers"] as Array).erase(id)
	r["gold"] = int(r["gold"]) + Jokers.sell_value(id)
	Sfx.play("chip")
	SaveManager.save_game()
	_render()


func _reroll(price: int) -> void:
	if not _spend(price):
		return
	var r := GameState.run()
	r["rerolls"] = int(r["rerolls"]) + 1
	_roll_offers()
	SaveManager.save_game()
	_render()
