# Plano: Blitz competitivo sem complicar o jogo

Regra do plano: **nada de regra nova pesada**. Cada item é pequeno, tem critério de sucesso
medível e mexe no máximo em uma coisa do jogo. Ordem = retorno / esforço.

Base atual (simulação, bot×bot): o jogador que joga os pontos ganha ≈ +1 blind/nível sobre quem só
palpita; mesa espelho ≈ 0 (justa). Ver `docs/BLITZ.md`.

## Fase 1 — pequeno, não muda a regra (fazer primeiro)

| # | Ação concreta | Critério que melhora | Sucesso mede-se por |
|---|---|---|---|
| 1 | **Registro de mão** (`hand_log`): a cada nível guardar seed, palpites, cartas jogadas na ordem, fluxo de fichas. Base de replay, telemetria e detecção de fraude | Integridade PvP, habilidade | nível reproduzível 100% a partir do log |
| 2 | **Índice de habilidade** no perfil e no resumo da sessão: *lucro por nível (em blinds)*, *% de acerto do palpite* e *acerto acima da média* (média da mesa ≈ 30%). Ranking usa lucro/nível dos últimos 100 níveis (mínimo 30 jogados), não fichas totais | Habilidade, retorno | jogador bom aparece no topo de forma estável |
| 3 | **Compartilhar momento épico**: ao acertar triplicada, ganhar jackpot acumulado ou fechar 3 acertos seguidos, botão "Compartilhar" (Web Share com texto + link do jogo). Sem imagem por enquanto | Viral | % de sessões com clique em compartilhar |
| 4 | **Tutorial do 1º nível do Blitz** guiado: palpite sugerido (★) já existe; acrescentar 3 dicas contextuais (palpite, "já no alvo? fuja", quando dobrar) só no 1º nível | Aprendizado | % que termina o 1º nível sem sair |

## Fase 2 — uma mudança de regra pequena + um modo novo simples

| # | Ação concreta | Critério | Notas |
|---|---|---|---|
| 5 | **Mão do Dia**: todo mundo joga a mesma seed (data) contra os mesmos bots, 1 tentativa/dia, 8 níveis. Placar = fichas líquidas. Deterministico → habilidade pura, ranking do dia, compartilhável (estilo Wordle) | Viral, habilidade, retenção | usa o motor atual; ranking local até haver servidor |
| 6 | **Palpite oculto até a 3ª rodada**: cada um vê só o próprio palpite; os dos rivais viram "?" e são revelados antes da 3ª rodada. Dobrar já só existe a partir da 4ª, então continua depois da revelação. Abre espaço pra blefe (jogar as duas primeiras rodadas "disfarçando") e leitura do adversário | Informação escondida | 1 constante (`BLITZ_REVEAL_AT = 2`) + pílulas com "?" na UI. Bots ignoram palpites alheios até revelar. **Só entra se a simulação mostrar vantagem de habilidade ≥ a atual** |

## Fase 3 — antes de abrir pra jogadores reais (infra, quase não mexe no jogo)

| # | Ação concreta | Critério |
|---|---|---|
| 7 | **Sem chat e com assentos anônimos** (só apelido). Reduz combinar jogadas por fora | Integridade |
| 8 | **Matchmaking aleatório por faixa**, nunca as mesmas 3 pessoas em sequência (máx. 2 níveis seguidos com a mesma mesa completa) | Integridade |
| 9 | **Detecção de fraude sobre o `hand_log`**: fluxo líquido entre um par de contas acima de X blinds em Y níveis; jogar carta cara em rodada que o mesmo rival vence quando havia opção barata (repetido); palpite deliberadamente errado recorrente. Alerta → revisão manual | Integridade |
| 10 | **Limites por conta nova**: só mesas de entrada baixa até N níveis jogados | Integridade, economia |
| 11 | **Duelo rápido 1v1** (mesma regra, 2 jogadores, pote de 2 entradas, 4 rodadas): sessões de 2 min, mais viral | Viral, sessão curta |

## O que NÃO vamos fazer agora
Cosméticos, torneios, chat, novos modificadores, novos tipos de aposta.

## Como validar (dados, não achismo)
- Simulação antes de cada mudança de regra (`tests/blitz_skill_sim.gd`): nenhuma mudança pode
  reduzir a vantagem de habilidade do bot bom nem deixar o espelho longe de zero.
- Em produção (com o `hand_log`): o top 10% deve manter lucro/nível positivo estável; se todos
  convergem pra zero, a habilidade não está aparecendo e ajustamos o fator de pontos
  (`ChaosEngine.BLITZ_POINT_FACTOR`) ou a regra.
