# Mesa Caos — poker de rodadas

Vocabulário: **Partida → Nível → Rodada → Vez**. Um nível são 8 rodadas (8 cartas por jogador) com um modificador sorteado.

## Mesa (padrão, sem fim)
- Mesas por blind: Iniciante ◎10, Regular ◎25, Alta ◎100. Entrada = 20 blinds (a stack); o resto da carteira fica protegido.
- Sem última rodada: a cada nível as cartas são redistribuídas e outro modificador é sorteado.
- Sair da mesa devolve a stack à carteira. Ficou sem fichas pro blind: recompra ou sai. Bot quebrado é trocado por outro.
- O placar é a stack de fichas. Não há pontos de partida.

## Aposta em cada rodada
1. Todos pagam o blind (ante). O botão (D) gira a cada rodada e fala por último.
2. Na vez: **Passar** (sem aposta aberta), **Aumentar** (mínimo +1 blind, até o all-in; limitado à menor stack em jogo, então não há potes paralelos), **Pagar** ou **Desistir**.
3. Até 2 aumentos por rodada.
4. Só quem ficou joga carta. Quem desistiu descarta a carta mais fraca, virada, e as mãos continuam do mesmo tamanho.
5. Quem vence a rodada leva o pote. Se todos desistem, o último leva sem jogar (blefe vencido).
6. Quem vence abre a próxima rodada de cartas.

## Prêmio da banca
Os pontos das cartas da rodada (com modificadores, sequência e combos) viram fichas pagas pela banca ao vencedor: 1 ponto = ¼ do blind. Saque e Assalto ao Líder tiram fichas dos rivais; Rodada Maldita faz o vencedor pagar à banca.

## Combos
Sequência de vitórias (×1,25 / ×1,5 / ×2), Cortado, Corte de Rei, Chuva de Trunfos, Realeza e Escada, todos lidos na mesa.

## Bots
Estimam a força da mão (Trunfos altos e Reis; invertida no Mundo ao Contrário), comparam com as odds do pote e passam, pagam, aumentam ou desistem. No Difícil blefam (~14%).

## Fora de escopo por enquanto
Torneio com blind crescente e eliminação (base para o Ranqueado), Deixar rolar e Torcida.

## HUD
- Cabeçalho fixo (menu, nível/blind, ajuda) e, logo abaixo, os 4 avatares redondos lado a lado, esticados na largura, na ordem de jogo (você primeiro).
- Sob cada avatar: nome, stack, as fichas apostadas na frente dele e a situação (SUA VEZ / É A VEZ, PRÓXIMO, PASSOU, PAGOU, AUMENTOU, DESISTIU).
- Números nos avatares mostram a ordem de fala (1 = age agora) e depois a ordem de jogada; (D) marca o botão.
- As apostas ficam na frente de cada jogador até a rodada de apostas fechar; aí voam juntas pro pote.
- As cartas na mesa ficam na coluna do avatar de quem jogou.
