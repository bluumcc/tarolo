class_name HelpContent
extends RefCounted
## Textos das ajudas em passos (um parágrafo por passo, sem quebras de linha), usados pelo
## StepsModal. Vanilla segue o Jeu de Tarot; o Caos tem as próprias regras.

const GOLD := Color("#FFC933")


static func vanilla() -> Array:
	return [
		{"icon": "♠ ♥ ◆ ♣", "title": "O BÁSICO", "text": "Uma rodada é uma jogada de 4 cartas, uma de cada jogador. Quem jogou a carta mais forte leva as 4 e os pontos delas. Você tem que jogar o naipe da primeira carta. Se não tiver, tem que jogar um Trunfo, e se também não tiver Trunfo joga qualquer carta. O Trunfo ganha de qualquer naipe e, entre Trunfos, o número maior ganha. Se alguém já cortou, quem também corta deve subir com um Trunfo maior, se tiver. Em cada naipe, do menor pro maior: Ás, 2 a 10, Valete, Cavaleiro, Rainha e Rei."},
		{"icon": "★ 1 21", "title": "OS BOUTS", "text": "São as 3 cartas mais valiosas: o Trunfo 1 (Le Petit), o Trunfo 21 (Le Monde) e O Louco. Cada um vale 4,5 pontos, como um Rei. O Louco nunca ganha a rodada: quem o joga fica com ele e só na última rodada ele vai pra quem ganhar. Os Bouts que o Atacante captura baixam a meta dele."},
		{"icon": "⚔", "title": "LICITAÇÃO: QUEM JOGA SOZINHO", "text": "Cada um passa ou dá um lance. O lance mais alto vira o Atacante: ele joga sozinho contra os outros 3, a Defesa. Do mais leve ao mais arriscado: Petite ×1, Garde ×2, Garde Sans ×4 e Garde Contre ×6. O número é quanto você ganha ou perde. O lance não custa nada, é só dizer que você confia na sua mão."},
		{"icon": "▣", "title": "O MONTE", "text": "São 6 cartas viradas no meio da mesa. Na Petite e na Garde, o Atacante pega o monte, olha e devolve 6 cartas da mão, nunca Reis nem Bouts. Na Garde Sans ele não pega e os pontos do monte contam pra ele. Na Garde Contre ele também não pega e os pontos vão pra Defesa."},
		{"icon": "✓", "title": "COMO SE GANHA", "text": "O Atacante precisa somar 56 pontos sem Bout, 51 com 1 Bout, 41 com 2 ou 36 com 3, usando as cartas que ganhar. Se conseguir, ganha pontos dos outros 3. Se não, paga."},
		{"icon": "✦", "title": "BÔNUS", "text": "Só o Atacante escolhe. Poignée: com 10 ou mais Trunfos, ele pode mostrá-los pra ganhar pontos extras. Chelem: ganhar as 18 rodadas. Se avisar antes e conseguir: +400; se avisar e falhar: −200; sem avisar, se acontecer: +200. Petit na última rodada: quem ganhar a última rodada com o Trunfo 1 nela leva +10.", "color": Color("#C792EA")},
	]


static func bout() -> Array:
	return [
		{"icon": "★", "title": "O QUE É BOUT?", "text": "Bout, que se lê \"bu\", é o nome das 3 cartas mais valiosas: Le Petit (o Trunfo 1), Le Monde (o Trunfo 21) e O Louco. Cada Bout vale 4,5 pontos, o mesmo que um Rei. E os Bouts que o Atacante captura baixam a meta dele: com 0 Bouts ele precisa de 56 pontos, com 1 de 51, com 2 de 41 e com 3 de 36. Por isso, Bout na mão é um bom motivo pra licitar mais alto."},
		{"icon": "!", "title": "CUIDADOS", "text": "O Petit é fraco: qualquer Trunfo maior o vence, então proteja-o. O Louco nunca vence uma rodada, mas quem o joga guarda os pontos dele. Bouts nunca podem ser devolvidos ao monte."},
	]


static func chaos_intro() -> Array:
	return [
		{"icon": "♠ ♥ ◆ ♣", "title": "GANHE RODADAS", "text": "Cada nível tem 8 cartas e um modificador sorteado que muda as regras. Em cada rodada todo mundo joga 1 carta: vence a maior do naipe e o Trunfo corta. Quem vence leva o pote."},
		{"icon": "◎ ▲ ◎", "title": "APOSTE, PASSE OU DESISTA", "text": "Antes de cada rodada todo mundo paga o blind. Na sua vez você pode PASSAR, AUMENTAR, PAGAR ou DESISTIR. Só quem fica joga carta. Aumente com uma mão fraca e, se todo mundo desistir, o pote é seu sem mostrar nada: isso é um blefe.", "color": Color("#5EEAD4")},
		{"icon": "✦ ⚡ ★", "title": "BÔNUS E COMBOS", "text": "Cartas fortes, modificadores e combos rendem um prêmio extra da banca, como 3 Trunfos, 3 figuras ou 3 cartas seguidas do mesmo naipe. Ganhar rodadas seguidas multiplica o prêmio. Suas fichas na mesa são seu placar: saia quando quiser levando a stack.", "color": Color("#FF9A3D")},
	]


static func chaos() -> Array:
	return [
		{"icon": "◎", "title": "A MESA", "text": "Você senta com uma stack de 20 blinds e joga sem fim: a cada 8 rodadas as cartas são distribuídas de novo e um novo modificador é sorteado. Suas fichas na mesa são seu placar. Saia quando quiser e leve a stack de volta pra sua carteira. Ficou sem fichas pro blind? Recompre ou saia. Rivais que quebram são trocados por jogadores novos."},
		{"icon": "▲", "title": "APOSTAS A CADA RODADA", "text": "Todo mundo paga o blind, a aposta mínima da mesa. O botão (D) gira a cada rodada e fala por último. Na sua vez: PASSAR se ninguém aumentou, AUMENTAR no mínimo mais 1 blind até o all-in, PAGAR pra igualar ou DESISTIR. Cada rodada permite até 2 aumentos e as fichas ficam na frente de cada jogador até fechar a rodada de apostas, quando vão juntas pro pote.", "color": Color("#5EEAD4")},
		{"icon": "✕", "title": "DESISTIR E BLEFAR", "text": "Quem desiste perde o que pôs, não joga carta e descarta a carta mais fraca, virada, então todas as mãos continuam do mesmo tamanho. Se todo mundo desistir, o último leva o pote sem jogar: o blefe funcionou. O painel de aposta mostra se a sua mão está fraca, média, boa ou forte pra essa rodada.", "color": Color("#FF6F86")},
		{"icon": "✦", "title": "MODIFICADOR DO NÍVEL", "text": "Todo nível sorteia UM modificador. Ele pode valer no nível inteiro, e você vê a regra logo no início, ou só numa rodada, que é surpresa e aparece quando começa, antes das apostas. As cartas afetadas mostram o valor real direto na carta.", "color": Color("#C792EA")},
		{"icon": "★", "title": "PRÊMIO DA BANCA E COMBOS", "text": "Os pontos das cartas da rodada viram fichas extras pagas pela banca a quem vence: cada ponto vale um quarto do blind. Modificadores e combos aumentam esse prêmio. Sequência: 2 rodadas seguidas ×1,25, 3 seguidas ×1,5 e 4 ou mais ×2. Cortado quebra a sequência de alguém, Corte de Rei corta um Rei com Trunfo, Chuva de Trunfos são 3 ou mais Trunfos na mesa (×2), Realeza são 3 ou mais figuras (×1,5) e Escada são 3 cartas seguidas do mesmo naipe.", "color": Color("#FF9A3D")},
		{"icon": "⏱", "title": "CARTAS E RELÓGIO", "text": "As regras de carta são as do Vanilla: seguir o naipe e cortar com Trunfo se não tiver. No Caos você não é obrigado a cobrir com um Trunfo maior, então qualquer Trunfo vale e você decide se quer ganhar a rodada. O Louco nunca vence, a não ser no modificador O Louco Vence. Você tem 10 segundos pra jogar a carta; estourou, jogamos a mais fraca."},
	]
