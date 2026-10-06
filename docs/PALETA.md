# Paleta de cores — Tarolo

Tokens definidos pelo dono do projeto. Nunca usar hex solto nas telas — sempre importar via `UIKit.TR_*`.

## Cores definidas

| Nome PT | Token GDScript | Hex | Uso |
|---|---|---|---|
| branco | `TR_WHITE` | `#e8e7e6` | Texto principal, face de carta |
| dourado | `TR_GOLD` | `#d8c7aa` | Recompensas, fichas, destaque |
| vermelho-claro | `TR_RED_LIGHT` | `#ffd4e0` | Texto sobre fundo vermelho, estado hover claro |
| vermelho-normal | `TR_RED` | `#f61b54` | Vermelho principal (perigo, naipes vermelhos, RANKEADA) |
| vermelho-escuro | `TR_RED_DARK` | `#5d1440` | Fundo de botão vermelho, sombra |
| roxo-claro | `TR_PURPLE_LIGHT` | `#4f346a` | Superfícies elevadas, botões ativos |
| roxo-normal | `TR_PURPLE` | `#191430` | Superfícies (painéis, modais) |
| roxo-escuro | `TR_PURPLE_DARK` | `#140c33` | Fundo da tela, camada mais profunda |

## Cores complementares (mantidas do sistema anterior)

| Token | Hex | Uso |
|---|---|---|
| `TR_BLACK` | `#080413` | Sombra/contorno, fundo de carta |
| `TR_CYAN` | `#6cbfc5` | Info, seleção, ação secundária |
| `TR_BLUE` | `#236592` | Defesa, elementos de fundo |
| `TR_RED_GLOW` | `#d63060` | Glow difuso do botão vermelho |
| `TR_RED_NEON` | `#ff8099` | Neon quente (borda interna) |

## Regras de uso

- **Um hex por nome** — se precisar de variação, use `.lightened(x)` / `.darkened(x)` em código.
- **Sem hex inline nas telas** — toda cor via `UIKit.TR_*` ou derivada programaticamente.
- **Texto sobre fundo escuro:** `TR_WHITE` ou `TR_GOLD`.
- **Texto sobre vermelho:** `TR_RED_LIGHT` ou `TR_WHITE` com contraste verificado.
- **Botão vermelho:** fundo `TR_RED_DARK`, borda `TR_RED_LIGHT`, glow `TR_RED`.
- **Superfícies:** `TR_PURPLE_DARK` (fundo de tela) → `TR_PURPLE` (painéis) → `TR_PURPLE_LIGHT` (cards elevados).

## Padrão de borda com glow (`rim_box`)

Todo elemento com borda usa o helper `UIKit.rim_box(bg, rim_col, glow_col, size)`:

- **`rim_col`** (borda visual): versão **clara** da cor (ex.: `TR_RED_LIGHT`, `TR_PURPLE_LIGHT`)
- **`glow_col`** (shadow feathered): versão **normal** da cor (ex.: `TR_RED`, `TR_PURPLE`)
- Godot não suporta blur nativo em bordas — o efeito de "borda com glow" vem de:
  1. Linha de borda na cor clara (contraste visual = parece mais nítida)
  2. Shadow feathered grande e esparsa na cor normal (dá o brilho difuso externo)

### Dois tamanhos

| Tamanho | `glow_size` | `shadow_alpha` | Uso |
|---|---|---|---|
| `"large"` | 30 | 0.42 | Botões de destaque (RANKEADA, JOGAR RANKEADA) |
| `"small"` | 14 | 0.35 | Cards secundários, botões menores |

### Cards sem glow

Cards de estatísticas, painéis informativos e abas não-rankeada usam `UIKit.box(bg, TR_PURPLE_LIGHT)` — sem glow, só borda roxo-claro.
