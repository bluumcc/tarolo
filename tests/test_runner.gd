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
	check(e.blind == 10 and int(e.stacks[0]) == 200, "mesa padrão: blind 10 e stack de 20 blinds")

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

	# ---- Aposta estilo poker
	var p1 := ChaosEngine.new()
	p1.setup_match({"seed": 3})
	p1.begin_trick()
	check(is_equal_approx(p1.pot, 40.0) and is_equal_approx(p1.stacks[0], 190.0), "blind de todos vai pro pote")
	check(p1.button == 1 and p1.bet_actor() == 2, "o botão gira e fala primeiro quem vem depois dele")
	var o0 := p1.bet_options(2)
	check(bool(o0["can_check"]) and is_equal_approx(float(o0["min_to"]), 20.0) and is_equal_approx(float(o0["max_to"]), 200.0), "primeiro a falar pode passar; aumento mínimo = 1 blind; máximo = menor stack")
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
	check(is_equal_approx(p1.stacks[2], 160.0) and is_equal_approx(p1.pot, 130.0), "quem pagou põe o mesmo valor (40 cada; 10 do que desistiu)")
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
	check(bool(wo["walkover"]) and is_equal_approx(p2.stacks[2], 200.0 - 20.0 + 50.0), "blefe vence: leva o pote sem jogar carta")
	check(p2.hands[2].size() == 7 and p2.hands[3].size() == 7, "no blefe vencido o vencedor também descarta, mãos iguais")
	check(p2.trick_number == 1 and p2.session_stats[2]["bluffs"] == 1, "rodada conta e o blefe é registrado")
	# All-in limitado pela menor stack.
	var p3 := ChaosEngine.new()
	p3.setup_match({"seed": 5, "stacks": [200, 200, 60, 200]})
	p3.begin_trick()
	check(is_equal_approx(p3.bet_cap(), 60.0), "aumento máximo é a menor stack em jogo (sem potes paralelos)")
	# Bot sem fichas pro blind é trocado.
	p3.stacks[3] = 4.0
	check(p3.refill_bots() == [3] and is_equal_approx(p3.stacks[3], 200.0), "bot quebrado sai e um novo senta com o buy-in")
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
		p4.stacks[0] = maxf(p4.stacks[0], 200.0)
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
	pb.modifier = ChaosModifiers.Modifier.MUNDO_CONTRARIO
	pb.modifier_trick = -1
	check(ChaosBot.hand_strength(pb, 2) > ChaosBot.hand_strength(pb, 3), "no Mundo ao Contrário, cartas baixas são fortes")
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

	# Modificadores de vaza única e combos.
	var e7 := ChaosEngine.new()
	e7.setup_match({"seed": 9})
	e7.modifier = ChaosModifiers.Modifier.VAZA_INVERTIDA
	e7.modifier_trick = 3
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
	e7.trick_number = 2
	e7.plays = [
		{"player": 0, "card": c(CardData.Suit.PAUS, 9)},
		{"player": 1, "card": c(CardData.Suit.PAUS, 2)},
		{"player": 2, "card": c(CardData.Suit.PAUS, 12)},
		{"player": 3, "card": c(CardData.Suit.PAUS, 6)},
	]
	check(int(e7._resolve_trick()["winner"]) == 2, "fora da vaza sorteada a regra normal vale (maior vence)")
	e7.modifier = ChaosModifiers.Modifier.VAZA_DOURADA
	e7.modifier_trick = 3
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
	e7.modifier = ChaosModifiers.Modifier.NAIPE_MALDITO
	e7.weak_suit = CardData.Suit.COPAS
	check(e7.card_value(c(CardData.Suit.COPAS, 14)) == -1.0, "Naipe Maldito: carta do naipe vale -1")
	# Bots cientes dos modificadores
	var eb := ChaosEngine.new()
	eb.setup_match({"seed": 1})
	var brng := RandomNumberGenerator.new()
	brng.seed = 7
	eb.modifier = ChaosModifiers.Modifier.VAZA_MALDITA
	eb.modifier_trick = 3
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
	# Sorteio: escopo de vaza sempre tem vaza definida; escopo de rodada não.
	var e8 := ChaosEngine.new()
	e8.setup_match({"seed": 11})
	var seen_trick := 0
	var seen_round := 0
	for r in range(ChaosEngine.ROUNDS):
		if ChaosModifiers.scope_of(e8.modifier) == ChaosModifiers.Scope.TRICK:
			check(e8.modifier_trick >= 0 and e8.modifier_trick < ChaosEngine.HAND_SIZE, "modificador de vaza tem vaza sorteada")
			seen_trick += 1
		else:
			check(e8.modifier_trick == -1, "modificador de rodada não tem vaza")
			seen_round += 1
		if ChaosModifiers.has_suit(e8.modifier):
			check(e8.weak_suit != -1, "modificador de naipe sorteia o naipe")
		if r < ChaosEngine.ROUNDS - 1:
			e8.advance_round()
	check(seen_trick + seen_round == ChaosEngine.ROUNDS, "toda rodada sorteia exatamente um modificador")


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
