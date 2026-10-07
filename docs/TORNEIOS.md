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

## Estrutura (uma regra só, escalada pelo buy-in) — `Tournament.OPEN_EVENTS`
1. **Bolão** = inscrição × 16 × 0,9; prêmios 60/28/12% (1º/2º/3º).
2. **Stack inicial = 10× o buy-in.**
3. **Blind inicial `u` = 1% da stack** (100 blinds = 12,5 entradas de palpite; a entrada é 8 blinds).
4. **O blind sobe SEMPRE um degrau por nível, numa escada fixa igual pra todos os torneios** (a escada clássica de poker,
   cada degrau +20% a +50%, sem exceção nem pulo): `u × 1; 1,5; 2; 2,5; 3; 4; 5; 6; 8; 10; 15; 20; 25; 30; 40; 50…`
   Com `u = 10`: **10 · 15 · 20 · 25 · 30 · 40 · 50 · 60 · 80 · 100 · 150 · 200 · 250 · 300 · 400 · 500 · 600 · 800 · 1000…**
   Com `u = 30`: 30 · 45 · 60 · 75 · 90 · 120 · 150 · 180 · 240 · 300…  (a mesma escada, ×3).
   `u` múltiplo de 10 ⇒ blind, ante (20%) e entrada sempre inteiros e múltiplos de 5, nunca decimais.

| Torneio | Inscrição | Stack | `u` (blind inicial) | Primeiros blinds | Duração (sim) |
|---|---|---|---|---|---|
| Freeroll Arcano | ◎100 | ◎1.000 | 10 | 10 · 15 · 20 · 25 · 30 · 40 · 50 · 60 · 80 · 100 | ~14,6 níveis |
| Torneio Clássico | ◎300 | ◎3.000 | 30 | 30 · 45 · 60 · 75 · 90 · 120 · 150 · 180 · 240 · 300 | ~14,3 |
| Mesa dos Magos | ◎600 | ◎6.000 | 60 | 60 · 90 · 120 · 150 · 180 · 240 · 300 · 360 · 480 · 600 | ~14,0 |
| Grande Arcano | ◎1500 | ◎15.000 | 150 | 150 · 225 · 300 · 375 · 450 · 600 · 750 · 900 · 1200 · 1500 | ~14,1 |

Tabela fixa: o final não depende de ninguém "aceitar apostar" — o blind (e a entrada de 8 blinds) acaba passando o que qualquer
stack cobre, e quem não cobre a entrada é eliminado. `godot --headless --path . -s res://tests/sim/tournament_pace.gd` mede
duração e quebras por nível.
