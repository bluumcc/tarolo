# Checklist de Componentes — Figma → Godot

## Configuração do canvas

- Canvas virtual: **720 × 1280 px** (celular em pé) — exporte @2x (1440 × 2560 px)
- Grade base: **8 px**; margens de tela: **24 px**
- Safe area: reservar 32 px no fundo (barra de gestos)
- Nomeie cada quadro como `NomeComponente/estado` — o Figma exporta com `/` no nome

---

## Regra de exportação

| O que desenhar | O que NÃO desenhar |
|---|---|
| Borda, fundo, textura, gradiente, brilho superior, sombra interna | Texto (o jogo escreve por cima) |
| Sombra externa → **desenhe junto**, no mesmo PNG | Ícones vetoriais simples → use atlas (mais tarde) |
| Contorno escuro (4 px) | Qualquer efeito aplicado pelo Godot (shake, flash) |

> **Fundo transparente fora da forma** — tudo o que é fora do shape fica com alpha 0.
> A sombra externa (drop shadow) vai no mesmo PNG, com alpha real (semitransparente).

---

## 1. BigButton — botão 3D gordo

**Conceito:** face colorida + contorno escuro 4 px + brilho superior (oval branco, ~20 % opacidade)
Sombra sólida inferior de **8 px** (mesma cor da face, escurecida 40 %) — desenhada no PNG.
Ao pressionar: a sombra some e a face desce 6 px (estado `pressed`).

### Tamanho do frame

| Uso | W | H |
|---|---|---|
| Botão grande (ação principal) | **400 px** | **88 px** |
| Botão médio (secundário) | **280 px** | **72 px** |
| Botão pequeno (inline) | **160 px** | **64 px** |

> 9-slice margins: **24 px** em tudo (os 4 cantos arredondados ficam nas bordas; o meio estica).

### Estados × Tons → 16 PNGs por tamanho

| Estado \ Tom | `primario` | `perigo` | `sucesso` | `secundario` |
|---|---|---|---|---|
| `normal` | ✓ | ✓ | ✓ | ✓ |
| `hover` | ✓ | ✓ | ✓ | ✓ |
| `pressed` | ✓ | ✓ | ✓ | ✓ |
| `disabled` | ✓ | ✓ | ✓ | ✓ |

**Paleta de face (lembrete):**

| Tom | Cor da face |
|---|---|
| `primario` | Violeta `#7C3AED` |
| `perigo` | Vermelho `#DC2626` |
| `sucesso` | Verde `#16A34A` |
| `secundario` | Cinza `#374151` |

**Nome de export:** `btn_grande_primario_normal.png`, `btn_grande_primario_hover.png`, etc.

---

## 2. IconButton — botão quadrado com ícone

**Tamanho:** 64 × 64 px frame, mesma estética do BigButton mas quadrado.
Badge de notificação (círculo vermelho 20 px no canto superior direito): estado separado `_badge`.

**Estados:** `normal`, `hover`, `pressed`, `disabled` → 4 PNGs
(sem tons diferentes — cor fixa escura/neutra)

**9-slice margins:** 16 px em tudo.

---

## 3. Card (painel elevação 1)

Painéis de informação: ficha do jogador, cartão de modo, cartão de torneio.

**Tamanhos:**

| Uso | W | H |
|---|---|---|
| Cartão de modo (menu) | **640 px** | **160 px** |
| Cartão de jogador | **320 px** | **120 px** |
| Cartão genérico | **640 px** | **auto** (9-slice) |

Estilo: fundo `#1A0A2E` + contorno roxo `#4B1D8A` 2 px + raio 24 px.
**9-slice margins:** 28 px em tudo.

---

## 4. Modal (painel elevação 3)

Painel que cobre a tela com overlay escuro.

**Frame da caixa modal:** 680 × variável (min 400 px)
Estilo: fundo `#12082A` + contorno `#6D28D9` 3 px + raio 32 px + brilho interno suave.
**9-slice margins:** 36 px.

**Overlay (fundo escurecido):** não precisa de PNG — o jogo desenha um `ColorRect` semi-transparente.

---

## 5. TopBar

Barra do topo persistente (menu e partida).

**Tamanho:** 720 × 96 px
Fundo: gradiente do `#0D0518` para transparente (de cima para baixo).
Conteúdo que você **não** desenha: avatar, fichas, fragmentos (o jogo coloca por cima).
Exporte como faixa plana — sem 9-slice (largura sempre 720 px).

---

## 6. BottomNav

Barra de navegação inferior (menu principal).

**Tamanho:** 720 × 112 px
Fundo sólido `#0D0518` + linha superior de 1 px `#4B1D8A` + safe area de 32 px abaixo.
Ícones das abas: desenhe separado (ver item 9).
A aba central em destaque: 72 × 72 px, cor primária, levemente elevado (borda superior arredondada sobressai 16 px).

---

## 7. TimerRing — relógio circular de jogada

Círculo oco que vai esvaziando (progress).

**Tamanho do frame:** 96 × 96 px
Exporte 2 arquivos:
- `timer_ring_bg.png` — trilha de fundo (arco cinza escuro, ~20 % opacidade)
- `timer_ring_fill.png` — arco cheio (cor da borda neon); o Godot usa `radial_initial_angle` pra animar

**9-slice:** não (é circular, escala uniforme).

---

## 8. ChipCounter — contador de fichas

Badge com número e ícone de ficha.

**Tamanho:** 120 × 48 px
Fundo: pílula `#1A0A2E` + contorno dourado `#CA8A04` 2 px.
O Godot escreve o número; exporte apenas a pílula vazia.
**9-slice margins:** 24 px horizontal, 0 px vertical.

---

## 9. Ícones de interface (atlas)

Tamanho de cada ícone: **48 × 48 px** (exporta @2x = 96 × 96)

| Nome do arquivo | Ícone |
|---|---|
| `ic_home.png` | Casa |
| `ic_play.png` | Triângulo play |
| `ic_shop.png` | Sacola |
| `ic_rank.png` | Troféu |
| `ic_profile.png` | Pessoa |
| `ic_settings.png` | Engrenagem |
| `ic_help.png` | ? |
| `ic_close.png` | × |
| `ic_back.png` | Seta ← |
| `ic_ficha.png` | Disco/moeda |
| `ic_frag.png` | Fragmento (losango) |

Fundo **transparente**. Cor branca (o jogo recolore via `modulate`).

---

## 10. Cartas (card_view)

**Tamanhos de contexto:**

| Contexto | W | H |
|---|---|---|
| Mão (handfã) | **168 px** | **240 px** |
| Mesa | **120 px** | **172 px** |
| Mini (histórico) | **72 px** | **104 px** |

**Componentes da face:**
- `carta_frente_base.png` — fundo branco + borda arredondada 12 px (contorno escuro 2 px)
- `carta_frente_trunfo.png` — fundo branco + borda roxa 3 px + glow roxo suave (para arcanos maiores)
- `carta_verso.png` — fundo `#1A0A2E` + padrão geométrico + borda `#4B1D8A`

O jogo escreve naipe, valor e nome por cima; você não desenha nenhum texto.
**9-slice margins:** 16 px em tudo.

---

## 11. SeatSlot — assento vazio na mesa

Quando um assento existe mas não tem jogador (mesa fixa de 6).

**Tamanho:** 80 × 80 px (tamanho de HexAvatar.SIZE_PX)
Estilo: círculo pontilhado `#4B1D8A` 2 px + interior `#1A0A2E` 40 % opacidade + runa central 40 % opacidade.
**Estados:** apenas `empty` (o jogo esconde quando há jogador).

---

## Estrutura de pastas no Godot

```
assets/ui/
  buttons/
    btn_grande_primario_normal.png
    btn_grande_primario_hover.png
    ... (64 PNGs de botão grande)
    btn_medio_primario_normal.png
    ... (64 PNGs de botão médio)
  panels/
    card_panel.png
    modal_panel.png
  bars/
    topbar_bg.png
    bottomnav_bg.png
  icons/
    ic_home.png  ic_play.png  ... (11 PNGs)
  hud/
    timer_ring_bg.png  timer_ring_fill.png
    chip_counter.png
  cards/
    carta_frente_base.png
    carta_frente_trunfo.png
    carta_verso.png
  seats/
    seat_empty.png
```

---

## Checklist antes de exportar cada componente

- [ ] Nenhum texto dentro do frame (camadas de texto: visibilidade desligada)
- [ ] Fundo fora da forma: transparente (alpha 0)
- [ ] Sombra externa desenhada dentro do frame (não como efeito do Figma — rasterize)
- [ ] Tamanho exato conforme tabela acima
- [ ] Exportado @2x em PNG
- [ ] Nome do arquivo em minúsculo com underscores, sem espaços
- [ ] Margens de 9-slice anotadas aqui ao lado (para configurar no Godot)

---

## Margens de 9-slice por componente (referência rápida)

| Componente | Top | Right | Bottom | Left |
|---|---|---|---|---|
| BigButton grande | 24 | 24 | 24 | 24 |
| BigButton médio | 24 | 24 | 24 | 24 |
| IconButton | 16 | 16 | 16 | 16 |
| Card panel | 28 | 28 | 28 | 28 |
| Modal panel | 36 | 36 | 36 | 36 |
| ChipCounter | 0 | 24 | 0 | 24 |
| Cartas | 16 | 16 | 16 | 16 |
