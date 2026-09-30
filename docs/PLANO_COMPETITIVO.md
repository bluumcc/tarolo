# Plano: o jogo do Blitz atender bem aos critérios competitivos

Foco só nas **regras do jogo**. Ranking, vitrine, tops, compartilhar, tutorial e UI ficam pra
depois (fim do documento). Cada mudança tem que passar na simulação antes de entrar
(`tests/blitz_skill_sim.gd`): vantagem de habilidade não pode cair e a mesa espelho tem que ficar ≈ 0.

## Onde estamos (nota 1–5, avaliação nossa)
| Critério | Hoje | Meta | Como |
|---|---|---|---|
| Teto de habilidade | 3 | 4 | 1, 2 |
| Peso da sorte (menor = melhor) | 3 | 4 | 2, 4 |
| Informação escondida / blefe | 1 | 4 | 1 |
| Decisão em cada turno | 4 | 4 | (manter) |
| Fácil de aprender | 3 | 4 | 3 |
| Sessão curta e viciante | 4 | 4 | (manter) |
| Integridade PvP (regras) | 2 | 3 | 1, 4 |

## Mudanças de regra (ordem de prioridade)

### 1. Palpite oculto até o fim do nível (showdown)
Hoje todos veem o palpite de todos (não há o que esconder nem ler). Novo: cada um vê só o próprio
palpite; os rivais mostram apenas quantas rodadas já ganharam. No fim do nível, todos revelam
(o "showdown"). **Dobrar = aumentar a aposta, cobrir = pagar pra ver, deixar = desistir do peso**:
o mesmo raciocínio do poker (o rival dobrou: ele acha que acerta?). Blefe = dobrar sem estar
seguro. Leitura = deduzir o palpite de quem joga de um jeito estranho. Também fica MAIS simples de
aprender: menos coisa na mesa pra acompanhar. Custo de implementação: pequeno (a engine já guarda
os palpites; só muda o que é mostrado) + bots deixam de ler o palpite dos outros (passam a
estimar pelo placar).

### 2. Troca de 1 carta antes do palpite
Cada jogador recebe 1 carta aberta do monte e pode trocá-la por qualquer carta da própria mão
(ou recusar). É uma decisão barata, clara e que dá controle sobre a sorte da mão (sobe o teto de
habilidade e reduz o peso da sorte). Custo: ~5 s por nível.

### 3. Enxugar regras que não pagam o preço
- **Sem triplicar**: só dobrar (1 vez por nível). A 3ª camada de aposta quase não muda decisões e
  ocupa espaço de regra.
- **Peso do palpite** (×1 / ×1,5 / ×2): manter só se a simulação mostrar que ele equilibra a
  dificuldade dos palpites; se não, dividir o pote igualmente entre quem acertou.
- **Modificadores**: o conjunto (9) é sempre o mesmo, só a ordem das 8 rodadas muda — o jogador
  aprende a lista uma vez e planeja em cima dela.

### 4. Teto de prêmio por rodada
As fichas das cartas (e Saque/Assalto/Maldita) têm teto por rodada (ex.: 2 blinds). Duas razões:
diminuem o peso da sorte de uma rodada rica e limitam "passar fichas de propósito" entre dois
jogadores combinados (dump), hoje possível jogando carta cara na rodada de um parceiro.

## Como validar cada mudança
| Mudança | Simulação | Passa se |
|---|---|---|
| 1 | bots com estimativa de palpite alheio pelo placar vs bots que ignoram | quem estima ganha ≥ quem ignora; espelho ≈ 0 |
| 2 | bot que usa a troca vs bot que recusa | troca dá ≥ +0,3 blind/nível e reduz a variância |
| 3 | com e sem triplicar; com e sem peso | vantagem de habilidade não cai |
| 4 | teto 1, 2, 3 blinds | vantagem de habilidade ≥ 80% da atual e dump rende menos que hoje |

## Depois (não agora)
Ranking por habilidade (lucro/nível), tops, jogadores, vitrine, compartilhar momentos, Mão do
Dia, tutorial guiado, registro de mão (`hand_log`), detecção de fraude, matchmaking, duelo 1v1.
