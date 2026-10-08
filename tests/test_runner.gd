extends SceneTree
## Testes headless da Fase 1: baralho de 78 cartas e regras de vaza (obrigação de
## seguir naipe, obrigação de cortar/cobrir com Trunfo, O Louco).
## Uso: godot --headless --path . -s res://tests/test_runner.gd

var failures := 0
var passed := 0


func _init() -> void:
	_test_deck()
	await _test_accounts()
	_test_dynamic_seats()
	_test_points()
	_test_follow_suit()
	_test_trunfo_forced()
	_test_cover_trunfo()
	_test_louco()
	_test_louco_ownership()
	_test_winner()
	_test_bidding()
	_test_bonuses()
	_test_blitz_engine()
	_test_blitz()
	_test_blitz_phase4()
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
	check((caos["hands"][0] as Array).size() == 8, "Deck: 8 cartas por jogador")
	check((caos["rest"] as Array).size() == 78 - 32, "Deck: resto do baralho não usado")


## Mesa ranqueada com gente entrando e saindo: assentos vagos, jogadores em espera e conservação de fichas.
func _test_dynamic_seats() -> void:
	# Mesa de 6 lugares com 2 vagos: vago não paga ante, não entra na classificação, não tem mão.
	var d := BlitzEngine.new()
	d.setup_match({"seed": 21, "levels": 0, "blind": 10, "players": 6, "stacks": [400.0, 400.0, 400.0, 400.0, 400.0, 400.0], "vacant": [4, 5], "dynamic_seats": true, "ante_factor": 0.0})
	check(d.seated_count() == 4 and d.vacant[4] and d.vacant[5] and not d.vacant[0], "mesa de 6 lugares com 4 sentados")
	check(is_zero_approx(float(d.stacks[4])) and (d.hands[4] as Array).is_empty() and bool(d.busted[5]), "assento vago: sem fichas, sem mão, fora do jogo")
	_discard_all(d)
	for dp in range(6):
		d.blitz_place(dp, 2)
	check(not d.blitz_place(4, 2) and is_zero_approx(float(d.stakes[4])), "assento vago não faz profecia")
	d.begin_trick()
	check(is_equal_approx(d.trick_pot, 40.0) and d.active_count() == 4, "só os sentados pagam o blind e jogam (4 x ◎10)")
	check((d.make_standings()["standings"] as Array).size() == 4 and not (d.make_standings()["standings"] as Array).has(5), "a classificação só tem quem está sentado")
	d.betting = false
	d.trick_pot = 0.0
	for dq in range(6):
		d.contrib[dq] = 0.0

	# Quem sai: as fichas saem da mesa, o seu assento vira vago, a entrada da profecia fica no pote.
	var lv := BlitzEngine.new()
	lv.setup_match({"seed": 22, "levels": 0, "blind": 10, "players": 6, "stacks": [400.0, 400.0, 400.0, 400.0, 400.0, 400.0], "dynamic_seats": true})
	_discard_all(lv)
	for lp in range(6):
		lv.blitz_place(lp, 2)
	var lv_total := SimLib.total_chips(lv)
	var lv_stake := float(lv.stakes[3])
	var lv_pot := lv.pot
	check(not lv.leave_seat(0), "você não sai da mesa pela agenda")
	check(lv.leave_seat(3) and lv.vacant[3] and is_zero_approx(float(lv.stacks[3])) and (lv.hands[3] as Array).is_empty(), "quem sai deixa o assento vago, sem fichas nem mão")
	check(is_equal_approx(lv.cashed_out, 400.0 - lv_stake) and is_equal_approx(lv.pot, lv_pot), "as fichas saem com ele; a entrada da profecia dele continua no pote")
	check(absf(SimLib.total_chips(lv) - lv_total) < SimLib.EPS, "sair da mesa não cria nem apaga fichas na contabilidade")
	lv.begin_trick()
	check(not lv.leave_seat(2), "ninguém sai no meio de uma jogada")
	lv.betting = false
	lv.trick_pot = 0.0
	for lq in range(6):
		lv.contrib[lq] = 0.0

	# Quem entra no meio do Ritual espera: sem mão, sem ante, sem profecia, até o próximo.
	var jn := BlitzEngine.new()
	jn.setup_match({"seed": 23, "levels": 0, "blind": 10, "players": 6, "stacks": [400.0, 400.0, 400.0, 400.0, 400.0, 400.0], "vacant": [5], "dynamic_seats": true})
	_discard_all(jn)
	for jp in range(6):
		jn.blitz_place(jp, 1)
	check(jn.join_seat(5, 500.0, 1) and jn.waiting[5] and jn.busted[5] and not jn.vacant[5], "quem entra no meio do Ritual fica em espera")
	check(not jn.join_seat(1, 500.0, 1), "só entra em assento vago")
	check(is_equal_approx(jn.cashed_in, 500.0) and (jn.hands[5] as Array).is_empty(), "entrou com 500 fichas e sem mão")
	jn.begin_trick()
	check(is_equal_approx(float(jn.stacks[5]), 500.0) and not jn.active_players().has(5), "quem espera não paga blind nem joga")
	check(not jn.blitz_place(5, 3), "quem espera não faz profecia")
	jn.betting = false
	jn.trick_pot = 0.0
	for jq in range(6):
		jn.contrib[jq] = 0.0
	jn.trick_number = BlitzEngine.HAND_SIZE   # o Ritual acaba
	jn.blitz_result = jn._settle_blitz()
	jn.advance_round()
	check(not jn.waiting[5] and not jn.busted[5] and (jn.hands[5] as Array).size() == BlitzEngine.BLITZ_DEAL_SIZE, "no próximo Ritual quem esperava recebe mão e joga")

	# Completar a mesa no começo do Ritual: senta já jogando.
	var fl := BlitzEngine.new()
	fl.setup_match({"seed": 24, "levels": 0, "blind": 10, "players": 6, "stacks": [400.0, 400.0, 400.0, 400.0, 400.0, 400.0], "vacant": [2, 3, 4, 5], "dynamic_seats": true})
	var fl_ev := fl.ensure_seated(4)
	check(fl.seated_count() == 4 and fl_ev.size() == 2, "mesa com poucos sentados é completada no começo do Ritual")
	var sat_ok := true
	for fe in fl_ev:
		sat_ok = sat_ok and not bool(fl.busted[int(fe["seat"])]) and not bool(fl.waiting[int(fe["seat"])])
	check(sat_ok, "quem senta antes do Ritual já joga ele")

	# Simulação: 40 Rituais com gente entrando e saindo. Nada trava, nenhuma ficha some,
	# a mesa nunca fica com menos de 3 sentados e você nunca perde o assento.
	var sim := BlitzEngine.new()
	sim.setup_match({"seed": 77, "levels": 0, "blind": 10, "players": 6, "stacks": [600.0, 600.0, 600.0, 600.0, 600.0, 600.0], "dynamic_seats": true})
	var srng := RandomNumberGenerator.new()
	srng.seed = 5
	var diffs := [1, 1, 1, 1, 1, 1]
	var prev_end := -1.0   # as fichas só fecham a conta no fim do nível (durante ele o acumulado aparece em `pot` e em `carry`)
	var lefts := 0
	var joins := 0
	var sim_ok := true
	var min_seated := 99
	var seat0 := true
	for lvl in range(40):
		var seated_before := sim.seated_count()
		var done := SimLib.play_level(sim, srng, diffs, "bot", Callable(), true)
		var end_total := SimLib.total_chips(sim)
		sim_ok = sim_ok and done and (prev_end < 0.0 or absf(end_total - prev_end) < SimLib.EPS)
		prev_end = end_total
		min_seated = mini(min_seated, sim.seated_count())
		seat0 = seat0 and not bool(sim.vacant[0])
		lefts += maxi(seated_before - sim.seated_count(), 0)
		for sq in range(6):
			joins += 1 if sim.waiting[sq] else 0
		sim.advance_round()
		sim.refill_bots()
		sim.ensure_seated(BlitzEngine.MIN_SEATED)
		if float(sim.stacks[0]) < float(sim.blind) * 12.0:   # recompra (entra como ficha nova na conta)
			sim.stacks[0] += 600.0
			sim.cashed_in += 600.0
	check(sim_ok, "40 Rituais com gente entrando e saindo: terminam e nenhuma ficha some")
	check(min_seated >= BlitzEngine.MIN_SEATED and seat0, "a mesa nunca fica com menos de 3 sentados e o seu assento nunca vaga")
	check(lefts > 0 and joins > 0, "no meio disso, de fato entra e sai gente (saídas %d, entradas %d)" % [lefts, joins])


## Contas: regras de validação, backend local e o serviço da conta ativa (convidado → cadastrada).
func _test_accounts() -> void:
	check(AccountRules.validate_display_name("Ana") == "" and AccountRules.validate_display_name("João da Silva") == "", "nome aceita letras com acento e espaço")
	check(AccountRules.validate_display_name("ab") == "name_short" and AccountRules.validate_display_name("a".repeat(17)) == "name_long", "nome tem de 3 a 16 caracteres")
	check(AccountRules.validate_display_name("<script>") == "name_chars" and AccountRules.validate_display_name("Ana  Maria") == "", "nome recusa símbolos e espaços repetidos são colapsados")
	check(AccountRules.clean_name("  Ana   Maria ") == "Ana Maria", "nome limpo: sem espaços nas pontas nem repetidos")
	check(AccountRules.validate_username("ana_01") == "" and AccountRules.validate_username("ANA_01") == "", "usuário aceita letras, números e _ (maiúscula é normalizada)")
	check(AccountRules.validate_username("an") == "user_short" and AccountRules.validate_username("ana maria") == "user_chars" and AccountRules.validate_username("jo\u00e3o") == "user_chars", "usuário recusa curto, espaço e acento")
	check(AccountRules.validate_password("12345678") == "" and AccountRules.validate_password("1234567") == "pass_short", "senha tem no mínimo 8 caracteres")
	check(AccountRules.validate_password("ana_0001", "ANA_0001") == "pass_same_as_user", "senha não pode ser igual ao usuário")
	var grng := RandomNumberGenerator.new()
	grng.seed = 5
	var gname := AccountRules.guest_name(grng)
	check(gname.begins_with(AccountRules.GUEST_BASE) and AccountRules.validate_display_name(gname) == "", "nome de convidado sorteado é um nome válido")

	var be := LocalAccountBackend.new()
	be.persist = false
	var g := be.create_guest("Visitante")
	check(bool(g["ok"]) and g["account"]["kind"] == "guest" and g["account"]["username"] == "", "convidado nasce só com nome")
	check(not bool(be.create_guest("x")["ok"]) and be.create_guest("x")["error"] == "name_short", "convidado com nome inválido é recusado")
	var gid: String = g["account"]["id"]
	var linked := be.link_guest("Ana_01", "senha1234")
	check(bool(linked["ok"]) and linked["account"]["id"] == gid and linked["account"]["kind"] == "registered" and linked["account"]["username"] == "ana_01", "criar conta promove o convidado mantendo id e nome")
	check(linked["account"]["display_name"] == "Visitante", "promover não muda o nome de exibição")
	check(be.link_guest("outra", "senha1234")["error"] == "not_guest", "quem já tem conta não promove de novo")
	check(be.sign_out()["ok"] and be.restore_session()["error"] == "no_session", "sair encerra a sessão")
	check(be.sign_in("ana_01", "errada123")["error"] == "bad_login" and be.sign_in("ninguem", "senha1234")["error"] == "bad_login", "senha errada e usuário inexistente dão o mesmo erro")
	var back := be.sign_in("ANA_01", "senha1234")
	check(bool(back["ok"]) and back["account"]["id"] == gid, "entrar com o usuário (qualquer caixa) recupera a mesma conta")
	check(be.restore_session()["account"]["id"] == gid, "a sessão ativa é restaurável")
	be.create_guest("Outro")
	check(be.link_guest("ana_01", "senha1234")["error"] == "user_taken", "usuário repetido é recusado")
	check(be.sign_up("novo_user", "senha1234", "Novo")["account"]["kind"] == "registered", "cadastro direto cria conta registrada")
	check(be.sign_up("ab", "senha1234", "Novo")["error"] == "user_short" and be.sign_up("zeca", "1", "Zeca")["error"] == "pass_short", "cadastro valida usuário e senha")
	check(be.update_display_name("Nome Novo")["account"]["display_name"] == "Nome Novo" and be.update_display_name("")["error"] == "name_short", "trocar nome valida o novo nome")

	# Persistência: a conta e a sessão sobrevivem a reabrir o backend.
	var pbe := LocalAccountBackend.new()
	pbe.path = "user://tarolo_accounts_test.json"
	pbe.sign_up("persist_1", "senha1234", "Persistente")
	var pbe2 := LocalAccountBackend.new()
	pbe2.path = pbe.path
	var rs := pbe2.restore_session()
	check(bool(rs["ok"]) and rs["account"]["username"] == "persist_1", "conta e sessão são lidas de volta do arquivo")
	check(not FileAccess.open(pbe.path, FileAccess.READ).get_as_text().contains("senha1234"), "a senha não é gravada em texto puro")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pbe.path))

	# Serviço: convidado → cadastrada → sair volta a convidado novo.
	var sbe := LocalAccountBackend.new()
	sbe.persist = false
	var svc := AccountService.new(sbe)
	await svc.start("Arcanista", grng)
	check(svc.is_guest() and svc.display_name().begins_with("Arcanista") and svc.display_name() != "Arcanista", "sem sessão, entra como convidado com nome sorteado (o genérico não vale)")
	var svc2 := AccountService.new(sbe)
	check(svc2.has_account() == false, "serviço novo começa sem conta")
	await svc2.start("")
	check(svc2.is_guest(), "reabrir sem sessão válida cria convidado")
	var created := await svc.create_account("jogador_1", "senha1234")
	check(bool(created["ok"]) and svc.is_registered() and svc.username() == "jogador_1", "criar conta pelo serviço registra o convidado")
	var old_id := svc.id()
	await svc.sign_out()
	check(svc.is_guest() and svc.id() != old_id, "sair volta a um convidado novo, nunca sem identidade")
	var again := await svc.sign_in("jogador_1", "senha1234")
	check(bool(again["ok"]) and svc.id() == old_id, "entrar de novo recupera a conta")
	check(not bool((await svc.rename(""))["ok"]) and bool((await svc.rename("Mestre"))["ok"]) and svc.display_name() == "Mestre", "renomear pelo serviço valida e atualiza")
	var count := [0]
	svc.changed.connect(func(): count[0] += 1)
	await svc.rename("Mestre Dois")
	check(count[0] == 1, "a mudança de conta avisa quem escuta")


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


## Motor do Blitz com todas as mãos já sacrificadas até 8 cartas (como no início das jogadas).
func _discard_all(e: BlitzEngine) -> void:
	for p in range(e.num_players):
		var hand: Array = e.hands[p]
		e.apply_discard(p, hand.slice(0, BlitzEngine.BLITZ_DEAL_SIZE - BlitzEngine.HAND_SIZE))


func _test_blitz_engine() -> void:
	var e := BlitzEngine.new()
	e.setup_match({"seed": 11})
	check((e.hands[0] as Array).size() == BlitzEngine.BLITZ_DEAL_SIZE, "Blitz: cada jogador recebe 10 cartas (e sacrifica 2)")
	check(e.blind == 10 and int(e.stacks[0]) == 400, "mesa padrão: blind 10 e stack de 40 blinds")

	# Nenhum modificador mexe no valor (pontos) das cartas.
	for m in BlitzModifiers.ALL:
		e.modifier = m
		check(e.card_value(c(0, 14)) == 4.5 and e.card_value(c(4, 5)) == 0.5 and e.card_value(c(1, 3)) == 0.5, "modificador %s não muda o valor das cartas" % BlitzModifiers.name_of(m))

	# Loucura: O Louco vence qualquer carta, até arcano maior.
	var mods := BlitzModifiers.Modifier
	var louco_plays := [
		{"player": 0, "card": c(2, 14)},
		{"player": 1, "card": CardData.louco()},
		{"player": 2, "card": c(2, 3)},
		{"player": 3, "card": c(2, 9)},
	]
	check(TrickRules.winning_index_mod(louco_plays, mods.LOUCO_VENCE) == 1, "Loucura: O Louco bate qualquer carta de naipe comum")
	check(TrickRules.winning_index_mod(louco_plays, mods.SAQUE) == 0, "sem a Loucura, O Louco nunca vence (regra normal intacta)")
	var louco_vs_trunfo := louco_plays + [{"player": 0, "card": c(4, 3)}]
	check(TrickRules.winning_index_mod(louco_vs_trunfo, mods.LOUCO_VENCE) == 1, "Loucura: O Louco vence até um arcano maior")
	check(TrickRules.would_win_mod(CardData.louco(), 1, [{"player": 0, "card": c(4, 21)}], mods.LOUCO_VENCE), "Loucura: would_win do Louco sobre o Trunfo 21")

	# Oposição: vence a MENOR do naipe. Arcano maior só vale se abrir a jogada.
	var opo := [
		{"player": 0, "card": c(1, 9)},
		{"player": 1, "card": c(1, 2)},
		{"player": 2, "card": c(4, 5)},
		{"player": 3, "card": c(1, 12)},
	]
	check(TrickRules.winning_index_mod(opo, mods.VAZA_INVERTIDA) == 1, "Oposição: a menor do naipe vence e o arcano maior não corta")
	var opo_trunfo := [
		{"player": 0, "card": c(4, 15)},
		{"player": 1, "card": c(4, 3)},
		{"player": 2, "card": c(1, 2)},
		{"player": 3, "card": c(4, 20)},
	]
	check(TrickRules.winning_index_mod(opo_trunfo, mods.VAZA_INVERTIDA) == 1, "Oposição: se o arcano maior abriu, vence o menor arcano maior")
	var opo_louco := [
		{"player": 0, "card": c(4, 15)},
		{"player": 1, "card": c(4, 2)},
		{"player": 2, "card": CardData.louco()},
		{"player": 3, "card": c(4, 1)},
	]
	check(TrickRules.winning_index_mod(opo_louco, mods.VAZA_INVERTIDA) == 2, "Oposição: com arcano maior aberto, O Louco (0) vence até o Mago (1)")
	var opo_louco_aberto := [
		{"player": 0, "card": CardData.louco()},
		{"player": 1, "card": c(4, 7)},
		{"player": 2, "card": c(4, 3)},
	]
	check(TrickRules.winning_index_mod(opo_louco_aberto, mods.VAZA_INVERTIDA) == 0, "Oposição: O Louco que abre a jogada de arcano maior também é o menor")
	var opo_louco_naipe := [
		{"player": 0, "card": c(1, 9)},
		{"player": 1, "card": CardData.louco()},
		{"player": 2, "card": c(1, 3)},
	]
	check(TrickRules.winning_index_mod(opo_louco_naipe, mods.VAZA_INVERTIDA) == 2, "Oposição: em naipe comum O Louco segue sem naipe e não vence")
	var opo_louco_abre := [
		{"player": 0, "card": CardData.louco()},
		{"player": 1, "card": c(1, 9)},
		{"player": 2, "card": c(2, 2)},
	]
	check(TrickRules.winning_index_mod(opo_louco_abre, mods.VAZA_INVERTIDA) == 0, "Oposição: O Louco abriu (naipe é arcano maior) e os outros jogaram outros naipes: o Louco vence")
	# O Louco abre a jogada: o naipe é Trunfo e quem tem arcano maior é obrigado a jogar um.
	check(TrickRules.blitz_lead_suit([{"player": 0, "card": CardData.louco()}]) == CardData.Suit.TRUNFO, "Blitz: O Louco que abre faz o naipe ser Trunfo")
	check(TrickRules.blitz_lead_suit([{"player": 0, "card": c(1, 5)}, {"player": 1, "card": CardData.louco()}]) == CardData.Suit.PAUS, "Blitz: O Louco que não abre não muda o naipe")
	var louco_aberto := [{"player": 0, "card": CardData.louco()}]
	check(TrickRules.legal_cards_for([c(4, 5), c(1, 3)], louco_aberto, false, mods.SAQUE).size() == 1, "Blitz: com O Louco aberto, quem tem arcano maior é obrigado a jogá-lo")
	check(TrickRules.legal_cards_for([c(1, 3), c(2, 4)], louco_aberto, false, mods.SAQUE).size() == 2, "Blitz: com O Louco aberto, quem não tem arcano maior joga qualquer carta")
	check(TrickRules.legal_cards([c(4, 5), c(1, 3)], louco_aberto, false).size() == 2, "Clássico: com O Louco aberto a regra oficial segue (a próxima carta define o naipe)")
	var sem_trunfo := [
		{"player": 0, "card": CardData.louco()},
		{"player": 1, "card": c(1, 9)},
		{"player": 2, "card": c(1, 3)},
	]
	check(TrickRules.winning_index_mod(sem_trunfo, mods.SAQUE) == 1, "Louco aberto e ninguém com arcano maior: vence a maior do naipe da primeira carta real (O Louco não vence)")
	var silencio_louco := [
		{"player": 0, "card": CardData.louco()},
		{"player": 1, "card": c(4, 5)},
		{"player": 2, "card": c(4, 9)},
	]
	check(TrickRules.winning_index_mod(silencio_louco, mods.SILENCIO) == 2, "Silêncio: O Louco abriu (naipe Trunfo), os arcanos maiores disputam e o maior vence")

	# Silêncio: arcano maior não vence naipe (vence a maior do naipe). Se ele abriu, disputam entre si.
	var sil := [
		{"player": 0, "card": c(1, 9)},
		{"player": 1, "card": c(1, 12)},
		{"player": 2, "card": c(4, 21)},
		{"player": 3, "card": c(1, 3)},
	]
	check(TrickRules.winning_index_mod(sil, mods.SILENCIO) == 1, "Silêncio: o arcano maior não corta, vence a maior do naipe")
	check(TrickRules.winning_index(sil) == 2, "sem o Silêncio, o Trunfo corta (regra normal intacta)")
	var sil_trunfo := [
		{"player": 0, "card": c(4, 8)},
		{"player": 1, "card": c(1, 14)},
		{"player": 2, "card": c(4, 19)},
		{"player": 3, "card": c(4, 2)},
	]
	check(TrickRules.winning_index_mod(sil_trunfo, mods.SILENCIO) == 2, "Silêncio: se o arcano maior abriu, vence o maior arcano maior")

	# Pitagórico: qualquer carta pode ser jogada; vence o maior número (arcano maior ainda vence); empate pelo naipe.
	var pit_hand := [c(0, 3), c(2, 9), c(4, 5), CardData.louco()]
	check(TrickRules.legal_cards_for(pit_hand, [{"player": 3, "card": c(1, 8)}], false, mods.PITAGORICO).size() == 4, "Pitagórico: toda a mão é jogável, sem seguir o naipe")
	check(TrickRules.legal_cards_for(pit_hand, [{"player": 3, "card": c(1, 8)}], false, mods.SAQUE).size() == 2, "fora do Pitagórico, a obrigação de naipe/Trunfo continua")
	var pit := [
		{"player": 0, "card": c(1, 8)},
		{"player": 1, "card": c(2, 13)},
		{"player": 2, "card": c(0, 11)},
		{"player": 3, "card": c(3, 6)},
	]
	check(TrickRules.winning_index_mod(pit, mods.PITAGORICO) == 1, "Pitagórico: vence o maior número, qualquer naipe")
	var pit_tie := [
		{"player": 0, "card": c(1, 10)},
		{"player": 1, "card": c(2, 10)},
		{"player": 2, "card": c(0, 10)},
		{"player": 3, "card": c(3, 10)},
	]
	check(TrickRules.winning_index_mod(pit_tie, mods.PITAGORICO) == 3, "Pitagórico: empate de número vale o naipe (Espadas > Copas > Paus > Ouros)")
	var pit_order := BlitzModifiers.TIE_ORDER
	check(pit_order == [CardData.Suit.ESPADAS, CardData.Suit.COPAS, CardData.Suit.PAUS, CardData.Suit.OUROS], "ordem de desempate: Espadas, Copas, Paus, Ouros")
	var pit_trunfo := [
		{"player": 0, "card": c(1, 14)},
		{"player": 1, "card": c(4, 2)},
		{"player": 2, "card": c(2, 14)},
		{"player": 3, "card": c(4, 7)},
	]
	check(TrickRules.winning_index_mod(pit_trunfo, mods.PITAGORICO) == 3, "Pitagórico: o arcano maior ainda vence (o maior deles)")
	var pe := BlitzEngine.new()
	pe.setup_match({"seed": 4, "blind": 10})
	pe.modifier = mods.PITAGORICO
	pe.hands[0] = [c(0, 3), c(2, 9)]
	pe.plays = [{"player": 3, "card": c(1, 8)}]
	pe.current = 0
	check(pe.legal_for(0).size() == 2 and bool(pe.play(0, c(0, 3))["ok"]), "Pitagórico: o motor aceita jogar outro naipe")

	# Sem obrigação de cobrir no Blitz (o Clássico continua com ela).
	var lg := BlitzEngine.new()
	lg.setup_match({"seed": 2})
	lg.hands[0] = [c(CardData.Suit.TRUNFO, 9), c(CardData.Suit.TRUNFO, 19), c(CardData.Suit.PAUS, 3)]
	lg.plays = [{"player": 3, "card": c(CardData.Suit.TRUNFO, 18)}]
	check(lg.legal_for(0).size() == 2 and TrickRules.legal_cards(lg.hands[0], lg.plays).size() == 1, "Blitz: pode jogar Trunfo mais fraco; o Clássico obriga a cobrir")
	lg.plays = [{"player": 3, "card": c(CardData.Suit.PAUS, 8)}]
	lg.hands[0] = [c(CardData.Suit.TRUNFO, 2), c(CardData.Suit.TRUNFO, 19), c(CardData.Suit.COPAS, 3)]
	lg.plays.append({"player": 2, "card": c(CardData.Suit.TRUNFO, 15)})
	check(lg.legal_for(0).size() == 2, "Blitz: sem naipe, corta com qualquer Trunfo (mesmo menor que o cortado)")

	# ---- clone_for_sim copia todo o estado do motor (um campo esquecido quebra bots/Oráculo)
	var cl_e := BlitzEngine.new()
	cl_e.setup_match({"seed": 5, "blind": 10, "players": 4, "levels": 2})
	for cl_p in range(4):
		cl_e.apply_discard(cl_p, BlitzBot.wants_discard(cl_e, cl_p, 1, cl_e.rng))
		cl_e.blitz_place(cl_p, 2)
	cl_e.draw_trick_modifier()
	cl_e.begin_trick()
	var cl_c := cl_e.clone_for_sim()
	var cl_diff: Array = []
	for pr in cl_e.get_property_list():
		if int(pr["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var cl_a = cl_e.get(pr["name"])
		var cl_b = cl_c.get(pr["name"])
		if (cl_a is Array or cl_a is Dictionary) and cl_a.size() != cl_b.size():
			cl_diff.append(pr["name"])
		elif not (cl_a is Object or cl_a is Array or cl_a is Dictionary) and cl_a != cl_b:
			cl_diff.append(pr["name"])
	check(cl_diff.is_empty(), "clone_for_sim copia todos os campos do motor %s" % str(cl_diff))

	# ---- Torneio: realocação equilibrada entre mesas
	for rb in [[16, [6, 5, 5]], [13, [5, 4, 4]], [11, [6, 5]], [7, [4, 3]], [6, [6]], [4, [4]], [2, [2]]]:
		var rb_tables: Array = []
		var rb_left := int(rb[0])
		var rb_id := 0
		while rb_left > 0:   # começa desbalanceado: mesas cheias e uma ou duas sobras
			var rb_n := mini(Tournament.MAX_TABLE, rb_left)
			var rb_t: Array = []
			for _i in range(rb_n):
				rb_t.append({"id": rb_id, "human": rb_id == 0})
				rb_id += 1
			rb_tables.append(rb_t)
			rb_left -= rb_n
		if rb_tables.size() > 2:
			(rb_tables[0] as Array).resize(1)   # uma mesa quase vazia
		var rb_count := 0
		for t in rb_tables:
			rb_count += (t as Array).size()
		var rb_out := Tournament.rebalance(rb_tables)
		var rb_sizes: Array = []
		var rb_sum := 0
		for t in rb_out:
			rb_sizes.append((t as Array).size())
			rb_sum += (t as Array).size()
		rb_sizes.sort()
		rb_sizes.reverse()
		var rb_ok: bool = rb_sum == rb_count and rb_sizes[0] - rb_sizes[rb_sizes.size() - 1] <= 1 and rb_sizes[0] <= Tournament.MAX_TABLE
		check(rb_count < Tournament.MIN_TABLE or rb_sizes[rb_sizes.size() - 1] >= mini(Tournament.MIN_TABLE, rb_count), "Torneio: %d jogadores nunca viram mesa de heads-up fora da final" % rb_count)
		check(rb_ok, "Torneio: %d jogadores realocados em mesas parelhas (%s)" % [rb_count, str(rb_sizes)])
		check(rb_sizes.size() == ceili(float(rb_count) / float(Tournament.MAX_TABLE)), "Torneio: %d jogadores usam o mínimo de mesas" % rb_count)

	# ---- Eliminado (torneio) sai da jogada: não ante, não fala, não ocupa vaga de carta
	var bu := BlitzEngine.new()
	bu.setup_match({"seed": 5, "ante_factor": 0.0})
	bu.stacks[1] = 0.0
	bu.bust_broke()
	bu.begin_trick()
	check(bu.folded[1] and bu.bet_actor() != 1 and is_equal_approx(bu.trick_pot, 30.0), "eliminado não paga ante nem fala")
	while bu.betting:
		bu.bet_act(bu.bet_actor(), "check")
	var bu_order: Array = []
	var bu_done := false
	while not bu_done:
		var bu_cur := bu.current
		bu_order.append(bu_cur)
		bu_done = bu.play(bu_cur, (bu.legal_for(bu_cur) as Array)[0])["trick_complete"]
	check(bu_order.size() == 3 and not bu_order.has(1) and bu_order.has(0), "com um eliminado, jogam os outros 3 (você incluído) e a vaza fecha certo")

	# ---- Blind do torneio: UMA escada fixa pra todos × unidade do evento (1% da stack; stack = 10× buy-in)
	var want_ladder := [10, 15, 20, 25, 30, 40, 50, 60, 80, 100, 150, 200, 250, 300, 400, 500, 600, 800, 1000, 1500]
	var ladder_ok := true
	for li in range(want_ladder.size()):
		if Tournament.blind_for(li, {"blind_base": 10}) != int(want_ladder[li]):
			ladder_ok = false
	check(ladder_ok, "escada de blinds (u=10): 10, 15, 20, 25, 30, 40, 50, 60, 80, 100, 150, 200, 250, 300, 400…")
	var bl_ok := true
	var bl_int := true
	for ev in Tournament.OPEN_EVENTS:
		var prev_b := 0
		for lv in range(0, 40):
			var cur_b := Tournament.blind_for(lv, ev)
			if cur_b <= prev_b:
				bl_ok = false
			prev_b = cur_b
			if cur_b % 5 != 0:
				bl_int = false
		if Tournament.blind_for(0, ev) != int(ev["blind_base"]) or float(ev["stack"]) != float(ev["buy_in"]) * 10.0 or float(ev["blind_base"]) != float(ev["stack"]) / 100.0:
			bl_ok = false
	check(bl_ok, "evento: stack = 10× buy-in, blind inicial = 1% da stack, blind sobe um degrau por nível")
	check(bl_int, "blinds sempre inteiros e múltiplos de 5 (ante de 20% e entrada de 8 blinds sem decimais)")
	# ---- Dealer: sorteado na 1ª rodada; depois é sempre o vencedor da última jogada da rodada anterior
	var dl := BlitzEngine.new()
	dl.setup_match({"seed": 4, "levels": 3, "blind": 10, "players": 4, "start_leader": 2, "stacks": [500.0, 500.0, 500.0, 500.0]})
	check(dl.leader == 2, "dealer da 1ª rodada = o sorteado na abertura da partida")
	dl.leader = 3   # (a última jogada da rodada foi vencida pelo jogador 3)
	dl.trick_number = BlitzEngine.HAND_SIZE
	dl.advance_round()
	check(dl.leader == 3, "dealer da rodada seguinte = vencedor da última jogada")
	dl.busted[3] = true
	dl.trick_number = BlitzEngine.HAND_SIZE
	dl.advance_round()
	check(dl.leader == 0, "vencedor eliminado: o dealer passa pro próximo vivo")
	# ---- Torneio: sem fichas pra entrada do palpite = eliminado antes de jogar; sobrou ≥1 ficha = joga em all-in
	var ai := BlitzEngine.new()
	ai.setup_match({"seed": 9, "levels": 1, "blind": 10, "players": 3, "stacks": [60.0, 85.0, 500.0]})
	var ai_out := ai.bust_cant_enter()
	check(ai_out == [0] and bool(ai.busted[0]) and not bool(ai.busted[1]), "sem fichas pra entrada do palpite (60 < 80): eliminado; com 85 pode palpitar")
	check(not ai.blitz_place(0, 2) and float(ai.stakes[0]) == 0.0, "eliminado não põe entrada no pote")
	ai.blitz_place(1, 2)
	ai.blitz_place(2, 2)
	check(is_equal_approx(float(ai.stacks[1]), 5.0) and ai.bust_broke().is_empty(), "sobrou 5 ficha depois da entrada: segue jogando (all-in), não é eliminado")
	# Eliminado deixa de ganhar o palpite (a entrada fica no pote): é o que impedia ele de "voltar" a cada nível
	var ez := BlitzEngine.new()
	ez.setup_match({"seed": 9, "levels": 1, "blind": 10, "players": 3, "stacks": [80.0, 500.0, 500.0]})
	for ez_p in range(3):
		ez.blitz_place(ez_p, 0)
	check(ez.bust_broke() == [0], "entrada levou tudo (stack 0): eliminado")
	ez.trick_number = BlitzEngine.HAND_SIZE
	var ez_res := ez._settle_blitz()
	check(not (ez_res["hits"] as Array).has(0) and is_equal_approx(float(ez_res["payouts"][0]), 0.0), "eliminado com palpite 0 certo NÃO recebe prêmio")
	# ---- Mesa desfeita no meio da rodada: jogadas que faltam não contam vitória; palpite vale pelo que já foi jogado
	var vd := BlitzEngine.new()
	vd.setup_match({"seed": 9, "levels": 1, "blind": 10, "players": 3, "stacks": [500.0, 500.0, 500.0]})
	for vd_p in range(3):
		vd.blitz_place(vd_p, 1 if vd_p == 0 else 5)
	vd.wins[0] = 1   # já bateu o palpite
	vd.trick_number = 4
	var vd_total := SimLib.total_chips(vd)
	vd.void_remaining_tricks()
	check(vd.is_round_over() and int(vd.wins[0]) == 1, "mesa desfeita: nenhuma vitória de graça nas jogadas que faltavam")
	check((vd.blitz_result["hits"] as Array).is_empty() and bool(vd.blitz_result["voided"]), "mesa desfeita no meio do nível: ninguém leva prêmio com o nível incompleto")
	check(absf(SimLib.total_chips(vd) - vd_total) < SimLib.EPS and is_zero_approx(vd.pot) and is_zero_approx(vd.carry), "mesa desfeita: nenhuma ficha some, todas voltam pros jogadores")
	# Desfeita antes de qualquer jogada: o nível não aconteceu, as entradas voltam
	var vz := BlitzEngine.new()
	vz.setup_match({"seed": 9, "levels": 1, "blind": 10, "players": 3, "stacks": [500.0, 500.0, 500.0]})
	for vz_p in range(3):
		vz.blitz_place(vz_p, 2)
	vz.void_remaining_tricks()
	check(is_equal_approx(float(vz.stacks[0]) + float(vz.stacks[1]) + float(vz.stacks[2]), 1500.0) and is_equal_approx(float(vz.stacks[0]), 500.0), "mesa desfeita antes da 1ª jogada devolve as entradas do palpite")

	# Desfeita no meio do nível com alguém eliminado e uma jogada em andamento: nada some.
	var vm := BlitzEngine.new()
	vm.setup_match({"seed": 12, "levels": 1, "blind": 10, "players": 3, "stacks": [500.0, 500.0, 500.0]})
	_discard_all(vm)
	for vm_p in range(3):
		vm.blitz_place(vm_p, 2)
	vm.begin_trick()   # ante e blind já pagos, jogada sem vencedor
	var vm_stake := float(vm.stakes[2])
	var vm_before := SimLib.total_chips(vm)
	vm.busted[2] = true
	vm.folded[2] = true
	vm.void_remaining_tricks()
	var vm_after := float(vm.stacks[0]) + float(vm.stacks[1]) + float(vm.stacks[2])
	check(absf(SimLib.total_chips(vm) - vm_before) < SimLib.EPS and absf(vm_after - 1500.0) < SimLib.EPS, "mesa desfeita no meio de uma jogada: ante e blind pagos voltam, nenhuma ficha some")
	check(vm.stacks[0] > 500.0 - 0.01 and vm.stacks[1] > 500.0 - 0.01 and vm_stake > 0.0, "mesa desfeita: os sobreviventes não saem no prejuízo")
	check(absf(float(vm.stacks[0]) - float(vm.stacks[1])) <= 1.0, "mesa desfeita: a entrada de quem foi eliminado é dividida entre os sobreviventes")
	check(bool(vm.blitz_result["voided"]) and is_zero_approx(vm.carry) and is_zero_approx(vm.pot) and is_zero_approx(vm.trick_pot), "mesa desfeita não deixa pote nem acumulado pra uma mesa que acabou")

	# ---- Aposta estilo poker
	var p1 := BlitzEngine.new()
	p1.setup_match({"seed": 3, "ante_factor": 0.0})
	_discard_all(p1)
	p1.begin_trick()
	check(is_equal_approx(p1.trick_pot, 40.0) and is_equal_approx(p1.stacks[0], 390.0), "blind de todos vai pro pote")
	check(p1.button == 0 and p1.bet_actor() == 1, "o botão é o líder e fala primeiro quem vem depois dele")
	var o0 := p1.bet_options(1)
	check(bool(o0["can_check"]) and is_equal_approx(float(o0["min_to"]), 20.0) and is_equal_approx(float(o0["max_to"]), 400.0), "primeiro a falar pode passar; aumento mínimo = 1 blind; máximo = menor stack")
	var r1 := p1.bet_act(1, "raise", 30.0)
	check(r1["ok"] and is_equal_approx(p1.trick_pot, 60.0) and p1.to_act.size() == 3, "aumentar põe fichas e todo mundo precisa responder")
	check(not p1.bet_act(2, "raise", 10.0)["ok"] == false, "aumento abaixo do mínimo é corrigido pro mínimo")
	check(is_equal_approx(p1.bet_level, 40.0), "aumento mínimo sobre 30 é 40")
	var r3 := p1.bet_act(3, "check")
	check(not r3["ok"], "não dá pra passar com aposta aberta")
	p1.bet_act(3, "fold")
	check(p1.folded[3], "desistir tira da rodada")
	p1.raises = 50
	check(bool(p1.bet_options(0)["can_raise"]), "sem teto de re-aumentos: só o all-in limita")
	p1.bet_act(0, "call")
	p1.bet_act(1, "call")
	check(not p1.betting and p1.active_count() == 3, "rodada de apostas fecha quando todo mundo igualou ou desistiu")
	check(is_equal_approx(p1.stacks[2], 360.0) and is_equal_approx(p1.trick_pot, 130.0), "quem pagou põe o mesmo valor (40 cada; 10 do que desistiu)")
	check(p1.current != 3, "quem desistiu não joga carta")
	var played := 0
	while played < 3:
		var pp := p1.current
		var res := p1.play(pp, (p1.legal_for(pp) as Array)[0])
		check(res["ok"], "jogada legal aceita com 3 na rodada")
		played += 1
		if res["trick_complete"]:
			var rr: Dictionary = res["result"]
			check(is_equal_approx(float(rr["trick_pot"]), 130.0), "resultado informa o pote da jogada")
			check(p1.stacks[int(rr["winner"])] >= 130.0 and float(rr["gain"]) > 0.0 - 200.0, "vencedor leva o pote")
	check(p1.hands[0].size() == 7 and p1.hands[1].size() == 7 and p1.hands[3].size() == 7, "quem desistiu descarta a mais fraca: todas as mãos ficam do mesmo tamanho")
	# Todo mundo desiste: o último leva o pote sem jogar.
	var p2 := BlitzEngine.new()
	p2.setup_match({"seed": 4, "ante_factor": 0.0})
	_discard_all(p2)
	p2.begin_trick()
	p2.bet_act(1, "raise", 20.0)
	p2.bet_act(2, "fold")
	p2.bet_act(3, "fold")
	p2.bet_act(0, "fold")
	check(p2.walkover_player() == 1, "sobrou um: ele leva o pote")
	var wo := p2.resolve_walkover()
	check(bool(wo["walkover"]) and is_equal_approx(p2.stacks[1], 400.0 - 20.0 + 50.0), "blefe vence: leva o pote sem jogar carta")
	check(p2.hands[1].size() == 7 and p2.hands[2].size() == 7, "no blefe vencido o vencedor também descarta, mãos iguais")
	check(p2.trick_number == 1 and p2.session_stats[1]["bluffs"] == 1, "rodada conta e o blefe é registrado")
	# All-in: cada um vai até a própria stack; stack curta paga "o que tem" e nunca fica negativa.
	var p3 := BlitzEngine.new()
	p3.setup_match({"seed": 5, "stacks": [200, 200, 60, 200]})
	p3.begin_trick()
	var first := p3.bet_actor()
	var o1 := p3.bet_options(first)
	check(is_equal_approx(float(o1["max_to"]), p3.stacks[first] + p3.contrib[first]), "all-in vai até a stack inteira, mesmo com rival de stack curta")
	var all_to := float(o1["max_to"])
	p3.bet_act(first, "raise", all_to)
	check(is_equal_approx(p3.stacks[first], 0.0), "all-in zera a stack (nada sobra fora do pote)")
	while p3.betting:
		var who := p3.bet_actor()
		p3.bet_act(who, "call")
	var min_stack := 0.0
	for st in p3.stacks:
		min_stack = minf(min_stack, float(st))
	check(min_stack >= 0.0, "stack nunca fica negativa depois de pagar um all-in")
	var total_before := 0.0
	for q in range(4):
		total_before += float(p3.stacks[q])
	total_before += p3.trick_pot
	p3.betting = false
	p3._settle_side_pots(2)
	var total_after := 0.0
	for q in range(4):
		total_after += float(p3.stacks[q])
	total_after += p3.trick_pot
	check(is_equal_approx(total_before, total_after), "potes paralelos devolvem o excedente sem criar nem perder fichas")
	check(p3.trick_pot <= 4.0 * float(p3.contrib[2]) + 0.001, "all-in curto só leva de cada rival o que ele mesmo pôs")
	# Potes laterais de verdade: A (curto, melhor mão) ganha só o principal; o lateral vai pro melhor dos que cobriram.
	var sp := BlitzEngine.new()
	sp.setup_match({"seed": 3, "levels": 1, "blind": 10, "players": 4, "stacks": [500.0, 500.0, 500.0, 500.0]})
	sp.contrib = [100.0, 300.0, 300.0, 40.0]   # 3 é all-in curto; 1 e 2 cobrem 300; 0 desistiu com 100
	sp.folded = [true, false, false, false]
	sp.stacks = [0.0, 0.0, 0.0, 0.0]
	sp.trick_pot = 740.0
	sp.plays = []
	sp._settle_side_pots(3)   # 3 é o melhor de todos
	# principal: 40 de cada um dos 4 = 160 → 3; lateral: 1 e 2 e 0 (até 300): (60+260+260)=580 → melhor dos que cobriram (1, pela ordem)
	check(is_equal_approx(sp.trick_pot, 160.0), "pote principal vai pro all-in curto")
	check(sp.last_pots.size() == 2 and int(sp.last_pots[0]["winner"]) == 3 and not bool(sp.last_pots[1]["uncalled"]), "camadas do pote registradas pra UI (principal → all-in curto, lateral → quem cobriu)")
	check(is_equal_approx(float(sp.stacks[1]) + float(sp.stacks[2]), 580.0), "pote lateral vai pro melhor dos que cobriram")
	# All-in maior que o dos rivais: o excedente que ninguém cobriu volta pra quem pôs.
	var up := BlitzEngine.new()
	up.setup_match({"seed": 4, "levels": 1, "blind": 10, "players": 4, "stacks": [500.0, 500.0, 500.0, 500.0]})
	up.contrib = [400.0, 100.0, 0.0, 0.0]
	up.folded = [false, false, true, true]
	up.stacks = [0.0, 0.0, 0.0, 0.0]
	up.trick_pot = 500.0
	up.plays = []
	up._settle_side_pots(1)   # o curto (1) vence
	check(is_equal_approx(up.trick_pot, 200.0) and is_equal_approx(float(up.stacks[0]), 300.0), "excedente não coberto volta pra quem apostou além")
	check(up.last_pots.size() == 2 and bool(up.last_pots[1]["uncalled"]) and int(up.last_pots[1]["winner"]) == 0, "excedente aparece como 'sem cobertura' pra UI")

	# Bot sem fichas pro blind é trocado.
	p3 = BlitzEngine.new()
	p3.setup_match({"seed": 5, "stacks": [200, 200, 60, 200]})
	p3.begin_trick()
	p3.stacks[3] = 4.0
	check(p3.refill_bots() == [3] and p3.stacks[3] >= 300.0 and p3.stacks[3] <= 600.0, "bot quebrado sai e um novo senta com 30 a 60 blinds")
	# Prêmio da banca e mesa sem fim.
	check(is_equal_approx(BlitzEngine.PRIZE_PER_POINT * 4.0 * float(p3.blind), 10.0), "1 ponto de carta = 1/4 do blind (4 pts = ◎10)")
	var p4 := BlitzEngine.new()
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
			var d := BlitzBot.bet_decision(p4, actor, BotAI.Difficulty.HARD, rng4)
			var br := p4.bet_act(actor, str(d["action"]), float(d.get("to", 0.0)))
			check(br["ok"], "decisão do bot é sempre uma ação válida")
			if not br["ok"]:
				p4.bet_act(actor, "fold")
		if p4.walkover_player() != -1:
			p4.resolve_walkover()
		else:
			while true:
				var pl := p4.current
				var rs := p4.play(pl, BlitzBot.choose(p4, pl, BotAI.Difficulty.HARD, rng4))
				if rs["trick_complete"]:
					break
		trick_count += 1
	check(p4.round_index >= 2, "mesa segue em novos níveis sem fim (%d níveis)" % (p4.round_index + 1))
	check(not p4.is_match_over(), "mesa livre nunca acaba sozinha")
	for st in p4.stacks:
		check(float(st) >= 0.0, "ninguém fica com stack negativa")
	var pl2 := BlitzEngine.new()
	pl2.setup_match({"seed": 8, "levels": 2})
	pl2.round_index = 1
	pl2.trick_number = BlitzEngine.HAND_SIZE
	check(pl2.is_match_over() and pl2.is_final_round(), "partida com fim acaba no último nível")
	# Bot: força da mão e decisões.
	var pb := BlitzEngine.new()
	pb.setup_match({"seed": 6})
	pb.hands[3] = [c(CardData.Suit.TRUNFO, 21), c(CardData.Suit.TRUNFO, 20), c(CardData.Suit.PAUS, 14), c(CardData.Suit.COPAS, 14)]
	pb.hands[2] = [c(CardData.Suit.PAUS, 2), c(CardData.Suit.PAUS, 3), c(CardData.Suit.COPAS, 4), c(CardData.Suit.OUROS, 5)]
	check(BlitzBot.hand_strength(pb, 3) > BlitzBot.hand_strength(pb, 2) + 0.4, "mão com Trunfos altos e Reis é bem mais forte")
	pb.modifier = BlitzModifiers.Modifier.VAZA_INVERTIDA
	check(BlitzBot.hand_strength(pb, 2) > BlitzBot.hand_strength(pb, 3), "na Oposição, cartas baixas são fortes")
	pb.modifier = BlitzModifiers.Modifier.VAZA_DOURADA
	pb.begin_trick()
	var pbr := RandomNumberGenerator.new()
	pbr.seed = 3
	var raises := 0
	for i in range(30):
		var dd := BlitzBot.bet_decision(pb, 2, BotAI.Difficulty.HARD, pbr)
		if dd["action"] == "raise":
			raises += 1
	var raises_strong := 0
	for i in range(30):
		if BlitzBot.bet_decision(pb, 3, BotAI.Difficulty.HARD, pbr)["action"] == "raise":
			raises_strong += 1
	check(raises_strong > raises, "bot aumenta mais com mão forte que com mão fraca (%d > %d)" % [raises_strong, raises])
	# Stack e blind: com pote grande e stack fundo, o aumento forte acompanha o pote (não fica em 1–3 blinds).
	var pd := BlitzEngine.new()
	pd.setup_match({"seed": 6, "blind": 10, "stacks": [800.0, 800.0, 800.0, 800.0]})
	pd.hands[3] = pb.hands[3]
	pd.modifier = BlitzModifiers.Modifier.VAZA_DOURADA
	pd.begin_trick()
	pd.trick_pot = 300.0
	var big_to := 0.0
	var pdr := RandomNumberGenerator.new()
	pdr.seed = 5
	for i in range(60):
		var dec := BlitzBot.bet_decision(pd, pd.bet_actor(), BotAI.Difficulty.HARD, pdr)
		if dec["action"] == "raise":
			big_to = maxf(big_to, float(dec["to"]) - float(pd.bet_level))
	check(big_to > 3.0 * 10.0, "com pote grande o aumento passa de 3 blinds (maior: %.0f)" % big_to)
	check(big_to <= 800.0 / 3.0 + 10.0 or big_to <= 300.0 * 0.75 + 0.5, "e não joga mais que 1/3 do stack sem mão muito forte (%.0f)" % big_to)
	pb.bet_act(pb.bet_actor(), "raise", 60.0)
	var facing := BlitzBot.bet_decision(pb, pb.bet_actor(), BotAI.Difficulty.NORMAL, pbr)
	check(facing["action"] in ["call", "fold", "raise"], "diante de aumento o bot paga, aumenta ou desiste (não passa)")

	# Modificadores (sempre por vaza).
	var e7 := BlitzEngine.new()
	e7.setup_match({"seed": 9})
	e7.modifier = BlitzModifiers.Modifier.VAZA_INVERTIDA
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
	e7.modifier = BlitzModifiers.Modifier.VAZA_DOURADA
	e7.trick_number = 3
	e7.current = 0
	e7.plays = [
		{"player": 0, "card": c(CardData.Suit.PAUS, 9)},
		{"player": 1, "card": c(CardData.Suit.PAUS, 2)},
		{"player": 2, "card": c(CardData.Suit.PAUS, 12)},
		{"player": 3, "card": c(CardData.Suit.PAUS, 6)},
	]
	var gold := e7._resolve_trick()
	check(int(gold["value"]) == 2, "Vaza Dourada (Rodada Dobrada) conta 2 vitórias")
	e7.modifier = BlitzModifiers.Modifier.VAZA_MALDITA
	e7.trick_number = 3
	e7.plays = [
		{"player": 0, "card": c(CardData.Suit.PAUS, 9)},
		{"player": 1, "card": c(CardData.Suit.PAUS, 2)},
		{"player": 2, "card": c(CardData.Suit.PAUS, 3)},
		{"player": 3, "card": c(CardData.Suit.PAUS, 6)},
	]
	e7.stacks = [200.0, 200.0, 200.0, 200.0]
	var curse := e7._resolve_trick()
	check(is_equal_approx(float(curse["curse_amount"]), 30.0), "Maldição: quem vence paga 3 blinds (30 com blind 10), divididos entre os rivais")
	# Bots cientes dos modificadores
	var eb := BlitzEngine.new()
	eb.setup_match({"seed": 1})
	var brng := RandomNumberGenerator.new()
	brng.seed = 7
	eb.modifier = BlitzModifiers.Modifier.VAZA_MALDITA
	eb.trick_number = 3
	eb.current = 3
	eb.plays = [
		{"player": 0, "card": c(CardData.Suit.PAUS, 9)},
		{"player": 1, "card": c(CardData.Suit.PAUS, 2)},
		{"player": 2, "card": c(CardData.Suit.PAUS, 3)},
	]
	eb.hands[3] = [c(CardData.Suit.PAUS, 12), c(CardData.Suit.PAUS, 6)]
	var pick := BlitzBot.choose(eb, 3, BotAI.Difficulty.HARD, brng)
	check(pick.rank == 6 or pick.rank == 12, "bot joga carta legal na Vaza Maldita")
	eb.hands[3] = [c(CardData.Suit.PAUS, 12), c(CardData.Suit.PAUS, 1)]
	pick = BlitzBot.choose(eb, 3, BotAI.Difficulty.HARD, brng)
	check(not eb.would_win(pick, 3) and pick.rank == 1, "Vaza Maldita: bot foge de vencer")
	# Sorteio por jogada: cada Ritual embaralha os 8 e usa todos, um por vaza, sem repetir no nível.
	var e8 := BlitzEngine.new()
	e8.setup_match({"seed": 11})
	check(e8.modifier == -1, "antes da 1ª vaza começar, ainda não tem modificador sorteado")
	var seen := {}
	for t in range(BlitzEngine.HAND_SIZE):
		e8.trick_number = t
		e8.draw_trick_modifier()
		check(e8.modifier != -1, "toda vaza sorteia um modificador")
		check(not seen.has(e8.modifier), "não repete modificador dentro do mesmo nível")
		seen[e8.modifier] = true
	check(seen.size() == BlitzEngine.HAND_SIZE, "as 8 vazas do nível usam 8 modificadores diferentes")
	check(BlitzModifiers.ALL.size() == 8, "são 8 modificadores ao todo")


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
	var e := BlitzEngine.new()
	e.setup_match({"seed": 11, "blind": 10, "levels": 0})
	e.rake_on = false
	e.bonus_on = false
	e.trick_number = 0
	e.draw_trick_modifier()
	check(BlitzModifiers.ALL.has(e.modifier), "Blitz: sorteia entre os modificadores")
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
			if e.modifier == BlitzModifiers.Modifier.VAZA_DOURADA:
				had_gold = true
		var pl := e.current
		e.play(pl, BlitzBot.choose(e, pl, BotAI.Difficulty.NORMAL, brng))
	var total := 0.0
	for x in e.stacks:
		total += float(x)
	check(is_equal_approx(total + e.carry, start_total), "Blitz: fichas se conservam (sem taxa): tem %s esperava %s" % [total + e.carry, start_total])
	var won_sum := 0
	for w in e.wins:
		won_sum += int(w)
	check(won_sum == BlitzEngine.HAND_SIZE or had_gold, "Blitz: 8 vitórias distribuídas por nível")

	# Liquidação com números forçados: entrada 20 por jogador, pote 80.
	var f := BlitzEngine.new()
	f.setup_match({"seed": 1, "blind": 10})
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
	check(is_equal_approx(float(r["net"][2]), -40.0) and is_equal_approx(float(r["net"][3]), -40.0), "Blitz: errou por 2+ perde a entrada e paga multa")
	check(is_equal_approx(f.carry, 40.0) and is_equal_approx(f.pot, 0.0), "Blitz: pote pago zera, multas ficam no carry")

	var f2 := BlitzEngine.new()
	f2.setup_match({"seed": 1, "blind": 10})
	f2.rake_on = false
	f2.bonus_on = false
	f2.pot = 80.0
	f2.stakes = [20.0, 20.0, 20.0, 20.0]
	f2.predicts = [1, 3, 5, 0]
	f2.wins = [4, 4, 0, 4]
	var r2 := f2._settle_blitz()
	check((r2["hits"] as Array).is_empty() and is_equal_approx(f2.carry, 80.0 - float(r2["refunds"][1]) - float(r2["refunds"][3]) - float(r2["refunds"][0]) - float(r2["refunds"][2]) + 60.0), "Blitz: ninguém acertou, pote acumula + multas")
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
	var bn := BlitzEngine.new()
	bn.setup_match({"seed": 1, "blind": 10})
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
	check(float(rb3["bonus"]) <= BlitzEngine.BLITZ_STREAK_BONUS_BLINDS * bn.blind, "Blitz: prêmio tem teto de %d blinds" % BlitzEngine.BLITZ_STREAK_BONUS_BLINDS)
	check(bn.human_rake > vault_before, "Blitz: o cofre segue enchendo mesmo depois de pagar o prêmio")
	bn.pot = 800.0
	bn.predicts = [3, 0, 0, 0]
	bn.wins = [2, 1, 1, 1]
	var rb4 := bn._settle_blitz()
	check(is_equal_approx(float(rb4["bonus"]), 0.0) and bn.hit_streak == 0, "Blitz: errar zera a sequência e não dá prêmio")

	# Taxa da casa só quando o pote é pago.
	var f3 := BlitzEngine.new()
	f3.setup_match({"seed": 1, "blind": 10})
	f3.pot = 80.0
	f3.stakes = [20.0, 20.0, 20.0, 20.0]
	f3.predicts = [2, 2, 2, 2]
	f3.wins = [2, 1, 1, 4]
	var r4 := f3._settle_blitz()
	check(float(r4["rake"]) > 0.0 and float(r4["rake"]) <= 1.5 * 10.0, "Blitz: taxa da casa limitada quando há pagamento")

	# Dobrar / triplicar.
	var d := BlitzEngine.new()
	d.doubles_enabled = true
	d.setup_match({"seed": 4, "blind": 10})
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
	var cv := BlitzEngine.new()
	cv.doubles_enabled = true
	cv.setup_match({"seed": 4, "blind": 10})
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

	# Os 8 modificadores entram no sorteio e nenhum Ritual repete um.
	var pool := BlitzModifiers.blitz_pool()
	check(pool.size() == 8 and pool.has(BlitzModifiers.Modifier.PITAGORICO) and pool.has(BlitzModifiers.Modifier.SILENCIO), "Blitz: sorteio dos 8 modificadores novos")
	var gp := BlitzEngine.new()
	for lv in range(12):
		gp.setup_match({"seed": 100 + lv, "blind": 10})
		var uniq := {}
		for m in gp.modifier_sequence:
			uniq[m] = true
		check(uniq.size() == 8 and gp.modifier_sequence.size() == BlitzEngine.HAND_SIZE, "Blitz: cada Ritual usa os 8 modificadores, sem repetir")

	# Pontos das cartas viram fichas, pagas pelos rivais: 4,5 + 3×0,5 = 6 pts → 6×0,25×10×0,5 = 7,5 → 8, 3 cada.
	var g2 := BlitzEngine.new()
	g2.setup_match({"seed": 9, "blind": 10})
	g2.modifier = -1
	g2.hands[0] = [c(CardData.Suit.TRUNFO, 21)]
	g2.hands[1] = [c(CardData.Suit.PAUS, 3)]
	g2.hands[2] = [c(CardData.Suit.PAUS, 4)]
	g2.hands[3] = [c(CardData.Suit.PAUS, 5)]
	g2.leader = 0
	g2.current = 0
	var total0 := 0.0
	for st in g2.stacks:
		total0 += float(st)
	for pl in range(4):
		g2.play(pl, (g2.hands[pl] as Array)[0])
	check(int(g2.wins[0]) == 1, "Blitz: vencer a rodada conta 1 vitória")
	var g2_total := 0.0
	for st in g2.stacks:
		g2_total += float(st)
	check(is_equal_approx(float(g2.stacks[0]), float(g2.buy_in) + 9.0) and is_equal_approx(float(g2.stacks[1]), float(g2.buy_in) - 3.0), "Blitz: pontos das cartas pagam fichas do vencedor (rivais dividem)")
	check(is_equal_approx(g2_total, total0), "Blitz: fichas das cartas são soma zero")

	# Rodada Dobrada: conta 2 vitórias e NÃO multiplica os pontos (mesmo prêmio de fichas de antes).
	var g3 := BlitzEngine.new()
	g3.setup_match({"seed": 9, "blind": 10})
	g3.modifier = BlitzModifiers.Modifier.VAZA_DOURADA
	g3.hands[0] = [c(CardData.Suit.TRUNFO, 21)]
	g3.hands[1] = [c(CardData.Suit.PAUS, 3)]
	g3.hands[2] = [c(CardData.Suit.PAUS, 4)]
	g3.hands[3] = [c(CardData.Suit.PAUS, 5)]
	g3.leader = 0
	g3.current = 0
	for pl in range(4):
		g3.play(pl, (g3.hands[pl] as Array)[0])
	check(int(g3.wins[0]) == 2, "Blitz: Rodada Dobrada conta 2 vitórias")
	check(is_equal_approx(float(g3.stacks[0]), float(g3.buy_in) + 9.0), "Blitz: Rodada Dobrada não multiplica o prêmio das cartas")

	# Fator 0 desliga o prêmio das cartas (isola os efeitos de fichas dos outros modificadores).
	var g0 := BlitzEngine.new()
	g0.setup_match({"seed": 9, "blind": 10, "point_factor": 0.0})
	g0.modifier = -1
	g0.hands[0] = [c(CardData.Suit.TRUNFO, 20)]
	g0.hands[1] = [c(CardData.Suit.PAUS, 3)]
	g0.hands[2] = [c(CardData.Suit.PAUS, 4)]
	g0.hands[3] = [c(CardData.Suit.PAUS, 5)]
	g0.leader = 0
	g0.current = 0
	for pl in range(4):
		g0.play(pl, (g0.hands[pl] as Array)[0])
	check(is_equal_approx(float(g0.stacks[0]), float(g0.buy_in)), "Blitz: fator 0 = sem prêmio das cartas")

	# Saque/Assalto/Maldita mexem em fichas à parte dos pontos.
	var gs := BlitzEngine.new()
	gs.setup_match({"seed": 9, "blind": 10, "point_factor": 0.0, "stacks": [200.0, 200.0, 200.0, 200.0]})
	gs.modifier = BlitzModifiers.Modifier.SAQUE
	gs.hands[0] = [c(CardData.Suit.TRUNFO, 20)]
	gs.hands[1] = [c(CardData.Suit.PAUS, 3)]
	gs.hands[2] = [c(CardData.Suit.PAUS, 4)]
	gs.hands[3] = [c(CardData.Suit.PAUS, 5)]
	gs.leader = 0
	gs.current = 0
	for pl in range(4):
		gs.play(pl, (gs.hands[pl] as Array)[0])
	check(is_equal_approx(float(gs.stacks[0]), 230.0) and is_equal_approx(float(gs.stacks[1]), 190.0), "Blitz: Saque rouba 3 blinds no total (10 de cada rival), além de contar a vitória")

	var ga := BlitzEngine.new()
	ga.setup_match({"seed": 9, "blind": 10, "point_factor": 0.0, "stacks": [200.0, 200.0, 500.0, 200.0]})
	ga.modifier = BlitzModifiers.Modifier.ASSALTO_LIDER
	ga.hands[0] = [c(CardData.Suit.TRUNFO, 20)]
	ga.hands[1] = [c(CardData.Suit.PAUS, 3)]
	ga.hands[2] = [c(CardData.Suit.PAUS, 4)]
	ga.hands[3] = [c(CardData.Suit.PAUS, 5)]
	ga.leader = 0
	ga.current = 0
	for pl in range(4):
		ga.play(pl, (ga.hands[pl] as Array)[0])
	check(is_equal_approx(float(ga.stacks[0]), 230.0) and is_equal_approx(float(ga.stacks[2]), 470.0), "Blitz: Assalto rouba 3 blinds do rival com mais fichas, além de contar a vitória")
	var gl := BlitzEngine.new()
	gl.setup_match({"seed": 9, "blind": 10, "point_factor": 0.0, "stacks": [500.0, 200.0, 250.0, 200.0]})
	gl.modifier = BlitzModifiers.Modifier.ASSALTO_LIDER
	gl.hands[0] = [c(CardData.Suit.TRUNFO, 20)]
	gl.hands[1] = [c(CardData.Suit.PAUS, 3)]
	gl.hands[2] = [c(CardData.Suit.PAUS, 4)]
	gl.hands[3] = [c(CardData.Suit.PAUS, 5)]
	gl.leader = 0
	gl.current = 0
	for pl in range(4):
		gl.play(pl, (gl.hands[pl] as Array)[0])
	check(is_equal_approx(float(gl.stacks[0]), 530.0) and is_equal_approx(float(gl.stacks[2]), 220.0), "Assalto: se o vencedor é o líder, rouba do segundo com mais fichas (nunca fica sem efeito)")

	var gm := BlitzEngine.new()
	gm.setup_match({"seed": 9, "blind": 10, "point_factor": 0.0, "stacks": [200.0, 200.0, 200.0, 200.0]})
	gm.modifier = BlitzModifiers.Modifier.VAZA_MALDITA
	gm.hands[0] = [c(CardData.Suit.TRUNFO, 20)]
	gm.hands[1] = [c(CardData.Suit.PAUS, 3)]
	gm.hands[2] = [c(CardData.Suit.PAUS, 4)]
	gm.hands[3] = [c(CardData.Suit.PAUS, 5)]
	gm.leader = 0
	gm.current = 0
	for pl in range(4):
		gm.play(pl, (gm.hands[pl] as Array)[0])
	check(is_equal_approx(float(gm.stacks[0]), 170.0) and is_equal_approx(float(gm.stacks[1]), 210.0), "Blitz: Maldição faz quem vence pagar 3 blinds aos rivais, além de contar a vitória")

	# Quem zera por causa de um modificador de ficha é eliminado (perde a mão e sai da mesa).
	var gz := BlitzEngine.new()
	gz.setup_match({"seed": 9, "blind": 10, "point_factor": 0.0, "stacks": [200.0, 5.0, 200.0, 200.0]})
	gz.modifier = BlitzModifiers.Modifier.SAQUE
	gz.hands[0] = [c(CardData.Suit.TRUNFO, 20)]
	gz.hands[1] = [c(CardData.Suit.PAUS, 3)]
	gz.hands[2] = [c(CardData.Suit.PAUS, 4)]
	gz.hands[3] = [c(CardData.Suit.PAUS, 5)]
	gz.leader = 0
	gz.current = 0
	for pl in range(4):
		gz.play(pl, (gz.hands[pl] as Array)[0])
	check(float(gz.stacks[1]) == 0.0 and not bool(gz.busted[1]), "Saque: quem tinha 5 fichas paga só o que tem e zera")
	check(gz.bust_broke() == [1] and bool(gz.busted[1]), "quem zerou pelo Saque é eliminado na checagem de quebra")
	gz.begin_trick()
	check(bool(gz.folded[1]) and not gz.to_act.has(1), "eliminado fica fora da jogada seguinte: sem ante, sem fala, sem carta")
	var gw := BlitzEngine.new()
	gw.setup_match({"seed": 9, "blind": 10, "point_factor": 0.0, "stacks": [18.0, 200.0, 200.0, 200.0]})
	gw.modifier = BlitzModifiers.Modifier.VAZA_MALDITA
	gw.hands[0] = [c(CardData.Suit.TRUNFO, 20)]
	gw.hands[1] = [c(CardData.Suit.PAUS, 3)]
	gw.hands[2] = [c(CardData.Suit.PAUS, 4)]
	gw.hands[3] = [c(CardData.Suit.PAUS, 5)]
	gw.leader = 0
	gw.current = 0
	for pl in range(4):
		gw.play(pl, (gw.hands[pl] as Array)[0])
	check(float(gw.stacks[0]) == 0.0 and gw.bust_broke() == [0], "Maldição: quem vence e fica sem fichas é eliminado também")

	# Bots: palpite em 0..8, calibrado com a média real (2 vitórias por jogador).
	var cal := BlitzEngine.new()
	cal.setup_match({"seed": 77, "blind": 10})
	var sum_exp := 0.0
	var n_exp := 0
	for i in range(60):
		cal.advance_round()
		for p in range(4):
			if cal.can_discard(p):
				cal.apply_discard(p, BlitzBot.wants_discard(cal, p, BotAI.Difficulty.HARD, brng))
		for p in range(4):
			var pick := BlitzBot.blitz_pick(cal, p, BotAI.Difficulty.HARD, brng)
			check(pick >= 0 and pick <= BlitzEngine.HAND_SIZE, "Blitz: palpite do bot em 0..8")
			sum_exp += BlitzBot.expected_wins(cal, p)
			n_exp += 1
	check(absf(sum_exp / float(n_exp) - 2.0) < 0.35, "Blitz: palpite esperado calibrado perto de 2 (deu %s)" % [sum_exp / float(n_exp)])
	# No alvo, o bot foge da rodada: joga a carta menor.
	var fb := BlitzEngine.new()
	fb.setup_match({"seed": 2, "blind": 10})
	fb.modifier = BlitzModifiers.Modifier.LOUCO_VENCE
	fb.predicts = [1, 1, 1, 1]
	fb.wins = [1, 0, 0, 0]
	fb.hands[0] = [c(CardData.Suit.PAUS, 14), c(CardData.Suit.PAUS, 2)]
	fb.plays = [{"player": 3, "card": c(CardData.Suit.PAUS, 10)}]
	fb.current = 0
	check(BlitzBot.choose(fb, 0, BotAI.Difficulty.HARD, brng).rank == 2, "Blitz: bot já no alvo evita vencer a rodada")


func _test_blitz_phase4() -> void:
	# Descarte inicial: recebe 10, descarta 2, sempre a 1ª decisão do nível — antes de qualquer
	# modificador ou palpite.
	var d1 := BlitzEngine.new()
	d1.setup_match({"seed": 22, "blind": 10})
	check((d1.hands[0] as Array).size() == BlitzEngine.BLITZ_DEAL_SIZE and d1.can_discard(0), "Descarte: recebe 10 cartas antes de descartar")
	var hand10: Array = (d1.hands[0] as Array).duplicate()
	var discard: Array = [hand10[0], hand10[1]]
	check(d1.apply_discard(0, discard), "Descarte: descarta 2 válidas")
	check((d1.hands[0] as Array).size() == BlitzEngine.HAND_SIZE and not d1.can_discard(0), "Descarte: fica com 8, não descarta de novo")
	for c in discard:
		check(not (d1.hands[0] as Array).any(func(h): return (h as CardData).equals(c)), "Descarte: a carta descartada sai da mão de verdade")
	check(not d1.apply_discard(0, [hand10[2]]), "Descarte: precisa ser exatamente 2 cartas")

	var d2 := BlitzEngine.new()
	d2.setup_match({"seed": 23, "blind": 10})
	var hand2: Array = (d2.hands[1] as Array).duplicate()
	check(not d2.apply_discard(1, [hand2[0], hand2[0]]), "Descarte: não descarta a mesma carta 2x")

	var d3 := BlitzEngine.new()
	d3.setup_match({"seed": 24, "blind": 10})
	var outside := CardData.louco()
	if (d3.hands[2] as Array).any(func(c): return (c as CardData).equals(outside)):
		outside = CardData.make(CardData.Suit.TRUNFO, 1)
	check(not d3.apply_discard(2, [outside, (d3.hands[2] as Array)[0]]), "Descarte: carta que não está na mão não descarta")

	# Bot: descarta as 2 mais fracas da mão (calibrado, sem estourar a mão em cartas boas).
	var brng2 := RandomNumberGenerator.new()
	brng2.seed = 8
	var d4 := BlitzEngine.new()
	d4.setup_match({"seed": 25, "blind": 10})
	var picks: Array = BlitzBot.wants_discard(d4, 0, BotAI.Difficulty.HARD, brng2)
	check(picks.size() == 2, "Descarte do bot: sempre escolhe 2")
	check(d4.apply_discard(0, picks), "Descarte do bot: a escolha do bot sempre é válida")


func _test_colors() -> void:
	var bgs := {"NIGHT": UIKit.NIGHT, "PURPLE_DEEP": UIKit.PURPLE_DEEP}
	var fgs := {"INK": UIKit.INK, "MUTED": UIKit.MUTED, "MONEY": UIKit.MONEY, "TURN": UIKit.TURN, "GAIN": UIKit.GAIN, "LOSS": UIKit.LOSS, "INFO": UIKit.INFO, "COMBO": UIKit.COMBO, "MODIFIER": UIKit.MODIFIER}
	for bn in bgs:
		for fn in fgs:
			check(UIKit.contrast(fgs[fn], bgs[bn]) >= 4.5, "cor %s legível sobre %s (%.1f:1)" % [fn, bn, UIKit.contrast(fgs[fn], bgs[bn])])
	check(UIKit.text_on(UIKit.GOLD) == UIKit.TEXT_ON_LIGHT and UIKit.text_on(UIKit.OK) == UIKit.TEXT_ON_LIGHT, "botões dourado e verde usam texto escuro")
	check(UIKit.text_on(UIKit.PURPLE_DEEP) == UIKit.INK, "botões escuros usam texto claro")
	# Regra real: o texto escolhido sempre tem contraste ≥ 3:1 com a face (claro em fundo escuro, escuro em fundo claro).
	var faces := {"PURPLE_DEEP": UIKit.PURPLE_DEEP, "VIOLET": UIKit.VIOLET, "GOLD": UIKit.GOLD, "OK": UIKit.OK, "NIGHT": UIKit.NIGHT}
	for face_name in faces:
		var face: Color = faces[face_name]
		check(UIKit.contrast(UIKit.text_on(face), face) >= 3.0, "texto do botão %s legível (%.1f:1)" % [face_name, UIKit.contrast(UIKit.text_on(face), face)])
	check(UIKit.contrast(UIKit.TEXT_ON_LIGHT, UIKit.GOLD) >= 4.5, "texto escuro legível sobre dourado")


## Economia de fichas: pacotes, recarga diária, taxa da casa e conservação de fichas.
func _test_economy() -> void:
	var prev := 0.0
	for pk in BlitzEconomy.PACKS:
		var rate := BlitzEconomy.fichas_per_real(pk)
		check(rate >= prev, "pacote %s não dá menos fichas por real que o menor (%.0f/R$)" % [pk["name"], rate])
		prev = rate
	check(BlitzEconomy.bonus_pct(BlitzEconomy.PACKS[0]) == 0 and BlitzEconomy.bonus_pct(BlitzEconomy.PACKS[3]) >= 30, "bônus cresce com o tamanho do pacote")
	check(BlitzEconomy.START_FICHAS >= 10 * BlitzEngine.BUY_IN_BLINDS * 3, "saldo inicial paga 3 entradas mínimas")
	check(BlitzEconomy.DAILY_MIN >= 10 * BlitzEngine.BUY_IN_BLINDS, "recarga libera quando não dá pra pagar a entrada mais barata")
	var prof := {"fichas": 100}
	check(BlitzEconomy.daily_available(prof), "recarga liberada abaixo do mínimo")
	check(BlitzEconomy.claim_daily(prof) == BlitzEconomy.DAILY_AMOUNT and int(prof["fichas"]) == 100 + BlitzEconomy.DAILY_AMOUNT, "coletar credita a recarga")
	prof["fichas"] = 50
	check(not BlitzEconomy.daily_available(prof) and BlitzEconomy.claim_daily(prof) == 0, "só uma recarga por dia")
	prof = {"fichas": 900}
	check(not BlitzEconomy.daily_available(prof), "sem recarga com saldo acima do mínimo")
	prof = {"fichas": 10}
	check(BlitzEconomy.PACKS.size() == 4 and BlitzEconomy.buy_simulated(prof, "cofre") == 3600 and int(prof["fichas"]) == 3610 and int(prof["spent_cents"]) == 1990, "compra simulada credita fichas e registra o gasto")
	check(BlitzEconomy.buy_simulated(prof, "nada") == 0, "pacote inexistente não credita")
	check(BlitzEconomy.price_text(1990) == "R$ 19,90", "preço em reais")
	# Conservação: um nível inteiro com bots — fichas na mesa + potes + taxa da casa não mudam.
	var ec := BlitzEngine.new()
	ec.setup_match({"seed": 31, "levels": 0})
	var total0 := SimLib.total_chips(ec)
	var rr := RandomNumberGenerator.new()
	rr.seed = 4
	SimLib.play_level(ec, rr, [BotAI.Difficulty.NORMAL, BotAI.Difficulty.NORMAL, BotAI.Difficulty.NORMAL, BotAI.Difficulty.NORMAL], "bot")
	var total1 := SimLib.total_chips(ec)
	check(absf(total0 - total1) < SimLib.EPS, "fichas se conservam: mesa + potes + taxa da casa = total inicial (taxa %.0f)" % ec.house_rake)
	check(ec.house_rake > 0.0, "a casa cobra taxa no fechamento do nível")


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
