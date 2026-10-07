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
(stack de 100 blinds = 12,5 entradas de palpite) → **blind sobe ×`growth` por nível**, tabela FIXA por evento (arredondada pra
valores redondos, sempre crescente; igual pra todas as mesas). Entrada do palpite = 8 blinds. Quanto mais caro o evento, mais
devagar sobe.

| Evento | Inscrição | Stack | Blind inicial | Sobe por nível | Duração média (sim) |
|---|---|---|---|---|---|
| Freeroll Arcano | ◎100 | ◎1.000 | 10 | ×1,35 | ~12,6 níveis |
| Torneio Clássico | ◎300 | ◎3.000 | 30 | ×1,32 | ~14,2 |
| Mesa dos Magos | ◎600 | ◎6.000 | 60 | ×1,30 | ~14,0 |
| Grande Arcano | ◎1500 | ◎15.000 | 150 | ×1,28 | ~14,9 |

Como a tabela é fixa, o final não depende de ninguém "aceitar apostar": o blind (e a entrada de 8 blinds) acaba
passando o que qualquer stack cobre, e quem não cobre a entrada é eliminado. Um 1x1 final dura ~5 níveis.
`godot --headless --path . -s res://tests/sim/tournament_pace.gd` mede duração e quebras por nível.
