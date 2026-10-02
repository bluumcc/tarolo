# Tarolo — guia para Claude Code

## Princípios do produto
- **O Vanilla é sempre o modo mais fiel ao Jeu de Tarot lúdico (Tarot francês).** Regras oficiais (seguir naipe, cortar com Trunfo, obrigação de cobrir com Trunfo maior, Bouts, licitação, contratos) não devem ser alteradas pra "melhorar o jogo". Variações de regra pertencem ao Caos (ou a modos novos), nunca ao Vanilla.
- O Caos é o modo dinâmico/experimental: poker de rodadas (blind, stack, apostas), modificadores e combos. Ver `docs/MESA_CAOS.md`.
- **Ranqueado é o Blitz, fila única** (não o Vanilla): toda mesa real de Blitz vale fichas E LP/MMR ao mesmo tempo, sem distinção casual/ranqueada. Vanilla é 100% recreativo, nunca mexe em elo. Ver `docs/BLITZ.md`.

## Vocabulário
Partida → Nível → Rodada → Vez (uma "rodada" tem 4 cartas; um "nível" tem 8 rodadas no Caos).

## Fluxo
- Godot 4.3, UI em código. Testes: `godot --headless --path . -s res://tests/test_runner.gd` e `res://tests/Smoke.tscn`.
- Web export em `docs/play` (`godot --headless --path . --export-release "Web" docs/play/index.html`) e push direto no `main`.
- Modos de mesa: **Caos** (aposta por rodada, `docs/MESA_CAOS.md`) e **Blitz** (palpite de vitórias por nível, `docs/BLITZ.md`); mesma cena/motor, flag `engine.blitz`.

## Testes e economia de tokens
Rodar a bateria inteira pra toda mudança é desperdício — escalonar pelo que mudou:
- **Sempre, antes de considerar algo pronto:** checagem de sintaxe rápida e barata —
  `godot --headless --editor --quit` (ou `--check-only -s <arquivo>` pra um script isolado).
- **Mudou `scripts/core/*` (motor, bots, economia, torneio):** rodar
  `test_runner.gd` e o(s) gate(s) relevante(s) (`tests/blitz_gate.gd`,
  `tests/blitz_betting_gate.gd`) antes de comitar — é exatamente pra isso que eles existem.
- **Mudança estrutural de cena/UI** (fluxo novo, nó novo, reorganização de containers):
  rodar `Smoke.tscn` uma vez, não repetidamente "por garantia".
- **Mudança cosmética pura** (cor, texto, espaçamento, posição, nome de card): só a
  checagem de sintaxe. Não rodar `test_runner`/`Smoke`/export de novo pra cada ajuste
  pequeno — esses testes não exercitam nada que uma cor ou um texto possa quebrar.
- **Export Web + commit/push:** uma vez por entrega (não a cada iteração).
- **Nunca tirar screenshot "pra conferir visualmente" por conta própria — gasta muito
  token.** Só capturar tela quando o usuário pedir explicitamente, ou quando for
  indispensável pra diagnosticar um bug visual relatado — e mesmo assim, o mínimo de
  capturas possível, apagando os arquivos temporários depois.
