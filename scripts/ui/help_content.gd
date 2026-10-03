class_name HelpContent
extends RefCounted
## Textos das ajudas em passos (um parágrafo por passo, sem quebras de linha), usados pelo
## StepsModal. Vanilla segue o Jeu de Tarot; o Caos tem as próprias regras.

static func vanilla() -> Array:
	return [
		{"icon": "♠ ♥ ◆ ♣", "title": "O BÁSICO", "text": "Uma rodada é uma jogada de 4 cartas, uma de cada jogador. Quem jogou a carta mais forte leva as 4 e os pontos delas. Você tem que jogar o naipe da primeira carta. Se não tiver, tem que jogar um Trunfo, e se também não tiver Trunfo joga qualquer carta. O Trunfo ganha de qualquer naipe e, entre Trunfos, o número maior ganha. Se alguém já cortou, quem também corta deve subir com um Trunfo maior, se tiver. Em cada naipe, do menor pro maior: Ás, 2 a 10, Valete, Cavaleiro, Rainha e Rei."},
		{"icon": "★ 1 21", "title": "OS BOUTS", "text": "São as 3 cartas mais valiosas: o Trunfo 1 (Le Petit), o Trunfo 21 (Le Monde) e O Louco. Cada um vale 4,5 pontos, como um Rei. O Louco nunca ganha a rodada: quem o joga fica com ele e só na última rodada ele vai pra quem ganhar. Os Bouts que o Atacante captura baixam a meta dele."},
		{"icon": "⚔", "title": "LICITAÇÃO: QUEM JOGA SOZINHO", "text": "Cada um passa ou dá um lance. O lance mais alto vira o Atacante: ele joga sozinho contra os outros 3, a Defesa. Do mais leve ao mais arriscado: Petite ×1, Garde ×2, Garde Sans ×4 e Garde Contre ×6. O número é quanto você ganha ou perde. O lance não custa nada, é só dizer que você confia na sua mão."},
		{"icon": "▣", "title": "O MONTE", "text": "São 6 cartas viradas no meio da mesa. Na Petite e na Garde, o Atacante pega o monte, olha e devolve 6 cartas da mão, nunca Reis nem Bouts. Na Garde Sans ele não pega e os pontos do monte contam pra ele. Na Garde Contre ele também não pega e os pontos vão pra Defesa."},
		{"icon": "✓", "title": "COMO SE GANHA", "text": "O Atacante precisa somar 56 pontos sem Bout, 51 com 1 Bout, 41 com 2 ou 36 com 3, usando as cartas que ganhar. Se conseguir, ganha pontos dos outros 3. Se não, paga."},
		{"icon": "✦", "title": "BÔNUS", "text": "Só o Atacante escolhe. Poignée: com 10 ou mais Trunfos, ele pode mostrá-los pra ganhar pontos extras. Chelem: ganhar as 18 rodadas. Se avisar antes e conseguir: +400; se avisar e falhar: −200; sem avisar, se acontecer: +200. Petit na última rodada: quem ganhar a última rodada com o Trunfo 1 nela leva +10.", "color": UIKit.MODIFIER},
	]


static func bout() -> Array:
	return [
		{"icon": "★", "title": "O QUE É BOUT?", "text": "Bout, que se lê \"bu\", é o nome das 3 cartas mais valiosas: Le Petit (o Trunfo 1), Le Monde (o Trunfo 21) e O Louco. Cada Bout vale 4,5 pontos, o mesmo que um Rei. E os Bouts que o Atacante captura baixam a meta dele: com 0 Bouts ele precisa de 56 pontos, com 1 de 51, com 2 de 41 e com 3 de 36. Por isso, Bout na mão é um bom motivo pra licitar mais alto."},
		{"icon": "!", "title": "CUIDADOS", "text": "O Petit é fraco: qualquer Trunfo maior o vence, então proteja-o. O Louco nunca vence uma rodada, mas quem o joga guarda os pontos dele. Bouts nunca podem ser devolvidos ao monte."},
	]


static func chaos_intro() -> Array:
	return [
		{"icon": "♠ ♥ ◆ ♣", "title": "GANHE RODADAS", "text": "Cada nível tem 8 cartas e um modificador sorteado que muda as regras. Em cada rodada todo mundo joga 1 carta: vence a maior do naipe e o Trunfo corta. Quem vence leva o pote."},
		{"icon": "◎ ▲ ◎", "title": "APOSTE, PASSE OU DESISTA", "text": "Antes de cada rodada todo mundo paga o blind. Na sua vez você pode PASSAR, AUMENTAR, PAGAR ou DESISTIR. Só quem fica joga carta. Aumente com uma mão fraca e, se todo mundo desistir, o pote é seu sem mostrar nada: isso é um blefe.", "color": UIKit.TURN},
		{"icon": "✦ ⚡ ★", "title": "BÔNUS E COMBOS", "text": "Cartas fortes, modificadores e combos rendem um prêmio extra pago pelos rivais, como 3 Trunfos, 3 figuras ou 3 cartas seguidas do mesmo naipe. Ganhar rodadas seguidas multiplica o prêmio. Suas fichas na mesa são seu placar: saia quando quiser levando a stack.", "color": UIKit.COMBO},
	]


static func chaos() -> Array:
	return [
		{"icon": "◎", "title": "A MESA", "text": "Você senta com uma stack de 40 blinds e joga sem fim: a cada 8 rodadas as cartas são distribuídas de novo e um novo modificador é sorteado. Suas fichas na mesa são seu placar. Saia quando quiser e leve a stack de volta pra sua carteira. Ficou sem fichas pro blind? Recompre ou saia. Rivais que quebram são trocados por jogadores novos."},
		{"icon": "▲", "title": "APOSTAS A CADA RODADA", "text": "Todo mundo paga o blind, a aposta mínima da mesa. O D dourado marca o dealer: joga a carta primeiro e fala por último nas apostas (quem fala primeiro é o jogador logo depois dele). Na sua vez: PASSAR se ninguém aumentou, AUMENTAR no mínimo mais 1 blind até o all-in (limitado ao que o rival mais forte ainda consegue cobrir), PAGAR pra igualar (com pouca ficha, paga o que tem) ou DESISTIR. Se um rival sem fichas der all-in, o que você pôs além do que ele cobre volta pra você. Cada rodada permite até 4 aumentos (dá pra aumentar em cima de quem aumentou) e as fichas ficam na frente de cada jogador até fechar a rodada de apostas, quando vão juntas pro pote.", "color": UIKit.TURN},
		{"icon": "✕", "title": "DESISTIR E BLEFAR", "text": "Quem desiste perde o que pôs, não joga carta e descarta a carta mais fraca, virada, então todas as mãos continuam do mesmo tamanho. Se todo mundo desistir, o último leva o pote sem jogar: o blefe funcionou. O painel de aposta mostra se a sua mão está fraca, média, boa ou forte pra essa rodada.", "color": UIKit.LOSS},
		{"icon": "✦", "title": "MODIFICADOR DE CADA RODADA", "text": "Toda rodada tem o seu: uma tela cheia explica a regra antes das apostas, sem surpresa nenhuma. São 11 no total, um por rodada sem repetir dentro do nível. As cartas afetadas mostram o valor real direto na carta.", "color": UIKit.MODIFIER},
		{"icon": "★", "title": "PRÊMIO DA BANCA E COMBOS", "text": "Os pontos das cartas da rodada viram fichas extras pagas pelos rivais a quem vence: cada ponto vale um quarto do blind. Modificadores e combos aumentam esse prêmio. Sequência: 2 rodadas seguidas ×1,25, 3 seguidas ×1,5 e 4 ou mais ×2. Cortado quebra a sequência de alguém, Corte de Rei corta um Rei com Trunfo, Chuva de Trunfos são 3 ou mais Trunfos na mesa (×2), Realeza são 3 ou mais figuras (×1,5) e Escada são 3 cartas seguidas do mesmo naipe.", "color": UIKit.COMBO},
		{"icon": "⏱", "title": "CARTAS E RELÓGIO", "text": "As regras de carta são as do Vanilla: seguir o naipe e cortar com Trunfo se não tiver. No Caos você não é obrigado a cobrir com um Trunfo maior, então qualquer Trunfo vale e você decide se quer ganhar a rodada. O Louco nunca vence, a não ser no modificador O Louco Vence. Você tem 10 segundos pra jogar a carta; estourou, jogamos a mais fraca."},
	]


static func blitz_intro() -> Array:
	return [
		{"icon": "♠ ♥ ◆ ♣", "title": "GANHE RODADAS", "text": "Cada nível tem 8 rodadas de 1 carta por jogador. Vence a maior do naipe e o Trunfo corta, como no Vanilla. Cada carta tem pontos (mostrados nela): quem vence a rodada leva fichas dos rivais por esses pontos. Um modificador sorteado muda as regras da rodada, sempre anunciado antes."},
		{"icon": "1 2 3", "title": "DÊ O SEU PALPITE", "text": "Antes de jogar, cada um diz quantas rodadas vai ganhar (0 a 8) e paga a entrada. Todos revelam juntos. Acertou o número exato: leva o pote. Errou por 1: recebe metade da entrada de volta. A estrela ★ mostra o palpite que combina com a sua mão.", "color": UIKit.TURN},
		{"icon": "◎ ×2", "title": "JOGUE PRA FECHAR A CONTA", "text": "Chegou no palpite? Agora é fugir das rodadas que sobraram, jogando fora as suas cartas fortes debaixo de cartas maiores. Se a mão que sobrou é fraca, DOBRE: paga mais uma entrada e o seu peso no pote dobra (dá pra TRIPLICAR depois). Quando um rival dobra, você pode COBRIR pra igualar o peso dele. Ninguém acertou? O pote acumula pro próximo nível. Acertou 3 vezes seguidas? A casa paga um prêmio especial.", "color": UIKit.MONEY},
	]


static func blitz() -> Array:
	return [
		{"icon": "◎", "title": "A MESA", "text": "Você senta com uma stack de 40 blinds e joga sem fim: a cada nível as cartas são distribuídas de novo e um novo modificador é sorteado. Suas fichas na mesa são seu placar. Saia quando quiser e leve a stack de volta pra sua carteira. Rivais que quebram são trocados por jogadores novos."},
		{"icon": "✋", "title": "O DESCARTE", "text": "Você recebe 10 cartas, não 8. Antes de saber a regra da 1ª rodada, escolhe 2 pra descartar — o resto do nível você joga com as 8 que sobraram.", "color": UIKit.INFO},
		{"icon": "1 2 3", "title": "O PALPITE", "text": "No começo do nível você vê a sua mão e diz quantas rodadas vai ganhar, de 0 a 8. Cada jogador paga a entrada de 4 blinds. O seu palpite é seu: os dos rivais ficam em segredo até o fim do nível — só vê quantas rodadas cada um já venceu. A estrela ★ é uma sugestão baseada na força da sua mão. Palpites altos pesam mais no pote: 0 a 2 valem ×1, 3 e 4 valem ×1,5 e 5 ou mais valem ×2.", "color": UIKit.TURN},
		{"icon": "✓", "title": "QUEM LEVA O POTE", "text": "Acertou o número exato: divide o pote com os outros acertos, pelo peso (entrada × dificuldade do palpite). Errou por 1: recebe metade da entrada de volta. Errou por 2 ou mais: perde a entrada. Ninguém acertou: o pote inteiro acumula pro próximo nível, o jackpot cresce e a casa cobra uma pequena taxa só quando o pote é pago. Acertando o número exato 3 vezes seguidas, a casa paga um prêmio especial de sequência.", "color": UIKit.OK},
		{"icon": "↯", "title": "JOGAR PRA FECHAR A CONTA", "text": "Sob o avatar de cada jogador aparece o progresso ao vivo, como 1/3: verde no alvo, vermelho se estourou ou não dá mais tempo. Já no alvo, você quer perder as rodadas que sobram. Jogue a carta mais forte que ainda perde, debaixo de uma carta maior, pra não ser forçado a ganhar mais tarde. Se falta ganhar, guarde os Trunfos altos.", "color": UIKit.COMBO},
		{"icon": "◎ ×2", "title": "DOBRAR E COBRIR", "text": "A partir da 4ª rodada o botão DOBRAR paga mais uma entrada e dobra o seu peso no pote; da 6ª em diante dá pra TRIPLICAR. No máximo 2 lances por nível, e só aparece se ainda dá pra acertar. Quando um RIVAL dobra ou triplica, você pode COBRIR na hora (mesmo custo, mesmo efeito) ou DEIXAR de graça. Vale a pena quando você já está no alvo e sobrou uma mão fraca demais pra ganhar mais uma rodada. Como o palpite dos rivais é segredo, dobrar/cobrir virou a única pista sobre a confiança de cada um — nem sempre é verdade.", "color": UIKit.MONEY},
		{"icon": "◇", "title": "FICHAS DAS CARTAS", "text": "Além do palpite, cada rodada paga fichas: quem vence leva dos rivais o valor em pontos das cartas que estavam na mesa (os pontos aparecem na carta). É um tempero pequeno perto do pote, mas soma: vencer uma rodada cheia de Reis e Trunfos rende, e perder uma paga a conta. Isso também pesa no palpite: fugir de uma rodada rica pode custar menos que vencer sem querer.", "color": UIKit.GAIN},
		{"icon": "✦", "title": "MODIFICADORES", "text": "Toda rodada tem o seu, um dos 9, sempre anunciado em tela cheia antes de qualquer decisão. O Louco Vence e a Rodada Invertida mudam quem vence. A Rodada Dobrada conta 2 vitórias pra quem ganhar. Naipe Fraco/Forte e Cartas Pequenas mudam quanto as cartas pagam. Saque, Assalto ao Líder e Rodada Maldita movem fichas à parte. Todos valem só pra uma rodada.", "color": UIKit.MODIFIER},
		{"icon": "⏱", "title": "CARTAS E RELÓGIO", "text": "As regras de carta são as do Caos: siga o naipe, corte com Trunfo se não tiver, qualquer Trunfo vale. O Louco nunca vence, a não ser no modificador O Louco Vence. Você tem 10 segundos por jogada; estourou, jogamos a mais fraca."},
	]
