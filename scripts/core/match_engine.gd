class_name MatchEngine
extends RefCounted
## Estado puro de um nível de Tarot Clássico (sem UI): licitação, talão, rodadas e a
## pontuação final do atacante contra a defesa.

signal trick_resolved(result: Dictionary)
signal round_finished()

var num_players := 4
var hands: Array = []          # Array[Array[CardData]]
var chien: Array = []          # talão (6 cartas)
var plays: Array = []          # rodada atual: [{player, card}]
var captured: Array = []       # Array[Array[CardData]] capturado por cada jogador
var leader := -1
var current := -1
var trick_number := 0
var total_tricks := -1
var history: Array = []        # resultados das rodadas
var result: Dictionary = {}    # preenchido quando o nível acaba (round_finished)
var rng := RandomNumberGenerator.new()

# ------------------------------------------------------------------ licitação
var taker := -1
var contract := -1
var bid_turn := 0
var bid_active: Array = []     # ainda não passou
var highest_bid := -1
var highest_bidder := -1
var bidding_done := false
var bidding_void := false      # todos passaram (mão anulada — chamador deve refazer o setup)
var taker_trump_count := 0     # trunfos na mão do atacante já com o talão resolvido (Poignée)
var poignee_declared := false  # escolha do atacante: mostrar os trunfos pra valer o bônus
var chelem_announced := false  # escolha do atacante: apostar alto em vencer as 18 rodadas
var awaiting_discard := false  # Petite/Garde: esperando o atacante escolher o descarte (écart)
var louco_owed := {}           # dono do Louco -> vencedor a quem ainda deve uma carta de 0,5


## config: { seed, players }
func setup(config: Dictionary) -> void:
	num_players = int(config.get("players", 4))
	if config.has("seed"):
		rng.seed = int(config["seed"])
	else:
		rng.randomize()
	var deck := Deck.build(rng)
	var dealt := Deck.deal(deck, num_players, 18)
	_reset_state(dealt["hands"], dealt["rest"])


## Mão do tutorial: sorteada de verdade a cada partida, mas com garantias mínimas pra
## que os cenários de ensino apareçam — 10 a 14 trunfos (dá pra declarar Poignée), O
## Louco (sempre pelo menos 1 Bout na mão) e 2 naipes comuns totalmente ausentes (força
## cortar com Trunfo mais cedo ou mais tarde). Tudo o resto — quais trunfos, quais
## cartas dos outros 2 naipes, mãos dos bots, talão — é sorteio de verdade.
func setup_tutorial() -> void:
	num_players = 4
	rng.randomize()

	var all_trunfos: Array = []
	for r in range(1, 22):
		all_trunfos.append(CardData.make(CardData.Suit.TRUNFO, r))
	Deck.shuffle(all_trunfos, rng)
	var trunfo_count := rng.randi_range(10, 14)
	var human: Array = all_trunfos.slice(0, trunfo_count)
	var trunfo_pool: Array = all_trunfos.slice(trunfo_count)
	human.append(CardData.louco())

	var suits := [CardData.Suit.OUROS, CardData.Suit.PAUS, CardData.Suit.COPAS, CardData.Suit.ESPADAS]
	var void_suits: Array = []
	while void_suits.size() < 2:
		var s: int = suits[rng.randi_range(0, suits.size() - 1)]
		if not void_suits.has(s):
			void_suits.append(s)
	var play_suits: Array = suits.filter(func(s: int) -> bool: return not void_suits.has(s))

	var suit_pool: Array = []
	for s in play_suits:
		for r in range(1, 15):
			suit_pool.append(CardData.make(s, r))
	Deck.shuffle(suit_pool, rng)
	var need := 18 - human.size()
	human.append_array(suit_pool.slice(0, need))
	var leftover_suit_pool: Array = suit_pool.slice(need)

	var remaining: Array = []
	remaining.append_array(trunfo_pool)
	remaining.append_array(leftover_suit_pool)
	for s in void_suits:
		for r in range(1, 15):
			remaining.append(CardData.make(s, r))

	Deck.shuffle(remaining, rng)
	var bots := [[], [], []]
	for i in range(54):
		bots[i % 3].append(remaining[i])
	var chien_cards: Array = remaining.slice(54, 60)
	_reset_state([human, bots[0], bots[1], bots[2]], chien_cards)


func _reset_state(dealt_hands: Array, dealt_chien: Array) -> void:
	hands = dealt_hands
	chien = dealt_chien
	captured = []
	for p in range(num_players):
		captured.append([])

	taker = -1
	contract = -1
	bid_turn = 0
	bid_active = []
	for p in range(num_players):
		bid_active.append(true)
	highest_bid = -1
	highest_bidder = -1
	bidding_done = false
	bidding_void = false
	taker_trump_count = 0
	poignee_declared = false
	chelem_announced = false
	awaiting_discard = false
	louco_owed = {}

	leader = -1
	current = -1
	trick_number = 0
	total_tricks = -1
	plays = []
	history = []
	result = {}


# ------------------------------------------------------------------ licitação

## Contratos que `player` pode oferecer agora (estritamente acima do lance atual).
## Passar sempre é permitido à parte, exceto quando `is_bidding_forced`.
func bid_options(player: int) -> Array:
	var opts: Array = []
	for c in range(highest_bid + 1, Scoring.Contract.GARDE_CONTRE + 1):
		opts.append(c)
	return opts


## Verdadeiro quando `player` é o único que ainda não passou e ninguém deu lance —
## nesse caso, alguém precisa assumir (não pode passar), como no jogo real.
func is_bidding_forced(player: int) -> bool:
	if highest_bidder != -1 or not bid_active[player]:
		return false
	for p in range(num_players):
		if p != player and bid_active[p]:
			return false
	return true


## `choice` = -1 (passar) ou um valor de `Scoring.Contract`.
func place_bid(player: int, choice: int) -> Dictionary:
	if bidding_done or player != bid_turn or not bid_active[player]:
		return {"ok": false, "error": "fora de vez"}
	if choice == -1:
		if is_bidding_forced(player):
			return {"ok": false, "error": "obrigado a dar um lance"}
		bid_active[player] = false
	else:
		if choice <= highest_bid:
			return {"ok": false, "error": "lance muito baixo"}
		highest_bid = choice
		highest_bidder = player
	_advance_bidding()
	return {"ok": true, "done": bidding_done}


func _advance_bidding() -> void:
	var active_count := 0
	for a in bid_active:
		if a:
			active_count += 1
	if active_count == 0:
		bidding_done = true
		bidding_void = true
		return
	if active_count == 1 and highest_bidder != -1 and bid_active[highest_bidder]:
		bidding_done = true
		taker = highest_bidder
		contract = highest_bid
		_finalize_taker()
		return
	var attempts := 0
	while attempts < num_players:
		bid_turn = (bid_turn + 1) % num_players
		attempts += 1
		if bid_active[bid_turn] and bid_turn != highest_bidder:
			return


## Aplica as regras do contrato vencedor sobre o talão. Petite/Garde: o atacante vê o
## talão, incorpora na mão e escolhe (ele mesmo, não o jogo) 6 cartas pra descartar de
## volta — as rodadas só começam depois disso (ver `awaiting_discard`/`legal_discards`/
## `discard`). Garde Sans: o atacante não vê o talão, mas ele conta pra ele mesmo assim.
## Garde Contre: o atacante não vê o talão, e ele NÃO conta pra ele (fica com a defesa).
func _finalize_taker() -> void:
	match contract:
		Scoring.Contract.PETITE, Scoring.Contract.GARDE:
			(hands[taker] as Array).append_array(chien)
			Deck.sort_hand(hands[taker])
			awaiting_discard = true
			return
		Scoring.Contract.GARDE_SANS:
			captured[taker].append_array(chien)
		Scoring.Contract.GARDE_CONTRE:
			pass  # talão não entra na jogada nem pontua pro atacante
	_start_tricks()


func _start_tricks() -> void:
	total_tricks = (hands[0] as Array).size()
	leader = (taker + 1) % num_players
	current = leader
	taker_trump_count = 0
	for c in hands[taker]:
		if (c as CardData).is_trunfo():
			taker_trump_count += 1


## Cartas elegíveis pro descarte (écart): nunca um Bout, nunca um Rei — e Trunfo comum
## só entra na lista se não sobrarem cartas normais suficientes pra completar as 6
## (regra oficial: só corta Trunfo pro talão em último caso).
func legal_discards(hand: Array) -> Array:
	var safe: Array = (hand as Array).filter(func(c: CardData) -> bool: return not c.is_bout() and not c.is_trunfo() and c.rank != 14)
	if safe.size() >= Deck.CHIEN_SIZE:
		return safe
	var extra: Array = (hand as Array).filter(func(c: CardData) -> bool: return c.is_trunfo() and not c.is_bout())
	return safe + extra


## Aplica o descarte escolhido pelo atacante (humano ou bot) e libera o início das rodadas.
func discard(cards: Array) -> Dictionary:
	if not awaiting_discard or cards.size() != Deck.CHIEN_SIZE:
		return {"ok": false, "error": "descarte inválido"}
	var legal: Array = legal_discards(hands[taker])
	for c in cards:
		var card: CardData = c
		if not (legal as Array).any(func(l: CardData) -> bool: return l.equals(card)):
			return {"ok": false, "error": "carta não pode ir pro descarte"}
	for c in cards:
		(hands[taker] as Array).erase(c)
	captured[taker].append_array(cards)
	awaiting_discard = false
	_start_tricks()
	return {"ok": true}


## Verdadeiro se o atacante tem trunfos suficientes pra ter direito de declarar Poignée
## (a escolha de mostrar a mão pra valer o bônus é dele — ver `declare_poignee`).
func poignee_eligible() -> bool:
	return taker_trump_count >= 10


func declare_poignee(v: bool) -> void:
	poignee_declared = v


func announce_chelem(v: bool) -> void:
	chelem_announced = v


# ------------------------------------------------------------------ rodadas

func legal_for(player: int) -> Array:
	return TrickRules.legal_cards(hands[player], plays)


func is_round_over() -> bool:
	return total_tricks > 0 and trick_number >= total_tricks


## Joga `card` pelo jogador da vez. Retorna { ok, trick_complete, result? }.
func play(player: int, card: CardData) -> Dictionary:
	if player != current or is_round_over():
		return {"ok": false, "error": "fora de turno"}
	var hand: Array = hands[player]
	if not TrickRules.is_legal(card, hand, plays):
		return {"ok": false, "error": "jogada ilegal"}
	hand.erase(card)
	plays.append({"player": player, "card": card})
	if plays.size() < num_players:
		current = (current + 1) % num_players
		return {"ok": true, "trick_complete": false}
	return {"ok": true, "trick_complete": true, "result": _resolve_trick()}


func _resolve_trick() -> Dictionary:
	var idx := TrickRules.winning_index(plays)
	var winner: int = plays[idx]["player"]
	# O Louco fica com quem o jogou (só troca de dono na última rodada). Em troca, o dono
	# entrega ao vencedor uma carta de 0,5 ponto das que já capturou.
	var is_last := trick_number == total_tricks - 1
	var louco_owner := -1
	var louco_card: CardData = null
	var cards: Array = []
	for entry in plays:
		var cd: CardData = entry["card"]
		if cd.is_louco() and not is_last:
			louco_owner = int(entry["player"])
			louco_card = cd
		else:
			cards.append(cd)
	captured[winner].append_array(cards)
	if louco_owner != -1:
		captured[louco_owner].append(louco_card)
		if louco_owner != winner:
			louco_owed[louco_owner] = winner
	_settle_louco_debts()
	var points := 0.0
	for c in cards:
		points += (c as CardData).points()
	var trick_result := {
		"winner": winner,
		"winning_index": idx,
		"plays": plays.duplicate(),
		"points": points,
		"trick_number": trick_number,
	}
	history.append(trick_result)
	plays = []
	trick_number += 1
	leader = winner
	current = winner
	trick_resolved.emit(trick_result)
	if is_round_over():
		result = _finish()
		round_finished.emit()
	return trick_result


## Troco do Louco: o dono entrega ao vencedor da rodada uma carta de 0,5 ponto (nunca Bout)
## do que já capturou. Se ainda não tem nenhuma (Louco na 1ª rodada), a dívida fica pra
## quando tiver.
func _settle_louco_debts() -> void:
	for owner in louco_owed.keys():
		var pile: Array = captured[owner]
		for i in range(pile.size()):
			var cd: CardData = pile[i]
			if not cd.is_bout() and is_equal_approx(cd.points(), 0.5):
				pile.remove_at(i)
				captured[int(louco_owed[owner])].append(cd)
				louco_owed.erase(owner)
				break


func _finish() -> Dictionary:
	var taker_points := 0.0
	var bouts := 0
	for c in captured[taker]:
		var card: CardData = c
		taker_points += card.points()
		if card.is_bout():
			bouts += 1
	# Garde Sans/Contre: o talão nunca entrou na mão do atacante (não é jogado em rodada
	# nenhuma), então ele só entra na conta final aqui — não nos dois casos acima.
	var bonuses := _round_bonuses()
	var r := Scoring.resolve(taker_points, bouts, contract, bonuses)
	r["taker"] = taker
	r["taker_points"] = taker_points
	r["bouts"] = bouts
	r["deltas"] = Scoring.distribute(r["score"], taker, num_players)
	return r


## Poignée e Chelem só valem se o atacante escolheu declarar/anunciar (ver `declare_poignee`
## e `announce_chelem`) — são apostas estratégicas dele, não bônus automáticos. Petit au
## bout é o único automático: depende só de como a última rodada terminou, ninguém declara.
func _round_bonuses() -> Dictionary:
	var poignee := Scoring.poignee_bonus(taker_trump_count) if poignee_declared else 0.0
	var taker_won_all := true
	for p in range(num_players):
		if p != taker and not (captured[p] as Array).is_empty():
			taker_won_all = false
			break
	var chelem := 0.0
	if chelem_announced:
		chelem = Scoring.CHELEM_ANNOUNCED_BONUS if taker_won_all else -Scoring.CHELEM_ANNOUNCED_FAIL_PENALTY
	elif taker_won_all:
		chelem = Scoring.CHELEM_UNANNOUNCED_BONUS
	var petit_au_bout := 0.0
	if not history.is_empty():
		var last_trick: Dictionary = history[-1]
		var has_petit := false
		for entry in (last_trick["plays"] as Array):
			var card: CardData = entry["card"]
			if card.is_trunfo() and card.rank == CardData.PETIT:
				has_petit = true
				break
		if has_petit:
			var winner: int = last_trick["winner"]
			petit_au_bout = Scoring.PETIT_AU_BOUT_BONUS if winner == taker else -Scoring.PETIT_AU_BOUT_BONUS
	return {"poignee": poignee, "chelem": chelem, "petit_au_bout": petit_au_bout}


## Pontos capturados até agora por um jogador (visível durante a partida — o placar
## oficial só fecha no fim, como no Tarot de verdade).
func points_of(player: int) -> float:
	var total := 0.0
	for c in captured[player]:
		total += (c as CardData).points()
	return total


## Índices dos jogadores do melhor ao pior resultado do nível (pelo delta de pontos).
func standings() -> Array:
	var deltas: Array = result.get("deltas", [])
	var order: Array = range(num_players)
	if deltas.is_empty():
		return order
	order.sort_custom(func(a: int, b: int) -> bool: return int(deltas[a]) > int(deltas[b]))
	return order


func placement_of(player: int) -> int:
	return standings().find(player)
