# Plano de aprendizagem (tutorial, ajuda e textos)

Foco: o Blitz. Quem chega começa nele. O Clássico (Vanilla) fica como modo secundário e não
entra na primeira experiência.

Meta única: **em 3 minutos, uma pessoa que nunca viu o jogo faz sua primeira profecia certa
sem ter lido um parágrafo.**

## 1. Diagnóstico (o que existe hoje)

| Peça | Estado | Problema |
|---|---|---|
| Menu → COMO JOGAR | abre `HelpContent.vanilla()` | Ensina o **Clássico**, não o Blitz. Quem quer aprender o jogo principal lê a regra errada. |
| `HelpContent.blitz()` | 8 passos, ~540 palavras | **Não é usado em lugar nenhum** e está desatualizado ("40 blinds", agora são 80). |
| `HelpContent.blitz_intro()` | 3 passos, ~150 palavras, 1ª partida | Um bloco de leitura antes de ver a mesa. Termina em "profecia" e "pote" sem a pessoa ter jogado nada. |
| Dicas de uso único (`_tip`) | 5 popups modais (vez, dobrar, apostar, sacrifício, profecia) | Interrompem, são longos (até 60 palavras) e aparecem justo na hora de decidir. |
| Botão "?" na mesa | painel lateral: modificador ativo + "tutorial (placeholder)" | O tutorial não existe. |
| Prática | nenhuma | A primeira partida já é uma mesa de verdade, com bots, fichas e blind. |

Vocabulário que a pessoa precisa entender para a primeira partida: Ritual, jogada, naipe,
arcano maior (Trunfo), Louco, sacrifício, profecia, entrada, pote, blind, ante, passar/aumentar/
pagar/desistir, modificador, dobrar. São 14 termos. O objetivo é que a primeira partida use 4.

## 2. Princípios

1. **Uma ideia por vez, na hora em que ela é necessária.** Nada de regra antes de a pessoa ver a carta.
2. **Aprender fazendo.** Cada conceito é praticado uma vez, com a ação guiada, antes de ser explicado por completo.
3. **Texto curto.** Cartão de ajuda: no máximo **25 palavras**, 2 frases, 1 exemplo com número. Título de 1 a 3 palavras.
4. **Mostrar antes de dizer.** Destacar a carta, o botão ou o número na tela (com seta ou brilho) em vez de descrevê-los.
5. **Sem risco no começo.** Tutorial sem perda de fichas; o ranqueado só abre depois dele (ou ao pular).
6. **Um vocabulário só.** Glossário fechado (seção 7), com teste automático que impede termos antigos (Caos, nível no lugar de Ritual, etc.).
7. **A ajuda nunca ensina o que a tela já diz.** Se um aviso na mesa explica, o cartão some.
8. **Linguagem neutra e frases na ordem direta** (sujeito, verbo, objeto), como no manual de escrita do projeto.

## 3. As cinco camadas

### A. Ritual de Iniciação (tutorial jogável) — a peça central
Primeira partida de quem entra pela primeira vez. Mesa curta, controlada e sem custo.

- **Formato:** 1 Ritual de **6 jogadas** (não 8; ver decisão 4), 3 jogadores (você + 2 bots fixos), sem fichas em risco (o saldo volta intacto; ao final há um prêmio de boas-vindas).
- **Mão montada** (não aleatória), pensada para ensinar:
  - jogada 1: ganhar com a carta mais alta do naipe;
  - jogada 2: um bot corta com arcano maior, a pessoa vê o Trunfo ganhar;
  - jogada 3: pagar um aumento (uma aposta, com a ação sugerida);
  - jogadas 4 a 6: dois modificadores novos e **perder de propósito** para fechar a profecia.
- **Fluxo, com cartão curto e destaque a cada passo:**
  1. *Jogue uma carta.* (destaca a mão; só a carta certa é jogável)
  2. *Maior carta do naipe vence.* (resultado + as fichas das cartas)
  3. *Arcano maior corta.* (o bot corta; a carta pisca)
  4. *Faça sua profecia.* (a pessoa escolhe o número sugerido; a ★ é explicada aqui)
  5. *Aposta.* Passar / pagar, uma vez.
  6. *Feche a conta.* Se já está no alvo, jogue para perder.
  7. *Resultado:* quem acertou leva o pote. Prêmio e convite para o ranqueado.
- **Um modificador por jogada**, como no jogo de verdade, do mais simples ao mais estranho, cada um explicado na hora em que aparece.
- **Pular:** botão discreto desde o início; pular marca "já sei jogar" e abre direto o ranqueado. Dá para refazer no menu (AJUDA → Treino).
- **Recompensa:** ◎2.000 fichas de boas-vindas (+ verso de carta exclusivo quando houver arte).
- **O que fica de fora de propósito:** sacrifício das 2 cartas, dobrar, Louco, potes laterais, taxa, ante. Entram nas camadas B e D.

Para construir isso, o motor precisa de: tamanho de mão e número de jogadas configuráveis (hoje `HAND_SIZE = 8`
é constante), baralho/mão pré-montados por semente, bots com ações roteirizadas, e uma camada de "treinador"
na cena (seção 6).

### B. Dicas na hora (no lugar dos popups)
Trocar os 5 popups modais por **cartões de treinador** não bloqueantes (faixa curta + destaque), um por situação, mostrados
só na primeira vez em que a situação ocorre e nunca no tutorial A:

| Situação | Dica (≤ 25 palavras) |
|---|---|
| 1º sacrifício | "Escolha 2 cartas para sacrificar. Descarte as mais fracas e as que não combinam com sua profecia." |
| 1ª aposta | "Passar não custa nada. Pagar mantém você na jogada. Desistir perde o que já colocou." |
| 1ª vez que pode dobrar | "Dobrar paga mais uma entrada e vale o dobro. Use quando já está no alvo e a mão está fraca." |
| 1ª vez com o Louco | "O Louco é um arcano maior, mas nunca vence. Se ele abrir, todos precisam jogar arcano maior." |
| 1º modificador novo | Uma frase de ≤ 12 palavras ao sortear (já existe o anúncio em tela cheia; reaproveitar). |
| 1ª vez que é eliminado/ganha o pote | "Você errou por 2: perdeu a entrada." (mensagem de resultado com a causa) |

### C. Ajuda consultável (botão "?" e menu)
Reorganizar em **tópicos curtos**, abertos por busca ou lista, e não em um carrossel linear:

1. Objetivo (3 frases)
2. Uma jogada (naipe, Trunfo, Louco)
3. Preparação (sacrifício, profecia, ★)
4. Apostas (passar, pagar, aumentar, desistir; blind e ante em 1 linha)
5. Quem leva o pote (exato / errou por 1 / ninguém acertou)
6. Fechar a conta (fugir ou ganhar as jogadas que faltam)
7. Modificadores (12 itens de 1 linha cada, na ordem em que aparecem)
8. Relógio (os tempos, em tabela)
9. Ranqueada (níveis, buy-in, LP) e Torneio

Cada tópico ≤ 60 palavras no total. **Orçamento:** `blitz()` cai de ~540 palavras para ≤ 350 no conjunto,
mais ≤ 150 de modificadores.
O menu "COMO JOGAR" passa a abrir isto; o Clássico ganha o próprio botão dentro do modo Clássico.

### D. Desbloqueio progressivo (esconder o que não é essencial)
- **Partidas 1–3:** a interface mostra só jogar, profecia e pagar/passar. Ante, taxa, potes laterais e "dobrar" ficam
  recolhidos (o motor continua igual).
- **Partida 4 em diante:** "dobrar" e detalhes do pote aparecem, cada um com sua dica da camada B.
- **Modificadores:** os mais simples primeiro; os que mexem em fichas (Saque, Assalto, Maldição) depois.
  (Requer uma lista de modificadores permitidos por estágio na configuração da mesa.)

### E. Aprendizado contínuo
- **Resumo do Ritual** com a causa em uma linha: "Você previu 4 e fez 3: perdeu metade da entrada."
- **"Por que perdi?"** no fim da partida: os 2 momentos que mais custaram fichas (uma frase cada).
- **Dica do dia** na tela de espera (uma frase, rodízio) — barata e já cabe no menu.

## 3.1 Linguagem visual do treinador (sem popup antigo)

O treinador não é um popup no meio da tela com botão OK. Ele usa os padrões de jogos modernos, no mesmo estilo
da mesa (vidro roxo, borda neon, tipografia e cores por função do `UIKit`, partículas e contadores do `FX`):

| Padrão | Para que serve | Como fica |
|---|---|---|
| **Foco (spotlight)** | Mostrar um botão, a mão, o pote, o contador de vitórias | Escurece a tela com um recorte suave no alvo (cantos arredondados, leve brilho). Só o recorte recebe toque. |
| **Anel pulsante + seta** | Dizer onde tocar | Anel dourado que respira em volta do alvo; seta curta que flutua e aponta para ele. |
| **Cartão de treinador** | Dar a instrução | Faixa baixa, sobre a mão, com borda neon e ícone; entra deslizando, 1 a 2 linhas. Sem fundo cheio e sem botão OK: avança quando a pessoa faz a ação. |
| **Mão guiada** | Ensinar a jogar a carta | As cartas que não servem escurecem; a certa sobe sozinha e fica brilhando. |
| **Rótulos flutuantes** | Explicar números (pote, fichas, 1/3) | Etiqueta pequena ligada por uma linha fina ao elemento, some após 3 segundos ou no próximo toque. |
| **Resultado com causa** | Fechar o ciclo | Contador que rola, pop de cor (verde/vermelho) e uma linha: "Previu 3 e fez 3: leva o pote." |
| **Retoque, não bloqueio** | Dicas fora do tutorial | Selo "?" pulsando no botão relevante; só abre se a pessoa tocar. |

Regras de comportamento:

- **Sem fricção:** nenhum passo pede "OK" só para continuar; o avanço é a própria ação (tocar a carta, escolher o número).
- **Nunca prende a pessoa:** botão de pular visível (canto, discreto) e "voltar" no passo anterior; errar uma ação mostra
  uma dica gentil e deixa tentar de novo (nunca uma tela de erro).
- **Ritmo:** a animação do foco leva 250–350 ms; o cartão aparece depois de 400 ms de pausa, para a pessoa olhar a tela primeiro.
- **Respeita o relógio:** durante o tutorial o relógio de jogada fica desligado; na dica fora do tutorial, ele pausa enquanto o foco está aberto.
- **Movimento reduzido:** com `GameState.anim()` desligado, o foco aparece sem animar e a seta fica parada.
- **Som e vibração:** um toque suave ao abrir o foco e um som de acerto ao concluir o passo; no celular, vibração curta no acerto.
- **Toque e PC:** o mesmo alvo vale para toque e para clique; no PC, o foco também aceita Enter para o passo certo.
- **Acessível:** contraste mínimo do cartão sobre o fundo escuro, fonte do cartão igual à do jogo (nunca menor que 18 px
  na escala atual), e o texto nunca é a única forma de mostrar o alvo.
- **Coeso com a mesa:** o cartão usa a mesma `rim_box`, as mesmas cores por função (verde ganho, vermelho perda, dourado
  destaque, azul informação) e a mesma tipografia dos avisos da mesa. Nada de caixa cinza com borda reta.

Componentes novos em `scripts/ui/coach/`: `spotlight.gd` (escurecimento com recorte e anel), `coach_card.gd` (faixa com
ícone e texto), `coach_pointer.gd` (seta e etiquetas) e o controlador `coach.gd`. Todos ficam atrás de `FX` e do tema atual.
O `StepsModal` continua para ajuda longa consultada pelo menu, mas deixa de ser usado durante a partida.

## 4. Textos: como reescrever

Regras de redação (somam ao `docs/manual_escrita.md` quando se tratar de mapas, aqui é interface):

- Verbo no início do cartão quando for ação ("Faça sua profecia."); afirmação curta quando for regra.
- Sempre um número concreto: "Previu 3 e fez 3: leva o pote." em vez de "acertar o número exato".
- Nada de "pode ser que"; nada de duas regras na mesma frase.
- Nomes de botão com 1 verbo: JOGAR, PASSAR, PAGAR, AUMENTAR, DESISTIR, DOBRAR.

Exemplo do antes e depois (profecia):

> **Antes (60 palavras):** "Com a mão na tela, você diz quantas jogadas vai ganhar, de 0 a 8. Cada jogador paga a entrada de 8 blinds. A sua profecia é sua: as dos rivais ficam em segredo até o fim do Ritual, e só se vê quantas jogadas cada um já venceu. A estrela ★ é uma sugestão baseada na força da sua mão. Profecias altas pesam mais no pote…"
>
> **Depois (22 palavras):** "Diga quantas jogadas você vai ganhar (0 a 8) e pague a entrada. Acertou em cheio: leva o pote. A ★ sugere um número."

O peso por dificuldade da profecia (×1, ×1,5, ×2) sai do tutorial e vai para o tópico 5 da ajuda.

## 5. Ordem de execução

| Fase | Entrega | Pré-requisito |
|---|---|---|
| 0 | Corrigir o óbvio: menu COMO JOGAR → ajuda do Blitz; corrigir "40 blinds"→"80"; esconder o placeholder do "?" | nenhum |
| 1 | Glossário fechado + teste de lint de textos (limite de palavras por cartão, termos proibidos) | fase 0 |
| 2 | Reescrever ajuda (camada C) dentro do orçamento de palavras | fase 1 |
| 3 | Camada de treinador (cartão + destaque + bloqueio de toque) como componente separado de `blitz_scene.gd` | nenhum |
| 4 | Motor: mão e nº de jogadas configuráveis, baralho por semente, bots roteirizados | nenhum |
| 5 | Ritual de Iniciação (camada A) + fluxo de primeiro acesso | fases 3 e 4 |
| 6 | Dicas na hora (camada B), trocando os popups | fase 3 |
| 7 | Desbloqueio progressivo (camada D) | fase 5 |
| 8 | Camada E (resumo com causa, "por que perdi?") | independente |

Cada fase é publicável sozinha e deixa o jogo funcionando.

## 6. Arquitetura

- `scripts/ui/coach.gd` (novo): recebe uma lista de passos `{when, target, text, allow}`, mostra a faixa, destaca o nó
  alvo e bloqueia os outros toques. Sem lógica de regra.
- `scripts/core/tutorial_script.gd` (novo, sem autoload): define o Ritual de Iniciação (mão, ordem dos bots, passos).
- `HelpContent`: passa a ter `topics()` (camada C) e `tips()` (camada B), com `{id, title, text}`; os dados ficam separados
  da interface para o teste de lint ler.
- `blitz_scene.gd` (já com ~3.000 linhas): só chama o `Coach` nos pontos de fase; o código novo não entra nele.
- Estado de aprendizado em `SaveManager.section("learn")`: `{tutorial: "done"|"skipped"|"", tips_seen: [...], matches: n}`.
  Substitui o dicionário `tips` atual (migrando as chaves já vistas).

## 7. Glossário fechado (nomes oficiais)

Ritual (8 jogadas), jogada, Sacrifício, Profecia, entrada, pote, blind, ante, Trunfo / arcano maior, Louco, modificador,
nível (reservado ao **nível do jogador/XP**; para as 5 salas da ranqueada, o termo também é "nível" por decisão do projeto,
sempre acompanhado do nome do arcano: "nível O Mago").

Termos proibidos nos textos: Caos, rodada (use Ritual ou jogada), vaza, mão (para a mesa inteira), cego.

## 8. Testes

- **Lint de textos:** cada cartão de dica ≤ 25 palavras; cada tópico da ajuda ≤ 60; nenhum termo proibido; nenhuma
  referência a número de blinds fora de `RANKED_STACK_BLINDS` (o texto lê a constante).
- **Tutorial automático:** o Ritual de Iniciação roda em autoplay até o fim, a profecia sugerida fecha certa e o saldo
  de fichas fica igual ao do início (menos o prêmio).
- **Treinador:** o teste de interface confere que cada passo destaca um nó existente e que só o alvo recebe toque.
- **Migração:** save antigo com `tips` não repete as dicas já vistas.

## 9. Como medir se funcionou

Sem servidor de métricas ainda, a medição é por observação, com 5 a 10 pessoas que nunca viram o jogo:

- chegam ao fim do Ritual de Iniciação? (meta: 9 em 10)
- fazem a 1ª profecia certa sozinhas na partida seguinte? (meta: 6 em 10)
- conseguem explicar com as próprias palavras "o que é a profecia"? (meta: 8 em 10)
- em qual cartão pararam para reler ou pediram ajuda?

Quando existir servidor, os mesmos eventos viram métricas (tutorial concluído, pulado, abandono por passo).

## 10. Decisões tomadas

1. **Tutorial pulável** desde o primeiro toque (com confirmação).
2. **Prêmio do tutorial: ◎2.000 fichas** (paga mais de duas entradas do nível mais barato, ◎800). Verso de carta exclusivo entra quando houver arte.
3. **Clássico** já tem a aba própria no menu: nada muda ali.
4. **Modificadores no tutorial:** toda jogada tem um, então o tutorial **mostra vários**, um por jogada, apresentados na ordem
   do mais simples para o mais estranho. Cada um ganha uma frase de ≤ 12 palavras na hora em que aparece (a mesma do anúncio em tela cheia).
   Por isso o Ritual de Iniciação passa de 4 para **6 jogadas** (a definir na fase 4), com a mão montada para que cada
   modificador mude algo visível.
