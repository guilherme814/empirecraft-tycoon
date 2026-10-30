class_name Economy
extends RefCounted
## Central econômica: demonstrativo (DRE), fluxo de caixa, desempenho por produto e equilíbrio
## do mercado. Só lê o estado da empresa; a UI apenas exibe estes números.

const OPEX_OTHER := ["dev", "research", "hiring", "training", "commission", "fees", "tests", "recall", "events", "other"]

static func _g(led: Dictionary, k: String) -> float:
	return float(led.get(k, 0.0))

## DRE a partir de um ledger mensal (receitas +, despesas −) e dos movimentos fora do resultado.
static func dre(led: Dictionary, cash_items: Dictionary) -> Dictionary:
	var revenue := _g(led, "sales")
	var cogs := -_g(led, "cogs")
	var marketing := -_g(led, "marketing")
	var payroll := -_g(led, "payroll")
	var structure := -_g(led, "rent")
	var other := 0.0
	for k in OPEX_OTHER:
		other += -_g(led, k)
	# qualquer categoria desconhecida cai em "outras", para o DRE sempre fechar com o ledger
	var known := ["sales", "cogs", "marketing", "payroll", "rent", "interest", "taxes"] + OPEX_OTHER
	for k in led:
		if not known.has(k):
			other += -float(led[k])
	var gross := revenue - cogs
	var operating := gross - marketing - payroll - structure - other
	var interest := -_g(led, "interest")
	var taxes := -_g(led, "taxes")
	var net := operating - interest - taxes
	var invest := 0.0
	for k in cash_items:
		invest += float(cash_items[k])
	return {"revenue": revenue, "cogs": cogs, "gross": gross, "marketing": marketing, "payroll": payroll,
		"structure": structure, "other": other, "operating": operating, "interest": interest, "taxes": taxes,
		"net": net, "non_result": invest, "cash_flow": net + invest,
		"margin": operating / revenue if revenue > 0.0 else 0.0}

static func current(c: Company) -> Dictionary:
	return dre(c.ledger, c.cash_items)

static func last_month(c: Company) -> Dictionary:
	return dre(c.ledger_last, c.cash_items_last)

## Média ponderada (por vendas diárias) de preço e custo dos produtos à venda.
static func price_cost(c: Company) -> Dictionary:
	var w := 0.0
	var pr := 0.0
	var co := 0.0
	for p in c.released_products():
		var u := maxf(p.ema_units, 0.01)
		w += u
		pr += u * p.price
		co += u * c.current_unit_cost(p)
	if w <= 0.0:
		return {"price": 0.0, "cost": 0.0, "margin": 0.0}
	return {"price": pr / w, "cost": co / w, "margin": (pr - co) / maxf(pr, 1.0)}

## Por produto: vendas/dia, receita, lucro acumulado (já descontando desenvolvimento) e margem unitária.
static func products(c: Company) -> Array:
	var out: Array = []
	for p in c.products:
		if p.state != Product.STATE_RELEASED and p.state != Product.STATE_RETIRED:
			continue
		var uc := c.current_unit_cost(p)
		out.append({"id": p.id, "name": p.pname, "cat": p.category, "state": p.state, "units": p.units_total,
			"per_day": p.ema_units, "revenue": p.revenue_total, "profit": p.profit_total(),
			"unit_margin": (p.price - uc) / maxf(p.price, 1.0), "price": p.price, "cost": uc})
	out.sort_custom(func(a, b): return float(a.profit) > float(b.profit))
	return out

## Oferta e demanda de hoje, somadas nas categorias: o que o mercado quer, quem atendeu e o que ficou de fora.
static func balance(c: Company) -> Dictionary:
	var size := 0.0
	var mine := 0.0
	var rivals := 0.0
	var none := 0.0
	for k in c.market_stats:
		var s: Dictionary = c.market_stats[k]
		size += float(s.size)
		mine += float(s.mine)
		rivals += float(s.rivals)
		none += float(s.none)
	var total := mine + rivals + none
	return {"demand": size, "mine": mine, "rivals": rivals, "unmet": none,
		"share": mine / total if total > 0.0 else 0.0}

static func daily(c: Company) -> Dictionary:
	var rev := 0.0
	var prof := 0.0
	for p in c.released_products():
		rev += p.ema_units * p.price
		prof += p.ema_units * (p.price - c.current_unit_cost(p))
	var fixed := (c.monthly_payroll() + c.monthly_rent()) / float(Rules.DAYS_IN_MONTH)
	return {"revenue": rev, "profit": prof - fixed}
