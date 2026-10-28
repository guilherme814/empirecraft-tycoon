class_name Market
extends RefCounted
## Mercado: expectativa de qualidade crescente, tamanho por categoria, tendências e concorrentes.

const COMPETITORS := ["Nova Corp", "Helix Labs", "Orbital", "Kairo Systems", "Zenite"]

var rng: RandomNumberGenerator
var comp_products: Array = []   # {id, company, cat, quality, born}
var trends: Array = []          # {cat, mult, until}
var _next_id: int = 1

func _init(p_rng: RandomNumberGenerator) -> void:
	rng = p_rng

## Concorrentes iniciais: o jogador nunca começa sozinho no mercado.
func seed_competitors(day: int) -> void:
	for cat in GameData.categories():
		for i in 2:
			var c := launch_competitor(cat.id, day)
			c.quality = expectation(day) * rng.randf_range(0.9, 1.2)

## Qualidade que o mercado considera "normal" neste dia: sobe com o tempo.
func expectation(day: int) -> float:
	return minf(Rules.EXPECTATION_MAX, Rules.EXPECTATION_START + Rules.EXPECTATION_PER_DAY * float(day))

func trend_mult(cat_id: String, day: int) -> float:
	var m := 1.0
	for t in trends:
		if day < int(t.until) and (t.cat == "all" or t.cat == cat_id):
			m *= float(t.mult)
	return m

func market_size(cat_id: String, day: int) -> float:
	var cat: Dictionary = GameData.category(cat_id)
	if cat.is_empty():
		return 0.0
	var growth := 1.0 + Rules.MARKET_GROWTH_PER_DAY * float(day)
	var month := floori(float(day % Rules.DAYS_IN_YEAR) / float(Rules.DAYS_IN_MONTH))
	var season := 1.35 if month == 10 else 1.0    # "Black Friday"
	return float(cat.base_demand) * growth * season * trend_mult(cat_id, day)

static func decay(age: int, lifetime: float) -> float:
	return maxf(0.08, exp(-float(age) / lifetime))

func competitor_attractiveness(cat_id: String, day: int) -> float:
	var cat: Dictionary = GameData.category(cat_id)
	var exp_q := expectation(day)
	var total := 0.0
	for c in comp_products:
		if c.cat != cat_id:
			continue
		var qf := pow(clampf(float(c.quality) / exp_q, 0.0, 3.0), 3.0)
		total += qf * decay(day - int(c.born), float(cat.lifetime))
	return total

func competitor_count(cat_id: String) -> int:
	var n := 0
	for c in comp_products:
		if c.cat == cat_id:
			n += 1
	return n

func add_trend(cat_id: String, mult: float, days: int, day: int) -> void:
	trends.append({"cat": cat_id, "mult": mult, "until": day + days})

func launch_competitor(cat_id: String, day: int) -> Dictionary:
	var c := {"id": _next_id, "company": COMPETITORS[rng.randi() % COMPETITORS.size()], "cat": cat_id,
		"quality": expectation(day) * rng.randf_range(0.8, 1.3), "born": day}
	_next_id += 1
	comp_products.append(c)
	return c

func tick(day: int) -> void:
	for t in trends.duplicate():
		if day >= int(t.until):
			trends.erase(t)
	for cat in GameData.categories():
		if rng.randf() < 1.0 / 140.0:
			launch_competitor(cat.id, day)
	for c in comp_products.duplicate():
		var cat: Dictionary = GameData.category(c.cat)
		if day - int(c.born) > int(float(cat.lifetime) * 2.5):
			comp_products.erase(c)

func to_dict() -> Dictionary:
	return {"comp": comp_products, "trends": trends, "next": _next_id}

func load_dict(d: Dictionary) -> void:
	comp_products = d.get("comp", []).duplicate(true)
	trends = d.get("trends", []).duplicate(true)
	_next_id = int(d.get("next", 1))
