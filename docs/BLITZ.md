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
6. **Modificadores** (todos anunciados, nenhuma surpresa): O Louco Vence, Mundo ao Contrário, Rodada
   Invertida e Rodada Dobrada (quem vence conta 2 vitórias). Sem prêmio em pontos/combos.

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
