class_name HelpContent
extends RefCounted
## Textos das ajudas em passos (um parágrafo por passo, sem quebras de linha), usados pelo
## StepsModal. Clássico segue o Jeu de Tarot; o Blitz tem as próprias regras.

static func vanilla() -> Array:
	return [
		{"icon": "♠ ♥ ◆ ♣", "title": "O BÁSICO", "text": "Uma rodada é uma jogada de 4 cartas, uma de cada jogador. Quem jogou a carta mais forte leva as 4 e os pontos delas. Você tem que jogar o naipe da primeira carta. Se não tiver, tem que jogar um arcano maior, e se também não tiver arcano maior joga qualquer carta. O arcano maior ganha de qualquer naipe e, entre arcanos maiores, o número maior ganha. Se alguém já cortou, quem também corta deve subir com um arcano maior mais alto, se tiver. Em cada naipe, do menor pro maior: Ás, 2 a 10, Valete, Cavaleiro, Rainha e Rei."},
		{"icon": "★ 1 21", "title": "OS BOUTS", "text": "São as 3 cartas mais valiosas: o arcano maior 1 (Le Petit), o arcano maior 21 (Le Monde) e O Louco. Cada um vale 4,5 pontos, como um Rei. O Louco nunca ganha a rodada: quem o joga fica com ele e só na última rodada ele vai pra quem ganhar. Os Bouts que o Atacante captura baixam a meta dele."},
		{"icon": "⚔", "title": "LICITAÇÃO: QUEM JOGA SOZINHO", "text": "Cada um passa ou dá um lance. O lance mais alto vira o Atacante: ele joga sozinho contra os outros 3, a Defesa. Do mais leve ao mais arriscado: Petite ×1, Garde ×2, Garde Sans ×4 e Garde Contre ×6. O número é quanto você ganha ou perde. O lance não custa nada, é só dizer que você confia na sua mão."},
		{"icon": "▣", "title": "O MONTE", "text": "São 6 cartas viradas no meio da mesa. Na Petite e na Garde, o Atacante pega o monte, olha e devolve 6 cartas da mão, nunca Reis nem Bouts. Na Garde Sans ele não pega e os pontos do monte contam pra ele. Na Garde Contre ele também não pega e os pontos vão pra Defesa."},
		{"icon": "✓", "title": "COMO SE GANHA", "text": "O Atacante precisa somar 56 pontos sem Bout, 51 com 1 Bout, 41 com 2 ou 36 com 3, usando as cartas que ganhar. Se conseguir, ganha pontos dos outros 3. Se não, paga."},
		{"icon": "✦", "title": "BÔNUS", "text": "Só o Atacante escolhe. Poignée: com 10 ou mais arcanos maiores, ele pode mostrá-los pra ganhar pontos extras. Chelem: ganhar as 18 rodadas. Se avisar antes e conseguir: +400; se avisar e falhar: −200; sem avisar, se acontecer: +200. Petit na última rodada: quem ganhar a última rodada com o arcano maior 1 nela leva +10.", "color": UIKit.MODIFIER},
	]


static func bout() -> Array:
	return [
		{"icon": "★", "title": "O QUE É BOUT?", "text": "Bout, que se lê \"bu\", é o nome das 3 cartas mais valiosas: Le Petit (o arcano maior 1), Le Monde (o arcano maior 21) e O Louco. Cada Bout vale 4,5 pontos, o mesmo que um Rei. E os Bouts que o Atacante captura baixam a meta dele: com 0 Bouts ele precisa de 56 pontos, com 1 de 51, com 2 de 41 e com 3 de 36. Por isso, Bout na mão é um bom motivo pra licitar mais alto."},
		{"icon": "!", "title": "CUIDADOS", "text": "O Petit é fraco: qualquer arcano maior mais alto o vence, então proteja-o. O Louco nunca vence uma rodada, mas quem o joga guarda os pontos dele. Bouts nunca podem ser devolvidos ao monte."},
	]


static func blitz_intro() -> Array:
	return [
		{"icon": "♠ ♥ ◆ ♣", "title": "GANHE JOGADAS", "text": "Cada Ritual tem 8 jogadas de 1 carta por jogador. Vence a maior do naipe e o arcano maior corta, como no Clássico. Cada carta tem pontos (mostrados nela): quem vence a jogada leva fichas dos rivais por esses pontos. Um modificador sorteado muda as regras da jogada, sempre anunciado antes."},
		{"icon": "1 2 3", "title": "PREPARAÇÃO: SACRIFÍCIO E PROFECIA", "text": "No começo do Ritual você recebe 10 cartas e sacrifica 2. Depois faz a sua profecia: quantas jogadas vai ganhar (0 a 8), e paga a entrada. Todos revelam juntos. Acertou o número exato: leva o pote. Errou por 1: recebe metade da entrada de volta. A estrela ★ mostra a profecia que combina com a sua mão.", "color": UIKit.TURN},
		{"icon": "◎ ×2", "title": "JOGUE PRA FECHAR A CONTA", "text": "Chegou na profecia? Agora é fugir das jogadas que sobraram, jogando fora as suas cartas fortes debaixo de cartas maiores. Ninguém acertou? O pote acumula pro próximo Ritual. Acertou 3 vezes seguidas? A casa paga um prêmio especial.", "color": UIKit.MONEY},
	]


static func blitz() -> Array:
	return [
		{"icon": "◎", "title": "A MESA", "text": "Você senta com o buy-in da sala (40 blinds) e joga sem fim: a cada Ritual as cartas são distribuídas de novo e os modificadores são sorteados. Suas fichas na mesa são seu placar. Saia quando quiser e leve a stack de volta pra sua carteira. Rivais que quebram são trocados por jogadores novos."},
		{"icon": "✋", "title": "PREPARAÇÃO: SACRIFÍCIO", "text": "Você recebe 10 cartas, não 8. Antes de saber a regra da 1ª jogada, escolhe 2 pra sacrificar. O resto do Ritual você joga com as 8 que sobraram.", "color": UIKit.INFO},
		{"icon": "1 2 3", "title": "PREPARAÇÃO: PROFECIA", "text": "Com a mão na tela, você diz quantas jogadas vai ganhar, de 0 a 8. Cada jogador paga a entrada de 8 blinds. A sua profecia é sua: as dos rivais ficam em segredo até o fim do Ritual, e só se vê quantas jogadas cada um já venceu. A estrela ★ é uma sugestão baseada na força da sua mão. Profecias altas pesam mais no pote: 0 a 2 valem ×1, 3 e 4 valem ×1,5 e 5 ou mais valem ×2.", "color": UIKit.TURN},
		{"icon": "✓", "title": "QUEM LEVA O POTE", "text": "Acertou o número exato: divide o pote com os outros acertos, pelo peso (entrada × dificuldade da profecia). Errou por 1: recebe metade da entrada de volta. Errou por 2 ou mais: perde a entrada. Ninguém acertou: o pote inteiro acumula pro próximo Ritual, o jackpot cresce e a casa cobra uma pequena taxa só quando o pote é pago. Acertando o número exato 3 vezes seguidas, a casa paga um prêmio especial de sequência.", "color": UIKit.OK},
		{"icon": "↯", "title": "JOGAR PRA FECHAR A CONTA", "text": "Sob o avatar de cada jogador aparece o progresso ao vivo, como 1/3: verde no alvo, vermelho se estourou ou não dá mais tempo. Já no alvo, você quer perder as jogadas que sobram. Jogue a carta mais forte que ainda perde, debaixo de uma carta maior, pra não ser forçado a ganhar mais tarde. Se falta ganhar, guarde os arcanos maiores altos.", "color": UIKit.COMBO},
		{"icon": "◇", "title": "FICHAS DAS CARTAS", "text": "Além da profecia, cada jogada paga fichas: quem vence leva dos rivais o valor em pontos das cartas que estavam na mesa (os pontos aparecem na carta). É um tempero pequeno perto do pote, mas soma: vencer uma jogada cheia de Reis e arcanos maiores rende, e perder uma paga a conta. Isso também pesa na profecia: fugir de uma jogada rica pode custar menos que vencer sem querer.", "color": UIKit.GAIN},
		{"icon": "✦", "title": "MODIFICADORES", "text": "Cada Ritual usa os 8, um por jogada, sem repetir, sempre anunciado em tela cheia antes de qualquer decisão. Loucura, Oposição, Silêncio e Pitagórico mudam quem vence. Transmutação conta 2 vitórias pra quem ganhar. Saque, Assalto e Maldição movem 3 blinds, sempre o mesmo total em qualquer mesa. Nenhum mexe no valor das cartas, e todos valem só pra uma jogada.", "color": UIKit.MODIFIER},
		{"icon": "⏱", "title": "CARTAS E RELÓGIO", "text": "Siga o naipe e corte com arcano maior se não tiver, e qualquer arcano maior vale (menos no Pitagórico, onde qualquer carta pode ser jogada). O Louco nunca vence, a não ser na Loucura. Relógio: 10 s pra jogar a carta, 18 s pro sacrifício, 15 s pra profecia e 12 s pras apostas. Estourou, jogamos por você: a carta mais fraca, as 2 mais fracas, a profecia que estiver na tela, ou passar (desistir, se tiver que pagar)."},
	]
