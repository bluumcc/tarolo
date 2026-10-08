# Plano: apostas centrais + combos + HUD + animações (modo Caos)

Vocabulário: **Partida → Nível → Rodada → Vez** (Caos: 5 níveis de 8 rodadas).

## 1. Princípios
1. **Uma decisão grande por nível** (o palpite) e **uma decisão pequena durante** (dobrar). Nada além disso.
2. **Tudo que vale fichas aparece na tela**: quem apostou quanto, quanto está no pote, quanto falta para acertar.
3. **Todo ganho tem camadas**: número que rola + som + tremor proporcional + partículas.
4. Apostas e combos **conversam**: combo feito durante o nível aumenta o prêmio de quem acertou o palpite.
5. Só fichas (nunca pontos da partida) para não confundir a classificação.

## 2. Regras

### 2.1 Palpite exato
Antes de cada nível (mão e regra já à vista) o jogador escolhe:
- **Rodadas que vai ganhar:** 0 a 8.
- **Aposta:** ◎10 · ◎25 · ◎50 · TUDO (limitada ao saldo). Pode "NÃO APOSTAR" (fica de fora do pote).

Todos os palpites são revelados juntos (showdown).

### 2.2 Pote
- Pote do nível = soma de todas as apostas + **pote acumulado** dos níveis anteriores.
- No fim do nível cada jogador cai em uma faixa:
  - **Acertou o número exato** → divide o pote. Peso = `aposta × dificuldade`, com dificuldade 1,0 (0–2 rodadas), 1,5 (3–4) e 2,0 (5+ rodadas). Se fez o combo do nível, peso ×(1 + 0,25 por combo, máx. ×2).
  - **Errou por 1** → recebe metade da aposta de volta; a outra metade fica no pote.
  - **Errou por 2 ou mais** → perde a aposta (vai para o pote).
- **Ninguém acertou** → o pote inteiro **acumula** para o próximo nível ("JACKPOT ACUMULADO"). No último nível o pote acumulado é pago aos que mais chegaram perto.
- Bots apostam de uma banca virtual (não mexe no saldo do jogador); só a parte do jogador altera as fichas do perfil.

### 2.3 Dobrar
A partir da rodada 4, uma vez por nível, botão **DOBRAR ×2** no rodapé (ao lado do poder): a aposta entra no pote de novo (dobra) e o peso dobra. Só disponível se ainda dá para acertar o palpite e há saldo.
Bots dobram quando estão a 1 rodada do alvo com mão forte.

### 2.4 Combos (enxutos: 3 de sequência + 3 de mesa)
Já existem e ficam: **Mão Quente** (3 vitórias seguidas, ×1,5), **Cortado** (quebrou sequência, +2), **Corte de Rei** (+3).
Novos, todos lidos direto na mesa, sem regra escondida:

| Combo | Como faz | Efeito |
|---|---|---|
| **Realeza** | 3 ou mais figuras (Valete, Cavaleiro, Dama, Rei) na mesa | ×1,5 para quem leva |
<!-- Naipe Puro foi trocado por Realeza: 4 cartas do mesmo naipe acontece o tempo todo, então não era um "combo". -->
| **Escada** | 3 ou mais cartas seguidas do mesmo naipe na mesa | +3 pts |
| **Chuva de Trunfos** | 3 ou mais Trunfos na mesma rodada | ×2 para quem leva |

- **Nível de combo** (o medidor de chamas): cada vitória seguida sobe ×1,0 → ×1,25 → ×1,5 → ×2 (limite). Perder a rodada zera. Substitui o "Mão Quente" solto e fica sempre visível.
- Cada combo feito conta como **+1 "combo do nível"** para o bônus do pote (2.2).

## 3. HUD
Retrato (720×1280) e largo usam os mesmos blocos; só muda a posição.

1. **Assentos** (4): avatar + placar + **ficha-aposta** ao lado: `◎25 · 3` e, ao vivo, `1/3` (verde no alvo, âmbar perto, vermelho estourou, dourado quando garantiu).
2. **Medidor de combo** sob cada avatar: até 3 chamas + selo `×1,5` que pulsa quando sobe.
3. **Pote no centro da mesa:** pilha de fichas com o total `◎ 340` e, se houver, "+ acumulado ◎ 120". O pote engorda a cada aposta/dobrar.
4. **Faixa de aviso** (existente): nome do combo, pontos e multiplicador; nunca cobre cartas.
5. **Painel "Apostas"** ao tocar no pote: tabela dos 4 jogadores (palpite, aposta, peso, situação atual) e o quanto você ganharia se acertar hoje ("Vale ◎ 180").
6. **Rodapé:** botões PODER e DOBRAR lado a lado; DOBRAR mostra o custo.

## 4. Animações e som (tudo em `FX`, desligável em "reduzir movimento")
| Momento | Animação | Som |
|---|---|---|
| Apostar | fichas voam do assento ao pote em arco, pilha cresce, contador do pote rola | `chip` por ficha |
| Showdown | fichas-aposta viram (flip) uma a uma, do menor ao maior palpite | `flip` + `tick` |
| Dobrar | pilha do assento pula, contorno de fogo, +ficha voa ao pote, tremor leve | `boost` |
| Rodada resolvida | marcador `1/3` atualiza com pop; âmbar pulsa; estourar = shake vermelho | `tick` / `lose` |
| Combo | faixa entra por cima, número do bônus sobe, explosão de partículas na cor do combo, tremor proporcional ao valor | `combo` (escala com o nível) |
| Fim do nível | resumo em tela cheia: fichas do pote voam **para o(s) vencedor(es)** com contador rolando; quem errou vê as fichas se desfazerem; **jackpot acumulado** vira "JACKPOT!" com chuva de fichas | `win` / `jackpot` |
| Próximo nível | pote acumulado brilha e passa para o nível seguinte | — |

## 5. Bots
- Palpite: soma de valor esperado por carta (Trunfos e Reis) + regra sorteada; aposta por perfil (fácil: baixo, difícil: agressivo).
- Jogo: se está no alvo, **evita ganhar** mais; se falta, **força** rodadas fortes. O `BlitzBot` já sabe evitar rodada; falta ler o alvo.
- Dobrar: 1 rodada do alvo com mão forte.
- Blefe (difícil): 15% de chance de apostar alto sem mão.

## 6. Arquitetura
- `BlitzEngine`: `bets` passa a `{predict, stake, doubled}` por jogador; novos `pot`, `carry`, `combo_count[]`, `combo_level[]`; `set_bet(player, predict, stake)`, `double_bet(player)`, `_settle_pot()`; `trick_result` ganha `combos: []`.
- Novo `BlitzCombos` (lógica pura): detecta Naipe Puro, Escada, Chuva de Trunfos na mesa.
- `BlitzBot`: `choose_bet` → `{predict, stake}`, `maybe_double`, ajuste em `choose` para o alvo.
- UI: `bet_modal.gd` (palpite + aposta), `pot_view.gd` (pilha + contador), `seat_tag.gd` (aposta ao vivo + chamas), `payout_fx.gd` (fichas voando).
- Testes: pote soma certo, acúmulo sem vencedor, divisão por peso, erro por 1, dobrar, cada combo, bots respeitam alvo; partidas completas no Smoke.

## 7. Etapas (cada uma publicada e jogável)
1. **Engine + testes:** palpite exato, pote, acúmulo, dobrar. UI antiga só adaptada.
2. **Modal do palpite** (stepper 0–8 e fichas de aposta) + revelação simultânea.
3. **HUD:** fichas-aposta nos assentos com marcador ao vivo + pote no centro + painel de apostas.
4. **Animações do dinheiro:** apostar, showdown, dobrar, pagamento e jackpot.
5. **Combos:** engine + medidor de chamas + faixa + efeitos + bônus no pote.
6. **Bots:** palpite, dobrar e leitura do alvo.
7. **Polimento e mobile:** tamanhos ≥ 26 px, teste em 720×1280 e 1600×900, ajuste de textos e tutorial (slide 2 novo).

## 8. Decisões que ainda precisam de você
- Pote acumulado com jackpot: aprovado como padrão? (alternativa: quem errou perde para o "banco" e nada acumula).
- Faixas do pote: peso por dificuldade 1,0/1,5/2,0 ok?
- Combos novos: manter os 3 (Naipe Puro, Escada, Chuva de Trunfos) ou cortar para 2?

## 9. Riscos
- Espaço no HUD do celular: seguro com ficha compacta e o painel "Apostas" atrás de um toque.
- Complexidade: mantemos 1 palpite + 1 dobrar; combos só os 3 acima.
- Economia: recarga ilimitada evita frustração, então a aposta pode ser agressiva.
