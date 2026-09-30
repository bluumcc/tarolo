# Design e identidade visual — pesquisa e plano de cores

## 1. Pesquisa (o que vale pro Tarolo)
- **Regra 60-30-10:** 60% base neutra (fundo), 30% superfícies (cartões, painéis), 10% destaque. O destaque só funciona se for raro. ([Vision Australia](https://visionaustralia.org/business-consulting/digital-access/Creating-accessible-digital-colour-palettes-60-30-10-design-rule), [Rometheme](https://rometheme.net/blog/?p=12779))
- **Cores semânticas** (verde = ok/ganho, vermelho = erro/perda, amarelo = atenção, azul = informação) não devem servir de decoração, e precisam de ícone/texto junto por causa do daltonismo. ([UX Design](https://uxdesign.cc/10-principles-for-color-usage-in-ui-design-65174b213004), [Prototypr](https://blog.prototypr.io/basic-ui-color-guide-7612075cc71a))
- **Contraste WCAG 2.2:** texto 4,5:1 (texto grande 3:1); componentes de interface e ícones 3:1. ([Stark](https://www.getstark.co/wcag-explained/perceivable/distinguishable/contrast-minimum/))
- **Tema escuro:** evitar preto e branco puros, reduzir saturação de cores vibrantes, texto principal em ~90% de luminosidade. ([Color System Reference](https://cdn.jsdelivr.net/npm/opencode-agent-config@1.1.3/skills/frontend-design/color-system.md))
- **Fichas/cartas:** vermelho/verde e azul/roxo se confundem em daltonismo; diferenciar por forma, número e posição, não só por cor. ([Poker Chip Forum](https://www.pokerchipforum.com/goto/post?id=2267037))

## 2. Auditoria da paleta atual
Contraste calculado sobre os fundos do jogo:

| Cor | sobre NIGHT | sobre PURPLE_DEEP | Leitura |
|---|---|---|---|
| Branco (INK) | 17,8 | 14,4 | ótimo |
| Dourado | 11,6 | 9,4 | ótimo |
| Verde OK | 9,6 | 7,8 | ótimo |
| Muted (texto secundário) | 7,7 | 6,2 | bom |
| Azul CHIPS/DEF | 7,1 | 5,7 | bom |
| Vermelho DANGER | 5,5 | 4,5 | no limite |
| Violeta (destaque) | 4,3 | 3,5 | **falha como texto** |
| Vermelho BOSS | 4,4 | 3,6 | **falha como texto** |

Achados:
1. **Texto branco em botão verde (1,8) e dourado (1,5)** só é legível pelo contorno escuro; formalmente falha. Botões claros deveriam usar texto escuro.
2. **Verde × vermelho** (PAGOU × DESISTIU, ganho × perda) tem contraste entre si de 1,7 e é o par pior para daltonismo. Hoje a distinção é só de cor no status dos assentos.
3. **Dourado faz coisa demais:** título, stack, aposta, botão primário, anel de vez, botão (D), carteira. O destaque perde força.
4. **Violeta** aparece como texto/barras com contraste baixo e como face de botões secundários (MUTED #6B6BC4).
5. Não há regra escrita: cada tela escolhe a cor na hora.

## 3. Plano: cor = função
Cada cor tem um único trabalho, e o dourado passa a ser raro.

| Papel | Cor | Onde usa | Onde NÃO usa |
|---|---|---|---|
| Base (60%) | NIGHT / BLACK | fundo, mesa | texto |
| Superfície (30%) | PURPLE_DEEP / PURPLE | painéis, popups, cartões | destaque |
| Texto principal | INK (branco levemente tingido) | títulos, números | — |
| Texto secundário | MUTED | legendas, dicas | ação |
| **Ação primária** | **VIOLET** (face de botão, texto escuro/branco com contorno) | um único botão por tela (Jogar, Próximo, Aumentar) | texto solto |
| **Recompensa / dinheiro** | **GOLD** | fichas, stack, pote, ganho | botões comuns, títulos comuns |
| **Vez / foco** | **CIANO (novo, ex.: #5EEAD4)** | anel do jogador da vez, ordem 1/2/3, "É A VEZ" | dinheiro |
| Ganho / ok | OK verde | ganho de fichas, PAGOU, sucesso | destaque |
| Perda / perigo | DANGER vermelho | perda, DESISTIR, tempo acabando | decoração |
| Info / neutro | CHIPS azul | dicas, modificador de nível | perda |
| Combo / sequência | FLAME laranja | chamas e multiplicadores | — |
| Modificador de nível | ROXO CLARO (#C792EA) | faixa do modificador, Trunfos | ação |

Regras:
1. **Um destaque por tela** (o botão VIOLET). Dourado só para dinheiro e vitória.
2. **Nunca só cor:** todo estado tem palavra ou ícone (já existe no status dos assentos; falta nos resultados: ▲ ganho / ▼ perda, ✓ / ✕).
3. **Verde × vermelho sempre com ícone** (▲/▼, +/−) e texto; DESISTIR e PAGAR também diferem em posição.
4. **Texto sobre botão claro (GOLD, OK) usa BLACK**; sobre botão escuro usa INK.
5. **Texto ≥ 4,5:1** (DANGER passa a #FF7088 sobre PURPLE_DEEP; VIOLET e BOSS não são usados como texto).
6. **Tema escuro:** INK vira #F4F1FF (não branco puro); PURPLE_DEEP e NIGHT mantêm matiz roxo (sem preto puro nos fundos).
7. **Cartas:** naipes vermelhos e pretos continuam com tinta (forma do naipe já distingue), Trunfos em roxo claro, Bouts com selo dourado.

## 4. Implementação proposta (em etapas)
1. **Tokens:** consolidar em `UIKit` os papéis acima (`ACTION`, `MONEY`, `TURN`, `GAIN`, `LOSS`, `INFO`, `COMBO`, `MODIFIER`, `TEXT_ON_LIGHT`) e trocar as cores soltas por eles.
2. **Botões:** texto escuro em GOLD/OK; ação primária em VIOLET; secundários com face mais escura (contraste 3:1 contra o fundo).
3. **Mesa Caos:** anel e números de ordem em ciano; dourado só nas fichas e no pote; status com ícone (▲ PAGOU, ▼ DESISTIU, ↑ AUMENTOU, ✓ PASSOU).
4. **Vanilla:** BOSS/DEF só em bordas e preenchimentos, texto em INK.
5. **Menu:** cards de modo com uma cor de identidade cada (Caos vermelho, Vanilla azul, Ranqueado dourado, Tutorial verde), botão primário único.
6. **Revisão:** script que percorre a árvore e falha se algum texto tiver contraste < 4,5:1 (3:1 para texto grande).

## 5. Popups no celular
- `UIKit.fit()` roda em todo popup: reduz larguras mínimas fixas para caber na tela (margem de 16 px), faz botões e textos longos quebrarem linha e mantém o scroll vertical quando o conteúdo passa da altura.

## 6. Status da implementação
Feito: papéis de cor em `UIKit` (`ACTION`, `MONEY`, `TURN`, `GAIN`, `LOSS`, `INFO`, `COMBO`, `MODIFIER`, `TEXT_ON_LIGHT`), texto escuro automático em botões e cards claros (`UIKit.text_on`), botão primário em violeta, ciano para vez e ordem na Mesa Caos, status dos assentos com ícone (▶ ▲ ✓ – ✕), dealer branco, cores dos modificadores por função, estilos em cache no HUD (`UIKit.box_cached`), animação padrão de popup (`UIKit.pop_in`), feedback de toque nos botões, teste de contraste no `test_runner`.
Mantido de propósito: títulos de popup em dourado (identidade da marca).
Componentes: `StepsModal` (popup em passos) e `HelpContent` (textos das ajudas). Ver `scripts/ui/steps_modal.gd` e `scripts/ui/help_content.gd`.

### Vanilla e Ranqueado (aplicado)
Vanilla: anel/linha do jogador da vez e bolha "aguardando" em ciano (`TURN`), dicas do tutorial em azul (`INFO`), texto do chefe em `BOSS_TEXT` (o vermelho `BOSS` fica só em bordas e preenchimentos), botões de lance e confirmação em violeta (`ACTION`), título de derrota em `LOSS`. O Ranqueado já usava a cor da liga como identidade e ficou como está.
