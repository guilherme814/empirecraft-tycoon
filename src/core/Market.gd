class_name Market
extends RefCounted
## Mercado: expectativa de qualidade crescente, tamanho por categoria, tendências e concorrentes.


var rng: RandomNumberGenerator
var comp_products: Array = []   # {id, company, cat, quality, born}
var trends: Array = []          # {cat, mult, until}
var rivals: Array = []          # empresas concorrentes (ver seed_rivals)
var macro: float = 1.0          # humor geral da economia (1.0 = neutro)
var sentiment: float = 1.0      # confiança do consumidor
var inflation: float = 0.025    # inflação anual esperada
var supply_chain: float = 1.0   # saúde da cadeia de suprimentos (menor = escassez)
var fashion: Dictionary = {}    # cor da moda: {color, until}
var _next_id: int = 1

func _init(p_rng: RandomNumberGenerator) -> void:
	rng = p_rng

## Concorrentes iniciais: o jogador nunca começa sozinho no mercado.
func seed_competitors(day: int) -> void:
	seed_rivals()
	for cat in GameData.categories():
		for i in 2:
			var c := launch_competitor(cat.id, day)
			c.quality = expectation(day) * rng.randf_range(0.9, 1.2)

## Qualidade que o mercado considera "normal" neste dia: sobe com o tempo.
func expectation(day: int) -> float:
	return minf(Rules.EXPECTATION_MAX, Rules.EXPECTATION_START + Rules.EXPECTATION_PER_DAY * float(day))

## Efeito da economia na demanda: confiança do consumidor e ciclo macro (neutro = 1.0).
func economy_factor() -> float:
	var s := clampf(1.0 + (sentiment - 1.0) * 0.6, 0.7, 1.3)
	var m := clampf(1.0 + (macro - 1.0) * 0.8, 0.7, 1.3)
	return s * m

## Pressão de custos: escassez de componentes encarece a produção (1.0 = neutro).
func cost_pressure() -> float:
	return clampf(1.0 + (1.0 - supply_chain) * 0.5, 0.9, 1.3)

func apply_macro_shift(delta_macro: float, delta_sentiment: float = 0.0, delta_supply: float = 0.0, delta_inflation: float = 0.0) -> void:
	macro = clampf(macro + delta_macro, 0.55, 1.6)
	sentiment = clampf(sentiment + delta_sentiment, 0.6, 1.5)
	supply_chain = clampf(supply_chain + delta_supply, 0.65, 1.5)
	inflation = clampf(inflation + delta_inflation + maxf(0.0, delta_macro) * 0.04, 0.01, 0.15)

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
	var season := 1.28 if month == 10 else 1.0    # "Black Friday"
	return float(cat.base_demand) * growth * season * trend_mult(cat_id, day) * economy_factor()

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

func best_quality(cat_id: String) -> float:
	var best := 0.0
	for c in comp_products:
		if c.cat == cat_id:
			best = maxf(best, float(c.quality))
	return best

func competitor_count(cat_id: String) -> int:
	var n := 0
	for c in comp_products:
		if c.cat == cat_id:
			n += 1
	return n

func add_trend(cat_id: String, mult: float, days: int, day: int) -> void:
	trends.append({"cat": cat_id, "mult": mult, "until": day + days})

func launch_competitor(cat_id: String, day: int) -> Dictionary:
	var ri := _pick_rival(cat_id)
	var r: Dictionary = rivals[ri]
	var q := expectation(day) * rng.randf_range(0.8, 1.3) * float(r.tech) * float(r.get("q_mult", 1.0))
	var cat: Dictionary = GameData.category(cat_id)
	var price := float(cat.fair_price) * (0.5 + q / 100.0) * rng.randf_range(0.9, 1.1) * float(r.get("price_mult", 1.0))
	var c := {"id": _next_id, "company": r.name, "rival": ri, "cat": cat_id, "quality": q, "price": price, "born": day}
	_next_id += 1
	comp_products.append(c)
	return c

# ───────── empresas rivais e bolsa ─────────

const SHARES := 1000000.0
const HIST_LEN := 120

func seed_rivals() -> void:
	rivals.clear()
	for d in GameData.rivals():
		var value: float = float(d.get("value", rng.randf_range(4.0e6, 11.0e6))) * rng.randf_range(0.9, 1.1)
		rivals.append({"name": d.name, "aggr": float(d.aggr), "focus": d.focus, "strategy": d.get("strategy", ""),
			"price_mult": float(d.get("price_mult", 1.0)), "q_mult": float(d.get("q_mult", 1.0)), "desc": d.get("desc", ""),
			"tech": float(d.get("tech", 1.0)), "cash": value * 0.25,
			"value": value, "rev_year": value / 6.0, "rev_month": 0.0, "shock": 0.0,
			"price": value / SHARES, "hist": [value / SHARES]})

## Aceita foco antigo (texto) e novo (lista de categorias).
static func focus_has(r: Dictionary, cat_id: String) -> bool:
	var f: Variant = r.get("focus", "")
	if f is Array:
		return (f as Array).has(cat_id)
	return str(f) == cat_id

func _pick_rival(cat_id: String) -> int:
	if rivals.is_empty():
		seed_rivals()
	var best := 0
	var best_w := -1.0
	for i in rivals.size():
		var w: float = rng.randf() * float(rivals[i].aggr) * (2.0 if focus_has(rivals[i], cat_id) else 0.35)
		if w > best_w:
			best_w = w
			best = i
	return best

func rival_index(name: String) -> int:
	for i in rivals.size():
		if rivals[i].name == name:
			return i
	return -1

## Atratividade de cada produto rival (mesma fórmula, preço incluído).
func comp_attr(c: Dictionary, day: int) -> float:
	var cat: Dictionary = GameData.category(c.cat)
	var qf := pow(clampf(float(c.quality) / expectation(day), 0.0, 3.0), 3.0)
	var fair := float(cat.fair_price) * (0.5 + float(c.quality) / 100.0)
	var pf := clampf(pow(fair / maxf(float(c.get("price", fair)), 1.0), 2.2), 0.0, 4.0)
	return qf * pf * decay(day - int(c.born), float(cat.lifetime))

func add_rival_revenue(ri: int, rev: float) -> void:
	if ri >= 0 and ri < rivals.size():
		rivals[ri].rev_month = float(rivals[ri].rev_month) + rev

## Fim de mês: lucro, caixa, tecnologia e valor de cada rival.
func month_end() -> void:
	macro = clampf(macro + (1.0 - macro) * 0.12 + rng.randf_range(-0.09, 0.09), 0.65, 1.45)
	sentiment = clampf(sentiment + (1.0 - sentiment) * 0.10 + rng.randf_range(-0.07, 0.07), 0.7, 1.4)
	inflation = clampf(inflation + (0.025 - inflation) * 0.08 + (macro - 1.0) * 0.01 + rng.randf_range(-0.004, 0.006), 0.01, 0.12)
	supply_chain = clampf(supply_chain + (1.0 - supply_chain) * 0.15 + rng.randf_range(-0.05, 0.05), 0.7, 1.35)
	for r in rivals:
		var rev := float(r.rev_month)
		r.rev_year = lerpf(float(r.rev_year), rev * 12.0, 0.25)
		var profit := rev * 0.2 * float(r.tech) - 20000.0
		r.cash = maxf(0.0, float(r.cash) + profit)
		var target := float(r.cash) + 10.0 * maxf(0.0, profit * 12.0) + 2.0 * float(r.rev_year)
		r.value = lerpf(float(r.value), target, 0.2)
		r.tech = float(r.tech) + 0.004 * float(r.aggr) + (0.002 if profit > 0.0 else 0.0)
		r.rev_month = 0.0
		if rng.randf() < 0.08:
			r.shock = rng.randf_range(-0.2, 0.18)

## Preço das ações: tende ao valor da empresa, com ruído, humor geral e choques.
func price_tick() -> void:
	for r in rivals:
		var target := float(r.value) / SHARES * macro * (1.0 + float(r.shock))
		var p := float(r.price)
		p += (target - p) * 0.06 + p * rng.randf_range(-0.018, 0.018)
		r.price = maxf(0.05, p)
		r.shock = float(r.shock) * 0.97
		var h: Array = r.hist
		h.append(r.price)
		if h.size() > HIST_LEN:
			h.pop_front()

func tick(day: int) -> void:
	price_tick()
	if fashion.is_empty() or day >= int(fashion.until):
		var cols: Array = GameData.designs().colors
		fashion = {"color": str(cols[rng.randi() % cols.size()].id), "until": day + 120}
	if day % Rules.DAYS_IN_MONTH == 0:
		month_end()
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
	return {"comp": comp_products, "trends": trends, "next": _next_id, "rivals": rivals, "macro": macro, "fashion": fashion,
		"sentiment": sentiment, "inflation": inflation, "supply_chain": supply_chain}

func load_dict(d: Dictionary) -> void:
	comp_products = d.get("comp", []).duplicate(true)
	trends = d.get("trends", []).duplicate(true)
	_next_id = int(d.get("next", 1))
	macro = float(d.get("macro", 1.0))
	sentiment = float(d.get("sentiment", 1.0))
	inflation = float(d.get("inflation", 0.025))
	supply_chain = float(d.get("supply_chain", 1.0))
	fashion = d.get("fashion", {}).duplicate()
	rivals = d.get("rivals", []).duplicate(true)
	if rivals.is_empty():
		seed_rivals()
	for c in comp_products:
		if not c.has("rival"):
			c["rival"] = maxi(0, rival_index(str(c.get("company", ""))))
		if not c.has("price"):
			c["price"] = float(GameData.category(c.cat).fair_price) * (0.5 + float(c.quality) / 100.0)
