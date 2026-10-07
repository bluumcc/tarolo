# Torneios — regras e estrutura

## Eliminação (igual em todas as mesas do torneio)
- **Sem fichas pra entrada do palpite (8 blinds)** = eliminado antes de jogar o nível (nada vai pro pote).
- **Pagou a entrada e sobrou ≥ 1 ficha**: joga em all-in (ante limitada ao que sobrou, potes laterais).
- **Zerou a stack em qualquer momento** = eliminado, e acabou: o palpite dele deixa de valer (a entrada fica no pote
  como dinheiro morto). Antes o eliminado ainda "acertava" o palpite 0, recebia fichas e voltava — o loop.
- A rodada fechada normalmente (8 jogadas) liquida o palpite *antes* de checar quem zerou.

## Mesas
- Sempre 3 a 6 jogadores no começo de cada nível (`Tournament.rebalance`).
- Se a mesa cair abaixo de 3 no meio do nível e houver outras mesas, **ela se desfaz na hora**: as jogadas que
  faltam não contam vitória pra ninguém, o palpite vale pelo que já foi jogado, e se nenhuma jogada foi feita as
  entradas voltam. Nunca 1x1 — só a final (única mesa) pode ter 2.

## Estrutura por evento (`Tournament.OPEN_EVENTS`) — tudo deriva do buy-in
Buy-in → bolão (inscrição × 16 × 0,9; 60/28/12% pro 1º/2º/3º) → **stack = 10× o buy-in** → **blind inicial = 1% da stack**
(100 blinds = 12,5 entradas de palpite) → **blind sobe por uma escada fixa de valores redondos**, igual à de torneio de verdade:
`10, 15, 20, 25, 30, 40, 50, 60, 80, 100, 150, 200, 250, 300, 400, 500, 600, 800, 1000, 1500…` (todos inteiros e múltiplos de 5,
então a ante de 20% e a entrada do palpite de 8 blinds também são sempre inteiras — nunca decimais). Cada evento sobe `steps`
degraus por nível (1 degrau ≈ +29%; 1,2 = às vezes dois degraus). Mais caro = mais devagar. Tabela fixa, igual pra todas as mesas.

| Evento | Inscrição | Stack | Blinds dos primeiros níveis | Degraus/nível | Duração (sim) |
|---|---|---|---|---|---|
| Freeroll Arcano | ◎100 | ◎1.000 | 10 · 15 · 20 · 30 · 40 · 50 · 60 · 80 · 150… | 1,2 | ~12 níveis |
| Torneio Clássico | ◎300 | ◎3.000 | 30 · 40 · 50 · 60 · 80 · 150 · 200 · 250… | 1,1 | ~13,5 |
| Mesa dos Magos | ◎600 | ◎6.000 | 60 · 80 · 100 · 150 · 200 · 250 · 300 · 400… | 1,0 | ~14 |
| Grande Arcano | ◎1500 | ◎15.000 | 150 · 200 · 250 · 300 · 400 · 500 · 600 · 800… | 1,0 | ~15 |

Como a tabela é fixa, o final não depende de ninguém "aceitar apostar": o blind (e a entrada de 8 blinds) acaba passando o que
qualquer stack cobre, e quem não cobre a entrada é eliminado. `tournament_pace.gd` mede duração e quebras por nível.
