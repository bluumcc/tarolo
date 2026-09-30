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
	_test_blitz()
	_test_colors()
	_test_economy()
	_test_standards()
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
	check(e.taker == -1 and not e.bidding_done, "licitação começa sem atacante definido")

	# 3 passam, o 4º é obrigado a dar um lance (não pode passar sendo o único restante).
	check(e.place_bid(0, -1)["ok"], "jogador 0 passa")
	check(e.place_bid(1, -1)["ok"], "jogador 1 passa")
	check(e.place_bid(2, -1)["ok"], "jogador 2 passa")
	check(e.is_bidding_forced(3), "último jogador ativo é obrigado a dar lance")
	check(not e.place_bid(3, -1)["ok"], "não pode passar quando é obrigado a licitar")
	check(e.place_bid(3, Scoring.Contract.PETITE)["ok"], "jogador 3 assume com Petite")
	check(e.bidding_done and e.taker == 3 and e.contract == Scoring.Contract.PETITE, "jogador 3 vira atacante")
	check(e.awaiting_discard and (e.hands[3] as Array).size() == 24, "Petite: talão entra na mão (24 cartas) e espera o atacante escolher o descarte")
	var legal3 := e.legal_discards(e.hands[3])
	check(not (legal3 as Array).any(func(c: CardData) -> bool: return c.is_bout()), "Bout nunca pode ir pro descarte")
	check(not (legal3 as Array).any(func(c: CardData) -> bool: return c.rank == 14), "Rei nunca pode ir pro descarte")
	var bad_discard := (e.hands[3] as Array).filter(func(c: CardData) -> bool: return c.is_bout())
	if bad_discard.size() >= 1:
		check(not e.discard(bad_discard.slice(0, 1) + legal3.slice(0, 5))["ok"], "descarte com Bout é rejeitado")
	check(e.discard(legal3.slice(0, Deck.CHIEN_SIZE))["ok"], "atacante escolhe o próprio descarte")
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
	check((e2.hands[1] as Array).size() == 18, "Garde Sans: atacante não incorpora o talão na mão")
	var chien_pts := 0.0
	for c in e2.chien:
		chien_pts += (c as CardData).points()
	var captured_pts := 0.0
	for c in e2.captured[1]:
		captured_pts += (c as CardData).points()
	check(is_equal_approx(captured_pts, chien_pts), "Garde Sans: talão inteiro já conta pro atacante antes de qualquer vaza")

	var e3 := MatchEngine.new()
	e3.setup({"seed": 5})
	e3.place_bid(0, Scoring.Contract.GARDE_CONTRE)
	e3.place_bid(1, -1)
	e3.place_bid(2, -1)
	e3.place_bid(3, -1)
	check((e3.hands[0] as Array).size() == 18 and e3.captured[0].is_empty(), "Garde Contre: talão não entra em lugar nenhum pro atacante")
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
	check(r2["bonus_total"] == -10.0, "petit au bout a favor da defesa entra negativo pro atacante")

	# Detecção via MatchEngine: monta um estado final manualmente (sem rodar a partida
	# inteira) e confere se _round_bonuses() lê tudo certo — Poignée/Chelem só contam
	# se o atacante escolheu declarar/anunciar (ver `declare_poignee`/`announce_chelem`).
	var e := MatchEngine.new()
	e.setup({"seed": 42, "players": 4})
	e.num_players = 4
	e.taker = 0
	e.taker_trump_count = 13
	e.captured = [[], [], [], []]  # ninguém além do atacante capturou nada -> chelem
	e.captured[0].append(c(4, 5))
	var petit := c(4, CardData.PETIT)
	e.history = [{
		"winner": 0,
		"plays": [{"player": 0, "card": petit}, {"player": 1, "card": c(0, 3)}, {"player": 2, "card": c(1, 4)}, {"player": 3, "card": c(2, 6)}],
	}]
	var bonuses_undeclared: Dictionary = e._round_bonuses()
	check(bonuses_undeclared["poignee"] == 0.0, "Poignée não declarado não soma bônus")
	check(bonuses_undeclared["chelem"] == 200.0, "Chelem não anunciado ainda dá +200 sem risco quando vence todas por acaso")
	check(bonuses_undeclared["petit_au_bout"] == 10.0, "Petit au bout a favor do atacante é sempre automático")

	e.declare_poignee(true)
	e.announce_chelem(true)
	var bonuses: Dictionary = e._round_bonuses()
	check(bonuses["poignee"] == 30.0, "Poignée declarado soma o bônus (dupla, 13 trunfos)")
	check(bonuses["chelem"] == 400.0, "Chelem anunciado e cumprido vale o dobro (+400)")

	e.captured[1].append(c(0, 2))  # agora outro jogador venceu alguma vaza -> Chelem falha
	var bonuses_failed: Dictionary = e._round_bonuses()
	check(bonuses_failed["chelem"] == -200.0, "Chelem anunciado e não cumprido pune o atacante (-200)")

	e.taker = 1  # agora o Petit foi vencido por outro jogador na última vaza
	e.history = [{
		"winner": 0,
		"plays": [{"player": 0, "card": petit}, {"player": 1, "card": c(0, 3)}, {"player": 2, "card": c(1, 4)}, {"player": 3, "card": c(2, 6)}],
	}]
	var bonuses2: Dictionary = e._round_bonuses()
	check(bonuses2["petit_au_bout"] == -10.0, "Petit au bout vira pra defesa quando quem vence a última vaza não é o atacante")

	var cut := [
		{"player": 0, "card": c(2, 14)},
		{"player": 1, "card": c(4, 5)},
		{"player": 2, "card": c(4, 9)},
		{"player": 3, "card": c(2, 3)},
	]
	check(TrickRules.winning_index(cut) == 2, "trunfo mais alto vence quando a vaza é cortada")


func _test_chaos() -> void:
	var e := ChaosEngine.new()
	e.setup_match({"seed": 11})
	check((e.hands[0] as Array).size() == ChaosEngine.HAND_SIZE, "Caos: 8 cartas por jogador")
	check(e.blind == 10 and int(e.stacks[0]) == 400, "mesa padrão: blind 10 e stack de 40 blinds")

	e.modifier = ChaosModifiers.Modifier.TRUNFO_DOBRO
	check(e.card_value(c(4, 5)) == 1.0, "Trunfo em Dobro: 0,5 vira 1,0")
	check(e.card_value(c(0, 14)) == 4.5, "Trunfo em Dobro não afeta Rei de naipe comum")

	e.modifier = ChaosModifiers.Modifier.FIGURAS_DOBRO
	check(e.card_value(c(0, 14)) == 9.0, "Figuras em Dobro: Rei de 4,5 vira 9,0")
	check(e.card_value(c(0, 11)) == 3.0, "Figuras em Dobro: Valete de 1,5 vira 3,0")
	check(e.card_value(c(4, 14)) == 0.5, "Figuras em Dobro não afeta Trunfo 14 (não é figura de naipe comum)")

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

	# Sem obrigação de cobrir no Caos (o Vanilla continua com ela).
	var lg := ChaosEngine.new()
	lg.setup_match({"seed": 2})
	lg.hands[0] = [c(CardData.Suit.TRUNFO, 9), c(CardData.Suit.TRUNFO, 19), c(CardData.Suit.PAUS, 3)]
	lg.plays = [{"player": 3, "card": c(CardData.Suit.TRUNFO, 18)}]
	check(lg.legal_for(0).size() == 2 and TrickRules.legal_cards(lg.hands[0], lg.plays).size() == 1, "Caos: pode jogar Trunfo mais fraco; Vanilla obriga a cobrir")
	lg.plays = [{"player": 3, "card": c(CardData.Suit.PAUS, 8)}]
	lg.hands[0] = [c(CardData.Suit.TRUNFO, 2), c(CardData.Suit.TRUNFO, 19), c(CardData.Suit.COPAS, 3)]
	lg.plays.append({"player": 2, "card": c(CardData.Suit.TRUNFO, 15)})
	check(lg.legal_for(0).size() == 2, "Caos: sem naipe, corta com qualquer Trunfo (mesmo menor que o cortado)")

	# ---- Aposta estilo poker
	var p1 := ChaosEngine.new()
	p1.setup_match({"seed": 3})
	p1.begin_trick()
	check(is_equal_approx(p1.pot, 40.0) and is_equal_approx(p1.stacks[0], 390.0), "blind de todos vai pro pote")
	check(p1.button == 1 and p1.bet_actor() == 2, "o botão gira e fala primeiro quem vem depois dele")
	var o0 := p1.bet_options(2)
	check(bool(o0["can_check"]) and is_equal_approx(float(o0["min_to"]), 20.0) and is_equal_approx(float(o0["max_to"]), 400.0), "primeiro a falar pode passar; aumento mínimo = 1 blind; máximo = menor stack")
	var r1 := p1.bet_act(2, "raise", 30.0)
	check(r1["ok"] and is_equal_approx(p1.pot, 60.0) and p1.to_act.size() == 3, "aumentar põe fichas e todo mundo precisa responder")
	check(not p1.bet_act(3, "raise", 10.0)["ok"] == false, "aumento abaixo do mínimo é corrigido pro mínimo")
	check(is_equal_approx(p1.bet_level, 40.0), "aumento mínimo sobre 30 é 40")
	var r3 := p1.bet_act(0, "check")
	check(not r3["ok"], "não dá pra passar com aposta aberta")
	p1.bet_act(0, "fold")
	check(p1.folded[0], "desistir tira da rodada")
	check(not p1.bet_act(1, "raise", 60.0)["ok"], "só 2 aumentos por rodada")
	p1.bet_act(1, "call")
	p1.bet_act(2, "call")
	check(not p1.betting and p1.active_count() == 3, "rodada de apostas fecha quando todo mundo igualou ou desistiu")
	check(is_equal_approx(p1.stacks[2], 360.0) and is_equal_approx(p1.pot, 130.0), "quem pagou põe o mesmo valor (40 cada; 10 do que desistiu)")
	check(p1.current != 0, "quem desistiu não joga carta")
	var played := 0
	while played < 3:
		var pp := p1.current
		var res := p1.play(pp, (p1.legal_for(pp) as Array)[0])
		check(res["ok"], "jogada legal aceita com 3 na rodada")
		played += 1
		if res["trick_complete"]:
			var rr: Dictionary = res["result"]
			check(is_equal_approx(float(rr["pot"]), 130.0), "resultado informa o pote")
			check(p1.stacks[int(rr["winner"])] >= 130.0 and float(rr["gain"]) > 0.0 - 200.0, "vencedor leva o pote")
	check(p1.hands[0].size() == 7 and p1.hands[1].size() == 7 and p1.hands[3].size() == 7, "quem desistiu descarta a mais fraca: todas as mãos ficam do mesmo tamanho")
	# Todo mundo desiste: o último leva o pote sem jogar.
	var p2 := ChaosEngine.new()
	p2.setup_match({"seed": 4})
	p2.begin_trick()
	p2.bet_act(2, "raise", 20.0)
	p2.bet_act(3, "fold")
	p2.bet_act(0, "fold")
	p2.bet_act(1, "fold")
	check(p2.walkover_player() == 2, "sobrou um: ele leva o pote")
	var wo := p2.resolve_walkover()
	check(bool(wo["walkover"]) and is_equal_approx(p2.stacks[2], 400.0 - 20.0 + 50.0), "blefe vence: leva o pote sem jogar carta")
	check(p2.hands[2].size() == 7 and p2.hands[3].size() == 7, "no blefe vencido o vencedor também descarta, mãos iguais")
	check(p2.trick_number == 1 and p2.session_stats[2]["bluffs"] == 1, "rodada conta e o blefe é registrado")
	# All-in limitado pela menor stack.
	var p3 := ChaosEngine.new()
	p3.setup_match({"seed": 5, "stacks": [200, 200, 60, 200]})
	p3.begin_trick()
	check(is_equal_approx(p3.bet_cap(), 60.0), "aumento máximo é a menor stack em jogo (sem potes paralelos)")
	# Bot sem fichas pro blind é trocado.
	p3.stacks[3] = 4.0
	check(p3.refill_bots() == [3] and p3.stacks[3] >= 300.0 and p3.stacks[3] <= 600.0, "bot quebrado sai e um novo senta com 30 a 60 blinds")
	# Prêmio da banca e mesa sem fim.
	check(is_equal_approx(p3.chips_of(4.0), 10.0), "1 ponto de carta = 1/4 do blind (4 pts = ◎10)")
	var p4 := ChaosEngine.new()
	p4.setup_match({"seed": 21, "levels": 0})
	var trick_count := 0
	var rng4 := RandomNumberGenerator.new()
	rng4.seed = 5
	var guard := 0
	while trick_count < 24 and guard < 5000:
		guard += 1
		if p4.is_round_over():
			p4.advance_round()
		p4.refill_bots()
		p4.stacks[0] = maxf(p4.stacks[0], 400.0)
		p4.begin_trick()
		while p4.betting:
			var actor := p4.bet_actor()
			var d := ChaosBot.bet_decision(p4, actor, BotAI.Difficulty.HARD, rng4)
			var br := p4.bet_act(actor, str(d["action"]), float(d.get("to", 0.0)))
			check(br["ok"], "decisão do bot é sempre uma ação válida")
			if not br["ok"]:
				p4.bet_act(actor, "fold")
		if p4.walkover_player() != -1:
			p4.resolve_walkover()
		else:
			while true:
				var pl := p4.current
				var rs := p4.play(pl, ChaosBot.choose(p4, pl, BotAI.Difficulty.HARD, rng4))
				if rs["trick_complete"]:
					break
		trick_count += 1
	check(p4.round_index >= 2, "mesa segue em novos níveis sem fim (%d níveis)" % (p4.round_index + 1))
	check(not p4.is_match_over(), "mesa livre nunca acaba sozinha")
	for st in p4.stacks:
		check(float(st) >= 0.0, "ninguém fica com stack negativa")
	var pl2 := ChaosEngine.new()
	pl2.setup_match({"seed": 8, "levels": 2})
	pl2.round_index = 1
	pl2.trick_number = ChaosEngine.HAND_SIZE
	check(pl2.is_match_over() and pl2.is_final_round(), "partida com fim acaba no último nível")
	# Bot: força da mão e decisões.
	var pb := ChaosEngine.new()
	pb.setup_match({"seed": 6})
	pb.hands[3] = [c(CardData.Suit.TRUNFO, 21), c(CardData.Suit.TRUNFO, 20), c(CardData.Suit.PAUS, 14), c(CardData.Suit.COPAS, 14)]
	pb.hands[2] = [c(CardData.Suit.PAUS, 2), c(CardData.Suit.PAUS, 3), c(CardData.Suit.COPAS, 4), c(CardData.Suit.OUROS, 5)]
	check(ChaosBot.hand_strength(pb, 3) > ChaosBot.hand_strength(pb, 2) + 0.4, "mão com Trunfos altos e Reis é bem mais forte")
	pb.modifier = ChaosModifiers.Modifier.VAZA_INVERTIDA
	check(ChaosBot.hand_strength(pb, 2) > ChaosBot.hand_strength(pb, 3), "na Rodada Invertida, cartas baixas são fortes")
	pb.modifier = ChaosModifiers.Modifier.TRUNFO_DOBRO
	pb.begin_trick()
	var pbr := RandomNumberGenerator.new()
	pbr.seed = 3
	var raises := 0
	for i in range(30):
		var dd := ChaosBot.bet_decision(pb, 2, BotAI.Difficulty.HARD, pbr)
		if dd["action"] == "raise":
			raises += 1
	var raises_strong := 0
	for i in range(30):
		if ChaosBot.bet_decision(pb, 3, BotAI.Difficulty.HARD, pbr)["action"] == "raise":
			raises_strong += 1
	check(raises_strong > raises, "bot aumenta mais com mão forte que com mão fraca (%d > %d)" % [raises_strong, raises])
	pb.bet_act(pb.bet_actor(), "raise", 60.0)
	var facing := ChaosBot.bet_decision(pb, pb.bet_actor(), BotAI.Difficulty.NORMAL, pbr)
	check(facing["action"] in ["call", "fold", "raise"], "diante de aumento o bot paga, aumenta ou desiste (não passa)")

	# Combos de mesa e sequência.
	check("CHUVA_TRUNFOS" in ChaosCombos.detect([{"card": c(CardData.Suit.TRUNFO, 3)}, {"card": c(CardData.Suit.TRUNFO, 9)}, {"card": c(CardData.Suit.TRUNFO, 15)}, {"card": c(CardData.Suit.PAUS, 2)}]), "3 Trunfos na mesa = Chuva de Trunfos")
	check("REALEZA" in ChaosCombos.detect([{"card": c(CardData.Suit.PAUS, 11)}, {"card": c(CardData.Suit.PAUS, 13)}, {"card": c(CardData.Suit.PAUS, 14)}, {"card": c(CardData.Suit.PAUS, 2)}]), "3 figuras na mesa = Realeza")
	check("ESCADA" in ChaosCombos.detect([{"card": c(CardData.Suit.PAUS, 7)}, {"card": c(CardData.Suit.PAUS, 8)}, {"card": c(CardData.Suit.PAUS, 9)}, {"card": c(CardData.Suit.COPAS, 2)}]), "3 cartas seguidas do mesmo naipe = Escada")
	check(ChaosCombos.detect([{"card": c(CardData.Suit.PAUS, 7)}, {"card": c(CardData.Suit.COPAS, 8)}, {"card": c(CardData.Suit.PAUS, 10)}, {"card": c(CardData.Suit.PAUS, 2)}]).is_empty(), "sem combo quando não há sequência, figuras ou Trunfos")
	check(is_equal_approx(ChaosCombos.streak_mult(1), 1.0) and is_equal_approx(ChaosCombos.streak_mult(2), 1.25) and is_equal_approx(ChaosCombos.streak_mult(3), 1.5) and is_equal_approx(ChaosCombos.streak_mult(9), 2.0), "vitórias seguidas sobem o multiplicador até ×2")

	# Modificadores (sempre por vaza) e combos.
	var e7 := ChaosEngine.new()
	e7.setup_match({"seed": 9})
	e7.modifier = ChaosModifiers.Modifier.VAZA_INVERTIDA
	e7.round_index = 0
	e7.trick_number = 3
	e7.plays = [
		{"player": 0, "card": c(CardData.Suit.PAUS, 9)},
		{"player": 1, "card": c(CardData.Suit.PAUS, 2)},
		{"player": 2, "card": c(CardData.Suit.PAUS, 12)},
		{"player": 3, "card": c(CardData.Suit.PAUS, 6)},
	]
	var inv := e7._resolve_trick()
	check(int(inv["winner"]) == 1, "Vaza Invertida: a MENOR carta do naipe vence")
	e7.modifier = ChaosModifiers.Modifier.VAZA_DOURADA
	e7.trick_number = 3
	e7.current = 0
	e7.last_winner = 0
	e7.streak = [2, 0, 0, 0]
	e7.plays = [
		{"player": 0, "card": c(CardData.Suit.PAUS, 9)},
		{"player": 1, "card": c(CardData.Suit.PAUS, 2)},
		{"player": 2, "card": c(CardData.Suit.PAUS, 12)},
		{"player": 3, "card": c(CardData.Suit.PAUS, 6)},
	]
	var gold := e7._resolve_trick()
	check(is_equal_approx(float(gold["mult"]), ChaosEngine.GOLD_MULT), "Vaza Dourada multiplica os pontos por 3")
	check("CORTADO" in gold["combos"], "vencer depois de alguém ter 2+ vitórias seguidas é CORTADO")
	e7.modifier = ChaosModifiers.Modifier.VAZA_MALDITA
	e7.trick_number = 3
	e7.streak = [0, 0, 0, 0]
	e7.last_winner = -1
	e7.plays = [
		{"player": 0, "card": c(CardData.Suit.PAUS, 9)},
		{"player": 1, "card": c(CardData.Suit.PAUS, 2)},
		{"player": 2, "card": c(CardData.Suit.PAUS, 3)},
		{"player": 3, "card": c(CardData.Suit.PAUS, 6)},
	]
	var curse := e7._resolve_trick()
	check(float(curse["points"]) < 0.0, "Vaza Maldita: quem vence perde pontos")
	# Bots cientes dos modificadores
	var eb := ChaosEngine.new()
	eb.setup_match({"seed": 1})
	var brng := RandomNumberGenerator.new()
	brng.seed = 7
	eb.modifier = ChaosModifiers.Modifier.VAZA_MALDITA
	eb.trick_number = 3
	eb.current = 3
	eb.plays = [
		{"player": 0, "card": c(CardData.Suit.PAUS, 9)},
		{"player": 1, "card": c(CardData.Suit.PAUS, 2)},
		{"player": 2, "card": c(CardData.Suit.PAUS, 3)},
	]
	eb.hands[3] = [c(CardData.Suit.PAUS, 12), c(CardData.Suit.PAUS, 6)]
	var pick := ChaosBot.choose(eb, 3, BotAI.Difficulty.HARD, brng)
	check(pick.rank == 6 or pick.rank == 12, "bot joga carta legal na Vaza Maldita")
	eb.hands[3] = [c(CardData.Suit.PAUS, 12), c(CardData.Suit.PAUS, 1)]
	pick = ChaosBot.choose(eb, 3, BotAI.Difficulty.HARD, brng)
	check(not eb.would_win(pick, 3) and pick.rank == 1, "Vaza Maldita: bot foge de vencer")
	eb.modifier = ChaosModifiers.Modifier.VAZA_INVERTIDA
	eb.hands[3] = [c(CardData.Suit.PAUS, 12), c(CardData.Suit.PAUS, 1)]
	pick = ChaosBot.choose(eb, 3, BotAI.Difficulty.HARD, brng)
	check(pick.rank == 1 and eb.would_win(pick, 3), "Vaza Invertida: bot vence com a menor carta")
	e7.modifier = ChaosModifiers.Modifier.PEQUENAS_IMPORTAM
	check(e7.card_value(c(CardData.Suit.PAUS, 3)) == 1.0, "Cartas Pequenas Importam: 0,5 vira 1,0")
	e7.modifier = ChaosModifiers.Modifier.NAIPE_FORTE
	e7.weak_suit = CardData.Suit.PAUS
	check(e7.card_value(c(CardData.Suit.PAUS, 14)) == 6.75, "Naipe Forte: 1,5x nos pontos do naipe")
	e7.modifier = ChaosModifiers.Modifier.VAZA_MAIS_UM
	e7.streak = [0, 0, 0, 0]
	e7.last_winner = -1
	e7.trick_number = 1
	e7.plays = [
		{"player": 0, "card": c(CardData.Suit.PAUS, 9)},
		{"player": 1, "card": c(CardData.Suit.PAUS, 2)},
		{"player": 2, "card": c(CardData.Suit.PAUS, 3)},
		{"player": 3, "card": c(CardData.Suit.PAUS, 6)},
	]
	check(is_equal_approx(float(e7._resolve_trick()["bonus"]), 1.0), "Cada Vaza Vale +1 soma 1 ponto fixo")
	e7.modifier = ChaosModifiers.Modifier.TRUNFO_DOBRO
	e7.trick_number = 0
	e7.last_winner = 0
	e7.streak = [2, 0, 0, 0]
	e7.plays = [
		{"player": 0, "card": c(CardData.Suit.PAUS, 14)},
		{"player": 1, "card": c(CardData.Suit.PAUS, 2)},
		{"player": 2, "card": c(CardData.Suit.PAUS, 3)},
		{"player": 3, "card": c(CardData.Suit.PAUS, 6)},
	]
	var hot := e7._resolve_trick()
	check("MAO_QUENTE" in hot["combos"], "3ª vitória seguida é MÃO QUENTE")
	# Sorteio por vaza: cada nível embaralha os 12 e usa 8, um por vaza, sem repetir no nível.
	var e8 := ChaosEngine.new()
	e8.setup_match({"seed": 11})
	check(e8.modifier == -1, "antes da 1ª vaza começar, ainda não tem modificador sorteado")
	var seen := {}
	for t in range(ChaosEngine.HAND_SIZE):
		e8.trick_number = t
		e8.draw_trick_modifier()
		check(e8.modifier != -1, "toda vaza sorteia um modificador")
		check(not seen.has(e8.modifier), "não repete modificador dentro do mesmo nível")
		seen[e8.modifier] = true
		if ChaosModifiers.has_suit(e8.modifier):
			check(e8.weak_suit != -1, "modificador de naipe sorteia o naipe")
	check(seen.size() == ChaosEngine.HAND_SIZE, "as 8 vazas do nível usam 8 modificadores diferentes")
	check(ChaosModifiers.ALL.size() == 11, "são 11 modificadores ao todo")


## Bots estratégicos: só fazem jogadas legais em qualquer nível e, na defesa, seguram muito
## mais o Atacante do que o bot simples (mesmas mãos, mesma semente).
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
	check(int(results[BotAI.Difficulty.HARD]) < int(results[-1]), "defesa Difícil segura o Atacante mais que a simples (%d < %d)" % [results[BotAI.Difficulty.HARD], results[-1]])
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


## Contraste das cores por função sobre os fundos do jogo (WCAG: texto ≥ 4,5:1).
func _test_blitz() -> void:
	var e := ChaosEngine.new()
	e.setup_match({"seed": 11, "mode": "blitz", "blind": 10, "levels": 0})
	e.rake_on = false
	e.bonus_on = false
	e.trick_number = 0
	e.draw_trick_modifier()
	check(e.blitz and ChaosModifiers.ALL.has(e.modifier), "Blitz: sorteia dos mesmos 11 modificadores do Caos")
	var start_total := 0.0
	for x in e.stacks:
		start_total += float(x)
	for p in range(4):
		check(e.blitz_place(p, 2), "Blitz: palpite aceito")
	check(not e.blitz_place(0, 3), "Blitz: palpite só uma vez por nível")
	check(is_equal_approx(e.pot, 4.0 * e.blitz_entry()) and e.blitz_ready(), "Blitz: entradas somam no pote")
	check(not e.can_double(0), "Blitz: só dobra a partir da 4ª rodada")
	var brng := RandomNumberGenerator.new()
	brng.seed = 5
	var had_gold := false
	while not e.is_round_over():
		if e.plays.is_empty():
			e.draw_trick_modifier()
			if e.modifier == ChaosModifiers.Modifier.VAZA_DOURADA:
				had_gold = true
		var pl := e.current
		e.play(pl, ChaosBot.choose(e, pl, BotAI.Difficulty.NORMAL, brng))
	var total := 0.0
	for x in e.stacks:
		total += float(x)
	check(is_equal_approx(total + e.carry, start_total), "Blitz: fichas se conservam (sem taxa): tem %s esperava %s" % [total + e.carry, start_total])
	var won_sum := 0
	for w in e.wins:
		won_sum += int(w)
	check(won_sum == ChaosEngine.HAND_SIZE or had_gold, "Blitz: 8 vitórias distribuídas por nível")

	# Liquidação com números forçados: entrada 20 por jogador, pote 80.
	var f := ChaosEngine.new()
	f.setup_match({"seed": 1, "mode": "blitz", "blind": 10})
	f.rake_on = false
	f.bonus_on = false
	f.carry = 0.0
	f.pot = 80.0
	f.stakes = [20.0, 20.0, 20.0, 20.0]
	f.predicts = [1, 3, 5, 0]
	f.wins = [1, 2, 7, 4]      # p0 acerta; p1 erra por 1; p2 erra por 2; p3 erra por 4
	var r := f._settle_blitz()
	check((r["hits"] as Array) == [0] and (r["near"] as Array) == [1], "Blitz: acertou exato / errou por 1")
	check(is_equal_approx(float(r["refunds"][1]), 10.0), "Blitz: errou por 1 recebe metade da entrada")
	check(is_equal_approx(float(r["payouts"][0]), 70.0) and is_equal_approx(float(r["net"][0]), 50.0), "Blitz: único acerto leva o pote (menos o reembolso)")
	check(is_equal_approx(float(r["net"][2]), -20.0) and is_equal_approx(float(r["net"][3]), -20.0), "Blitz: errou por 2+ perde a entrada")
	check(is_equal_approx(f.carry, 0.0) and is_equal_approx(f.pot, 0.0), "Blitz: pote pago zera")

	var f2 := ChaosEngine.new()
	f2.setup_match({"seed": 1, "mode": "blitz", "blind": 10})
	f2.rake_on = false
	f2.bonus_on = false
	f2.pot = 80.0
	f2.stakes = [20.0, 20.0, 20.0, 20.0]
	f2.predicts = [1, 3, 5, 0]
	f2.wins = [4, 4, 0, 4]
	var r2 := f2._settle_blitz()
	check((r2["hits"] as Array).is_empty() and is_equal_approx(f2.carry, 80.0 - float(r2["refunds"][1]) - float(r2["refunds"][3]) - float(r2["refunds"][0]) - float(r2["refunds"][2])), "Blitz: ninguém acertou, pote acumula")
	f2.pot = f2.carry + 80.0
	var carried := f2.pot
	f2.stakes = [20.0, 20.0, 20.0, 20.0]
	f2.predicts = [1, 3, 5, 0]
	f2.wins = [1, 3, 0, 4]     # p0 (peso 1×20) e p1 (peso 1,5×20) acertam: reparte 2:3
	var r3 := f2._settle_blitz()
	check(is_equal_approx(float(r3["payouts"][0]) + float(r3["payouts"][1]), carried - float(r3["refunds"][3]) - float(r3["refunds"][2]) - float(r3["refunds"][0]) - float(r3["refunds"][1])), "Blitz: acertos dividem o pote inteiro (incluindo o acumulado)")
	check(float(r3["payouts"][1]) > float(r3["payouts"][0]), "Blitz: palpite mais alto pesa mais no pote")

	# Prêmio de sequência (rakeback): só pra você, só a partir do 3º acerto seguido, e nunca
	# maior que metade da taxa que a casa já cobrou de você (o "cofre").
	var bn := ChaosEngine.new()
	bn.setup_match({"seed": 1, "mode": "blitz", "blind": 10})
	bn.rake_on = true
	for i in range(2):
		bn.pot = 800.0
		bn.stakes = [200.0, 200.0, 200.0, 200.0]
		bn.predicts = [3, 0, 0, 0]
		bn.wins = [3, 1, 1, 1]
		var rb := bn._settle_blitz()
		check(is_equal_approx(float(rb["bonus"]), 0.0), "Blitz: %dº acerto seguido ainda não libera o prêmio de sequência" % (i + 1))
	check(bn.hit_streak == 2 and bn.human_rake > 0.0, "Blitz: taxa acumula no cofre a cada pote pago")
	var vault_before := bn.human_rake
	bn.pot = 800.0
	bn.stakes = [200.0, 200.0, 200.0, 200.0]
	bn.predicts = [3, 0, 0, 0]
	bn.wins = [3, 1, 1, 1]
	var rb3 := bn._settle_blitz()
	check(int(rb3["streak"]) == 3 and float(rb3["bonus"]) > 0.0, "Blitz: 3 acertos seguidos liberam o prêmio de sequência")
	check(float(rb3["bonus"]) <= 0.5 * bn.human_rake + 0.001, "Blitz: prêmio nunca passa de metade da taxa acumulada no cofre")
	check(float(rb3["bonus"]) <= ChaosEngine.BLITZ_STREAK_BONUS_BLINDS * bn.blind, "Blitz: prêmio tem teto de %d blinds" % ChaosEngine.BLITZ_STREAK_BONUS_BLINDS)
	check(bn.human_rake > vault_before, "Blitz: o cofre segue enchendo mesmo depois de pagar o prêmio")
	bn.pot = 800.0
	bn.predicts = [3, 0, 0, 0]
	bn.wins = [2, 1, 1, 1]
	var rb4 := bn._settle_blitz()
	check(is_equal_approx(float(rb4["bonus"]), 0.0) and bn.hit_streak == 0, "Blitz: errar zera a sequência e não dá prêmio")

	# Taxa da casa só quando o pote é pago.
	var f3 := ChaosEngine.new()
	f3.setup_match({"seed": 1, "mode": "blitz", "blind": 10})
	f3.pot = 80.0
	f3.stakes = [20.0, 20.0, 20.0, 20.0]
	f3.predicts = [2, 2, 2, 2]
	f3.wins = [2, 1, 1, 4]
	var r4 := f3._settle_blitz()
	check(float(r4["rake"]) > 0.0 and float(r4["rake"]) <= 1.5 * 10.0, "Blitz: taxa da casa limitada quando há pagamento")

	# Dobrar / triplicar.
	var d := ChaosEngine.new()
	d.setup_match({"seed": 4, "mode": "blitz", "blind": 10})
	for p in range(4):
		d.blitz_place(p, 1)
	d.trick_number = 3
	d.wins[0] = 1
	check(d.can_double(0), "Blitz: no alvo, a partir da 4ª rodada, pode dobrar")
	var pot_before := d.pot
	check(d.double_down(0) and is_equal_approx(d.pot, pot_before + d.blitz_entry()) and is_equal_approx(float(d.stakes[0]), 2.0 * d.blitz_entry()), "Blitz: dobrar põe outra entrada no pote")
	check(not d.can_double(0), "Blitz: o 2º lance só a partir da 6ª rodada")
	d.trick_number = 4
	check(not d.can_double(0), "Blitz: 5ª rodada ainda não libera triplicar")
	d.trick_number = 5
	check(d.can_double(0) and d.double_down(0) and int(d.doubles[0]) == 2, "Blitz: da 6ª rodada em diante, dá pra triplicar")
	check(not d.can_double(0), "Blitz: no máximo 2 lances por nível")
	d.wins[1] = 5
	check(not d.can_double(1), "Blitz: não dobra quando já estourou o palpite")
	d.wins[2] = 0
	d.trick_number = 7
	d.predicts[2] = 3
	check(not d.can_double(2), "Blitz: não dobra quando não dá mais tempo de acertar")

	# Cobrir a dobra/triplicada de um rival.
	var cv := ChaosEngine.new()
	cv.setup_match({"seed": 4, "mode": "blitz", "blind": 10})
	for p in range(4):
		cv.blitz_place(p, 1)
	cv.trick_number = 0
	cv.wins[0] = 1
	check(cv.can_cover(0), "Blitz: cobrir não espera a 4ª rodada, ao contrário de dobrar")
	check(not cv.can_double(0), "Blitz: dobrar (iniciativa própria) continua esperando a rodada")
	var pot_cover := cv.pot
	check(cv.cover_double(0) and is_equal_approx(cv.pot, pot_cover + cv.blitz_entry()) and int(cv.doubles[0]) == 1, "Blitz: cobrir paga mais uma entrada como um dobrar")
	cv.wins[1] = 6
	check(not cv.can_cover(1), "Blitz: não cobre quando já estourou o palpite")
	check(cv.can_cover(2), "Blitz: outro jogador ainda pode cobrir")
	cv.stacks[2] = 0.0
	check(not cv.can_cover(2), "Blitz: sem fichas pra pagar a entrada, não cobre")

	# Rodada Dobrada conta 2 vitórias.
	var g2 := ChaosEngine.new()
	g2.setup_match({"seed": 9, "mode": "blitz", "blind": 10})
	g2.modifier = ChaosModifiers.Modifier.VAZA_DOURADA
	g2.hands[0] = [c(CardData.Suit.TRUNFO, 20)]
	g2.hands[1] = [c(CardData.Suit.PAUS, 3)]
	g2.hands[2] = [c(CardData.Suit.PAUS, 4)]
	g2.hands[3] = [c(CardData.Suit.PAUS, 5)]
	g2.leader = 0
	g2.current = 0
	for pl in range(4):
		g2.play(pl, (g2.hands[pl] as Array)[0])
	check(int(g2.wins[0]) == 2, "Blitz: Rodada Dobrada conta 2 vitórias")

	# No Blitz, Saque/Assalto/Maldita ainda mexem em fichas de verdade (à parte do palpite);
	# os outros 6 modificadores não têm efeito nenhum lá (só valem no Caos).
	check(ChaosModifiers.has_blitz_effect(ChaosModifiers.Modifier.SAQUE), "Saque tem efeito no Blitz")
	check(not ChaosModifiers.has_blitz_effect(ChaosModifiers.Modifier.TRUNFO_DOBRO), "Trunfo em Dobro não tem efeito no Blitz")
	var gs := ChaosEngine.new()
	gs.setup_match({"seed": 9, "mode": "blitz", "blind": 10, "stacks": [200.0, 200.0, 200.0, 200.0]})
	gs.modifier = ChaosModifiers.Modifier.SAQUE
	gs.hands[0] = [c(CardData.Suit.TRUNFO, 20)]
	gs.hands[1] = [c(CardData.Suit.PAUS, 3)]
	gs.hands[2] = [c(CardData.Suit.PAUS, 4)]
	gs.hands[3] = [c(CardData.Suit.PAUS, 5)]
	gs.leader = 0
	gs.current = 0
	for pl in range(4):
		gs.play(pl, (gs.hands[pl] as Array)[0])
	var take := gs.chips_of(ChaosEngine.SAQUE_AMOUNT)
	check(is_equal_approx(float(gs.stacks[0]), 200.0 + 3.0 * take) and is_equal_approx(float(gs.stacks[1]), 200.0 - take), "Blitz: Saque rouba fichas de cada rival, além de contar a vitória")

	var ga := ChaosEngine.new()
	ga.setup_match({"seed": 9, "mode": "blitz", "blind": 10, "stacks": [200.0, 200.0, 500.0, 200.0]})
	ga.modifier = ChaosModifiers.Modifier.ASSALTO_LIDER
	ga.hands[0] = [c(CardData.Suit.TRUNFO, 20)]
	ga.hands[1] = [c(CardData.Suit.PAUS, 3)]
	ga.hands[2] = [c(CardData.Suit.PAUS, 4)]
	ga.hands[3] = [c(CardData.Suit.PAUS, 5)]
	ga.leader = 0
	ga.current = 0
	for pl in range(4):
		ga.play(pl, (ga.hands[pl] as Array)[0])
	var stolen := ga.chips_of(ChaosEngine.ASSALTO_AMOUNT)
	check(is_equal_approx(float(ga.stacks[0]), 200.0 + stolen) and is_equal_approx(float(ga.stacks[2]), 500.0 - stolen), "Blitz: Assalto ao Líder rouba de quem lidera a stack, além de contar a vitória")

	var gm := ChaosEngine.new()
	gm.setup_match({"seed": 9, "mode": "blitz", "blind": 10, "stacks": [200.0, 200.0, 200.0, 200.0]})
	gm.modifier = ChaosModifiers.Modifier.VAZA_MALDITA
	gm.hands[0] = [c(CardData.Suit.TRUNFO, 20)]
	gm.hands[1] = [c(CardData.Suit.PAUS, 3)]
	gm.hands[2] = [c(CardData.Suit.PAUS, 4)]
	gm.hands[3] = [c(CardData.Suit.PAUS, 5)]
	gm.leader = 0
	gm.current = 0
	for pl in range(4):
		gm.play(pl, (gm.hands[pl] as Array)[0])
	check(float(gm.stacks[0]) < 200.0 and float(gm.stacks[1]) > 200.0, "Blitz: Rodada Maldita faz quem vence pagar aos rivais, além de contar a vitória")

	# Bots: palpite em 0..8, calibrado com a média real (2 vitórias por jogador).
	var cal := ChaosEngine.new()
	cal.setup_match({"seed": 77, "mode": "blitz", "blind": 10})
	var sum_exp := 0.0
	var n_exp := 0
	for i in range(60):
		cal.advance_round()
		for p in range(4):
			var pick := ChaosBot.blitz_pick(cal, p, BotAI.Difficulty.HARD, brng)
			check(pick >= 0 and pick <= ChaosEngine.HAND_SIZE, "Blitz: palpite do bot em 0..8")
			sum_exp += ChaosBot.expected_wins(cal, p)
			n_exp += 1
	check(absf(sum_exp / float(n_exp) - 2.0) < 0.35, "Blitz: palpite esperado calibrado perto de 2 (deu %s)" % [sum_exp / float(n_exp)])
	# No alvo, o bot foge da rodada: joga a carta menor.
	var fb := ChaosEngine.new()
	fb.setup_match({"seed": 2, "mode": "blitz", "blind": 10})
	fb.modifier = ChaosModifiers.Modifier.LOUCO_VENCE
	fb.predicts = [1, 1, 1, 1]
	fb.wins = [1, 0, 0, 0]
	fb.hands[0] = [c(CardData.Suit.PAUS, 14), c(CardData.Suit.PAUS, 2)]
	fb.plays = [{"player": 3, "card": c(CardData.Suit.PAUS, 10)}]
	fb.current = 0
	check(ChaosBot.choose(fb, 0, BotAI.Difficulty.HARD, brng).rank == 2, "Blitz: bot já no alvo evita vencer a rodada")


func _test_colors() -> void:
	var bgs := {"NIGHT": UIKit.NIGHT, "PURPLE_DEEP": UIKit.PURPLE_DEEP}
	var fgs := {"INK": UIKit.INK, "MUTED": UIKit.MUTED, "MONEY": UIKit.MONEY, "TURN": UIKit.TURN, "GAIN": UIKit.GAIN, "LOSS": UIKit.LOSS, "INFO": UIKit.INFO, "COMBO": UIKit.COMBO, "MODIFIER": UIKit.MODIFIER}
	for bn in bgs:
		for fn in fgs:
			check(UIKit.contrast(fgs[fn], bgs[bn]) >= 4.5, "cor %s legível sobre %s (%.1f:1)" % [fn, bn, UIKit.contrast(fgs[fn], bgs[bn])])
	check(UIKit.text_on(UIKit.GOLD) == UIKit.TEXT_ON_LIGHT and UIKit.text_on(UIKit.OK) == UIKit.TEXT_ON_LIGHT, "botões dourado e verde usam texto escuro")
	check(UIKit.text_on(UIKit.PURPLE_DEEP) == UIKit.INK and UIKit.text_on(UIKit.VIOLET) == UIKit.INK, "botões escuros usam texto claro")
	check(UIKit.contrast(UIKit.TEXT_ON_LIGHT, UIKit.GOLD) >= 4.5, "texto escuro legível sobre dourado")


## Economia de fichas: pacotes, recarga diária, taxa da casa e conservação de fichas.
func _test_economy() -> void:
	var prev := 0.0
	for pk in ChaosEconomy.PACKS:
		var rate := ChaosEconomy.fichas_per_real(pk)
		check(rate >= prev, "pacote %s não dá menos fichas por real que o menor (%.0f/R$)" % [pk["name"], rate])
		prev = rate
	check(ChaosEconomy.bonus_pct(ChaosEconomy.PACKS[0]) == 0 and ChaosEconomy.bonus_pct(ChaosEconomy.PACKS[3]) >= 30, "bônus cresce com o tamanho do pacote")
	check(ChaosEconomy.START_FICHAS >= 10 * ChaosEngine.BUY_IN_BLINDS * 3, "saldo inicial paga 3 entradas mínimas")
	check(ChaosEconomy.DAILY_MIN >= 10 * ChaosEngine.BUY_IN_BLINDS, "recarga libera quando não dá pra pagar a entrada mais barata")
	var prof := {"fichas": 100}
	check(ChaosEconomy.daily_available(prof), "recarga liberada abaixo do mínimo")
	check(ChaosEconomy.claim_daily(prof) == ChaosEconomy.DAILY_AMOUNT and int(prof["fichas"]) == 100 + ChaosEconomy.DAILY_AMOUNT, "coletar credita a recarga")
	prof["fichas"] = 50
	check(not ChaosEconomy.daily_available(prof) and ChaosEconomy.claim_daily(prof) == 0, "só uma recarga por dia")
	prof = {"fichas": 900}
	check(not ChaosEconomy.daily_available(prof), "sem recarga com saldo acima do mínimo")
	prof = {"fichas": 10}
	check(ChaosEconomy.PACKS.size() == 4 and ChaosEconomy.buy_simulated(prof, "cofre") == 3600 and int(prof["fichas"]) == 3610 and int(prof["spent_cents"]) == 1990, "compra simulada credita fichas e registra o gasto")
	check(ChaosEconomy.buy_simulated(prof, "nada") == 0, "pacote inexistente não credita")
	check(is_equal_approx(ChaosEconomy.rake_of(100.0, 10), 3.0) and is_equal_approx(ChaosEconomy.rake_of(2000.0, 10), 15.0), "taxa é 3% do pote com teto de 1,5 blinds")
	check(ChaosEconomy.price_text(1990) == "R$ 19,90", "preço em reais")
	# Conservação: sem trocas de bot, fichas na mesa + taxa da casa não mudam.
	var ec := ChaosEngine.new()
	ec.setup_match({"seed": 31, "levels": 0})
	var total0 := 0.0
	for st in ec.stacks:
		total0 += float(st)
	var rr := RandomNumberGenerator.new()
	rr.seed = 4
	for i in range(6):
		ec.begin_trick()
		while ec.betting:
			var a := ec.bet_actor()
			var d := ChaosBot.bet_decision(ec, a, BotAI.Difficulty.NORMAL, rr)
			ec.bet_act(a, str(d["action"]), float(d.get("to", 0.0)))
		if ec.walkover_player() != -1:
			ec.resolve_walkover()
		else:
			while true:
				var pl := ec.current
				var rs := ec.play(pl, ChaosBot.choose(ec, pl, BotAI.Difficulty.NORMAL, rr))
				if rs["trick_complete"]:
					break
	var total1 := 0.0
	for st in ec.stacks:
		total1 += float(st)
	check(is_equal_approx(total0, total1 + ec.house_rake), "fichas se conservam: mesa + taxa da casa = total inicial (taxa %.0f)" % ec.house_rake)
	check(ec.house_rake > 0.0, "a casa cobra taxa nas rodadas disputadas")


## Padronização da interface: telas só criam botões, rótulos, estilos e cores pelo UIKit.
## (card_view e portrait são arte das cartas e dos avatares, com paleta própria.)
func _test_standards() -> void:
	var art := ["card_view.gd", "portrait.gd", "ui_kit.gd"]
	var files: Array = []
	for dir in ["res://scripts/ui/", "res://scripts/autoload/"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd") and not art.has(f):
				files.append(dir + f)
	var banned := {
		"Button.new()": "botão fora do UIKit (use UIKit.button / icon_button / nav_button)",
		"StyleBoxFlat.new()": "estilo fora do UIKit (use UIKit.box / chunky / dot_style / bar_style)",
		"Label.new()": "rótulo fora do UIKit (use UIKit.label)",
		"Color(\"#": "cor solta (use um token do UIKit)",
		"UIKit.GOLD": "dourado cru (use BRAND, MONEY ou ME conforme o papel)",
	}
	var re := RegEx.new()
	re.compile("(^|[^A-Za-z_])Button\\.new\\(\\)")
	for path in files:
		var f := FileAccess.open(path, FileAccess.READ)
		var lines := f.get_as_text().split("\n")
		var bad := 0
		for line in lines:
			var l: String = line
			if l.strip_edges().begins_with("#") or l.strip_edges().begins_with("##"):
				continue
			for pat in banned:
				var hit: bool = re.search(l) != null if pat == "Button.new()" else l.contains(pat)
				# UIKit.GOLD_LIGHT é um token legítimo.
				if pat == "UIKit.GOLD" and not l.replace("UIKit.GOLD_LIGHT", "").contains("UIKit.GOLD"):
					hit = false
				if hit:
					bad += 1
					printerr("  %s: %s -> %s" % [path.get_file(), banned[pat], l.strip_edges()])
		check(bad == 0, "%s segue o padrão do UIKit (%d desvios)" % [path.get_file(), bad])
