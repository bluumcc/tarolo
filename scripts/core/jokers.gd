class_name Jokers
extends RefCounted
## Catálogo de Curingas passivos da Loja Arcana (Modo Arcade).
## Cada curinga é consultado pelo `Scoring` / `MatchEngine` via `id`.

const MAX_SLOTS := 5

const CATALOG := {
	"louco": {"name": "O Louco", "desc": "+4 Mult em toda vaza vencida.", "price": 4, "rarity": "comum"},
	"mesa_cheia": {"name": "Mesa Cheia", "desc": "+8 Fichas por carta na vaza.", "price": 4, "rarity": "comum"},
	"as_oculto": {"name": "Ás Oculto", "desc": "Cada Ás na vaza dá +25 Fichas.", "price": 5, "rarity": "comum"},
	"copas_sangrentas": {"name": "Copas Sangrentas", "desc": "+3 Mult por carta de Copas na vaza.", "price": 5, "rarity": "comum"},
	"ganancia": {"name": "Ganância", "desc": "+2 Ouro por vaza vencida.", "price": 5, "rarity": "comum"},
	"eclipse": {"name": "Eclipse", "desc": "Arcanos Maiores valem +30 Fichas.", "price": 6, "rarity": "incomum"},
	"espelho": {"name": "Espelho Negro", "desc": "Bônus de Foil dobrado (+100 Fichas).", "price": 6, "rarity": "incomum"},
	"monarca": {"name": "Monarca", "desc": "x1,5 Mult se a vaza foi vencida por um Rei.", "price": 6, "rarity": "incomum"},
	"caos": {"name": "Caos Ordenado", "desc": "Monopólio de Naipe ativa com uma carta fora do naipe.", "price": 7, "rarity": "incomum"},
	"juros": {"name": "Juros Arcanos", "desc": "Juros no fim da fase: +1 Ouro a cada 4 (máx. 8).", "price": 6, "rarity": "incomum"},
	"escada_ceu": {"name": "Escada ao Céu", "desc": "Sequência Caótica passa a x3,5 Mult.", "price": 8, "rarity": "raro"},
	"prisma": {"name": "Prisma", "desc": "Polychrome passa a x3,0 Mult.", "price": 8, "rarity": "raro"},
	"torre": {"name": "A Torre", "desc": "x2,0 Mult em vazas com 2+ cartas modificadas.", "price": 9, "rarity": "raro"},
}


static func info(id: String) -> Dictionary:
	return CATALOG.get(id, {"name": id, "desc": "", "price": 0, "rarity": "comum"})


static func all_ids() -> Array:
	return CATALOG.keys()


static func sell_value(id: String) -> int:
	return maxi(1, int(info(id)["price"]) / 2)
