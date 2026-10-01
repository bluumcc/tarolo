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
Tem relógio próprio: `DISCARD_SECONDS` (15s, reaproveita a mesma `turn_bar` do relógio de jogar
carta). Estourou sem confirmar, descarta as 2 mais fracas por você (mesma heurística do bot,
`ChaosBot.wants_discard`), igual ao "jogamos sua carta mais fraca" de quando o relógio de jogar
carta estoura. Sempre ativo, **inclusive no onboarding** — é a única etapa nova que não se esconde
nas primeiras mesas de conta nova, porque molda a mão, não adiciona uma regra de aposta ou de
rodada.

## Onboarding: camadas de regra pros primeiros níveis
**Toda rodada de Blitz tem modificador, sempre — sem exceção, nem na conta nova, nem no nível 1.**
Isso já foi tentado ao contrário (modificador escondido nos primeiros níveis) e revertido: virou
bug reportado duas vezes ("sumiu?") sem eu nunca ter avisado que era onboarding, e modificador é
parte central do jogo, não uma camada avançada pra esconder. O que o onboarding esconde hoje:
primeiras `GameState.ONBOARDING_LEVELS` (3) mesas de Blitz de conta nova, **só dobrar/cobrir**
ficam fora — o descarte inicial e os modificadores valem sempre, em toda mesa, em toda rodada.
Contado por `profile.blitz_levels` (save), passado como `onboarding_levels` no config do motor.
`_test_blitz_phase4` (`test_runner.gd`) cobre o comportamento.

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

**Bots:** a decisão de aposta reaproveita `ChaosBot.bet_decision` tal como está no Caos — ainda não
é ciente do palpite do jogador (não considera "preciso de mais X vitórias" ao decidir apostar
alto). Primeira versão aceitável, mas não validada por simulação dedicada: `tests/blitz_gate.gd`
(espelho ≈0, escada de dificuldade, nenhum estilo dominado) passa, mas não cobre o caminho novo —
ainda simula só predict/jogo de carta/liquidação, sem `begin_trick`/`bet_act`. **Pendência real:**
escrever uma simulação que jogue com a aposta por rodada ligada e confirmar que a escada de
dificuldade e o equilíbrio entre estilos sobrevivem ao novo mecanismo, e depois calibrar os bots
pra também levarem o palpite em conta na hora de apostar.

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

- **Fichas** continuam sem valor monetário, não saem do jogo. Resgate automático
  (`ChaosEconomy.rescue_if_broke`): se o saldo zerar, a casa injeta `RESCUE_AMOUNT` (400, a
  entrada da mesa Iniciante) na hora de sentar — sem precisar pedir ou esperar a recarga diária.
- **Gemas** (antes "Fragmentos" — só o nome mudou, a moeda é a mesma: cosmética, nunca afeta
  jogo) são ganhas em partidas de Vanilla e Blitz e gastas na Loja de Cosméticos.
- **Carteira de dinheiro real:** reservado `profile.cash_balance` no save (sempre 0, sem UI) pra
  quando o pagamento de verdade for integrado — nenhuma mesa ou torneio em dinheiro real existe
  ainda.

## Torneios (v1)

`scripts/core/tournament.gd` (`Tournament`, lógica pura) + `GameState.start_tournament()` /
`tournament_table_config()` / `report_tournament_table()`. Sem matchmaking de verdade — o campo
inteiro é preenchido com bots; só a mesa do próprio jogador é jogada na cena, de verdade.

- **Campo fixo de 16** (1 humano + 15 bots, dificuldade variada) em **2 fases, mesas de 4**:
  Quartas (4 mesas) → Final (1 mesa, com os 4 vencedores das Quartas). Eliminação simples: só o
  1º lugar de cada mesa avança.
- **Buy-in cobrado uma vez** na inscrição (`Tournament.BUY_IN`, fichas), não por mesa — as mesas
  do torneio usam um stack neutro (400, igual a uma mesa Iniciante) que não é a carteira real do
  jogador. Quebrar numa mesa de torneio é eliminação (sem recompra com fichas de verdade — ver
  guard em `_ensure_solvent()`).
- **As 3 mesas da fase em que o jogador não está são resolvidas na hora, headless**
  (`Tournament.simulate_table`): roda o motor com bots dos dois lados por um número fixo de
  níveis (`LEVELS_PER_TABLE`) e ordena por stack final — mesmo padrão já usado em
  `tests/blitz_sim.gd` pra medir o motor sem UI. Essa simulação não liga a aposta por rodada
  (igual aos sims existentes): só decide colocação pra avançar o bracket, não precisa de
  fidelidade total.
- **Prêmio só pra quem chega na mesa final** (`Tournament.payout_for`): bolão = buy-in × 16, já
  líquido da taxa da casa, dividido 55/28/12/5% pelas 4 colocações da Final. Eliminado nas
  Quartas não leva fichas.
- **Nunca mexe no Elo da fila regular** (ver seção anterior) nem usa `report_chaos_match`.
- Troféus e títulos ficam na seção `tournaments` do save (`trophies`, `titles`, `history`) —
  mostrados no popup "TORNEIO" do menu.
- **Pendência real:** campo fixo de 16 é rígido (sem escolher tamanho de torneio nem horário de
  início — é tudo instantâneo, sem agenda), e os bots das mesas simuladas usam a mesma IA de
  sempre (sem estilo "grinder de torneio" dedicado). Primeira versão jogável, não o produto final
  do documento de arquitetura.
