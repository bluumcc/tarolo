# Plano: Blitz competitivo — singleplayer contra bots

Escopo: **só o jogo, só contra bots.** Fora do escopo (fica pra depois): PvP, integridade/anti-fraude,
ranking, tops, vitrine, compartilhar, tutorial/UI. Este documento tem três partes: (1) o que
medimos, (2) o plano em fases, (3) a **reavaliação** do plano anterior e o que foi corrigido.

Regra de ouro: nenhuma mudança de regra entra sem passar pela simulação, e toda mudança nasce
atrás de uma chave (flag) pra poder ser desligada.

---------------------------------------------------------------------------------------------

## 1. Diagnóstico (medido, não chutado)

Scripts: `tests/blitz_skill_sim.gd` (vantagem de habilidade), `tests/blitz_diag_sim.gd`
(estratégias degeneradas, uso de dobrar/cobrir, ruído). Bot×bot, sem taxa, ~60 sessões × 30 níveis.

| # | Fato medido | Leitura |
|---|---|---|
| F1 | Espelho (4 bots iguais) ≈ 0 (−0,06 ± 0,13 blind/nível) | a mesa é justa, nenhum assento tem vantagem |
| F2 | Bot que joga os pontos das cartas ganha ≈ +1,0 blind/nível do bot antigo; sem pontos (fator 0) ≈ +0,7 | a maior parte da habilidade está em **conduzir as vazas**, os pontos somam ≈ +0,3–0,4 |
| F3 | Nenhuma estratégia degenerada é positiva: palpite fixo 0 → −1,41; 1 → −0,43; 2 → −0,65; 3 → −0,66; 4 → −1,76; 5+ → −2,2 a −3,5 | não existe "truque" de palpite; o valor de **ler a mão** (vs. palpite fixo bom) é só ≈ 0,4–0,6 blind/nível |
| F4 | Desvio por nível ≈ 6,4–7,0 blinds (entrada = 4). Pra distinguir com 2σ uma vantagem de 1 blind/nível: **~150–180 níveis** | a sorte por nível é grande; no poker costuma ser pior (milhares de mãos), então é aceitável, mas o jogador nunca "sente" habilidade só pelo resultado |
| F5 | Dobrar: usado em 36% dos níveis-jogador, acerta 71% (base ≈ 30%). Triplicar: 19%, acerta **88%**. Cobrir: acerta 72% | triplicar é quase automático (no alvo + mão fraca): decisão de baixa qualidade que só ocupa regra |
| F6 | Os bots hoje **não usam o palpite dos outros** pra nada (só o próprio) | esconder os palpites hoje só prejudicaria o humano; o palpite alheio só vira decisão se os bots tiverem estilos que o revelem |
| F7 | Pote proporcional à proximidade (exato 1,0 / ±1 0,35 / ±2 0,1): desvio/nível 7,0 → 3,9 (−44%), mas a vantagem cai 1,05 → 0,65 (−38%); níveis pra 2σ: 177 → 147 | **rejeitado**: quase não melhora o sinal e tira a clareza "acertou = leva o pote" e o jackpot |

Consequências pra design (SP vs bots):
- A "habilidade" do humano é o quanto ele passa do bot. **A régua é o bot.** Se o Difícil for fraco, o
  teto é baixo; se for perfeito, o jogo é injusto. Precisamos de uma escada de bots calibrada.
- Bots previsíveis viram farm de fichas (o jogador aprende o padrão e nunca compra fichas).
  Precisa de estilos + aleatoriedade controlada + economia calibrada.

---------------------------------------------------------------------------------------------

## 2. Plano em fases

Cada fase: regra exata → motor → bots → testes → simulação → critério de aceite → risco/reversão.

### Fase 0 — Régua e instrumentos (antes de mexer em regra)
- **Bot Oráculo** (teto): joga com amostragem (Monte Carlo) das mãos ocultas dos rivais pra escolher
  palpite e carta. Serve só de régua: quanto o melhor jogador possível ganha do Difícil.
- **Curva de EV por palpite** (quanto rende cada palpite dado o quão "esperado" ele era) → decide se
  os pesos ×1 / ×1,5 / ×2 equilibram a dificuldade.
- **Painel de gate** `tests/blitz_gate.gd`: roda o conjunto de simulações e falha se sair dos
  limites (espelho |x| < 0,25; vantagem do bom ≥ 0,6; sem estratégia degenerada positiva).
- Aceite: Oráculo > Difícil por margem conhecida (esperado +0,5 a +1,5 blind/nível). Se for ≈ 0,
  o Difícil já é quase o teto e o problema é de regra, não de bot.

### Fase 1 — Bots com estilo e escada de dificuldade (base de tudo)
- 3 **estilos** por bot (persistem enquanto ele estiver na mesa; o jogador aprende quem é quem):
  *Cauteloso* (só dobra com quase certeza, palpite conservador), *Agressivo* (dobra e cobre mais,
  às vezes dobra sem estar no alvo = **blefe**), *Calculista* (equilibrado, joga pelos pontos).
- 3 **dificuldades** (Fácil / Normal / Difícil) ortogonais ao estilo; ruído de palpite e de carta
  calibrado; o Difícil nunca é o Oráculo.
- Aleatoriedade controlada: nenhuma decisão de bot 100% determinística (evita farm).
- Aceite (simulação): espelho por estilo ≈ 0; Difícil > Normal > Fácil com margens ≥ 0,4 blind/nível
  entre degraus; nenhum estilo domina os outros dois (cada um perde de pelo menos um).
- Risco: bots "agressivos" quebram a economia (pagam demais). Gate: fluxo de fichas por bot.

### Fase 2 — Enxugar regras (aprendizado + qualidade de decisão)
- **Sem triplicar** (F5: decisão quase automática). Só dobrar, 1× por nível (chave `max_doubles`).
- **Pesos do palpite**: manter, ajustar ou remover conforme a curva de EV da Fase 0.
- **Camadas de regra** pra quem está começando (SP): níveis 1–3 sem dobrar/cobrir/modificadores;
  dobrar entra no nível 4; modificadores no nível 6. Vale por conta (contador de níveis).
- Aceite: vantagem de habilidade não cai > 15%; % de sessões que passam do nível 5 sobe (medido
  depois, com telemetria) — aqui só validamos a vantagem por simulação.

### Fase 3 — Informação escondida (palpite oculto + showdown)
- Cada jogador vê só o próprio palpite; os rivais mostram só as rodadas já ganhas. Revelação no
  fim do nível. **Dobrar = aumentar (raise), cobrir = pagar pra ver (call), deixar = desistir do
  peso (fold).** Blefe = dobrar sem estar seguro; leitura = deduzir o alvo do rival pelo placar,
  pelo estilo e pelo momento em que dobrou.
- Bots: passam a **inferir** o alvo dos rivais (P(alvo | rodadas ganhas, rodadas que faltam,
  estilo)) e a usar isso ao cobrir/sabotar; bots Agressivos blefam.
- Dependência: **só entra com a Fase 1** (sem estilos e tells não há o que ler: seria só um
  handicap pro humano — F6).
- Aceite: bot que infere ≥ bot que ignora por ≥ +0,15 blind/nível; espelho ≈ 0; humano-proxy
  (Oráculo com informação parcial) > Difícil.
- Risco: excesso de incerteza deixa o jogo "cego". Reversão: chave `reveal_at` (revela na rodada N,
  0 = sempre visível, como hoje).

### Fase 4 — Troca de 1 carta
- Antes do palpite, cada jogador recebe 1 carta aberta do monte e pode trocá-la por uma da mão ou
  recusar. Bots decidem por poder da carta vs. a pior da mão.
- Aceite: bot que troca bem ≥ +0,3 blind/nível sobre o que recusa; a média de níveis com palpite
  exato não cai; sessão ≤ +8 s por nível.
- Risco: aumenta a força média das mãos (e portanto os acertos) → recalibrar bots.

### Fase 5 — Economia contra bots (fecha o ciclo)
- Problema: quem joga bem ganha dos bots e nunca compra fichas (fichas dos bots são "criadas").
  Medida: simular jornadas de 500 níveis com perfis novato / médio / forte / oráculo.
- Ajustes possíveis (nessa ordem): força dos bots por mesa (mesa cara = bots mais difíceis), taxa
  (rake) por mesa, valor do buy-in dos bots, teto de ganho por sessão.
- Meta: novato quebra em ≈ N níveis (compra ou recarga diária), médio perde ≈ 0,2–0,4 blind/nível
  (rake), forte ≈ 0 a +0,3, oráculo ≈ +0,7 no topo. Ninguém "farma" indefinidamente.
- Aceite: as trajetórias simuladas batem essas metas.

### Fase 6 — Fechamento
- Atualizar ajuda/texto (`help_content.gd`), `docs/BLITZ.md`, `docs/ECONOMIA.md`; congelar as
  chaves nos valores finais; rodar `blitz_gate.gd` e a suíte completa.

---------------------------------------------------------------------------------------------

## 3. Reavaliação do plano anterior e correções

Plano anterior (versão "regras do jogo"): 1) palpite oculto, 2) troca de carta, 3) enxugar regras,
4) teto de prêmio por rodada. O que a medição mostrou:

| Item anterior | Veredito | Correção |
|---|---|---|
| Palpite oculto sozinho | **Errado como estava.** Os bots não usam o palpite alheio (F6): só prejudicaria o humano | Depende de bots com estilo e inferência; vira **Fase 3**, depois da Fase 1 |
| Teto de prêmio por rodada (anti-dump) | **Removido.** Dump é problema de PvP; no SP só reduziria a vantagem que vem dos pontos (F2) | fora do plano |
| Trocar carta pra reduzir a sorte | **Hipótese não provada.** A sorte por nível (F4) é dominada pelo pote; troca de carta muda a mão, não o pote | Mantida como **Fase 4**, avaliada por vantagem de habilidade, não por "menos sorte" |
| "Sorte 3 → 4" como meta | **Meta mal posta.** Poker costuma precisar de milhares de mãos; ~150 níveis pra sentir habilidade é aceitável. Reduzir variância pelo pote custa vantagem (F7) | Nota de sorte mantida; o foco passa a ser **qualidade de decisão** |
| Sem triplicar | **Confirmado pelos dados** (F5: 88%, quase automático) | Fase 2 |
| Nota de "integridade PvP" | **Fora do escopo** (SP) | removida da tabela |
| (faltava) escada de bots | **Lacuna grave**: a habilidade do humano só existe em relação aos bots | Fase 0 (Oráculo) + Fase 1 |
| (faltava) economia vs bots | **Lacuna grave**: farm de fichas | Fase 5 |
| (faltava) aprendizado | Regras demais pro "arcade viral" | camadas de regra, Fase 2 |

### Pontos que ainda são incertos (e como resolver)
1. **Quanto vale o teto real?** Depende do Oráculo (Fase 0). Se Oráculo ≈ Difícil, o gargalo é a regra.
2. **Palpite oculto pode não melhorar nada** se os bots não tiverem bons tells. Só vale com a Fase 1.
3. **Simulação usa bots como humano**: comportamento real difere. Mitigação: só decidir por regra
   com margem ≥ 0,3 blind/nível (acima do ruído) e manter chaves pra reverter.
4. **Retenção** (viciante) não se mede em simulação. Depende de telemetria com jogadores reais
   (depois).

### Fora do escopo agora
PvP, matchmaking, anti-fraude, `hand_log` de produção, ranking/tops/vitrine, compartilhar, Mão do Dia,
tutorial guiado, cosméticos, torneios, novos modificadores.


## Status (atualizado)
- **Fase 0 (Oráculo/régua):** feito. `chaos_oracle.gd`, `tests/blitz_arena.gd`. Oráculo bate
  Difícil por +0,66 blind/nível — confirma que existe teto de habilidade acima do bot atual.
- **Fase 1 (estilos):** feito. 3 estilos (Calculista/Cauteloso/Agressivo, `ChaosBot.Style`),
  calibrados até nenhum ficar dominado (`tests/blitz_gate.gd`). Sorteados ao sentar/trocar
  (`refill_bots`), nunca mostrados na tela — só percebidos jogando. Timing de dobrar/cobrir varia
  por estilo (`ChaosBot.style_delay_mult`) — o único "tell" visível, já que o palpite é segredo
  (Fase 3).
- **Fase 2 (enxugar regras):** parcialmente revertida — ver `docs/BLITZ.md`. Tirar o triplicar
  quebrou a escada de dificuldade (Difícil passou a perder de Normal); mantido como estava.
  Pesos do palpite (×1/×1,5/×2) revalidados com o código atual (pontos + estilos): nenhum
  palpite fixo é lucrativo, sem mudança necessária (`tests/blitz_diag_sim.gd`). Camadas de regra
  pros primeiros níveis: feito (ver "Onboarding" abaixo).
- **Fase 3 (palpite oculto):** feito. Rivais em segredo até o showdown; sem mudança nos bots
  (eles já não liam o palpite alheio).
- **Fase 4 (troca de 1 carta):** feito. `engine.swap_cards`/`can_swap`/`apply_swap`/
  `decline_swap`; bot em `ChaosBot.wants_swap`; UI em `_human_swap_choice()`.
- **Onboarding (camadas de regra):** feito, fora do plano original de 6 fases, junto da Fase 2.
  `ChaosEngine.onboarding_levels` (config, contado por `GameState.ONBOARDING_LEVELS = 3`, salvo
  em `profile.blitz_levels`): as primeiras mesas de Blitz de uma conta nova não sorteiam
  modificador nem liberam dobrar/cobrir/carta aberta — só o palpite puro.
- **Fase 5 (economia vs bots):** medida, não calibrada. `tests/blitz_economy_check.gd`: um
  jogador nível Oráculo, mesmo com a taxa da casa ligada (4%), ainda lucra em média — mas pouco
  (+0,39 blind/nível, 6 sessões de 10 níveis, bem ruidoso: de −2,2 a +1,75 por sessão; o Oráculo
  é lento demais pra medir com precisão numa sessão). Não é o "farm infinito" que eu temi antes de
  medir direito: um erro meu de rótulo no primeiro teste tinha inflado o número em ~10×.
  Calibração fina (ajustar taxa/dificuldade por mesa) fica pra quando houver amostra maior ou
  telemetria real — mexer sem medir bem de novo é o mesmo erro do triplicar.
