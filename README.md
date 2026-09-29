# Tarolo (nome provisório) — Godot 4

Protótipo jogável do GDD em [`docs/GDD.md`](docs/GDD.md): roguelike de rodadas com pontuação estilo Balatro, nos modos Clássico, Arcade (Loja Arcana) e Ranqueado (ligas, LP, MMR).

## Rodar
1. Instale o **Godot 4.3+** (versão padrão, não precisa da .NET).
2. Abra `project.godot` no editor e aperte **F5**.

Ou pela linha de comando:
```bash
godot --path .
```

## Controles
- **Selecionar/jogar carta:** toque/clique uma vez para selecionar e de novo para jogar. Também dá para arrastar para cima ou dar duplo clique.
- **Zoom:** segurar o dedo na carta, ou botão direito do mouse.
- **Pausa:** botão ☰ ou `Esc`.

## Estrutura
```
project.godot
scenes/            MainMenu, GameScene, RankedLobby, Shop, Card (.tscn)
scripts/core/      Regras puras (sem UI): CardData, Deck, TrickRules, Scoring, Jokers, BotAI, MatchEngine, Ranked
scripts/autoload/  SaveManager (JSON), GameState (modos/economia/LP), Sfx (sons sintetizados)
scripts/ui/        Cenas e UIKit (paleta Dark Brutalist, formato numérico PT-BR)
shaders/           background, foil, holo (Polychrome)
tests/             test_runner.gd (regras), Smoke.tscn (partidas completas), Screenshot.tscn
```

## Testes (headless)
```bash
cd tarolo
godot --headless --import                              # 1ª vez: gera o cache de classes
godot --headless -s res://tests/test_runner.gd         # regras, pontuação, ranked, 300 partidas simuladas
godot --headless res://tests/Smoke.tscn                # cenas + partidas em autoplay nos 3 modos
```
