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

## Resultados de referência (mesa de 4/6, blind 10)
- Equilíbrio por tamanho (`blitz_size_sim`, vantagem Difícil × Normal): 2 jogadores −0,6 (não equilibrado, por isso o torneio evita heads-up), 3: +3,0, 4: +2,1, 5: +5,7, 6: +6,7.
- Economia completa (`tests/sim/economy_sim.gd`, 300 sessões, espelho): por assento −0,2 a −0,8 blinds/nível em mesa de 4 e −0,7 a +0,3 em mesa de 6; sem viés de posição relevante. A taxa da casa fica ≈ 1 blind/nível na mesa. Ordem de habilidade: Oráculo > Difícil > Normal > Fácil.
- Retorno de torneio de 16 (`sim_suite --only=roi`): Fácil ROI −52 %, Normal ≈ 0 %, Difícil +15 % (no dinheiro 11 / 22 / 25 %).
