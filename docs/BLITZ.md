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
fracas da mão crua, sem modificador — ainda não foi sorteado nesse ponto do nível), UI em
`_human_discard_choice()` (toque pra marcar/desmarcar, confirma só com exatamente 2 marcadas).
Sempre ativo, **inclusive no onboarding** — é a única etapa nova que não se esconde nas primeiras
mesas de conta nova, porque molda a mão, não adiciona uma regra de aposta ou de rodada.

## Onboarding: camadas de regra pros primeiros níveis
Conta nova, primeiras `GameState.ONBOARDING_LEVELS` (3) mesas de Blitz: sem modificador (a tela
cheia nem abre), sem dobrar/cobrir — só o palpite puro (mais o descarte inicial, que continua
ativo) pra aprender a mecânica central antes de mais uma camada. Contado por `profile.blitz_levels`
(save), passado como `onboarding_levels` no config do motor. `_test_blitz_phase4`
(`test_runner.gd`) cobre o comportamento.

## Fase 5: economia vs bots (medida, ver `docs/PLANO_COMPETITIVO.md`)
Um jogador nível Oráculo lucra em média mesmo com a taxa ligada, mas pouco (+0,39 blind/nível,
amostra pequena e ruidosa — `tests/blitz_economy_check.gd`). Não farma sem fim; calibração fina
fica pra quando houver amostra maior.
`var blitz_showdown` (`chaos_scene.gd`) controla a revelação; sem UI nova além da pílula existente.
