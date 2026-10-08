# Modificadores do Blitz

Todo Ritual usa os 8 modificadores, embaralhados, um por jogada e sem repetir. Cada um vale por UMA
jogada só. Antes de cada jogada, uma tela cheia explica a regra (e uma contagem visível até
começar, ~3s, que se pula tocando em "ENTENDI, CONTINUAR"). Nenhum é surpresa: o jogador sempre
sabe a regra antes de decidir.

Nenhum modificador mexe no valor (pontos) das cartas. Eles mudam só quem vence, quantas vitórias
a jogada conta ou quantas fichas se movem. Os três de ficha movem o MESMO total, **3 blinds**, em
qualquer mesa, dividido entre os rivais quando há vários.

Código: `scripts/core/blitz_modifiers.gd` (lista, nomes, textos), `scripts/core/trick_rules.gd`
(`winning_index_mod`, `legal_cards_for`), `BlitzEngine.draw_trick_modifier()` (sorteio),
`BlitzEngine._modifier_chips()` (fichas), `BlitzScene._modifier_transition()` (tela cheia).

## Os 8

| Nome | Texto (uma linha) | Regra |
|---|---|---|
| Loucura | O Louco vence qualquer carta, até arcano maior. | Quem jogar O Louco vence a jogada. |
| Oposição | Vence a menor carta do naipe. Arcano maior só vale se abrir a jogada. | Vence a menor do naipe da 1ª carta. Trunfo não corta. Se o Trunfo abriu, vence o menor Trunfo. |
| Transmutação | O vencedor conta 2 vitórias na profecia. | A vitória vale por 2. Os pontos das cartas não são multiplicados. |
| Saque | O vencedor rouba 3 blinds, divididos entre os rivais. | Cada rival que jogou paga a sua parte (limitada ao que tem). |
| Assalto | O vencedor rouba 3 blinds do rival com mais fichas. | Tira do rival mais rico (se o vencedor lidera, tira do segundo). |
| Maldição | O vencedor paga 3 blinds, divididos entre os rivais. | Quem vence paga (limitado ao que tem). |
| Silêncio | Arcano maior não vence naipe. Vence a maior carta do naipe. | Trunfo não corta. Quem não tem o naipe ainda é obrigado a jogar Trunfo, que não vence. Se o Trunfo abriu, vence o maior Trunfo. |
| Pitagórico | Jogue qualquer naipe. Vence o maior número e o arcano maior ainda vence. | Toda a mão é jogável. Se há Trunfo na mesa, vence o maior. Senão vence o maior número, de qualquer naipe. Empate de número: Espadas > Copas > Paus > Ouros (a tela mostra a ordem, com símbolo, cor e nome). |

## Quem zera por modificador sai da mesa
Se um Saque, um Assalto ou uma Maldição zera as fichas de alguém, ele é eliminado na checagem de
quebra que roda depois de cada jogada (`bust_broke`): perde a mão e sai da mesa. No torneio é a
eliminação definitiva. No ranqueado aparece "VOCÊ QUEBROU" com recomprar ou sair. Ninguém paga mais
do que tem: se faltar, paga só o que sobra.

## O Louco
Regra normal: o Louco pode ser jogado a qualquer momento, ignora naipe e Trunfo, mas nunca vence. Quem o
joga mantém os pontos dele (4,5, um dos 3 Bouts). Só na Loucura ele vence qualquer carta.

## Saíram nesta revisão
Trunfo em Dobro, Figuras em Dobro, Naipe Fraco, Naipe Forte e Cartas Pequenas Importam saíram por
mexerem nos pontos das cartas. "Cada Jogada Vale +1" saiu antes. Por isso Saque, Assalto e Maldição
deixaram de usar "pontos" e passaram a usar o blind.

## Equilíbrio medido (`tests/sim/modifier_balance.gd`, 2.000 Rituais, 4 bots Difícil, stacks 400 blinds)
"Peso" = fichas que o modificador move + o que ele muda na profecia (acertou +8,2 blinds, errou por 1
−4,0, errou por 2+ −10,0, médias reais), tudo em blinds por jogada. A coluna "muda quem vence" compara
com a regra normal sobre as mesmas cartas.

| Modificador | Muda quem vence | Fichas movidas | Vitórias | Mexe na profecia | Peso (blinds) |
|---|---|---|---|---|---|
| Loucura | 6% | 0 | 1 | 6% | 0,5 |
| Oposição | 87% | 0 | 1 | 86% | 7,8 |
| Transmutação | 0% | 0 | 2 | 83% | 4,2 |
| Saque | 0% | 3,0 | 1 | 0% | 3,0 |
| Assalto | 0% | 3,0 | 1 | 0% | 3,0 |
| Maldição | 0% | 3,0 | 1 | 0% | 3,0 |
| Silêncio | 40% | 0 | 1 | 40% | 3,5 |
| Pitagórico | 16% | 0 | 1 | 16% | 1,4 |

- Cada vez que um modificador troca o vencedor, a profecia muda em média ~8,7 blinds (todos os de
  "muda quem vence" ficam em 8,5 a 9 por troca). Por isso o peso deles é basicamente a taxa de troca.
- O Assalto pesava 1,8 (não rodava em 41% das jogadas) porque, quando o vencedor era o líder, não havia de
  quem roubar. Hoje rouba do rival mais rico (do segundo, se o vencedor lidera) e pesa 3,0 como os outros.
- Fora de linha: Oposição (muito forte), Loucura (muito fraca, depende de o Louco estar na mão) e
  Pitagórico (fraco, os bots ainda jogam quase sempre o naipe da 1ª carta). Os números dependem do jogo
  dos bots: quem aproveita melhor a regra muda o peso.
