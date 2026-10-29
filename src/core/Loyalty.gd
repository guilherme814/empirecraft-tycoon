class_name Loyalty
extends RefCounted
## Lealdade à marca (0..100): sobe com lançamentos bem avaliados e produtos sem falhas,
## despenca com defeitos graves e recalls. Cada 10% garante pré-vendas de fãs no dia
## do lançamento de qualquer produto novo e dá consciência de marca inicial.

const START := 5.0
const FAN_UNITS_PER_10 := 0.18      # fração da demanda diária da categoria por 10% de lealdade
const MAX_LOG := 12
const TIERS := [
	{"min": 0.0, "name": "Desconhecida"},
	{"min": 15.0, "name": "Curiosos"},
	{"min": 30.0, "name": "Entusiastas"},
	{"min": 50.0, "name": "Fãs"},
	{"min": 70.0, "name": "Devotos"},
	{"min": 90.0, "name": "Culto da marca"},
]

static func tier(v: float) -> String:
	var out := "Desconhecida"
	for t in TIERS:
		if v >= float(t.min):
			out = str(t.name)
	return out

static func change(c: Company, delta: float, why: String) -> void:
	var before := c.loyalty
	c.loyalty = clampf(c.loyalty + delta, 0.0, 100.0)
	var real := c.loyalty - before
	if absf(real) < 0.05:
		return
	c.loyalty_log.append({"day": c.day, "d": snappedf(real, 0.1), "why": why})
	while c.loyalty_log.size() > MAX_LOG:
		c.loyalty_log.pop_front()

## Unidades vendidas aos fãs no dia do lançamento.
static func preorders(c: Company, cat_id: String) -> int:
	var cat: Dictionary = GameData.category(cat_id)
	if cat.is_empty():
		return 0
	var size := c.market.market_size(cat_id, c.day)
	return int(floor(c.loyalty / 10.0 * size * FAN_UNITS_PER_10))

static func sales_mult(c: Company) -> float:
	return 1.0 + 0.12 * c.loyalty / 100.0

static func initial_awareness(c: Company) -> float:
	return 0.35 * c.loyalty / 100.0

## Resultado do lançamento (chamado por Reviews.launch).
static func on_launch(c: Company, p: Product) -> void:
	var d := 0.0
	if p.critic >= 80.0 and p.rating >= 4.0:
		d = 8.0
	elif p.critic >= 65.0 and p.rating >= 3.3:
		d = 4.0
	elif p.critic >= 50.0 and p.rating >= 2.7:
		d = 1.0
	elif p.critic < 45.0 or p.rating < 2.5:
		d = -6.0
	else:
		d = -1.0
	if p.promise_gap > 0.0:
		d -= 3.0
	var sev := Lab.severity_sum(p)
	if sev >= 3:
		d -= 2.0
	if d != 0.0:
		change(c, d, ("%s aclamado" if d > 0.0 else "%s decepcionou") % p.pname)

static func on_recall(c: Company, p: Product) -> void:
	change(c, -4.0, "Recall de %s" % p.pname)

## Mensal: fãs recompensam produtos bons e punem falhas graves abertas.
static func monthly(c: Company) -> void:
	var newest := -99999
	for p in c.released_products():
		newest = maxi(newest, p.release_day)
		var sev := Lab.severity_sum(p)
		if sev >= 3 and p.ema_units >= 0.5:
			change(c, -minf(3.0, 0.5 * float(sev)), "Falhas graves em %s" % p.pname)
		elif p.rating_n >= 5 and p.rating >= 4.2 and p.ema_units >= 0.5:
			change(c, 0.5, "%s encanta os clientes" % p.pname)
		elif p.rating_n >= 5 and p.rating < 2.5:
			change(c, -0.8, "%s irrita os clientes" % p.pname)
	if c.day - newest > 240:
		change(c, -0.4, "Sem novidades há muito tempo")
