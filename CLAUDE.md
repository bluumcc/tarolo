# Tarolo — guia para Claude Code

## Princípios do produto
- **O Vanilla é sempre o modo mais fiel ao Jeu de Tarot lúdico (Tarot francês).** Regras oficiais (seguir naipe, cortar com Trunfo, obrigação de cobrir com Trunfo maior, Bouts, licitação, contratos) não devem ser alteradas pra "melhorar o jogo". Variações de regra pertencem ao Caos (ou a modos novos), nunca ao Vanilla.
- Ranqueado usa as regras do Vanilla.
- O Caos é o modo dinâmico/experimental: poker de rodadas (blind, stack, apostas), modificadores e combos. Ver `docs/MESA_CAOS.md`.

## Vocabulário
Partida → Nível → Rodada → Vez (uma "rodada" tem 4 cartas; um "nível" tem 8 rodadas no Caos).

## Fluxo
- Godot 4.3, UI em código. Testes: `godot --headless --path . -s res://tests/test_runner.gd` e `res://tests/Smoke.tscn`.
- Web export em `docs/play` (`godot --headless --path . --export-release "Web" docs/play/index.html`) e push direto no `main`.
- Modos de mesa: **Caos** (aposta por rodada, `docs/MESA_CAOS.md`) e **Blitz** (palpite de vitórias por nível, `docs/BLITZ.md`); mesma cena/motor, flag `engine.blitz`.
- **Nunca tirar screenshot "pra conferir visualmente" por conta própria — gasta muito token.** Só capturar tela quando o usuário pedir explicitamente, ou quando for indispensável pra diagnosticar um bug visual relatado (e mesmo assim, o mínimo de capturas possível, apagando os arquivos temporários depois). Testes automatizados (`test_runner.gd`, `Smoke.tscn`) são a forma padrão de verificar qualquer mudança.
