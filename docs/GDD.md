# GAME DESIGN DOCUMENT — TAROLO

> Nome provisório. Título original do documento: *Tarot Arena: Chaos Edition*.

> **Status atual (pivô de arquitetura):** o jogo passou a ter dois modos de regras
> claramente separados, ambos sobre o **baralho real do Jeu de Tarot (78 cartas)**:
> - **Vanilla** — o jogo de rodadas clássico: 4 naipes de 14 cartas, 21 Trunfos, O Louco,
>   obrigação de seguir naipe/cortar/cobrir com Trunfo, Tomador vs Defesa, pontuação por
>   Bouts (implementado). Cada jogador recebe 18 cartas + talão de 6. **Falta**: licitação
>   interativa (hoje o Tomador é escolhido automaticamente pela força da mão — isso deixa
>   o Tomador perdendo com frequência maior que o ideal, porque ele não pode recusar uma
>   mão fraca) e os bônus raros (Poignée, Chelem, Petit au bout).
> - **Caos** — a camada dinâmica (Energia, Cartas de Ruptura, Curingas, Fôlego para
>   viradas), mão de 8 cartas do mesmo baralho de 78. **Ainda não implementado**
>   (o antigo protótipo com Foil/Polychrome/52 cartas foi removido nessa reescrita).
> - Apostas com Fichas fictícias (buy-in por mesa, payout 65/25/10 de rake) valem só pro
>   Vanilla — ainda não implementadas.
>
> O texto abaixo é o brief criativo original (Balatro-esque, baralho de 52+4 Arcanos) que
> deu origem ao projeto; várias seções (Loja Arcana, Foil/Polychrome, Arcade) descrevem o
> protótipo anterior e serão revisadas para refletir o Caos de verdade.

## 1. Visão Geral
- **Gênero:** Roguelike Deckbuilder / Card Battler tático de rodadas, com sinergias, matemática de combos, gestão de recursos e alta rejogabilidade (Balatro + a competitividade de Hearthstone/LoL).
- **Plataformas:** PC (Steam — Windows/macOS) e Mobile (iOS/Android).
- **Engine:** Godot 4.x · GDScript.
- **Visual:** Dark Brutalist / atmosférico: azul-noite, roxo fosco e preto, tipografia de alto contraste, cartas com brilho Foil e Polychrome.
- **Som:** atmosférico e progressivo, com batidas mecânicas de cassino.

## 2. Modos de Jogo
| Modo | Descrição | Implementação |
|---|---|---|
| **Clássico** | Rodadas com regras fechadas, sem Foil/Polychrome nem Curingas. | `GameState.Mode.CLASSIC` |
| **Arcade** | Run roguelike por fases. Cada fase tem um **Chefe** (um Arcano Maior, assento ☠). Superar o Chefe no placar avança a run e rende Ouro para a **Loja Arcana**. Perder encerra a run. | `GameState.Mode.ARCADE`, `Shop.tscn` |
| **Ranqueado** | Ligas Bronze → Prata → Ouro → Platina → Diamante (divisões IV–I, 100 LP cada) → Mestre → Desafiante. Matchmaking por MMR (Elo), temporadas e histórico. | `Ranked`, `RankedLobby.tscn` |

## 3. Stack & Arquitetura
- Godot 4.x (Forward+ no PC, Mobile renderer no celular).
- UI 100% em nós `Control` (`VBoxContainer`, `HBoxContainer`, `HFlowContainer`, `StyleBoxFlat`). A resolução base troca entre **1280×720 (paisagem)** e **720×1280 (retrato)** conforme a orientação da tela.
- Animações com `Tween` nativo: cartas voando para a mesa, zoom, contador de pontos, popups flutuantes.
- Persistência em JSON local (`user://tarolo_save.json`) via `FileAccess`.
- Regras separadas da UI (`scripts/core/*`), testadas em modo headless.

## 4. Regras de Jogabilidade
### Baralho e recursos
- 52 cartas: Ouros, Paus, Copas, Espadas; Ás (1) a Rei (13), sem duplicatas.
- **O Ás vale 1** e é a menor carta do naipe.
- **Arcanos Maiores:** 4 por rodada, sorteados entre os 22. Valem 15 pontos e podem ser jogados sobre qualquer naipe, ignorando a obrigação de seguir.
- **Foil:** +50 Fichas. **Polychrome:** ×2,0 Mult.
- **Drop no Arcade:** Padrão ~88%, Foil ~8%, Polychrome ~4%.

### Estrutura da rodada
1. **Naipe líder:** quem abre define o naipe. Se abrir com um Arcano, o naipe é definido pela primeira carta numérica jogada depois.
2. **Obrigação de seguir:** quem tem o naipe líder deve jogá-lo (ou um Arcano). Sem ele, joga qualquer carta.
3. **Resolução:** vence a maior carta do naipe líder. Se houver Arcano na rodada, **o primeiro Arcano jogado vence**.

### Decisões de design (fechadas no protótipo)
- Mesa de 4 jogadores. 56 cartas (52 + 4 Arcanos), 14 por jogador, 14 rodadas por partida.
- Quem abre a primeira rodada é sorteado. Depois, abre quem venceu a rodada anterior.
- Placar final: soma dos pontos das rodadas. Desempate por número de rodadas vencidas.

## 5. Pontuação e Sinergias
Quem vence a rodada pontua **Fichas × Mult** com todas as cartas da mesa:
- **Fichas:** soma do valor das cartas, mais Foil e Curingas de Fichas.
- **Mult:** começa em 1. Primeiro somam os bônus `+Mult`, depois entram os multiplicadores `×Mult`.
- **Monopólio de Naipe:** todas as cartas da rodada do mesmo naipe, ×2,0.
- **Sequência Caótica:** valores consecutivos em qualquer ordem (ex.: 4-5-6-7), ×2,5. Acumula com o Monopólio (×5,0).
- Arcanos quebram as duas sinergias.

## 6. Economia e Progressão
- **Ouro (Arcade):** +1 por rodada vencida. Ao superar o Chefe: bônus de fase (3 + nº da fase) e juros (1 a cada 5 de Ouro, máx. 5).
- **Chefes:** multiplicador de fase ×(1 + 0,2 × (fase − 1)). A IA fica mais forte com as fases (Fácil → Normal → Difícil).
- **Loja Arcana:** 3 Curingas (máx. 5 equipados; venda por metade do preço), 2 cartas modificadas permanentes na run e reroll com preço crescente (2, 3, 4...).
- **Curingas:** O Louco, Mesa Cheia, Ás Oculto, Copas Sangrentas, Ganância, Eclipse, Espelho Negro, Monarca, Caos Ordenado, Juros Arcanos, Escada ao Céu, Prisma, A Torre.
- **LP/MMR (Ranqueado):** 1º e 2º lugar ganham LP; 3º e 4º perdem. O ajuste depende da diferença para o MMR médio do lobby. O MMR usa Elo (K=48) sobre a colocação. Desafiante exige 2600+ pontos e MMR 1900+.
- **Fragmentos:** moeda cosmética ganha em todos os modos, usada para comprar versos de carta.

## 7. Estrutura de Cenas (`.tscn`)
- `MainMenu.tscn`: modos, Loja de Cosméticos, Configurações (volume, velocidade das animações, tela cheia) e Como Jogar.
- `GameScene.tscn`: mesa polivalente com `TableCenter`, HUD (placar, rodadas, colocação, Ouro/fase ou elo), barra de Curingas, `HandContainer`, zoom de carta, pausa e tela de resultado.
- `RankedLobby.tscn`: elo atual, barra de LP, escada de ligas, matchmaking e histórico das últimas 20 partidas.
- `Shop.tscn`: Loja Arcana entre as fases do Arcade.
- `Card.tscn`: carta reutilizável com estilos dinâmicos (`StyleBoxFlat`) e brilho por shader (`foil.gdshader` / `holo.gdshader`). Aceita toque para selecionar, arrastar para cima para jogar e segurar ou clicar com o botão direito para dar zoom.

## 8. Próximos passos sugeridos
- Arte final das cartas (22 Arcanos ilustrados) e fontes próprias.
- Trilha sonora e SFX finais (hoje são sintetizados em `Sfx` como placeholder).
- Ranqueado online (servidor de matchmaking). Hoje o lobby é simulado com bots escalados por MMR.
- Export presets (Steam/Android/iOS) e integração Steamworks.
- Chefes com habilidades próprias (ex.: "A Torre destrói um Curinga ao perder a rodada").
