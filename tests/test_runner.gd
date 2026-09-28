extends SceneTree
## Testes headless das regras (sem UI).
## Uso: godot --headless --path . -s res://tests/test_runner.gd

var failures := 0
var passed := 0


func _init() -> void:
	_test_deck()
	_test_follow_suit()
	_test_arcana()
	_test_winner()
	_test_scoring()
	_test_jokers()
	_test_ranked()
	_test_full_matches()
	_test_format()
	print("\n%d ok, %d falhas" % [passed, failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failures += 1
		printerr("FALHA: " + msg)


func c(s: int, r: int, m: int = 0) -> CardData:
	return CardData.make(s, r, m)


func _test_deck() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var deck := Deck.build(rng, 4, false)
	check(deck.size() == 56, "baralho = 52 + 4 arcanos")
	var keys := {}
	for card in deck:
		keys[card.key()] = true
	check(keys.size() == 56, "sem duplicatas")
	var hands := Deck.deal(deck, 4)
	check(hands.size() == 4 and (hands[0] as Array).size() == 14, "14 cartas por jogador")
	# Taxa de drop ~88/8/4
	var counts := [0, 0, 0]
	for i in range(50000):
		counts[Deck.roll_modifier(rng)] += 1
	check(absf(counts[1] / 50000.0 - 0.08) < 0.01, "drop Foil ~8%% (%d)" % counts[1])
	check(absf(counts[2] / 50000.0 - 0.04) < 0.01, "drop Polychrome ~4%% (%d)" % counts[2])
	var up := Deck.build(rng, 0, false, {"2:13": CardData.Modifier.POLYCHROME})
	var king: CardData = up.filter(func(x): return x.key() == "2:13")[0]
	check(king.modifier == CardData.Modifier.POLYCHROME, "upgrade da loja aplicado")


func _test_follow_suit() -> void:
	var hand := [c(0, 5), c(0, 9), c(2, 3), c(4, 7)]
	var plays := [{"player": 1, "card": c(0, 2)}]
	var legal := TrickRules.legal_cards(hand, plays)
	check(legal.size() == 3, "segue Ouros ou joga Arcano")
	check(not legal.has(hand[2]), "não pode descartar Copas tendo Ouros")
	plays = [{"player": 1, "card": c(1, 2)}]
	check(TrickRules.legal_cards(hand, plays).size() == 4, "sem Paus: qualquer carta")
	check(TrickRules.legal_cards(hand, []).size() == 4, "abrindo: qualquer carta")


func _test_arcana() -> void:
	var plays := [{"player": 0, "card": c(4, 3)}, {"player": 1, "card": c(3, 8)}]
	check(TrickRules.lead_suit(plays) == 3, "arcano abrindo: próxima carta define naipe")
	var hand := [c(3, 1), c(2, 13)]
	check(TrickRules.legal_cards(hand, plays).size() == 1, "segue naipe definido após arcano")
	check(c(4, 0).value() == 15, "arcano vale 15")


func _test_winner() -> void:
	var plays := [
		{"player": 0, "card": c(2, 5)},
		{"player": 1, "card": c(2, 1)},
		{"player": 2, "card": c(0, 13)},
		{"player": 3, "card": c(2, 11)},
	]
	check(TrickRules.winning_index(plays) == 3, "maior do naipe líder vence (Rei de outro naipe não)")
	check(TrickRules.winning_index([{"player": 0, "card": c(2, 1)}, {"player": 1, "card": c(2, 2)}]) == 1, "Ás é a menor carta")
	plays[1] = {"player": 1, "card": c(4, 5)}
	plays[2] = {"player": 2, "card": c(4, 9)}
	check(TrickRules.winning_index(plays) == 1, "primeiro arcano vence")


func _test_scoring() -> void:
	var cards := [c(0, 4), c(1, 9), c(2, 2), c(3, 6)]
	var ev := Scoring.evaluate(cards, cards[0])
	check(ev["chips"] == 21 and is_equal_approx(ev["mult"], 1.0) and ev["total"] == 21, "vaza simples = 21")
	cards = [c(2, 4), c(2, 9), c(2, 2), c(2, 12)]
	ev = Scoring.evaluate(cards, cards[3])
	check(ev["total"] == 54 and ev["synergies"].has("Monopólio de Naipe"), "monopólio x2")
	cards = [c(0, 5), c(1, 7), c(2, 4), c(3, 6)]
	ev = Scoring.evaluate(cards, cards[0])
	check(ev["total"] == 55 and ev["synergies"].has("Sequência Caótica"), "sequência x2,5 (22 x 2,5)")
	cards = [c(2, 5), c(2, 7), c(2, 4), c(2, 6)]
	ev = Scoring.evaluate(cards, cards[1])
	check(ev["total"] == 110, "monopólio + sequência = x5")
	cards = [c(0, 4, CardData.Modifier.FOIL), c(1, 9), c(2, 2, CardData.Modifier.POLYCHROME), c(3, 6)]
	ev = Scoring.evaluate(cards, cards[1])
	check(ev["chips"] == 71 and ev["total"] == 142, "foil +50 e polychrome x2")
	check(not Scoring.is_sequence([c(4, 3), c(0, 4), c(0, 5)]), "arcano quebra sequência")


func _test_jokers() -> void:
	var cards := [c(2, 1), c(2, 9), c(0, 2), c(2, 6)]
	var base: int = Scoring.evaluate(cards, cards[1])["total"]
	var ev := Scoring.evaluate(cards, cards[1], ["caos"])
	check(ev["total"] == base * 2, "Caos Ordenado: monopólio com 1 fora")
	ev = Scoring.evaluate(cards, cards[1], ["louco", "copas_sangrentas"])
	check(is_equal_approx(ev["mult"], 1.0 + 4 + 9), "+Mult aditivo")
	ev = Scoring.evaluate(cards, cards[1], ["as_oculto"])
	check(ev["chips"] == 18 + 25, "Ás Oculto")
	check(Jokers.all_ids().size() >= 10, "catálogo de curingas")


func _test_ranked() -> void:
	check(Ranked.tier_info(0)["label"] == "Bronze IV", "início em Bronze IV")
	check(Ranked.tier_info(399)["label"] == "Bronze I", "Bronze I")
	check(Ranked.tier_info(400)["label"] == "Prata IV", "promoção para Prata")
	check(Ranked.tier_info(2100)["label"] == "Mestre", "Mestre")
	check(Ranked.tier_info(2700, 2000)["label"] == "Desafiante", "Desafiante")
	check(Ranked.tier_info(2700, 1500)["label"] == "Mestre", "Desafiante exige MMR")
	check(Ranked.lp_delta(0, 1000, 1000) > 0 and Ranked.lp_delta(3, 1000, 1000) < 0, "LP ganha/perde")
	check(Ranked.lp_delta(1, 1400, 800) > 0, "2º lugar sempre ganha LP")
	check(Ranked.mmr_delta(0, 1000, 1000) > 0 and Ranked.mmr_delta(3, 1000, 1000) < 0, "MMR Elo")
	check(Ranked.mmr_delta(0, 1000, 1300) > Ranked.mmr_delta(0, 1300, 1000), "vencer lobby forte vale mais")


func _test_full_matches() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var boss_wins := 0
	var hard_first := 0
	var n := 300
	for i in range(n):
		var e := MatchEngine.new()
		e.setup({"seed": i, "arcana_count": 4, "modifiers": true, "stage_mult": [1.0, 1.0, 1.0, 1.0]})
		var guard := 0
		while not e.is_round_over() and guard < 100:
			guard += 1
			var p := e.current
			var diff := BotAI.Difficulty.HARD if p == 0 else BotAI.Difficulty.EASY
			var card := BotAI.choose(e.hands[p], e.plays, p, e.num_players, diff, rng)
			var res := e.play(p, card)
			if not res["ok"]:
				check(false, "bot jogou carta ilegal")
				return
		check(e.is_round_over() and e.trick_number == 14, "partida termina em 14 vazas")
		var total_tricks := 0
		for t in e.tricks_won:
			total_tricks += t
		if total_tricks != 14:
			check(false, "soma de vazas")
		if e.scores[0] > e.scores[2]:
			boss_wins += 1
		if e.placement_of(0) == 0:
			hard_first += 1
	print("Simulação (%d partidas): bot difícil vence o chefe fácil em %d%%, fica em 1º em %d%%" % [n, boss_wins * 100 / n, hard_first * 100 / n])
	check(boss_wins > n / 2, "jogador habilidoso supera o chefe da fase 1 na maioria")
	var e2 := MatchEngine.new()
	e2.setup({"seed": 1})
	var wrong := (e2.current + 1) % 4
	check(not e2.play(wrong, e2.hands[wrong][0])["ok"], "rejeita jogada fora de turno")


func _test_format() -> void:
	check(UIKit.fmt_int(1234567) == "1.234.567", "fmt_int PT-BR")
	check(UIKit.fmt_int(-980) == "-980", "fmt_int negativo")
	check(UIKit.fmt_dec(1234.56, 2) == "1.234,56", "fmt_dec PT-BR")
	check(UIKit.fmt_dec(2.5, 1) == "2,5", "fmt_dec")
