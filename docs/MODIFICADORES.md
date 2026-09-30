# Modificadores do modo Caos/Blitz

Todo nível sorteia UM modificador (sem repetir na partida). Código: `scripts/core/chaos_modifiers.gd`.

## Lista completa (16, todos implementados e testados)

### Escopo nível inteiro (anunciado no início do nível)
| Modificador | O que muda |
|---|---|
| Trunfo em Dobro | Todo Trunfo vale o dobro de pontos |
| Reis em Dobro | Todo Rei vale o dobro de pontos |
| O Louco Vence | O Louco passa a poder vencer a rodada (ver seção própria abaixo) |
| Naipe Fraco | Um naipe sorteado vale metade dos pontos |
| Naipe Forte | Um naipe sorteado vale 1,5× os pontos |
| Mundo ao Contrário | Em toda rodada vence a MENOR carta do naipe; Trunfo não corta |
| Cada Rodada Vale +1 | Quem vence uma rodada ganha +1 ponto fixo, em toda rodada |
| Cartas Pequenas Importam | As cartas de 0,5 ponto passam a valer 1,0 |
| Naipe Maldito | Um naipe sorteado vale −1 ponto pra quem o captura |

### Escopo uma rodada só (1ª/última são fixas e reveladas de cara; as demais são sorteadas
entre a 2ª e a 7ª e ficam em segredo — "plot twist" — até a rodada começar)
| Modificador | O que muda |
|---|---|
| Rodada Dourada | Os pontos dessa rodada valem ×3 (no Blitz: quem vencer conta 2 vitórias em vez de 1 — vira "Rodada Dobrada") |
| Rodada Invertida | Só nessa rodada, vence a MENOR carta do naipe; Trunfo não corta |
| Saque | Quem vencer rouba 2 pontos de cada rival |
| Assalto ao Líder | Quem vencer rouba 4 pontos de quem lidera o placar |
| Rodada Maldita | Quem vencer essa rodada PERDE 3 pontos |
| Rodada Relâmpago | Sempre a 1ª rodada do nível; vale o dobro |
| Última é Tudo | Sempre a última rodada do nível; vale o triplo |

## Quais estão sorteando de fato hoje

- **Modo Caos** (`ChaosModifiers.ALL`, 8 de 16): Trunfo em Dobro, Reis em Dobro, O Louco Vence,
  Mundo ao Contrário, Rodada Dourada, Rodada Invertida, Rodada Maldita, Saque. Os outros 8 ficam
  implementados e testados, só fora da pool ativa pra não poluir a experiência (podem voltar por
  temporada/evento).
- **Modo Blitz** (`ChaosModifiers.BLITZ_POOL`, 4): O Louco Vence, Mundo ao Contrário, Rodada
  Invertida, Rodada Dourada (aqui só conta vitórias, sem multiplicar pontos — o Blitz não tem
  prêmio em pontos, só o palpite de vitórias importa). Nenhum é surpresa no Blitz: o palpite
  precisa da regra já conhecida.

## O Louco Vence (explicação à parte, porque não é óbvio)

**Regra normal** (Vanilla e Caos sem esse modificador): O Louco pode ser jogado a qualquer
momento — ignora naipe e Trunfo, nunca precisa seguir nada — mas **nunca vence a rodada**. Quem
joga O Louco fica com ele e mantém os pontos que ele vale (4,5, como um Rei — é um dos 3 Bouts),
só que quem realmente ganhou a rodada leva as outras 3 cartas. Serve pra "escapar" de uma rodada
sem gastar Trunfo nem se comprometer com naipe, sem abrir mão dos pontos dele.

**Com O Louco Vence ativado**, essa trava cai: ele passa a poder vencer a rodada, só que se
comporta como **um Trunfo muito fraco**:
- Perde pra qualquer Trunfo de verdade jogado na mesma rodada.
- Vence naipe comum (Ouros, Paus, Copas, Espadas), mesmo contra um Rei desse naipe.
- Continua sem seguir naipe nem ser obrigado a acompanhar nada — a única coisa que muda é se ele
  pode ou não levar a rodada quando ninguém cortou com Trunfo de verdade.

Código: `ChaosEngine.louco_can_win()` habilita esse comportamento em `TrickRules.winning_index` /
`would_win` (parâmetro `louco_can_win`).
