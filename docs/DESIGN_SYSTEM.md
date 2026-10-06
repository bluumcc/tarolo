# Design system do Tarolo

Tudo vem de `scripts/ui/ds.gd` (tokens) + `scripts/ui/ui_kit.gd` (componentes). Nenhuma tela inventa tamanho, margem, raio ou estilo de botão.

## Tipografia
Uma só família: **Lilita One** (a do título TAROLO), com a DejaVu Sans de reserva pros símbolos (◎ ★ ♛).

| Degrau | px | Uso |
|---|---|---|
| `FS_DISPLAY` | 48 | título de tela cheia |
| `FS_H1` | 40 | título de modal / etapa (descarte, palpite) |
| `FS_H2` | 32 | subtítulo, título de seção |
| `FS_TITLE` | 28 | título de card, valores |
| `FS_BODY` | 24 | texto corrido, botões |
| `FS_LABEL` | 20 | legendas, rótulos de card |
| `FS_CAPTION` | 18 | mínimo absoluto |

`UIKit.serif_label` encaixa qualquer tamanho no degrau mais próximo (`UIKit.snap_font`).

## Espaçamento (grade de 4)
`SP_XS` 4 · `SP_S` 8 (dentro de um grupo: título↔subtítulo, linhas) · `SP_M` 12 · `SP_L` 16 (entre grupos) · `SP_XL` 24 (margem de tela) · `SP_XXL` 32.
Padding interno de card: `UIKit.card_pad()` = 12 no celular, 22 no desktop.

## Componentes
- **Superfície** (`UIKit.box` / `UIKit.panel`): fundo escuro `DS.surface()`, borda clara translúcida, brilho suave. Os fundos roxos "antigos" são convertidos nela automaticamente.
- **Botão** (`UIKit.button`, `UIKit.action_button`): fundo = tom escuro da cor da função, borda e texto = tom claro da mesma cor (`DS.tone`). Cinza/`MUTED` = secundário. Tema global (`build_theme`) usa o mesmo estilo.
- **Cartão de número** (`StatCard`): POTE, PRÊMIO.
- **Títulos** (`DS.heading`): título + subtítulo com o respiro padrão.
- Raios: `R_CARD` 16, `R_BUTTON` 14, `R_MODAL` 22.

## Desktop (tela larga)
Coluna direita fixa (420 px): Registro, Modificador, Prêmio, Pote, ações. Cenas e modais ficam centrados na área da esquerda; a coluna escurece junto.

## Regra de ouro
Precisa de um estilo novo? Primeiro veja se `DS`/`UIKit` já tem. Se não tiver, adicione lá — nunca na tela.
