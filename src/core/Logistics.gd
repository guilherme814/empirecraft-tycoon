class_name Logistics
extends RefCounted
## Estoque e produção: cada produto tem estoque real. Pedidos de produção custam caixa na hora,
## ocupam a capacidade do fabricante (fila), demoram (prazo + produção) e chegam com perdas por defeito.
## As vendas só saem do estoque; o que faltar vira demanda perdida.

const MAX_WAIT_DAYS := 60
const MIN_ORDER := 5
const CASH_RESERVE := 15000.0

static func complexity(cat_id: String) -> float:
	return float(GameData.category(cat_id).get("complexity", 1.0))

## Capacidade do fabricante em "unidades-padrão" por dia (notebook = 1,5; console = 2,0 etc.).
static func capacity(c: Company, mfr: String) -> float:
	if mfr == "own" and c.factory_level > 0:
		return float(GameData.manufacturers().own_factory.capacity[c.factory_level - 1])
	return float(c.contractor(mfr if mfr != "own" else "fabrix").get("capacity", 20))

static func lead_days(c: Company, mfr: String) -> int:
	if mfr == "own" and c.factory_level > 0:
		return int(GameData.manufacturers().own_factory.lead[c.factory_level - 1])
	return int(c.contractor(mfr if mfr != "own" else "fabrix").get("lead", 8))

static func pipeline(p: Product) -> int:
	var n := 0
	for o in p.orders:
		n += int(o.qty)
	return n

## Dias de fila na fábrica antes de começar um pedido novo.
static func queue_days(c: Company, mfr: String) -> int:
	return maxi(0, int(c.mfr_busy.get(mfr, 0)) - c.day)

static func max_affordable(c: Company, p: Product, reserve: float = 0.0) -> int:
	var u := maxf(c.current_unit_cost(p), 0.01)
	return maxi(0, int(floor((c.money - reserve) / u)))

## Previsão para um pedido: {days, cost, ready, ok, why}
static func quote(c: Company, p: Product, qty: int) -> Dictionary:
	var unit := c.current_unit_cost(p)
	var work := float(qty) * complexity(p.category)
	var prod_days := int(ceil(work / maxf(capacity(c, p.mfr), 0.1)))
	var start := maxi(c.day, int(c.mfr_busy.get(p.mfr, 0)))
	var finish := start + prod_days
	var ready := finish + lead_days(c, p.mfr)
	return {"unit": unit, "cost": unit * float(qty), "prod_days": prod_days, "finish": finish, "ready": ready,
		"wait": ready - c.day}

static func order(c: Company, pid: int, qty: int) -> Dictionary:
	var p: Product = c.get_product(pid)
	if p == null or p.state != Product.STATE_RELEASED:
		return c._fail("Só dá para produzir produtos lançados")
	if qty <= 0:
		return c._fail("Quantidade inválida")
	var q := quote(c, p, qty)
	if int(q.wait) > MAX_WAIT_DAYS:
		return c._fail("Fila de produção longa demais (%d dias). Peça menos ou troque de fábrica." % int(q.wait))
	if c.money < float(q.cost):
		return c._fail("Caixa insuficiente: o lote custa %s" % Fmt.money(float(q.cost)))
	c._cash_out(float(q.cost), "inventory")
	c.mfr_busy[p.mfr] = int(q.finish)
	p.orders.append({"qty": qty, "unit": float(q.unit), "ready": int(q.ready)})
	return c._ok("Pedido de %d un. (chega em %d dias)" % [qty, int(q.wait)])

## Lote inicial do lançamento: produzido durante o desenvolvimento, já em estoque no dia 1.
static func initial_qty(c: Company, cat_id: String, batch_days: int) -> int:
	var daily := maxf(2.0, c.market.market_size(cat_id, c.day) * 0.25)
	return int(ceil(daily * float(batch_days)))

static func add_stock(p: Product, qty: int, unit: float) -> void:
	if qty <= 0:
		return
	var total := float(p.stock) * p.avg_cost + float(qty) * unit
	p.stock += qty
	p.avg_cost = total / float(p.stock)

static func value(c: Company) -> float:
	var v := 0.0
	for p in c.products:
		v += float(p.stock) * p.avg_cost
	return v

static func total_stock(c: Company) -> int:
	var n := 0
	for p in c.products:
		n += p.stock
	return n

## Todo dia: recebe pedidos prontos (com defeitos descartados) e repõe sozinho quem está no automático.
static func tick(c: Company) -> void:
	for p in c.products:
		if p.state == Product.STATE_RETIRED and p.orders.is_empty():
			continue
		for o in p.orders.duplicate():
			if int(o.ready) <= c.day:
				p.orders.erase(o)
				var qty := int(o.qty)
				var risk := float(c.mfr_stats(p.mfr).risk)
				var bad := int(round(float(qty) * risk))
				add_stock(p, qty - bad, float(o.unit))
				if bad > 0:
					p.defects_total += bad
					c._pl_expense(float(bad) * float(o.unit), "writeoff")
				if p.state == Product.STATE_RELEASED:
					c.add_log("Chegaram %d un. de %s%s" % [qty - bad, p.pname, (" (%d com defeito descartadas)" % bad) if bad > 0 else ""], "info")
	for p in c.released_products():
		if p.auto_stock:
			_auto(c, p)

static func demand_est(p: Product) -> float:
	return maxf(p.ema_units + p.store_ema + p.lost_ema, 0.5)

static func target(p: Product) -> int:
	return int(ceil(demand_est(p) * float(p.cover_days)))

static func _auto(c: Company, p: Product) -> void:
	var tgt := target(p)
	var have := p.stock + pipeline(p)
	if float(have) > 0.5 * float(tgt):
		return
	var qty := maxi(tgt - have, 10)
	qty = mini(qty, max_affordable(c, p, CASH_RESERVE))
	if qty < MIN_ORDER:
		return
	# não empilha fila além do prazo
	while qty >= MIN_ORDER and int(quote(c, p, qty).wait) > MAX_WAIT_DAYS:
		qty = qty / 2
	if qty >= MIN_ORDER:
		order(c, p.id, qty)
