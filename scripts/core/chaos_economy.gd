class_name ChaosEconomy
extends RefCounted
## Economia de fichas (lógica pura). Números calculados por simulação, ver docs/ECONOMIA.md.
##
## - Fichas não valem dinheiro e não podem ser sacadas.
## - Fontes: saldo inicial, recarga diária, compra de pacotes, vitórias contra os bots.
## - Ralos: taxa da casa em cada pote e o que os jogadores perdem pros bots.

const START_FICHAS := 1500        # 3 entradas da mesa Iniciante (blind 10, stack 400)
const DAILY_MIN := 400            # abaixo disso (não paga nem a entrada mais barata) libera a recarga
const DAILY_AMOUNT := 500         # 1 entrada Iniciante + folga
const RAKE_PCT := 0.03            # taxa da casa sobre o pote quando há disputa de cartas
const RAKE_CAP_BLINDS := 1.5      # teto da taxa por rodada, em blinds
const BOT_STACK_BLINDS := [30, 60]  # bot novo senta com 30 a 60 blinds
const BUY_IN_BLINDS := 40           # stack padrão: 40 blinds (20 blinds quebra em ~18 rodadas por variância)

## price_cents em centavos de real. Compras são SIMULADAS por enquanto.
const PACKS := [
	{"id": "punhado", "name": "Punhado", "price_cents": 490, "fichas": 750, "tag": ""},
	{"id": "cofre", "name": "Cofre", "price_cents": 1990, "fichas": 3600, "tag": "POPULAR"},
	{"id": "bau", "name": "Baú", "price_cents": 4990, "fichas": 9750, "tag": ""},
	{"id": "tesouro", "name": "Tesouro", "price_cents": 9990, "fichas": 21000, "tag": "MELHOR CUSTO"},
]


static func today() -> String:
	return Time.get_date_string_from_system(true)


static func price_text(cents: int) -> String:
	return "R$ %d,%02d" % [cents / 100, cents % 100]


## Fichas por real gasto (pra mostrar o bônus dos pacotes maiores).
static func fichas_per_real(pack: Dictionary) -> float:
	return float(pack["fichas"]) / (float(pack["price_cents"]) / 100.0)


## Bônus do pacote em relação ao pacote base (Punhado).
static func bonus_pct(pack: Dictionary) -> int:
	var base := fichas_per_real(PACKS[0])
	return int(round((fichas_per_real(pack) / base - 1.0) * 100.0))


static func daily_available(profile: Dictionary) -> bool:
	return int(profile["fichas"]) < DAILY_MIN and str(profile.get("daily_on", "")) != today()


static func claimed_today(profile: Dictionary) -> bool:
	return str(profile.get("daily_on", "")) == today()


static func claim_daily(profile: Dictionary) -> int:
	if not daily_available(profile):
		return 0
	profile["fichas"] = int(profile["fichas"]) + DAILY_AMOUNT
	profile["daily_on"] = today()
	return DAILY_AMOUNT


## Compra simulada: credita as fichas e registra o gasto (nada é cobrado de verdade).
static func buy_simulated(profile: Dictionary, pack_id: String) -> int:
	for pk in PACKS:
		if pk["id"] == pack_id:
			profile["fichas"] = int(profile["fichas"]) + int(pk["fichas"])
			profile["spent_cents"] = int(profile.get("spent_cents", 0)) + int(pk["price_cents"])
			profile["purchases"] = int(profile.get("purchases", 0)) + 1
			return int(pk["fichas"])
	return 0


static func rake_of(pot: float, blind: int) -> float:
	return minf(roundf(pot * RAKE_PCT), roundf(RAKE_CAP_BLINDS * float(blind)))
