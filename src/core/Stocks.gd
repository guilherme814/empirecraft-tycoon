class_name Stocks
extends RefCounted
## Bolsa de valores: carteira do jogador, abertura de capital (IPO) e preço das ações da empresa.
## Os preços dos rivais vivem em Market (rivals[].price); aqui fica o lado do jogador.

const FEE := 0.01
const MAX_PUBLIC := 0.49
const IPO_MIN_VALUE := 1500000.0

var holdings: Dictionary = {}     # nome do rival -> {"n": int, "cost": float}
var public_pct: float = 0.0       # fração da empresa em mãos do público
var ipo_day: int = -1
var ipo_price: float = 0.0
var price: float = 0.0            # ação da empresa do jogador
var hist: Array = []
var value: float = 0.0
var dividends_paid: float = 0.0

func listed() -> bool:
	return public_pct > 0.0

func holding(name: String) -> int:
	return int(holdings.get(name, {}).get("n", 0))

func portfolio_value(market: Market) -> float:
	var t := 0.0
	for name in holdings:
		var i := market.rival_index(name)
		if i >= 0:
			t += float(holdings[name].n) * float(market.rivals[i].price)
	return t

func portfolio_cost() -> float:
	var t := 0.0
	for name in holdings:
		t += float(holdings[name].cost)
	return t

## Valor da empresa do jogador (mesma fórmula dos rivais).
func update_value(c: Company) -> void:
	var annual_profit := 12.0 * (c.last_income - c.last_expense)
	value = maxf(0.0, c.money) + 10.0 * maxf(0.0, annual_profit) + 2.0 * 12.0 * c.last_income \
		+ portfolio_value(c.market) + 1500.0 * c.reputation
	var target := value / Market.SHARES * c.market.macro
	if price <= 0.0:
		price = target
	price += (target - price) * 0.3
	hist.append(price)
	if hist.size() > Market.HIST_LEN:
		hist.pop_front()

func daily(c: Company) -> void:
	if price <= 0.0:
		update_value(c)
	var target := value / Market.SHARES * c.market.macro
	price = maxf(0.05, price + (target - price) * 0.06 + price * c.rng.randf_range(-0.012, 0.012))
	hist.append(price)
	if hist.size() > Market.HIST_LEN:
		hist.pop_front()

func buy(c: Company, name: String, qty: int) -> Dictionary:
	var i := c.market.rival_index(name)
	if i < 0 or qty <= 0:
		return c._fail("Ação inválida")
	var unit := float(c.market.rivals[i].price) * (1.0 + FEE)
	var total := unit * float(qty)
	if c.money < total:
		return c._fail("Dinheiro insuficiente")
	c._cash_out(total, "stocks")
	var h: Dictionary = holdings.get(name, {"n": 0, "cost": 0.0})
	h.n = int(h.n) + qty
	h.cost = float(h.cost) + total
	holdings[name] = h
	return c._ok("Comprou %d ações de %s" % [qty, name])

func sell(c: Company, name: String, qty: int) -> Dictionary:
	var have := holding(name)
	var i := c.market.rival_index(name)
	if i < 0 or qty <= 0 or have <= 0:
		return c._fail("Você não tem essas ações")
	qty = mini(qty, have)
	var total := float(qty) * float(c.market.rivals[i].price) * (1.0 - FEE)
	c._cash_in(total, "stocks")
	var h: Dictionary = holdings[name]
	var frac := float(qty) / float(have)
	h.cost = float(h.cost) * (1.0 - frac)
	h.n = have - qty
	if int(h.n) <= 0:
		holdings.erase(name)
	return c._ok("Vendeu %d ações de %s por %s" % [qty, name, Fmt.money(total)])

func can_ipo(c: Company) -> String:
	if c.research_level("res_capital") < 1:
		return "Pesquise Mercado de Capitais"
	if value < IPO_MIN_VALUE:
		return "Valor mínimo %s" % Fmt.money(IPO_MIN_VALUE)
	if public_pct >= MAX_PUBLIC - 0.001:
		return "Limite de 49% atingido"
	return ""

func ipo(c: Company, pct: float) -> Dictionary:
	var why := can_ipo(c)
	if why != "":
		return c._fail(why)
	pct = minf(pct, MAX_PUBLIC - public_pct)
	update_value(c)
	var raise := pct * value * 0.95
	c._cash_in(raise, "stocks")
	if public_pct == 0.0:
		ipo_day = c.day
		ipo_price = price
	public_pct += pct
	c.add_log("%s vendeu %d%% da empresa na bolsa e captou %s" % [c.company_name, int(pct * 100.0), Fmt.money(raise)], "good", "success")
	return c._ok()

func buyback(c: Company, pct: float) -> Dictionary:
	pct = minf(pct, public_pct)
	if pct <= 0.0:
		return c._fail("Nada para recomprar")
	var cost := pct * value * 1.05
	if c.money < cost:
		return c._fail("Dinheiro insuficiente (%s)" % Fmt.money(cost))
	c._cash_out(cost, "stocks")
	public_pct -= pct
	return c._ok("Recomprou %d%% das ações" % int(pct * 100.0))

func month_end(c: Company) -> void:
	update_value(c)
	if listed():
		var profit := c.last_income - c.last_expense
		if profit > 0.0:
			var div := public_pct * profit * 0.25
			c._expense(div)
			dividends_paid += div
		elif profit < 0.0:
			c.reputation = maxf(0.0, c.reputation - 0.5)
			c.add_log("Acionistas insatisfeitos com o prejuízo", "bad")

func to_dict() -> Dictionary:
	return {"holdings": holdings, "public": public_pct, "ipo_day": ipo_day, "ipo_price": ipo_price,
		"price": price, "hist": hist, "value": value, "div": dividends_paid}

func load_dict(d: Dictionary) -> void:
	holdings = {}
	var h: Dictionary = d.get("holdings", {})
	for k in h:
		holdings[k] = {"n": int(h[k].n), "cost": float(h[k].cost)}
	public_pct = float(d.get("public", 0.0))
	ipo_day = int(d.get("ipo_day", -1))
	ipo_price = float(d.get("ipo_price", 0.0))
	price = float(d.get("price", 0.0))
	hist = d.get("hist", []).duplicate()
	value = float(d.get("value", 0.0))
	dividends_paid = float(d.get("div", 0.0))
