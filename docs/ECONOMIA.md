# Economia de fichas — cálculo e decisões

Fichas **não valem dinheiro e não podem ser sacadas** (só existem dentro do jogo). Compras de pacotes são **simuladas** por enquanto: nada é cobrado.
Números vêm de simulação (`tests/economy_sim.gd`, 150 sessões por linha) com os bots do jogo. Contas em blinds; multiplique pelo blind da mesa.

## 1. O que a simulação mostrou
1. **Stack de 20 blinds quebra cedo demais.** Mesmo entre jogadores iguais, 54% das sessões quebram em até 40 rodadas (mediana ~18 a 34 rodadas). Motivo: o pote médio é ~7,5 blinds e o desvio por rodada é ~3,5 blinds, então a raiz de n rodadas estoura 20 blinds rápido. Com **40 blinds** a mediana sobe para ~60 a 80 rodadas (cerca de uma hora de jogo) e só ~22% quebram em 40 rodadas.
2. **O prêmio das cartas criava fichas do nada** (~1,6 blinds por rodada, +0,4 blind por rodada para cada jogador: inflação de ~160 fichas por sessão). Agora ele é **pago pelos rivais** (soma zero). Teste automático confirma: fichas na mesa + taxa da casa = total inicial.
3. **Pote médio 7,5 blinds, 6% de rodadas terminam em blefe** (todos desistem), ~4 a 11% conforme a mesa.
4. **Vantagem de posição** existe (o último a jogar a carta ganha ~0,1 a 0,15 blind por rodada) e é aceitável.

## 2. Regras da economia
| Item | Valor | Por quê |
|---|---|---|
| Stack padrão | **40 blinds** | mediana de ~1 hora por buy-in |
| Bot novo senta com | **30 a 60 blinds** (aleatório) | mesas com stacks variados, como gente de verdade |
| Taxa da casa | **3% do pote, teto de 1,5 blinds**, só quando as cartas são jogadas (blefe sem disputa não paga) | é o ralo fixo; ~7 blinds por buy-in (~18%) |
| Prêmio das cartas | pago pelos **rivais** que jogaram a rodada | economia fechada, sem inflação |
| Saldo inicial | **◎1.000** | 5 entradas Iniciante ou 1 Regular |
| Recarga diária grátis | **◎300**, 1 por dia, só se as fichas < **◎200** (não paga nem a entrada mais barata), precisa **coletar** | 1,5 entrada Iniciante |

### Mesas
| Mesa | Blind | Entrada (40 blinds) | Bots |
|---|---|---|---|
| Iniciante | ◎5 | ◎200 | Fácil, Normal, Normal |
| Regular | ◎25 | ◎1.000 | Normal, Normal, Difícil |
| Alta | ◎100 | ◎4.000 | Difícil ×3 |

Bots mais fortes conforme o blind sobe: quem quer lucrar sobe de mesa e enfrenta mais habilidade, quem é iniciante aprende com stakes baixos.

## 3. Resultado esperado por buy-in (40 blinds, até 300 rodadas)
Líquido médio em blinds (negativo = perde fichas pra casa):

| Mesa | Jogador fraco | Jogador médio | Jogador forte |
|---|---|---|---|
| Iniciante | −31 | −3 | **+27** |
| Regular | −35 | −5 | −4 |
| Alta | −37 | −10 | −15 |

Em fichas por buy-in: Iniciante (×5): fraco −155, médio −15, forte +135. Regular (×25): fraco −875, médio −125. Alta (×100): fraco −3.700, médio −1.050.
Leitura: o Iniciante é sustentável de graça (a recarga diária cobre ~2 buy-ins de um jogador fraco) e premia quem joga bem; Regular e Alta são onde as fichas realmente acabam e a compra faz sentido.

## 4. Pacotes (compra simulada)
Base: pacote pequeno ≈ 100 fichas por R$ 1. Preços em degraus de loja de aplicativos e bônus crescente, pra recompensar quem compra mais.

| Pacote | Preço | Fichas | Fichas por R$ | Bônus | R$ por 1.000 fichas |
|---|---|---|---|---|---|
| Punhado | R$ 4,90 | 500 | 102 | +0% | 9,80 |
| Cofre | R$ 19,90 | 2.400 | 121 | +18% | 8,29 |
| Baú | R$ 49,90 | 6.500 | 130 | +28% | 7,68 |
| Tesouro | R$ 99,90 | 14.000 | 140 | +37% | 7,14 |

O que cada pacote representa: Punhado = 2,5 entradas Iniciante ou meia Regular; Cofre = 2 entradas Regular; Baú = 6 entradas Regular ou 1,5 Alta; Tesouro = 3,5 entradas Alta.
Custo de jogar (com o Punhado): jogador médio no Regular ≈ R$ 1,2 por buy-in; fraco ≈ R$ 8,6; no Iniciante quase de graça.

## 5. Como a casa ganha
1. **Taxa de 3%** em cada pote disputado (~0,1 blind por rodada por jogador, ~7 blinds por buy-in).
2. **Bots como banca**: o que os humanos perdem para os bots some da economia; o que ganham vem de fichas criadas (só vale nos limites acima, por isso o Iniciante é o único em que o jogador forte lucra).
3. **Compras**: quem consome fichas nas mesas altas compra pacotes.
Ralos sem dinheiro: cosméticos e outros itens podem ser comprados com fichas no futuro.
Controle de inflação: a economia é fechada (soma zero menos a taxa); as únicas fontes de fichas novas são o saldo inicial, a recarga diária, as compras e o lucro de jogadores fortes no Iniciante.

## 6. Alavancas para ajustar depois de jogar
- Taxa (2 a 5%) e teto (1 a 2 blinds).
- Recarga diária (200 a 500) e o limite mínimo.
- Dificuldade dos bots por mesa.
- Stack padrão (30 a 60 blinds).
- Preços e bônus dos pacotes.

## 7. Aviso
Fichas compradas com dinheiro real que não podem ser sacadas caem no modelo de "jogo social" (cassino social) e algumas regiões têm regras próprias (classificação etária, loot boxes, tributos). Antes de cobrar de verdade, vale validar com a loja (Apple/Google) e com jurídico.


## 8. Ajuste de ritmo (blinds ×2)
Ganhar fichas era lento demais (~+90 em 15 min). Mudanças:
- Blinds das mesas dobraram: Iniciante 10, Regular 50, Alta 200 (stack de 40 blinds: 400, 2.000 e 8.000).
- Saldo inicial 1.500 (3 entradas Iniciante); recarga diária abaixo de 400, de 500 fichas.
- Pacotes ×1,5 (750, 3.600, 9.750, 21.000) mantendo os mesmos preços.

## 9. Blitz pensado para PvP: entrada maior, cobrir e rakeback
O Blitz é desenhado pra jogadores reais entre si (os bots hoje só preenchem o lugar do servidor
multiplayer, que ainda não existe). Nesse desenho a casa nunca cria ficha — só cobra taxa — e o
primeiro "prêmio da casa" (pago do nada a cada acerto exato) virou **rakeback**:
- Entrada por nível: de 2 para **4 blinds (10% da stack)**, pra o pote girar mais rápido.
- Dobrar ganhou um 2º nível (**triplicar**, da 6ª rodada) e a **cobertura**: quando alguém dobra ou
  triplica, os rivais podem cobrir (pagar o mesmo, igualar o peso) ou deixar. É dinheiro que sai
  dos próprios jogadores, não da casa.
- Taxa do Blitz: **4%** do pote pago, teto de 2 blinds.
- O prêmio de sequência (3 acertos exatos seguidos) só paga com a taxa que a casa já cobrou daquele
  jogador, no máximo metade dela: é rakeback, não fichas do nada, e a casa nunca fica no prejuízo
  por causa dele. Detalhes e a simulação completa em `docs/BLITZ.md`.
