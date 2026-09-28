extends SceneTree
## Testes headless da Fase 1: baralho de 78 cartas e regras de vaza (obrigação de
## seguir naipe, obrigação de cortar/cobrir com Trunfo, O Louco).
## Uso: godot --headless --path . -s res://tests/test_runner.gd

var failures := 0
var passed := 0


func _init() -> void:
	_test_deck()
	_test_points()
	_test_follow_suit()
	_test_trunfo_forced()
	_test_cover_trunfo()
	_test_louco()
	_test_winner()
	print("\n%d ok, %d falhas" % [passed, failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failures += 1
		printerr("FALHA: " + msg)


func c(s: int, r: int) -> CardData:
	return CardData.make(s, r)


func _test_deck() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var deck := Deck.build(rng)
	check(deck.size() == 78, "baralho tem 78 cartas (tem %d)" % deck.size())
	var keys := {}
	var loucos := 0
	var trunfos := 0
	for card in deck:
		keys[card.key()] = true
		if card.is_louco():
			loucos += 1
		if card.is_trunfo():
			trunfos += 1
	check(keys.size() == 78, "sem duplicatas")
	check(loucos == 1, "exatamente 1 Louco")
	check(trunfos == 21, "21 trunfos (tem %d)" % trunfos)

	var v := Deck.deal(deck, 4, 18)
	check((v["hands"] as Array).size() == 4 and (v["hands"][0] as Array).size() == 18, "Vanilla: 18 cartas por jogador")
	check((v["rest"] as Array).size() == 6, "Vanilla: talão de 6 cartas")

	rng.seed = 7
	var deck2 := Deck.build(rng)
	var caos := Deck.deal(deck2, 4, 8)
	check((caos["hands"][0] as Array).size() == 8, "Caos: 8 cartas por jogador")
	check((caos["rest"] as Array).size() == 78 - 32, "Caos: resto do baralho não usado")


func _test_points() -> void:
	check(is_equal_approx(c(0, 14).points(), 4.5), "Rei vale 4,5")
	check(is_equal_approx(c(0, 13).points(), 3.5), "Dama vale 3,5")
	check(is_equal_approx(c(0, 12).points(), 2.5), "Cavaleiro vale 2,5")
	check(is_equal_approx(c(0, 11).points(), 1.5), "Valete vale 1,5")
	check(is_equal_approx(c(0, 5).points(), 0.5), "carta numérica vale 0,5")
	check(is_equal_approx(c(4, 10).points(), 0.5), "trunfo comum vale 0,5")
	check(is_equal_approx(c(4, 1).points(), 4.5), "Le Petit (trunfo 1) vale 4,5")
	check(is_equal_approx(c(4, 21).points(), 4.5), "Le Monde (trunfo 21) vale 4,5")
	check(is_equal_approx(CardData.louco().points(), 4.5), "O Louco vale 4,5")
	check(c(4, 1).is_bout() and c(4, 21).is_bout() and CardData.louco().is_bout(), "os 3 Bouts identificados")
	check(not c(4, 10).is_bout(), "trunfo comum não é Bout")


func _test_follow_suit() -> void:
	var hand := [c(0, 5), c(0, 9), c(2, 3), c(4, 7)]
	var plays := [{"player": 1, "card": c(0, 2)}]
	var legal := TrickRules.legal_cards(hand, plays)
	check(legal.size() == 2, "com Ouros na mão, só pode jogar Ouros (+Louco se tivesse)")
	check(not legal.has(hand[2]), "não pode descartar Copas tendo Ouros")


func _test_trunfo_forced() -> void:
	# Sem o naipe líder (Ouros), mas com Trunfo na mão: obrigado a cortar.
	var hand := [c(2, 3), c(4, 5), c(4, 12)]
	var plays := [{"player": 1, "card": c(0, 2)}]
	var legal := TrickRules.legal_cards(hand, plays)
	check(legal.size() == 2, "obrigado a jogar Trunfo quando não tem o naipe (tem %d opções)" % legal.size())
	check(not legal.has(hand[0]), "não pode descartar Copas tendo Trunfo disponível")

	# Sem naipe líder e sem Trunfo: descarte livre.
	var hand2 := [c(2, 3), c(1, 5)]
	check(TrickRules.legal_cards(hand2, plays).size() == 2, "sem naipe e sem trunfo: qualquer carta")


func _test_cover_trunfo() -> void:
	# Alguém já cortou com Trunfo 8; jogador tem Trunfo 3 e Trunfo 15 — deve cobrir com o 15.
	var hand := [c(2, 3), c(4, 3), c(4, 15)]
	var plays := [{"player": 1, "card": c(0, 5)}, {"player": 2, "card": c(4, 8)}]
	var legal := TrickRules.legal_cards(hand, plays)
	check(legal.size() == 1 and legal[0].rank == 15, "obrigado a cobrir com trunfo maior quando possível")

	# Só tem trunfos menores que o maior da mesa: joga qualquer trunfo (não consegue cobrir).
	var hand2 := [c(2, 3), c(4, 2), c(4, 4)]
	var legal2 := TrickRules.legal_cards(hand2, plays)
	check(legal2.size() == 2, "sem trunfo pra cobrir, pode jogar qualquer trunfo que tiver")


func _test_louco() -> void:
	var hand := [c(0, 5), CardData.louco()]
	var plays := [{"player": 1, "card": c(2, 4)}]
	var legal := TrickRules.legal_cards(hand, plays)
	check(legal.has(hand[1]), "O Louco sempre pode ser jogado, mesmo sem ter o naipe/trunfo certo")

	var plays2 := [{"player": 0, "card": CardData.louco()}, {"player": 1, "card": c(0, 3)}]
	check(TrickRules.lead_suit(plays2) == 0, "naipe líder é definido pela 1ª carta real após O Louco")

	var full := [
		{"player": 0, "card": CardData.louco()},
		{"player": 1, "card": c(0, 2)},
		{"player": 2, "card": c(0, 9)},
		{"player": 3, "card": c(4, 3)},
	]
	check(TrickRules.winning_index(full) == 3, "trunfo vence naipe comum mesmo com Louco na mesa")
	check(not TrickRules.would_win(CardData.louco(), 0, []), "O Louco nunca vence a vaza")


func _test_winner() -> void:
	var plays := [
		{"player": 0, "card": c(2, 5)},
		{"player": 1, "card": c(2, 1)},
		{"player": 2, "card": c(0, 14)},
		{"player": 3, "card": c(2, 11)},
	]
	check(TrickRules.winning_index(plays) == 3, "maior do naipe líder vence (Rei de outro naipe não)")
	check(TrickRules.winning_index([{"player": 0, "card": c(2, 1)}, {"player": 1, "card": c(2, 2)}]) == 1, "Ás é a menor carta do naipe")

	var cut := [
		{"player": 0, "card": c(2, 14)},
		{"player": 1, "card": c(4, 5)},
		{"player": 2, "card": c(4, 9)},
		{"player": 3, "card": c(2, 3)},
	]
	check(TrickRules.winning_index(cut) == 2, "trunfo mais alto vence quando a vaza é cortada")
