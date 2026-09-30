# Modificadores do modo Caos/Blitz

Todo nível embaralha os 12 modificadores e usa 8, um por rodada, sem repetir dentro do
nível. Sempre por UMA rodada só — não existe mais modificador de nível inteiro. Antes de cada
rodada, uma tela cheia explica a regra com objetividade (sem distrações) e uma contagem visível
até começar (~3s; toca em "ENTENDI, CONTINUAR" pra pular). Nenhum é surpresa: o jogador sempre
sabe a regra antes de decidir, e no Blitz o palpite pode contar com essa informação a cada rodada.

Código: `scripts/core/chaos_modifiers.gd` (lista, textos), `ChaosEngine.draw_trick_modifier()`
(sorteio), `ChaosScene._trick_start()` (tela cheia + contagem).

## Os 12

| Modificador | O que muda | No Blitz |
|---|---|---|
| Trunfo em Dobro | Todo Trunfo vale o dobro de pontos | sem efeito |
| Figuras em Dobro | Valete, Cavaleiro, Dama e Rei valem o dobro | sem efeito |
| O Louco Vence | O Louco pode vencer, como um Trunfo fraquinho | muda quem vence |
| Naipe Fraco | Um naipe sorteado vale metade dos pontos | sem efeito |
| Naipe Forte | Um naipe sorteado vale 1,5× os pontos | sem efeito |
| Rodada Invertida | Vence a MENOR carta do naipe; Trunfo não corta | muda quem vence |
| Cada Rodada Vale +1 | Quem vencer ganha +1 ponto fixo | sem efeito |
| Cartas Pequenas Importam | As cartas de 0,5 ponto valem 1,0 | sem efeito |
| Rodada Dourada | Os pontos valem ×3 | conta 2 vitórias ("Rodada Dobrada") |
| Saque | Quem vencer rouba 2 pontos de cada rival | rouba fichas de verdade, além da vitória |
| Assalto ao Líder | Quem vencer rouba 4 pontos de quem lidera o placar | rouba fichas de quem lidera a stack, além da vitória |
| Rodada Maldita | Quem vencer PERDE 3 pontos | paga fichas aos rivais, além da vitória |

"Sem efeito" no Blitz não significa "não acontece": a rodada ainda é jogada normalmente e ainda
conta 1 vitória pro palpite de quem vencer — só não move fichas fora disso. A tela do
modificador avisa isso explicitamente quando é o caso.

## O que mudou nesta revisão
- **Mundo ao Contrário e Rodada Invertida eram a mesma regra em escopos diferentes** (nível
  inteiro vs. uma rodada). Como agora tudo é por rodada, viraram um modificador só: Rodada
  Invertida.
- **Rodada Relâmpago (1ª rodada ×2) e Última é Tudo (última ×3)** ficavam presas a uma posição
  fixa, o que só fazia sentido quando havia um modificador "de nível". Com toda rodada já
  ganhando uma regra sorteada, essa posição fixa deixou de ser necessária — o papel de "rodada
  que vale muito" já é coberto pela Rodada Dourada, agora podendo cair em qualquer rodada.
- **Reis em Dobro virou Figuras em Dobro**: Valete, Cavaleiro e Dama também dobram, não só o Rei.
- **Naipe Maldito foi removido**: fazia praticamente a mesma coisa que Naipe Fraco (reduzir o
  valor de um naipe-alvo), só que com sinal trocado — redundante o bastante pra não valer os dois.

## Sobre o Saque (por que "pontos" além do pote)
O pote (fichas apostadas) e os pontos das cartas são duas coisas separadas. Pontos são o valor
tradicional do Jeu de Tarot (0,5 a 4,5 por carta) e servem só de unidade de conta pros
modificadores: cada ponto vira ficha a uma taxa fixa (`ChaosEngine.PRIZE_PER_POINT`), paga
diretamente pelos rivais, por fora do pote. O Saque rouba 2 desses pontos (convertidos em fichas)
de cada rival na rodada, sem precisar capturar carta nenhuma — é uma fonte de fichas à parte do
pote, que dá um motivo pra disputar rodadas mesmo quando o pote da vez é pequeno.

## O Louco Vence (detalhe à parte, porque não é óbvio)
Regra normal: O Louco pode ser jogado a qualquer momento — ignora naipe e Trunfo — mas nunca
vence a rodada; quem o joga mantém os pontos dele (4,5, como um Rei — é um dos 3 Bouts), e quem
realmente ganhou leva as outras cartas. Com O Louco Vence ativo, ele passa a poder vencer, mas se
comporta como um Trunfo muito fraco: perde pra qualquer Trunfo de verdade, vence naipe comum.
Continua sem seguir naipe nem ser obrigado a acompanhar nada.
