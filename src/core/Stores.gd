class_name Stores
extends RefCounted
## Lojas próprias (versão enxuta): o jogador escolhe país, cidade, tamanho, fachada e equipe.
## Cada loja vende localmente os produtos lançados (demanda extra do país) e custa aluguel + salários.

static func get_store(c: Company, id: int) -> Variant:
	for s in c.stores:
		if int(s.id) == id:
			return s
	return null

static func default_spec(country: String = "br") -> Dictionary:
	var ct := GameData.country(country)
	return {"country": country, "city": str(ct.cities[0]), "size": "kiosk", "facade": "minimal", "staff": 1, "name": ""}

static func count_in(c: Company, country: String) -> int:
	var n := 0
	for s in c.stores:
		if str(s.country) == country:
			n += 1
	return n

static func experience(s: Dictionary) -> float:
	var size := GameData.store_opt("sizes", str(s.size))
	var e := 0.30 + 0.30 * float(s.staff) / maxf(float(size.max_staff), 1.0)
	e += float(GameData.store_opt("facades", str(s.facade)).get("exp", 0.0)) * 3.0
	return clampf(e, 0.0, 1.0)

static func open_cost(s: Dictionary) -> float:
	var size := GameData.store_opt("sizes", str(s.size))
	return float(size.open) * float(GameData.country(str(s.country)).open) * float(GameData.store_opt("facades", str(s.facade)).get("cost", 1.0))

static func monthly_cost(s: Dictionary) -> float:
	var size := GameData.store_opt("sizes", str(s.size))
	var ct := GameData.country(str(s.country))
	return float(size.rent) * float(ct.rent) + float(s.staff) * float(GameData.stores().staff_wage) * float(ct.wage)

## Motivo pelo qual não dá para abrir (vazio = pode).
static func blocker(c: Company, s: Dictionary) -> String:
	var ct := GameData.country(str(s.country))
	var size := GameData.store_opt("sizes", str(s.size))
	if ct.is_empty() or size.is_empty() or GameData.store_opt("facades", str(s.facade)).is_empty():
		return "Escolha inválida"
	if not (ct.cities as Array).has(str(s.city)):
		return "Cidade inválida"
	if c.reputation < float(ct.rep):
		return "%s exige reputação %d" % [ct.name, int(ct.rep)]
	if c.reputation < float(size.rep):
		return "%s exige reputação %d" % [size.name, int(size.rep)]
	if count_in(c, str(s.country)) >= int(GameData.stores().max_per_country):
		return "Máx. %d lojas por país" % int(GameData.stores().max_per_country)
	if c.stores.size() >= int(GameData.stores().max_total):
		return "Limite de %d lojas" % int(GameData.stores().max_total)
	return ""

static func _clean(c: Company, spec: Dictionary) -> Dictionary:
	var s := spec.duplicate(true)
	var size := GameData.store_opt("sizes", str(s.get("size", "kiosk")))
	s["staff"] = clampi(int(s.get("staff", 1)), 1, int(size.get("max_staff", 1)))
	if str(s.get("name", "")).strip_edges() == "":
		s["name"] = "%s %s" % [c.company_name, str(s.get("city", ""))]
	return s

static func open(c: Company, spec: Dictionary) -> Dictionary:
	var s := _clean(c, spec)
	var why := blocker(c, s)
	if why != "":
		return c._fail(why)
	var cost := open_cost(s)
	if c.money < cost + monthly_cost(s):
		return c._fail("Caixa insuficiente: abertura %s + 1º mês %s" % [Fmt.money(cost), Fmt.money(monthly_cost(s))])
	c._cash_out(cost, "capex")
	s["id"] = c._new_id()
	s["open_day"] = c.day
	s["units"] = 0
	s["revenue"] = 0.0
	s["carry"] = {}
	c.stores.append(s)
	c.add_log("Nova loja: %s (%s)" % [s.name, GameData.country(str(s.country)).name], "good", "success")
	return c._ok("Loja aberta: %s" % s.name)

## Muda fachada e equipe (reforma cobra uma taxa); país, cidade e tamanho não mudam.
static func update(c: Company, id: int, facade: String, staff: int) -> Dictionary:
	var s: Variant = get_store(c, id)
	if s == null:
		return c._fail("Loja não encontrada")
	var size := GameData.store_opt("sizes", str(s.size))
	staff = clampi(staff, 1, int(size.max_staff))
	var fee := 0.0
	if facade != str(s.facade):
		fee = float(GameData.stores().redecor_fee) * float(GameData.country(str(s.country)).open)
	if c.money < fee:
		return c._fail("Reforma custa %s" % Fmt.money(fee))
	if fee > 0.0:
		c._cash_out(fee, "capex")
	s.facade = facade
	s.staff = staff
	return c._ok("Loja atualizada")

static func close(c: Company, id: int) -> Dictionary:
	var s: Variant = get_store(c, id)
	if s == null:
		return c._fail("Loja não encontrada")
	c._cash_in(open_cost(s) * 0.3, "capex")
	c.stores.erase(s)
	c.add_log("Loja %s fechada" % s.name, "info")
	return c._ok("Loja fechada")

## Vendas/dia estimadas (un.) com os produtos atuais.
static func forecast(c: Company, s: Dictionary) -> float:
	var total := 0.0
	for cat_id in c.market_stats:
		total += _local(c, str(cat_id), s) * float((c.market_stats[cat_id] as Dictionary).get("share", 0.0))
	return total

static func _local(c: Company, cat_id: String, s: Dictionary) -> float:
	var size := GameData.store_opt("sizes", str(s.size))
	var ct := GameData.country(str(s.country))
	return c.market.market_size(cat_id, c.day) * float(ct.w) * float(size.reach) * (0.6 + 0.8 * experience(s))

static func daily(c: Company) -> void:
	for s in c.stores:
		var carry: Dictionary = s.carry
		for cat_id in c.market_stats:
			var st: Dictionary = c.market_stats[cat_id]
			var attr: Dictionary = st.get("attr", {})
			var denom := float(st.get("denom", 1.0))
			var local := _local(c, str(cat_id), s)
			for pid in attr:
				var p: Product = c.get_product(int(pid))
				if p == null or p.state != Product.STATE_RELEASED:
					continue
				var f := local * float(attr[pid]) / maxf(denom, 0.001) * c.rng.randf_range(0.85, 1.15) + float(carry.get(str(pid), 0.0))
				var n := int(floor(f))
				carry[str(pid)] = f - float(n)
				if n > 0:
					c._book_sale(p, n, str(cat_id))
					s.units = int(s.units) + n
					s.revenue = float(s.revenue) + float(n) * p.price

static func monthly(c: Company) -> void:
	for s in c.stores:
		c._expense(monthly_cost(s), "rent")
		var d := (experience(s) - 0.5) * 0.6
		if absf(d) > 0.01:
			Loyalty.change(c, d, "Loja %s" % s.name)

static func total_monthly(c: Company) -> float:
	var t := 0.0
	for s in c.stores:
		t += monthly_cost(s)
	return t
