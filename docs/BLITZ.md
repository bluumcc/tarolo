# Modo Blitz

O Blitz é o Caos com **palpite por nível** no lugar da aposta por rodada. Mesma mesa, mesmas
stacks, mesmas cartas (as regras de carta do Caos: qualquer Trunfo vale), mas o dinheiro só se
move **no fim do nível**, conforme quem acertou quantas rodadas ia ganhar.

Código: `ChaosEngine` com `blitz = true` (config `"mode": "blitz"`), `ChaosBot.blitz_*`,
`ChaosScene` (mesma cena, ramos `engine.blitz`). Simulação: `tests/blitz_sim.gd`.

## Regras (o que o jogador aprende)
1. **Palpite:** no início do nível você vê a mão e diz quantas rodadas vai ganhar (0 a 8). A ★ sugere
   o palpite que combina com a sua mão. Todos pagam a **entrada fixa de 2 blinds** e revelam juntos.
2. **Jogo:** 8 rodadas de 1 carta. Sob cada avatar o progresso ao vivo (`1/3`): verde no alvo,
   vermelho se estourou ou não dá mais tempo.
3. **Pote:**
   - Acertou o número exato → divide o pote com os outros acertos, pelo **peso** = entrada × dificuldade
     (palpite 0–2 ×1, 3–4 ×1,5, 5+ ×2).
   - Errou por 1 → recebe metade da entrada de volta (a outra metade fica no pote).
   - Errou por 2 ou mais → perde a entrada.
   - Ninguém acertou → o pote **acumula** pro próximo nível (jackpot).
4. **Dobrar:** a partir da 4ª rodada, uma vez por nível, só se ainda dá pra acertar: paga mais uma
   entrada e o peso dobra.
5. **Modificadores** (todos anunciados, nenhuma surpresa): O Louco Vence, Mundo ao Contrário, Rodada
   Invertida e Rodada Dobrada (quem vence conta 2 vitórias). Sem prêmio em pontos/combos.

## Prêmio da casa (ritmo de ganho)
Zero-sum contra bots rendia quase nada (~0,0 blind por nível mesmo jogando bem). Por isso quem **você** acerta o
número exato leva um prêmio extra pago pela casa: `3 blinds × peso do palpite (×1 / ×1,5 / ×2) × 2 se dobrou ×
sequência (×1, ×1,5, ×2 com 1, 2, 3+ acertos seguidos)`. Só o jogador humano recebe (os bots não ganham do nada,
o placar da mesa segue justo). Simulação (blind 10, ~55 s por nível, ~16 níveis em 15 min):

| Nível de jogo | Ganho médio por nível | Em 15 min (mesa Iniciante) |
|---|---|---|
| Difícil (habilidade alta) | ~+2,0 blinds | ~+320 fichas |
| Normal | ~+1,4 blinds | ~+220 fichas |
| Fácil (palpite e jogo ruins) | ~+0,65 blinds | ~+100 fichas |

O ganho depende da taxa de acertos, então melhorar o jogo rende ~3× mais. Constante: `BLITZ_BONUS_BLINDS`.

## Por que é simples e tem estratégia
- Uma decisão de dinheiro por nível (o palpite, com sugestão) e uma opcional (dobrar).
- A estratégia real está em **jogar pra fechar a conta**: já no alvo, perder as rodadas que sobram
  descartando a carta forte embaixo de uma maior; faltando, guardar Trunfos.
- Palpites baixos são mais controláveis (na simulação, palpite 0 acerta ~79%, 1 ~36%, 2 ~28%, 3 ~24%),
  mas os altos pesam mais no pote.
- Dobrar tem regra de bolso testada por simulação: **no alvo com mão fraca acerta ~90%** (vale dobrar);
  ainda faltando vitórias, só ~30% (não vale).

## Economia (simulação, 120 sessões × 30 níveis, blind 10)
| Cenário | Líquido médio (blinds) |
|---|---|
| Todos difíceis | +0,6 |
| Todos normais | −1,9 |
| Seat 0 difícil vs fáceis | +2,2 |
| Seat 0 normal vs iniciante | +0,9 |
| Seat 0 fácil vs difíceis | −9,8 |

- Jogar melhor rende; jogar mal custa. O resultado depende da habilidade (steering + dobrar), não só da sorte.
- **Taxa da casa:** a mesma do Caos (3% do pote, teto 1,5 blind) e **só quando o pote é pago**;
  jackpot acumulado não paga taxa. ~0,06 blind por nível por jogador.
- Fichas se conservam: nada é criado (testado). O pote acumulado fica na mesa.
- Mesas e bots: as mesmas do Caos (Iniciante, Regular, Alta), stack de 40 blinds.

## Calibração dos bots
`ChaosBot.EXPECT_SCALE` (1,48) calibra a soma de poder das cartas até a média real de 2 vitórias por
jogador por nível. Fácil erra o palpite (±0,9) e nunca dobra; normal (±0,45) só dobra com muita certeza;
difícil (±0,15) descarta forte embaixo de carta maior e dobra quando no alvo com mão fraca.
