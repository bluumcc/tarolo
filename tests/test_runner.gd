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
	_test_louco_ownership()
	_test_winner()
	_test_bidding()
	_test_bonuses()
	_test_chaos()
	_test_bot_strategy()
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
	check(is_equal_approx(c(0, 13).points(), 3.5), "Rainha vale 3,5")
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


func _test_bidding() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var e := MatchEngine.new()
	e.setup({"seed": 3})
	check(e.taker == -1 and not e.bidding_done, "licitação começa sem tomador definido")

	# 3 passam, o 4º é obrigado a dar um lance (não pode passar sendo o único restante).
	check(e.place_bid(0, -1)["ok"], "jogador 0 passa")
	check(e.place_bid(1, -1)["ok"], "jogador 1 passa")
	check(e.place_bid(2, -1)["ok"], "jogador 2 passa")
	check(e.is_bidding_forced(3), "último jogador ativo é obrigado a dar lance")
	check(not e.place_bid(3, -1)["ok"], "não pode passar quando é obrigado a licitar")
	check(e.place_bid(3, Scoring.Contract.PETITE)["ok"], "jogador 3 assume com Petite")
	check(e.bidding_done and e.taker == 3 and e.contract == Scoring.Contract.PETITE, "jogador 3 vira tomador")
	check(e.awaiting_discard and (e.hands[3] as Array).size() == 24, "Petite: talão entra na mão (24 cartas) e espera o tomador escolher o descarte")
	var legal3 := e.legal_discards(e.hands[3])
	check(not (legal3 as Array).any(func(c: CardData) -> bool: return c.is_bout()), "Bout nunca pode ir pro descarte")
	check(not (legal3 as Array).any(func(c: CardData) -> bool: return c.rank == 14), "Rei nunca pode ir pro descarte")
	var bad_discard := (e.hands[3] as Array).filter(func(c: CardData) -> bool: return c.is_bout())
	if bad_discard.size() >= 1:
		check(not e.discard(bad_discard.slice(0, 1) + legal3.slice(0, 5))["ok"], "descarte com Bout é rejeitado")
	check(e.discard(legal3.slice(0, Deck.CHIEN_SIZE))["ok"], "tomador escolhe o próprio descarte")
	check((e.hands[3] as Array).size() == 18, "depois do descarte, mão volta pra 18 cartas")
	check(e.total_tricks == 18, "18 vazas no Vanilla")
	check(not e.awaiting_discard, "descarte resolvido libera o início das vazas")

	# Lance mais baixo que o atual é rejeitado; lance maior sobrepõe.
	var e2 := MatchEngine.new()
	e2.setup({"seed": 4})
	e2.place_bid(0, Scoring.Contract.GARDE)
	check(not e2.place_bid(1, Scoring.Contract.PETITE)["ok"], "lance abaixo do atual é rejeitado")
	check(e2.place_bid(1, Scoring.Contract.GARDE_SANS)["ok"], "lance maior sobrepõe o anterior")
	e2.place_bid(2, -1)
	e2.place_bid(3, -1)
	check(not e2.bidding_done, "jogador 0 ainda não passou: licitação continua com ele")
	e2.place_bid(0, -1)  # 0 desiste de cobrir o Garde Sans
	check(e2.bidding_done and e2.taker == 1 and e2.contract == Scoring.Contract.GARDE_SANS, "quem arrematou por último vence a licitação")
	check((e2.hands[1] as Array).size() == 18, "Garde Sans: tomador não incorpora o talão na mão")
	var chien_pts := 0.0
	for c in e2.chien:
		chien_pts += (c as CardData).points()
	var captured_pts := 0.0
	for c in e2.captured[1]:
		captured_pts += (c as CardData).points()
	check(is_equal_approx(captured_pts, chien_pts), "Garde Sans: talão inteiro já conta pro tomador antes de qualquer vaza")

	var e3 := MatchEngine.new()
	e3.setup({"seed": 5})
	e3.place_bid(0, Scoring.Contract.GARDE_CONTRE)
	e3.place_bid(1, -1)
	e3.place_bid(2, -1)
	e3.place_bid(3, -1)
	check((e3.hands[0] as Array).size() == 18 and e3.captured[0].is_empty(), "Garde Contre: talão não entra em lugar nenhum pro tomador")
	check(e3.bid_options(0).is_empty(), "ninguém pode superar Garde Contre")


func _test_winner() -> void:
	var plays := [
		{"player": 0, "card": c(2, 5)},
		{"player": 1, "card": c(2, 1)},
		{"player": 2, "card": c(0, 14)},
		{"player": 3, "card": c(2, 11)},
	]
	check(TrickRules.winning_index(plays) == 3, "maior do naipe líder vence (Rei de outro naipe não)")
	check(TrickRules.winning_index([{"player": 0, "card": c(2, 1)}, {"player": 1, "card": c(2, 2)}]) == 1, "Ás é a menor carta do naipe")


func _test_bonuses() -> void:
	check(Scoring.poignee_bonus(9) == 0.0, "menos de 10 trunfos não dá Poignée")
	check(Scoring.poignee_bonus(10) == 20.0, "10 trunfos = Poignée simples (+20)")
	check(Scoring.poignee_bonus(12) == 20.0, "12 trunfos ainda é Poignée simples")
	check(Scoring.poignee_bonus(13) == 30.0, "13 trunfos = Poignée dupla (+30)")
	check(Scoring.poignee_bonus(15) == 40.0, "15 trunfos = Poignée tripla (+40)")

	var r := Scoring.resolve(60.0, 1, Scoring.Contract.GARDE, {"poignee": 20.0, "chelem": 200.0, "petit_au_bout": 10.0})
	check(r["bonus_total"] == 230.0, "bônus somam 230 antes de aplicar ao placar")
	check(r["score"] > 230.0, "placar final inclui o resultado do contrato mais os bônus")

	var r2 := Scoring.resolve(60.0, 1, Scoring.Contract.GARDE, {"petit_au_bout": -10.0})
	check(r2["bonus_total"] == -10.0, "petit au bout a favor da defesa entra negativo pro tomador")

	# Detecção via MatchEngine: monta um estado final manualmente (sem rodar a partida
	# inteira) e confere se _round_bonuses() lê tudo certo — Poignée/Chelem só contam
	# se o tomador escolheu declarar/anunciar (ver `declare_poignee`/`announce_chelem`).
	var e := MatchEngine.new()
	e.setup({"seed": 42, "players": 4})
	e.num_players = 4
	e.taker = 0
	e.taker_trump_count = 13
	e.captured = [[], [], [], []]  # ninguém além do tomador capturou nada -> chelem
	e.captured[0].append(c(4, 5))
	var petit := c(4, CardData.PETIT)
	e.history = [{
		"winner": 0,
		"plays": [{"player": 0, "card": petit}, {"player": 1, "card": c(0, 3)}, {"player": 2, "card": c(1, 4)}, {"player": 3, "card": c(2, 6)}],
	}]
	var bonuses_undeclared: Dictionary = e._round_bonuses()
	check(bonuses_undeclared["poignee"] == 0.0, "Poignée não declarado não soma bônus")
	check(bonuses_undeclared["chelem"] == 200.0, "Chelem não anunciado ainda dá +200 sem risco quando vence todas por acaso")
	check(bonuses_undeclared["petit_au_bout"] == 10.0, "Petit au bout a favor do tomador é sempre automático")

	e.declare_poignee(true)
	e.announce_chelem(true)
	var bonuses: Dictionary = e._round_bonuses()
	check(bonuses["poignee"] == 30.0, "Poignée declarado soma o bônus (dupla, 13 trunfos)")
	check(bonuses["chelem"] == 400.0, "Chelem anunciado e cumprido vale o dobro (+400)")

	e.captured[1].append(c(0, 2))  # agora outro jogador venceu alguma vaza -> Chelem falha
	var bonuses_failed: Dictionary = e._round_bonuses()
	check(bonuses_failed["chelem"] == -200.0, "Chelem anunciado e não cumprido pune o tomador (-200)")

	e.taker = 1  # agora o Petit foi vencido por outro jogador na última vaza
	e.history = [{
		"winner": 0,
		"plays": [{"player": 0, "card": petit}, {"player": 1, "card": c(0, 3)}, {"player": 2, "card": c(1, 4)}, {"player": 3, "card": c(2, 6)}],
	}]
	var bonuses2: Dictionary = e._round_bonuses()
	check(bonuses2["petit_au_bout"] == -10.0, "Petit au bout vira pra defesa quando quem vence a última vaza não é o tomador")

	var cut := [
		{"player": 0, "card": c(2, 14)},
		{"player": 1, "card": c(4, 5)},
		{"player": 2, "card": c(4, 9)},
		{"player": 3, "card": c(2, 3)},
	]
	check(TrickRules.winning_index(cut) == 2, "trunfo mais alto vence quando a vaza é cortada")


func _test_chaos() -> void:
	# card_value: efeito de cada modificador de pontos.
	var e := ChaosEngine.new()
	e.setup_match({"seed": 11})
	check((e.hands[0] as Array).size() == ChaosEngine.HAND_SIZE, "Caos: 8 cartas por jogador")
	check(e.folego_player == -1, "primeira rodada não tem Fôlego (ninguém ficou pra trás ainda)")

	e.modifier = ChaosModifiers.Modifier.TRUNFO_DOBRO
	check(e.card_value(c(4, 5)) == 1.0, "Trunfo em Dobro: 0,5 vira 1,0")
	check(e.card_value(c(0, 14)) == 4.5, "Trunfo em Dobro não afeta Rei de naipe comum")

	e.modifier = ChaosModifiers.Modifier.REIS_DOBRO
	check(e.card_value(c(0, 14)) == 9.0, "Reis em Dobro: Rei de 4,5 vira 9,0")
	check(e.card_value(c(4, 14)) == 0.5, "Reis em Dobro não afeta Trunfo 14 (não é Rei)")

	e.modifier = ChaosModifiers.Modifier.NAIPE_FRACO
	e.weak_suit = CardData.Suit.OUROS
	check(e.card_value(c(0, 14)) == 2.25, "Naipe Fraco: Rei de Ouros de 4,5 vira 2,25")
	check(e.card_value(c(1, 14)) == 4.5, "Naipe Fraco não afeta naipe diferente do sorteado")

	# O Louco Vence: TrickRules trata O Louco como Trunfo fraco (perde pra Trunfo real).
	var louco_plays := [
		{"player": 0, "card": c(2, 14)},
		{"player": 1, "card": CardData.louco()},
		{"player": 2, "card": c(2, 3)},
		{"player": 3, "card": c(2, 9)},
	]
	check(TrickRules.winning_index(louco_plays, true) == 1, "com O Louco Vence, ele bate qualquer carta de naipe comum")
	check(TrickRules.winning_index(louco_plays, false) == 0, "sem o modificador, O Louco nunca vence (regra normal intacta)")
	var louco_vs_trunfo := louco_plays + [{"player": 0, "card": c(4, 3)}]
	check(TrickRules.winning_index(louco_vs_trunfo, true) == 4, "O Louco perde pra um Trunfo de verdade mesmo com o modificador ativo")

	# Uma rodada completa (8 vazas) jogando sempre a primeira carta legal — só valida que
	# o motor fecha a rodada sozinho e preenche round_result corretamente.
	var e2 := ChaosEngine.new()
	e2.setup_match({"seed": 21})
	var guard := 0
	while not e2.is_round_over() and guard < 200:
		var p := e2.current
		var legal: Array = e2.legal_for(p)
		e2.play(p, legal[0])
		guard += 1
	check(e2.is_round_over(), "8 jogadas por jogador fecham a rodada (8 vazas)")
	check(not e2.round_result.is_empty(), "round_finished preenche round_result")
	check(int(e2.round_result["round"]) == 0, "primeira rodada tem índice 0")
	var sum_round_pts := 0.0
	for pts in (e2.round_result["round_points"] as Array):
		sum_round_pts += float(pts)
	var sum_totals := 0.0
	for t in e2.totals:
		sum_totals += float(t)
	check(is_equal_approx(sum_round_pts, sum_totals), "depois da 1ª rodada, pontos da rodada e total da partida batem")

	e2.advance_round()
	check(e2.round_index == 1, "advance_round avança o índice da rodada")
	check((e2.hands[0] as Array).size() == ChaosEngine.HAND_SIZE, "rodada nova também dá 8 cartas")

	# Fôlego: quem estava em último antes da 2ª rodada recebe o bônus dessa vez.
	var expected_folego := 0
	for p in range(1, 4):
		if e2.totals[p] < e2.totals[expected_folego]:
			expected_folego = p
	check(e2.folego_player == expected_folego, "Fôlego mira em quem está em último no total acumulado")

	# Partida completa (5 rodadas) até o fim, jogando sempre a primeira carta legal.
	var e3 := ChaosEngine.new()
	e3.setup_match({"seed": 99})
	var rounds_played := 0
	var safety := 0
	while rounds_played < ChaosEngine.ROUNDS and safety < 1000:
		var p := e3.current
		var legal: Array = e3.legal_for(p)
		e3.play(p, legal[0])
		safety += 1
		if e3.is_round_over():
			rounds_played += 1
			if rounds_played < ChaosEngine.ROUNDS:
				e3.advance_round()
	check(rounds_played == ChaosEngine.ROUNDS, "partida de Caos tem %d rodadas" % ChaosEngine.ROUNDS)
	check(not e3.match_result.is_empty(), "match_finished preenche match_result no fim da última rodada")
	var standings: Array = e3.match_result["standings"]
	check(standings.size() == 4, "pódio final tem os 4 jogadores")
	var totals: Array = e3.match_result["totals"]
	for i in range(standings.size() - 1):
		check(float(totals[standings[i]]) >= float(totals[standings[i + 1]]), "pódio ordenado do maior pro menor total")

	# Modificadores não repetem dentro da mesma partida (só 5 rodadas pra 6 modificadores).
	var e4 := ChaosEngine.new()
	e4.setup_match({"seed": 42})
	var seen_mods := {}
	for r in range(ChaosEngine.ROUNDS):
		check(not seen_mods.has(e4.modifier), "modificador da rodada %d não repetiu na partida" % (r + 1))
		seen_mods[e4.modifier] = true
		if r < ChaosEngine.ROUNDS - 1:
			e4.advance_round()

	# Pote/buy-in: pago integralmente pelas 4 fatias de colocação.
	var e5 := ChaosEngine.new()
	e5.setup_match({"seed": 7, "buy_in": 100})
	check(e5.pot == 400.0, "pote = buy-in x jogadores (100 x 4 = 400)")
	var paid := 0.0
	for pl in range(4):
		paid += e5.payout_for(pl)
	check(is_equal_approx(paid, e5.pot), "a soma dos pagamentos por colocação esgota o pote")
	check(e5.payout_for(0) > e5.payout_for(1) and e5.payout_for(1) > e5.payout_for(2) and e5.payout_for(2) > e5.payout_for(3), "pagamento cai a cada colocação pior")

	# Itens: efeito de cada um em card_value/roubo, isolado do jogador que não tem o item.
	var e6 := ChaosEngine.new()
	e6.setup_match({"seed": 5})
	e6.modifier = ChaosModifiers.Modifier.NAIPE_FRACO
	e6.weak_suit = CardData.Suit.OUROS
	e6.player_items[0] = ChaosItems.Item.ESCUDO_NAIPE
	check(e6.card_value(c(0, 14), 0) == 4.5, "Escudo de Naipe cancela a penalidade do Naipe Fraco pra quem tem o item")
	check(e6.card_value(c(0, 14), 1) == 2.25, "Escudo de Naipe não afeta quem não tem o item")

	e6.modifier = -1
	e6.weak_suit = -1
	e6.player_items[0] = ChaosItems.Item.TRUNFO_AFIADO
	check(e6.card_value(c(4, 5), 0) == 1.5, "Trunfo Afiado soma +1 pt fixo no Trunfo de quem tem o item")
	check(e6.card_value(c(4, 5), 1) == 0.5, "Trunfo Afiado não afeta quem não tem o item")

	e6.totals = [0.0, 20.0, 0.0, 0.0]
	e6.player_items = [ChaosItems.Item.ROUBO_VAZA, ChaosItems.Item.NONE, ChaosItems.Item.NONE, ChaosItems.Item.NONE]
	e6.roubo_used = [false, false, false, false]
	e6.plays = [
		{"player": 1, "card": c(CardData.Suit.PAUS, 3)},
		{"player": 2, "card": c(CardData.Suit.PAUS, 5)},
		{"player": 3, "card": c(CardData.Suit.PAUS, 7)},
		{"player": 0, "card": c(CardData.Suit.PAUS, 10)},
	]
	e6.trick_number = 1
	var steal_result := e6._resolve_trick()
	check(bool(steal_result["roubo_applied"]), "Roubo de Vaza dispara na 1ª vaza vencida com o item")
	check(int(steal_result["roubo_target"]) == 1, "Roubo de Vaza mira em quem está em 1º lugar no total")
	check(e6.totals[1] == 16.0, "alvo do roubo perde os pontos roubados")


## Bots estratégicos: só fazem jogadas legais em qualquer nível e, na defesa, seguram muito
## mais o Tomador do que o bot simples (mesmas mãos, mesma semente).
func _test_bot_strategy() -> void:
	var results := {}
	for def_level in [-1, BotAI.Difficulty.NORMAL, BotAI.Difficulty.HARD]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 99
		var ok := 0
		var rounds := 0
		var i := 0
		var illegal := 0
		while rounds < 120:
			i += 1
			var e := MatchEngine.new()
			e.rng.seed = 7000 + i
			e.setup({"players": 4, "tutorial": false})
			if BotAI.hand_strength(e.hands[0]) < 22.0:
				continue
			rounds += 1
			e.place_bid(0, Scoring.Contract.PETITE)
			while not e.bidding_done:
				e.place_bid(e.bid_turn, -1)
			if e.awaiting_discard:
				e.discard(BotAI.choose_discard(e.legal_discards(e.hands[e.taker]), Deck.CHIEN_SIZE))
			while not e.is_round_over():
				var p := e.current
				var card: CardData
				if p == 0 or def_level == -1:
					card = BotAI.choose(e.hands[p], e.plays, p, 4, BotAI.Difficulty.HARD, rng)
				else:
					card = BotStrategy.choose(e, p, def_level, rng)
				if not TrickRules.legal_cards(e.hands[p], e.plays).has(card):
					illegal += 1
				e.play(p, card)
			if e.result["success"]:
				ok += 1
		results[def_level] = ok
		check(illegal == 0, "bot estratégico (nível %d) só joga cartas legais" % def_level)
	check(int(results[BotAI.Difficulty.HARD]) < int(results[-1]), "defesa Difícil segura o Tomador mais que a simples (%d < %d)" % [results[BotAI.Difficulty.HARD], results[-1]])
	check(int(results[BotAI.Difficulty.NORMAL]) < int(results[-1]), "defesa Normal também segura mais que a simples (%d < %d)" % [results[BotAI.Difficulty.NORMAL], results[-1]])


## O Louco fica com quem o jogou (menos na última vaza) e o dono paga o vencedor com uma
## carta de 0,5 ponto das que já capturou.
func _test_louco_ownership() -> void:
	var e := MatchEngine.new()
	e.setup({"players": 4, "tutorial": false})
	e.total_tricks = 18
	e.trick_number = 2
	e.taker = 1
	e.captured[0] = [c(1, 2)]
	e.plays = [
		{"player": 0, "card": CardData.louco()},
		{"player": 1, "card": c(0, 3)},
		{"player": 2, "card": c(0, 9)},
		{"player": 3, "card": c(0, 4)},
	]
	var r := e._resolve_trick()
	check(r["winner"] == 2, "vaza com Louco: vence a maior carta do naipe")
	check((e.captured[0] as Array).any(func(x: CardData) -> bool: return x.is_louco()), "o dono guarda o Louco")
	check(not (e.captured[2] as Array).any(func(x: CardData) -> bool: return x.is_louco()), "o vencedor não leva o Louco")
	check((e.captured[2] as Array).any(func(x: CardData) -> bool: return x.suit == 1 and x.rank == 2), "o dono paga o vencedor com uma carta de 0,5")
	check(is_equal_approx(float(r["points"]), 1.5), "pontos da vaza não contam o Louco (1,5)")

	# sem carta de 0,5 ainda: a dívida fica pra quando tiver
	var e2 := MatchEngine.new()
	e2.setup({"players": 4, "tutorial": false})
	e2.total_tricks = 18
	e2.trick_number = 0
	e2.taker = 1
	e2.plays = [
		{"player": 0, "card": CardData.louco()},
		{"player": 1, "card": c(0, 3)},
		{"player": 2, "card": c(0, 9)},
		{"player": 3, "card": c(0, 4)},
	]
	e2._resolve_trick()
	check(e2.louco_owed.has(0), "Louco na 1ª vaza: dono fica devendo a carta de 0,5")

	# última vaza: o Louco vai pro vencedor
	var e3 := MatchEngine.new()
	e3.setup({"players": 4, "tutorial": false})
	e3.total_tricks = 18
	e3.trick_number = 17
	e3.taker = 1
	e3.plays = [
		{"player": 0, "card": CardData.louco()},
		{"player": 1, "card": c(0, 3)},
		{"player": 2, "card": c(0, 9)},
		{"player": 3, "card": c(0, 4)},
	]
	e3._resolve_trick()
	check((e3.captured[2] as Array).any(func(x: CardData) -> bool: return x.is_louco()), "última vaza: o Louco vai pro vencedor")
