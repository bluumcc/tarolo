# Tarolo — guia para Claude Code

## Paleta de cores

Arquivo de referência: `docs/PALETA.md`. Tokens em `scripts/ui/ui_kit.gd` (`UIKit.TR_*`).

| Cor | Token | Hex |
|---|---|---|
| branco | `TR_WHITE` | `#e8e7e6` |
| dourado | `TR_GOLD` | `#d8c7aa` |
| vermelho-claro | `TR_RED_LIGHT` | `#ffd4e0` |
| vermelho-normal | `TR_RED` | `#f61b54` |
| vermelho-escuro | `TR_RED_DARK` | `#5d1440` |
| roxo-claro | `TR_PURPLE_LIGHT` | `#4f346a` |
| roxo-normal | `TR_PURPLE` | `#191430` |
| roxo-escuro | `TR_PURPLE_DARK` | `#140c33` |

**Regra:** nunca hex inline nas telas — sempre `UIKit.TR_*`. Variações via `.lightened()` / `.darkened()`.

## Padrão de borda com glow (`rim_box`)

Helper: `UIKit.rim_box(bg, rim_col, glow_col, size)` — borda na cor **clara** + shadow feathered na cor **normal**.

- `size = "large"`: botões de destaque (glow_size 30, alpha 0.42)
- `size = "small"`: cards/botões secundários (glow_size 14, alpha 0.35)

Aplicação das cores: vermelho → `rim_box(TR_RED_DARK, TR_RED_LIGHT, TR_RED)`. Roxo → `box(bg, TR_PURPLE_LIGHT)` (sem glow). Godot não suporta blur em borda — o efeito vem do contraste da cor clara + shadow esparsa na cor normal. Ver `docs/PALETA.md` para detalhes.

## Tamanho das cartas (regra para não repetir o erro)
- Arte das cartas: PNG 540×900 (proporção `CardView.ART_ASPECT` = 0,6). `CardView.SIZE` **sempre deriva dela**: 188×313 (único tamanho; o seletor Compacta/Grande foi removido).
- `TextureRect` da arte: **nunca `EXPAND_KEEP_SIZE`** (o PNG inflaria a carta 3×). Usar `EXPAND_IGNORE_SIZE`.
- **Nunca compensar tamanho com escala "no olho".** Tamanhos por plataforma vêm de `CardView.hand_scale()` (celular 1,0; carta arrastada ×1,75), `focus_scale()` e `table_scale()`; a zona da mão vem de `HandLayout.fan_height()`.
- Escala de Control: pivô = `size/2` e posição = `centro - size/2` (tamanho sem escala). Ver `HandLayout._place`.
- Gate: `godot --headless --path . res://tests/card_layout_gate.tscn` (corpo = SIZE, leque inteiro e centralizado, em celular e PC).

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
