# Modificadores do Blitz

Todo Ritual usa os 8 modificadores, embaralhados, um por jogada e sem repetir. Cada um vale por UMA
jogada só. Antes de cada jogada, uma tela cheia explica a regra (e uma contagem visível até
começar, ~3s, que se pula tocando em "ENTENDI, CONTINUAR"). Nenhum é surpresa: o jogador sempre
sabe a regra antes de decidir.

Nenhum modificador mexe no valor (pontos) das cartas. Eles mudam só quem vence, quantas vitórias
a jogada conta ou quantas fichas se movem. Os três de ficha movem o MESMO total, **3 blinds**, em
qualquer mesa, dividido entre os rivais quando há vários.

Código: `scripts/core/chaos_modifiers.gd` (lista, nomes, textos), `scripts/core/trick_rules.gd`
(`winning_index_mod`, `legal_cards_for`), `ChaosEngine.draw_trick_modifier()` (sorteio),
`ChaosEngine._modifier_chips()` (fichas), `ChaosScene._modifier_transition()` (tela cheia).

## Os 8

| Nome | Texto (uma linha) | Regra |
|---|---|---|
| Loucura | O Louco vence qualquer carta, até arcano maior. | Quem jogar O Louco vence a jogada. |
| Oposição | Vence a menor carta do naipe. Arcano maior só vale se abrir a jogada. | Vence a menor do naipe da 1ª carta. Trunfo não corta. Se o Trunfo abriu, vence o menor Trunfo. |
| Transmutação | O vencedor conta 2 vitórias na profecia. | A vitória vale por 2. Os pontos das cartas não são multiplicados. |
| Saque | O vencedor rouba 3 blinds, divididos entre os rivais. | Cada rival que jogou paga a sua parte (limitada ao que tem). |
| Assalto | O vencedor rouba 3 blinds de quem tem mais fichas. | Tira do líder da stack (nada se o líder é o vencedor). |
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
