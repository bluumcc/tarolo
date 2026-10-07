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

## Estrutura por evento (`Tournament.OPEN_EVENTS`)
| Evento | Inscrição | Stack | Blind inicial | Dobra a cada | Depois do nível | Duração média (sim) |
|---|---|---|---|---|---|---|
| Freeroll Arcano | ◎100 | ◎800 | 10 | 3 níveis | 8 → a cada 2 | ~15 níveis |
| Torneio Clássico | ◎300 | ◎1000 | 10 | 3 níveis | 10 → a cada 2 | ~16 níveis |
| Mesa dos Magos | ◎600 | ◎1200 | 10 | 4 níveis | 11 → a cada 2 | ~19 níveis |
| Grande Arcano | ◎1500 | ◎1600 | 10 | 4 níveis | 12 → a cada 2 | ~19 níveis |

Entrada do palpite = 8 blinds. Stack em entradas (blind 10): 10 / 12,5 / 15 / 20. Bolão = inscrição × 16 × 0,9;
prêmios 60% / 28% / 12% (1º/2º/3º).
`godot --headless --path . -s res://tests/sim/tournament_pace.gd` mede a duração e as quebras por nível.
