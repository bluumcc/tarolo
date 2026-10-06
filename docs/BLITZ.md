# Modo Blitz

O Blitz é o Caos com **palpite por nível** no lugar da aposta por rodada. Mesma mesa, mesmas
stacks, mesmas cartas (as regras de carta do Caos: qualquer Trunfo vale), mas o dinheiro só se
move **no fim do nível**, conforme quem acertou quantas rodadas ia ganhar.

Pensado para **PvP** (jogadores reais entre si): a mesa hoje só roda contra bots porque o
servidor multiplayer ainda não existe, mas toda a economia (entrada, dobrar/cobrir, taxa) já é
desenhada como um sistema fechado entre jogadores — a casa não cria fichas, só cobra taxa.

Código: `ChaosEngine` com `blitz = true` (config `"mode": "blitz"`), `ChaosBot.blitz_*`,
`ChaosScene` (mesma cena, ramos `engine.blitz`). Simulação: `tests/blitz_sim.gd`.

## Regras (o que o jogador aprende)
1. **Palpite:** no início do nível você vê a mão e diz quantas rodadas vai ganhar (0 a 8). A ★ sugere
   o palpite que combina com a sua mão. Todos pagam a **entrada de 4 blinds (10% da stack)** e revelam
   juntos.
2. **Jogo:** 8 rodadas de 1 carta. Sob cada avatar o progresso ao vivo (`1/3`): verde no alvo,
   vermelho se estourou ou não dá mais tempo.
3. **Pote:**
   - Acertou o número exato → divide o pote com os outros acertos, pelo **peso** = entrada × dificuldade
     (palpite 0–2 ×1, 3–4 ×1,5, 5+ ×2).
   - Errou por 1 → recebe metade da entrada de volta (a outra metade fica no pote).
   - Errou por 2 ou mais → perde a entrada.
   - Ninguém acertou → o pote **acumula** pro próximo nível (jackpot), sem taxa.
4. **Dobrar / triplicar:** a partir da 4ª rodada (o 2º lance, da 6ª), só se ainda dá pra acertar: paga
   mais uma entrada e o peso sobe um degrau (×2, depois ×3). No máximo 2 lances por nível.
5. **Cobrir:** quando um rival dobra ou triplica, todo mundo tem uma janela curta pra **COBRIR**
   (paga 1 entrada, iguala o peso dele) ou **DEIXAR** (de graça, mas fica com peso menor no rateio).
   Cobrir também usa um dos seus 2 lances do nível. É a mesma decisão de dobrar, só que em resposta.
6. **Fichas das cartas**: cada rodada, quem vence leva fichas dos rivais pelos pontos das cartas da mesa
   (1 ponto = 0,25 blind × `BLITZ_POINT_FACTOR`, pago em partes iguais pelos rivais). Soma zero, sem
   taxa. Cria a tensão de estratégia: vencer uma rodada rica rende fichas mas pode estourar o palpite;
   perder uma rodada rica custa fichas mas protege o palpite.
7. **Modificadores**: toda rodada sorteia 1 dos 9 (ver `docs/MODIFICADORES.md`), sempre anunciado em
   tela cheia antes das apostas. O único "dobro" é a Rodada Dobrada (2 vitórias no palpite, sem
   multiplicar pontos); Trunfo em Dobro e Figuras em Dobro ficam de fora (se confundiriam com as
   vitórias). Naipe Fraco/Forte e Cartas Pequenas mudam quanto as cartas pagam; O Louco Vence e Rodada Invertida mudam quem vence;
   Saque/Assalto/Maldita movem fichas à parte.

## Economia: de onde vem e pra onde vai a ficha
Sem taxa, o Blitz é soma zero entre os jogadores: fichas só trocam de mão. A casa não cria ficha —
os dois ralos são:
- **Taxa (rake):** 4% do pote pago, teto de 2 blinds, só quando alguém acerta (jackpot acumulado
  não paga). `ChaosEconomy.blitz_rake_of`.
- **Prêmio de sequência (rakeback):** 3 acertos exatos seguidos liberam um prêmio especial, mas ele
  só sai do "cofre" — no máximo 50% da taxa que a casa já cobrou de você naquela mesa — e tem teto
  de 3 blinds. Isso significa que **a casa nunca fica no prejuízo por causa do prêmio**: ele é
  sempre menor que o que ela já embolsou. `ChaosEngine.BLITZ_STREAK_BONUS_BLINDS` / `BLITZ_BONUS_VAULT_SHARE`.

Contra bots (hoje), o placar da mesa continua justo: eles não recebem prêmio de sequência, só o
jogador humano. Em PvP isso deixa de fazer sentido nesses termos — o prêmio vale pra qualquer
jogador que fizer a sequência.

## Por que é simples e tem estratégia
- Decisões: o palpite (com sugestão) por nível, e dobrar/cobrir como opcionais durante o nível.
- A estratégia real está em **jogar pra fechar a conta**: já no alvo, perder as rodadas que sobram
  descartando a carta forte embaixo de uma maior; faltando, guardar Trunfos.
- Palpites baixos são mais controláveis (na simulação, palpite 0 acerta ~79%, 1 ~36%, 2 ~28%, 3 ~24%),
  mas os altos pesam mais no pote.
- Dobrar/cobrir usa a mesma regra de bolso, testada por simulação: **no alvo com mão fraca acerta
  ~90%** (vale entrar); ainda faltando vitórias, só ~30% (não vale). Cobrir é um pouco mais cauteloso
  (70% de chance de topar mesmo quando vale a pena, contra 85% de quem dobra por iniciativa própria).

## Simulação (120 sessões × 30 níveis, blind 10, com dobrar/triplicar/cobrir)
| Cenário | Líquido médio (blinds) | Quebra em 30 níveis |
|---|---|---|
| Seat 0 difícil vs 3 fáceis | +2,5 | 0% |
| Seat 0 normal vs 3 fáceis | −3,7 | 0% |
| Todos difíceis | −4,4 | 15% |
| Todos normais | −6,7 | 15% |
| Seat 0 difícil vs fáceis/normal | −2,4 | 11% |
| Seat 0 normal vs iniciante | +3,5 | 17% |
| Seat 0 fácil vs difíceis | −18,4 | 32% |

- Jogar melhor ainda rende mais e perde menos; jogar mal custa caro, mais que antes (entrada e
  cobertura maiores aumentam a variância, de propósito, pra o pote girar).
- A taxa acumulada por sessão fica em 1,5 a 5,4 blinds; o rakeback pago é sempre uma fração
  pequena disso (0,1 a 0,9 blind), confirmando que o cofre nunca estoura.
- Quebrar (ficar sem blind pra continuar) agora acontece mais: até ~30% em 30 níveis contra
  bots fortes. A mesa permite recomprar ou sair, então isso é esperado, mas vale acompanhar
  quando o PvP estiver rodando de verdade.
- Fichas se conservam entre os jogadores (testado): o que sai da casa em rakeback é sempre menor
  que o que ela cobrou. O pote acumulado fica na mesa.
- Mesas e bots: as mesmas do Caos (Iniciante blind 10, Regular blind 50, Alta blind 200), stack de
  40 blinds.

## Calibração dos bots
`ChaosBot.EXPECT_SCALE` (1,48) calibra a soma de poder das cartas até a média real de 2 vitórias por
jogador por nível. Fácil erra o palpite (±0,9) e nunca dobra/cobre; normal (±0,45) só entra com muita
certeza; difícil (±0,15) descarta forte embaixo de carta maior, dobra/triplica quando no alvo com mão
fraca, e cobre o lance de rivais nas mesmas condições.

## Fora de escopo por enquanto
- **PvP de verdade** (servidor, contas, livro-caixa de fichas, filas, reconexão): os bots
  continuam representando os outros jogadores até isso existir.
- **Cosméticos** como ralo extra de fichas.
- **Mesas configuráveis** (torneios): blind, buy-in, prêmio, data de início, número de níveis e
  blind crescente configuráveis por quem cria a mesa. Fica para uma fase futura de Blitz com salas
  criadas por jogadores.


## Habilidade: jogar os pontos das cartas (simulação)
`tests/blitz_skill_sim.gd` — bot "Difícil novo" (calcula fichas esperadas: palpite + prêmio das
cartas − custo de gastar a carta) contra o "Difícil antigo" (só palpite, ignora pontos). Líquido bruto
em blinds por nível, sem taxa da casa (soma zero entre os 4), 80 sessões × 30 níveis por linha, ±0,1 ep:

| fator pontos→fichas | espelho (antigo×4) | novo vs 3 antigos | novo vs 3 fáceis |
|---|---|---|---|
| 0 (sem pontos) | −0,04 | +0,70 | +0,36 |
| 0,25 | −0,05 | +0,81 | +0,46 |
| **0,5 (atual)** | −0,05 | **+1,09** | +0,60 |
| 1,0 | −0,18 | +1,40 | +0,79 |

Leituras: (1) o espelho ≈ 0 confirma que a mesa é justa (nenhum assento ganha sozinho); (2) jogar
bem rende de forma consistente (+1,1 blinds/nível ≈ 27% da entrada de 4 blinds), acima da taxa da
casa (4%, teto de 2 blinds por pote pago); (3) os pontos aumentam a vantagem de quem os joga bem
(+0,4 blinds/nível a 0,5 em relação a 0) sem tirar o palpite do centro (acerto do novo ≈ 37%).
Fator 0,5 escolhido: vantagem clara sem deixar os pontos dominarem o prêmio do pote. Ajuste em
`ChaosEngine.BLITZ_POINT_FACTOR`. Limite: bots, não humanos — a vantagem real contra jogadores humanos
só se mede em PvP.


## Habilidade e teto do jogo (Fase 0 / Fase 1 do plano competitivo, ver `docs/PLANO_COMPETITIVO.md`)

### Oráculo: existe teto acima do bot Difícil
`scripts/core/chaos_oracle.gd` é um jogador quase perfeito (só de medição, nunca senta como bot do
jogo — é lento): sorteia mãos compatíveis com o que ele vê e escolhe palpite/carta pela maior ficha
esperada em várias simulações. `tests/blitz_arena.gd` mede confrontos:

| Confronto | Líquido bruto (blinds/nível) |
|---|---|
| Difícil vs 3× Difícil (espelho) | +0,31 (±0,28), ≈ 0 |
| **Oráculo vs 3× Difícil** | **+0,66 (±0,26)**, acerto de palpite 43% vs. ~30% do Difícil |
| Difícil vs 3× Oráculo | −0,64 (±0,68, amostra menor) |

Confirma que o Difícil não é o teto: um jogador melhor bate ele por margem real, não só ruído.

### Estilos dos bots (Fase 1)
3 estilos fixos por bot enquanto ele estiver na mesa (`ChaosBot.Style`, `engine.styles`):
**Calculista** (padrão, equilibrado), **Cauteloso** (só dobra/cobre com bastante certeza, foge
mais de fichas de carta) e **Agressivo** (persegue mais os pontos, cobre mais, e às vezes dobra
sem estar no alvo — blefe, `BLUFF_CHANCE`). O jogador aprende o padrão de cada rival com o tempo
e usa isso pra decidir cobrir ou não.

Calibração (bot×bot, sem taxa): o primeiro ajuste deixou o Agressivo perdendo até do espelho dele
mesmo (−0,61 blind/nível): não era custo do blefe, era calibração ruim. Reduzido
(`BLUFF_CHANCE` 0,12→0,05; multiplicador de "vale a pena dobrar" 1,6→1,25; ganância pelos pontos
1,4→1,15) até nenhum estilo ficar dominado pelos outros dois:

| Confronto | Líquido |
|---|---|
| Cauteloso espelho | +0,01 |
| Agressivo espelho | −0,24 (±0,41, dentro do ruído de 0) |
| Cauteloso vs 3× Calculista | +0,23 |
| Agressivo vs 3× Calculista | −0,26 (±0,41) |

### Gate de equilíbrio (regressão automática)
`tests/blitz_gate.gd` — versão rápida (bots só, sem Oráculo) que roda sempre: espelho por
dificuldade ≈ 0, escada Difícil > Normal > Fácil com folga, e nenhum estilo dominado pelos
outros dois. 0 falhas na versão atual.


## Fase 2 (Plano Competitivo): tentativa de tirar o triplicar — revertida
Testei remover o 2º lance (triplicar), por ele acertar 88% quando usado (parecia decisão quase
automática, ver diagnóstico anterior). Simulação A/B (`tests/blitz_arena.gd`, n=800, mesmo
código, só essa mudança) mostrou que era ao contrário: o triplicar (liberado só pro Difícil) era
a MAIOR fonte da vantagem do Difícil sobre o Normal. Sem ele, Difícil passou a PERDER de Normal
(−0,26 blind/nível). Revertido: triplicar continua. Corrigido nessa mesma passada: quando um bot
quebra e outro senta no lugar, o estilo agora é sorteado de novo (antes ficava preso ao assento
antigo). `tests/blitz_gate.gd` volta a passar 100%.

## Fase 3 (Plano Competitivo): palpite dos rivais em segredo até o fim do nível
Antes, todo mundo revelava o palpite junto, no início do nível — não havia o que ler ou blefar.
Agora: você só vê o seu palpite (a pílula mostra "X/seu-alvo" como sempre); a dos rivais mostra só
quantas rodadas eles já venceram, com a legenda "EM SEGREDO" no lugar do alvo. O alvo de todos
só aparece no fim do nível (showdown), junto do resultado. Dobrar/cobrir continuam visíveis (a
única pista que sobra sobre a confiança do rival, como um aumento no poker) — o Agressivo (Fase 1)
às vezes dobra sem estar no alvo, então nem "vi ele dobrar" é garantia.

Como os bots nunca leram o palpite dos rivais pra decidir nada (só o próprio, ver `chaos_bot.gd`),
esconder da tela não desequilibra nada: não são bots ficando "mais burros" nem "mais espertos",
é só o jogador humano ganhando (e perdendo) a informação que os bots nunca tiveram de graça.

## Fase 4: recebe 10, descarta 2 (substituiu a carta aberta)
Primeira versão da Fase 4 era uma carta aberta trocável (1 carta oferecida, trocar ou recusar).
Substituída: agora todo mundo recebe `BLITZ_DEAL_SIZE` (10) cartas em vez de `HAND_SIZE` (8), e
a primeira decisão do nível — antes de saber a regra da 1ª rodada, antes do palpite — é escolher
`BLITZ_DISCARD_SIZE` (2) pra descartar. As descartadas somem do jogo (não voltam pro monte). O
nível continua com `HAND_SIZE` (8) rodadas; só a mão inicial nasce maior pra dar mais escolha.
Conta do baralho: 78 cartas no total, 10×4=40 distribuídas (antes eram 32), sobram 38 sem uso —
de sobra pro sorteio de naipe dos modificadores, que não consome carta nenhuma.

`engine.can_discard/apply_discard` (motor), `ChaosBot.wants_discard` (bot: descarta as 2 mais
fracas da mão crua, sem modificador — ainda não foi sorteado nesse ponto do nível). Sem popup: a
seleção é direto na própria mão, igual escolher carta pra jogar — `_human_discard_play()` põe a
cena em `phase == "discard"`, `_rebuild_hand()` deixa as 10 cartas tocáveis, `_on_discard_tapped()`
sobe a carta tocada (`CardView.set_selected`) e marca pra descarte, toca de novo pra desmarcar. O
botão DESCARTAR (no lugar do DOBRAR, que essa hora do nível ainda não existe) só libera com
exatamente `BLITZ_DISCARD_SIZE` marcadas; `_on_discard_pressed()` aplica e segue o nível.
Tem relógio próprio: `DISCARD_SECONDS` (18s). Todos os relógios da mesa passam pelo mesmo
`_clock_start` / `_clock_stop` (card TEMPO): jogar carta `TURN_SECONDS` 10s (joga a mais fraca),
descarte 18s, lance de vitórias `PREDICT_SECONDS` 15s (confirma o palpite que estiver na tela) e
apostas `BET_SECONDS` 12s (passa, ou desiste se tiver que pagar). Estourou sem confirmar no descarte,
descarta as 2 mais fracas por você (mesma heurística do bot, `ChaosBot.wants_discard`). Sempre ativo.

## Fase 5: economia vs bots (medida, ver `docs/PLANO_COMPETITIVO.md`)
Um jogador nível Oráculo lucra em média mesmo com a taxa ligada, mas pouco (+0,39 blind/nível,
amostra pequena e ruidosa — `tests/blitz_economy_check.gd`). Não farma sem fim; calibração fina
fica pra quando houver amostra maior.
`var blitz_showdown` (`chaos_scene.gd`) controla a revelação; sem UI nova além da pílula existente.

## Modo Caos removido
O modo Caos (aposta por rodada, sem palpite) foi tirado do jogo: sumiu do menu, do Smoke test e
da sua documentação própria (`docs/ECONOMIA.md`, `docs/MESA_CAOS.md`, `tests/economy_sim.gd` —
removidos). O Blitz é o único modo de mesa daqui pra frente.

**O que NÃO foi removido, de propósito:** o motor (`ChaosEngine`) e a cena (`chaos_scene.gd`)
continuam compartilhados entre os dois modos por baixo do capô — ainda têm `if engine.blitz else
...` para o Caos em alguns pontos (textos de intro, título do popup). Como `engine.blitz` nunca
mais é `false` (nada no menu cria uma mesa sem ser Blitz), esse código fica morto, mas inofensivo.
Não arranquei linha a linha porque é um arquivo de ~2200 linhas compartilhado com o Blitz ativo —
fazer isso com segurança é um corte à parte, não uma linha de continuação desta sessão.

## Aposta por rodada (cada uma das 8 rodadas é uma mini-mão de poker)
Motivação: o palpite sozinho não dava espaço suficiente pra estratégia virar ficha — a aposta é
essencialmente fixa (entrada + dobrar/cobrir) e só resolve no fim do nível. A mesma mecânica de
aposta por rodada que já existia no Caos (passar/apostar/aumentar/desistir, pote próprio por
rodada) foi reaproveitada pro Blitz: agora, **antes de cada uma das 8 rodadas**, rola uma rodada de
aposta normal — quem não desistir joga carta depois; quem vence a disputa de cartas também leva o
pote dessa aposta, em cima do que já ganha em pontos/modificador. Isso dá mais alavancagem pra quem
lê bem a mão (apostar mais quando a mão é forte) sem mudar o palpite do nível, que continua sendo o
prêmio principal.

**Dois potes distintos, nunca confundir:**
- `pot` — o pote do **palpite do nível inteiro** (entrada de `BLITZ_ENTRY_BLINDS`, dobrar/cobrir,
  acumula em `carry` se ninguém acerta). Existe o nível inteiro, zera só na liquidação
  (`_settle_blitz`).
- `trick_pot` — o pote da **aposta daquela rodada específica**, zera em todo `begin_trick()` e é
  pago pra quem vencer a disputa de cartas da rodada (ou pra quem sobrar, se todo mundo desistir —
  `resolve_walkover`). Os dois existem ao mesmo tempo o nível inteiro; misturá-los faria a conta do
  palpite vazar pra aposta da rodada (ou vice-versa).

**Ante por rodada:** `BLITZ_TRICK_ANTE_FACTOR` (0,25× blind) — mais baixa que a ante do Caos
(1× blind), porque a rodada de Blitz já carrega o custo da entrada do palpite por cima; cobrar o
blind inteiro de novo por rodada ficaria caro demais depressa.

**Desistir custa 1 carta aleatória, não dinheiro extra além do que já apostou.** No Caos quem
desiste descarta a carta mais fraca (`_discard_weakest`) — no Blitz, decisão explícita: descarta
uma carta **sorteada** da mão (`_discard_random`), pra não entregar de graça qual carta era boa ou
ruim. Em ambos os casos o consumo é de exatamente 1 carta por rodada, jogada ou descartada — as
mãos continuam do mesmo tamanho (nunca ficam sem carta antes da 8ª rodada).

**Reaproveitado quase 100% do Caos:** motor (`begin_trick`, `bet_actor`, `bet_cap`, `to_call`,
`bet_options`, `bet_act`, `walkover_player`/`resolve_walkover`) e UI (`_betting_phase`,
`_human_bet`, `_gather_bets`, `_show_bet_action`) já eram mode-agnósticos — a única mudança real
foi: (1) separar `pot` de `trick_pot` dentro do motor (os dois existiam misturados por engano, já
que até aqui só um modo usava pote por rodada de cada vez), (2) a ante proporcional
(`BLITZ_TRICK_ANTE_FACTOR`), (3) o descarte aleatório condicional no fold, e (4) pagar `trick_pot`
pro vencedor dentro de `_resolve_trick_blitz`/`resolve_walkover` (que antes só cuidavam do palpite
e não sabiam que existia um pote de rodada a liquidar).

**Bots:** `ChaosBot.bet_decision` agora é ciente do palpite — ajusta o quanto "quer vencer" essa
rodada conforme falta pra bater o número exato apostado: já bateu (ou passou) o palpite, evita
vencer rodadas demais (só o acerto exato paga o pote cheio); precisa de quase todas as que
faltam, força mais a sorte. `tests/blitz_betting_gate.gd` cobre o caminho que `blitz_gate.gd`
não cobria: roda o mesmo critério (espelho ≈0, escada de dificuldade Difícil > Normal > Fácil,
nenhum estilo dominado) mas com `begin_trick`/`bet_act`/`walkover` de verdade ligados. A
primeira calibração do bias (±0,12/0,15) quebrou o espelho (+1,12 blind/nível); reduzida pra
±0,02–0,06 até o gate passar de novo — os dois gates (`blitz_gate.gd` e
`blitz_betting_gate.gd`) devem continuar passando a cada ajuste nessa função.

## Fila única: Blitz é o Ranqueado

Decisão de arquitetura (sem matchmaking de verdade ainda — as mesas são preenchidas com bots,
o "Ranqueado" de hoje é a vitrine da liga + um atalho pro Blitz, não uma fila separada):

- **Vanilla é 100% recreativo.** Não lê nem escreve elo nenhum (`GameState.Mode` só tem
  `CLASSIC`). `report_match()` só dá Gemas e pontos — sem LP/MMR.
- **Toda mesa real de Blitz conta pro Elo**, automaticamente, sem escolha de "casual" vs
  "ranqueado": `report_chaos_match()` aplica `apply_ranked_progress()` (mesma fórmula de LP/MMR
  que o Vanilla usava antes) toda vez que o jogador completa pelo menos 1 nível inteiro
  (`hands >= ChaosEngine.HAND_SIZE`), seja entrando pelo card "MODO BLITZ" do menu ou pela tela
  de Ranqueado. Mesa de torneio (ver próxima seção) é um caminho **totalmente separado**
  (`report_tournament_table()`) que nunca chama `apply_ranked_progress()` — não precisa de flag
  nem exceção, só não passa por ali.
- `RankedLobby.tscn` não muda de função: mostra liga/LP/histórico e, ao "buscar partida", abre
  `ChaosScene.tscn` (antes abria `GameScene.tscn`, o motor Vanilla — por isso o Ranqueado nunca
  bateu com a regra "Blitz é a espinha dorsal do elo").

## Carteiras: Fichas (jogo) e Gemas (cosmético)

- **Fichas** continuam sem valor monetário, não saem do jogo. A recarga grátis (`ChaosEconomy.
  claim_daily`) continua **manual** — o jogador abre a Loja de Fichas e toca em RESGATAR — no
  máximo 1 vez a cada 24h (`daily_on`) e só aparece disponível com o saldo abaixo do teto
  (`DAILY_MIN`, 400). Nenhuma injeção automática de fichas existe em lugar nenhum do jogo.
- **Gemas** (antes "Fragmentos" — só o nome mudou, a moeda é a mesma: cosmética, nunca afeta
  jogo) são ganhas em partidas de Vanilla e Blitz e gastas na Loja de Cosméticos.
- **Carteira de dinheiro real:** reservado `profile.cash_balance` no save (sempre 0, sem UI) pra
  quando o pagamento de verdade for integrado — nenhuma mesa ou torneio em dinheiro real existe
  ainda.

## Torneios (v2 — MTT de verdade)

`scripts/core/tournament.gd` (`Tournament`, lógica pura) + `GameState.start_tournament()` /
`tournament_table_config()` / `report_tournament_table()`. Sem matchmaking de verdade — o campo
inteiro é preenchido com bots; só a mesa do próprio jogador é jogada na cena, de verdade, nível
por nível. A v1 era um bracket de eliminação simples (mesas fixas de 4, só o 1º avançava); a v2
é um multi-table tournament igual poker de verdade: várias mesas, gente indo embora conforme
quebra, mesas se fundindo, até sobrar 1 campeão.

- **Campo de 16** (1 humano + 15 bots, dificuldade variada), dividido em mesas de **2 a 4**
  jogadores (`Tournament.MIN_TABLE`/`MAX_TABLE`). O teto fica em 4 (não no máximo que o baralho
  permitiria — 78 cartas ÷ 10 da mão inicial do Blitz dariam pra ir até 7) porque 4 é o único
  tamanho de mesa balanceado e testado hoje: bots, dificuldade e modificadores como "Assalto ao
  Líder" foram calibrados especificamente pra 3 rivais.
- **A stack viaja com o jogador.** Cada `entrant` (humano ou bot) carrega sua própria stack real
  ao longo do torneio inteiro — não é mais "mesa neutra reiniciada a cada fase". Quem quebra
  (stack chega a 0) é eliminado e sai; ninguém senta no lugar dele (ao contrário da mesa de
  Blitz normal, que reaproveita `engine.refill_bots()` pra repor bot quebrado — isso é
  explicitamente desligado pras mesas de torneio, senão ninguém jamais seria eliminado).
- **Blind escalando** (`Tournament.blind_for`): dobra a cada 3 níveis GLOBAIS do torneio (não por
  mesa — todas as mesas, inclusive as headless, jogam no mesmo blind no mesmo nível). Sem isso o
  torneio nunca anda: com blind fixo e stack de 400 (40 blinds), quase ninguém quebra.
- **Realocação (`Tournament.rebalance`):** depois de cada nível, quem está numa mesa que caiu
  abaixo do mínimo (2) é redistribuído na mesa mais curta que tiver vaga; quando o total já cabe
  numa mesa só (≤7), tudo colapsa na mesa final.
- **As mesas sem o jogador tocam o MESMO nível, headless** (`Tournament.simulate_level`): motor
  rodado só com bots, sem UI, pra atualizar as stacks delas em paralelo com a mesa real do
  jogador. Essa simulação não liga a aposta por rodada completa (decide só quem quebra, não
  precisa de fidelidade total pras outras mesas).
- **Stack > 0 sempre pode jogar, mesmo abaixo do blind** (all-in pelo que tiver — a ante já é
  limitada ao que sobra em `begin_trick()`): só stack zerada é eliminação de verdade. Isso exigiu
  um guard específico em `_ensure_solvent()` pra mesas de torneio — sem ele, um jogador
  (humano ou bot) com stack positiva mas abaixo do blind escalado ficava travado pra sempre
  (nunca jogava a mão que o eliminaria, nem nunca era marcado como eliminado).
- **Prêmio pelos 4 melhores colocados do torneio inteiro** (`Tournament.payout_for`), não só de
  quem chega numa "mesa final" fixa: bolão = buy-in × 16, líquido da taxa da casa, dividido
  55/28/12/5%. Colocação de quem é eliminado é contada pelo tamanho do campo restante no
  momento (quebrar com 10 pessoas ainda vivas = 11º lugar).
- **Nunca mexe no Elo da fila regular** (ver seção anterior) nem usa `report_chaos_match`.
- Troféus e títulos ficam na seção `tournaments` do save (`trophies`, `titles`, `history`) —
  mostrados no popup "TORNEIO" do menu.
- **Pendência real:** os bots das mesas simuladas usam a mesma IA de sempre (sem estilo "grinder
  de torneio" dedicado nem consciência de ICM/all-in-or-fold perto da bolha), e o tamanho do
  campo (16) e a régua de blind são fixos, sem configuração. Primeira versão jogável do formato
  MTT, não o produto final.
