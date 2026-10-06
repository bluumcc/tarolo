# Simulações e verificações

Rodam sem UI, com sementes fixas (reproduzíveis). Qualquer falha sai com código 1.

| O quê | Comando | O que garante |
|---|---|---|
| Testes unitários/regras | `godot --headless --path . -s res://tests/test_runner.gd` | regras do motor, UI lógica, cores |
| **Suíte de simulação** | `godot --headless --path . -s res://tests/sim/sim_suite.gd -- --n=600 [--only=conserva\|potes\|fuzz\|extremos\|torneio]` | ver abaixo |
| Smoke (cena real, autoplay) | `godot --headless --path . res://tests/Smoke.tscn` | partidas e torneios completos pela cena |
| Mesa (geometria) | `-s res://tests/table_gate.gd` | assentos sem passar das margens |
| Equilíbrio dos bots | `-s res://tests/blitz_gate.gd` | escada de dificuldade e estilos |
| Economia vs Oráculo | `-s res://tests/blitz_economy_check.gd` | taxa da casa x jogador ótimo (sem fase de apostas) |
| Toque real nas etapas | `xvfb-run … res://tests/PhaseCheck.tscn` | CONFIRMAR e alturas do cabeçalho |

## Suíte `tests/sim/sim_suite.gd`
- **conserva**: soma de stacks + potes + acumulado + taxa − bônus constante a cada jogada; stack nunca negativa; nenhum nível trava (2 a 6 jogadores, stacks desiguais, apostas aleatórias incl. all-in).
- **potes**: divisão em camadas (principal/laterais) igual a um oráculo independente (força bruta) em milhares de cenários.
- **fuzz**: ações inválidas/fora de vez/valores absurdos nunca travam a rodada de apostas nem corrompem as mãos.
- **extremos**: stack 0, 1, abaixo do blind, todos all-in, mesa de 2.
- **torneio**: torneios de 16 sempre terminam com 1 campeão, mesas sempre parelhas (≤ 4, ≥ 2).

Validação do próprio teste (mutação): quebrar o pagamento de potes laterais faz a conservação falhar.

Bugs que a suíte/estas verificações acharam: fichas do acumulado sumiam ao fim de mesa de 1 nível (torneio, todos zerando); `clone_for_sim` não copiava `busted` (quebrava Oráculo/simulações).
