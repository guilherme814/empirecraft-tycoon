class_name Company
extends RefCounted
## Estado e regras da empresa do jogador. Não depende de nós nem de autoloads,
## então pode ser testado em modo headless (veja tests/).
##
## Toda ação do jogador devolve um Dictionary {ok: bool, msg: String, ...}.

signal log_added(text: String, kind: String, sfx: String)
signal day_advanced(day: int)

const SAVE_VERSION := 1
const DEV_PROFESSIONS := ["engineer", "programmer", "designer"]

var company_name: String = "Minha Empresa"
var day: int = 0
var money: float = Rules.START_MONEY
var reputation: float = Rules.START_REPUTATION
var research_points: float = Rules.START_RESEARCH_POINTS
var staff: Array = []             # Employee
var candidates: Array = []        # Employee (ainda não contratados)
var office_level: Dictionary = {}
var research_levels: Dictionary = {}
var products: Array = []          # Product
var market: Market
var rng := RandomNumberGenerator.new()
var seed_value: int = 0
var next_id: int = 1
var game_over: bool = false
var log_entries: Array = []       # {day, text, kind}
var income_month: float = 0.0
var expense_month: float = 0.0
var last_income: float = 0.0
var last_expense: float = 0.0

func _init(p_seed: int = 0) -> void:
	seed_value = p_seed if p_seed != 0 else int(Time.get_ticks_usec() % 2147483646) + 1
	rng.seed = seed_value
	market = Market.new(rng)
	market.seed_competitors(0)
	for p in GameData.professions():
		office_level[p.id] = 1

# ───────────────────────── utilidades ─────────────────────────

func _new_id() -> int:
	next_id += 1
	return next_id - 1

func _fail(msg: String) -> Dictionary:
	return {"ok": false, "msg": msg}

func _ok(msg: String = "", extra: Dictionary = {}) -> Dictionary:
	var d := {"ok": true, "msg": msg}
	d.merge(extra)
	return d

func _income(v: float) -> void:
	money += v
	income_month += v

func _expense(v: float) -> void:
	money -= v
	expense_month += v

## `sfx` é o nome do efeito sonoro associado (a UI decide se toca).
func add_log(text: String, kind: String = "info", sfx: String = "") -> void:
	log_entries.append({"day": day, "text": text, "kind": kind})
	if log_entries.size() > 60:
		log_entries.pop_front()
	log_added.emit(text, kind, sfx)

func _find_in(list: Array, id: int) -> Variant:
	for x in list:
		if x.id == id:
			return x
	return null

## Soma dos efeitos de pesquisa de uma chave (ex.: "dev_speed").
func effect(key: String) -> float:
	var total := 0.0
	for r in GameData.research():
		if r.effect.key == key:
			total += float(int(research_levels.get(r.id, 0))) * float(r.effect.per_level)
	return total

# ───────────────────────── equipe ─────────────────────────

func staff_of(prof: String) -> Array:
	return staff.filter(func(e): return e.profession == prof)

func candidates_of(prof: String) -> Array:
	return candidates.filter(func(e): return e.profession == prof)

func capacity(prof: String) -> int:
	return int(Rules.OFFICE_CAPS[int(office_level.get(prof, 1)) - 1])

func free_seats(prof: String) -> int:
	return maxi(0, capacity(prof) - staff_of(prof).size())

func monthly_payroll() -> float:
	var t := 0.0
	for e in staff:
		t += e.salary()
	return t

func monthly_rent() -> float:
	return Rules.RENT_BASE + Rules.RENT_PER_STAFF * float(staff.size())

func office_upgrade_cost(prof: String) -> float:
	var lvl: int = int(office_level.get(prof, 1))
	if lvl >= Rules.OFFICE_CAPS.size():
		return -1.0
	return float(Rules.OFFICE_COSTS[lvl - 1])

func upgrade_office(prof: String) -> Dictionary:
	var cost := office_upgrade_cost(prof)
	if cost < 0.0:
		return _fail("Escritório já está no nível máximo")
	if money < cost:
		return _fail("Dinheiro insuficiente")
	_expense(cost)
	office_level[prof] = int(office_level[prof]) + 1
	add_log("Escritório de %s ampliado (nível %d)" % [GameData.profession(prof).name, office_level[prof]], "good", "success")
	return _ok()

func _random_name() -> String:
	var n: Dictionary = GameData.names()
	return "%s %s" % [n.first[rng.randi() % n.first.size()], n.last[rng.randi() % n.last.size()]]

func _roll_employee(prof: String, ag: Dictionary) -> Employee:
	var e := Employee.new()
	e.id = _new_id()
	e.profession = prof
	e.emp_name = _random_name()
	var base: int = rng.randi_range(int(ag.skill_min), int(ag.skill_max))
	var primary: String = GameData.profession(prof).primary
	for a in Employee.ATTRS:
		var v: int = base + rng.randi_range(-10, 10)
		if a == primary:
			v += 12
		e.set(a, clampi(v, 1, 100))
	e.hired_day = day
	return e

func _trim_candidates(prof: String) -> void:
	var list := candidates_of(prof)
	while list.size() > Rules.MAX_CANDIDATES_PER_PROFESSION:
		candidates.erase(list[0])
		list.remove_at(0)

func search_agency(agency_idx: int, prof: String) -> Dictionary:
	var ags: Array = GameData.agencies()
	if agency_idx < 0 or agency_idx >= ags.size():
		return _fail("Agência inválida")
	var ag: Dictionary = ags[agency_idx]
	var price: float = float(ag.price)
	if money < price:
		return _fail("Dinheiro insuficiente")
	_expense(price)
	var n: int = rng.randi_range(int(ag.min_found), int(ag.max_found))
	for i in n:
		candidates.append(_roll_employee(prof, ag))
	_trim_candidates(prof)
	return _ok("%d candidatos encontrados" % n, {"found": n, "price": price})

func hire(cand_id: int) -> Dictionary:
	var e: Variant = _find_in(candidates, cand_id)
	if e == null:
		return _fail("Candidato não encontrado")
	if free_seats(e.profession) <= 0:
		return _fail("Escritório lotado")
	candidates.erase(e)
	e.hired_day = day
	staff.append(e)
	add_log("Contratou %s (%s)" % [e.emp_name, GameData.profession(e.profession).singular], "good", "hire")
	return _ok()

func fire(emp_id: int) -> Dictionary:
	var e: Variant = _find_in(staff, emp_id)
	if e == null:
		return _fail("Funcionário não encontrado")
	var severance: float = e.salary()
	_expense(severance)
	staff.erase(e)
	add_log("Demitiu %s (indenização %s)" % [e.emp_name, Fmt.money(severance)], "bad", "fire")
	return _ok()

## Automação: contrata os melhores candidatos disponíveis e busca mais até lotar o escritório.
func auto_fill(prof: String, agency_idx: int, reserve: float = 20000.0) -> Dictionary:
	var hired := 0
	var spent := 0.0
	var guard := 0
	while free_seats(prof) > 0 and guard < 40:
		guard += 1
		var cands := candidates_of(prof)
		cands.sort_custom(func(a, b): return a.total() > b.total())
		for c in cands:
			if free_seats(prof) <= 0:
				break
			if hire(c.id).ok:
				hired += 1
		if free_seats(prof) <= 0:
			break
		var price: float = float(GameData.agencies()[agency_idx].price)
		if money - price < reserve:
			break
		var r := search_agency(agency_idx, prof)
		if not r.ok:
			break
		spent += price
	return _ok("Contratados: %d" % hired, {"hired": hired, "spent": spent})

# ───────────────────────── treinamento ─────────────────────────

func train_cost(e: Employee) -> Dictionary:
	var disc: float = minf(0.5, effect("train_discount"))
	return {
		"money": float(e.total()) * Rules.TRAIN_COST_PER_POINT * (1.0 - disc),
		"rp": ceilf(float(e.total()) * Rules.TRAIN_RP_PER_POINT),
	}

func train(emp_id: int, reserve: float = 0.0) -> Dictionary:
	var e: Variant = _find_in(staff, emp_id)
	if e == null:
		return _fail("Funcionário não encontrado")
	if e.is_maxed():
		return _fail("Já está no nível máximo")
	var cost := train_cost(e)
	if money - float(cost.money) < reserve:
		return _fail("Dinheiro insuficiente")
	if research_points < float(cost.rp):
		return _fail("Pontos de pesquisa insuficientes")
	_expense(float(cost.money))
	research_points -= float(cost.rp)
	for a in Employee.ATTRS:
		e.set(a, mini(100, int(e.get(a)) + rng.randi_range(3, 9)))
	return _ok()

## Automação: treina todos (ou uma profissão) por N rodadas, enquanto houver recursos.
func train_all(prof: String = "", max_rounds: int = 1, reserve: float = 10000.0) -> Dictionary:
	var steps := 0
	var starved := false
	for r in max_rounds:
		var any := false
		for e in staff:
			if prof != "" and e.profession != prof:
				continue
			var res := train(e.id, reserve)
			if res.ok:
				steps += 1
				any = true
			elif str(res.msg).contains("insuficiente"):
				starved = true
				break
		if starved or not any:
			break
	return _ok("%d treinamentos" % steps, {"steps": steps})

# ───────────────────────── pesquisa ─────────────────────────

func research_level(id: String) -> int:
	return int(research_levels.get(id, 0))

func research_cost(r: Dictionary) -> Dictionary:
	var lvl := research_level(r.id)
	return {
		"rp": ceilf(float(r.rp_base) * pow(float(r.rp_growth), lvl)),
		"money": roundf(float(r.money_base) * pow(float(r.money_growth), lvl)),
	}

## Devolve "" se o item pode ser pesquisado agora, ou o motivo do bloqueio.
func research_blocker(r: Dictionary) -> String:
	if research_level(r.id) >= int(r.max):
		return "Nível máximo"
	if str(r.requires) != "" and research_level(str(r.requires)) < int(r.requires_level):
		var req: Dictionary = GameData.research_item(str(r.requires))
		return "Requer %s nv.%d" % [req.name, int(r.requires_level)]
	return ""

func do_research(id: String, reserve: float = 0.0) -> Dictionary:
	var r: Dictionary = GameData.research_item(id)
	if r.is_empty():
		return _fail("Pesquisa inválida")
	var blocker := research_blocker(r)
	if blocker != "":
		return _fail(blocker)
	var cost := research_cost(r)
	if research_points < float(cost.rp):
		return _fail("Pontos de pesquisa insuficientes")
	if money - float(cost.money) < reserve:
		return _fail("Dinheiro insuficiente")
	research_points -= float(cost.rp)
	_expense(float(cost.money))
	research_levels[id] = research_level(id) + 1
	add_log("Pesquisa concluída: %s (nv.%d)" % [r.name, research_levels[id]], "good", "research")
	return _ok()

## Automação: pesquisa tudo que for possível, do mais barato ao mais caro.
func research_all(reserve: float = 10000.0) -> Dictionary:
	var done := 0
	for guard in 300:
		var best: Dictionary = {}
		var best_rp := INF
		for r in GameData.research():
			if research_blocker(r) != "":
				continue
			var cost := research_cost(r)
			if research_points < float(cost.rp) or money - float(cost.money) < reserve:
				continue
			if float(cost.rp) < best_rp:
				best_rp = float(cost.rp)
				best = r
		if best.is_empty():
			break
		do_research(best.id, reserve)
		done += 1
	return _ok("%d pesquisas concluídas" % done, {"done": done})

func _research_tick() -> void:
	var rp := 0.0
	for e in staff_of("researcher"):
		rp += 0.3 + float(e.insight) / 100.0
	research_points += rp

func research_per_day() -> float:
	var rp := 0.0
	for e in staff_of("researcher"):
		rp += 0.3 + float(e.insight) / 100.0
	return rp

# ───────────────────────── produtos ─────────────────────────

func category_unlocked(cat_id: String) -> bool:
	var cat: Dictionary = GameData.category(cat_id)
	if cat.is_empty():
		return false
	return str(cat.unlock) == "" or research_level(str(cat.unlock)) > 0

func spec_budget() -> int:
	return Rules.SPEC_BUDGET_BASE + int(effect("spec_points"))

func specs_used(specs: Dictionary) -> int:
	var t := 0
	for k in specs:
		t += int(specs[k])
	return t

func missing_professions(cat_id: String) -> Array:
	var out: Array = []
	for need in GameData.category(cat_id).needs:
		if staff_of(need).is_empty():
			out.append(need)
	return out

func default_specs(cat_id: String) -> Dictionary:
	var cat: Dictionary = GameData.category(cat_id)
	var specs := {}
	var budget := spec_budget()
	var n: int = cat.axes.size()
	var each: int = mini(Rules.SPEC_AXIS_MAX, floori(float(budget) / float(n) / float(Rules.SPEC_STEP)) * Rules.SPEC_STEP)
	for a in cat.axes:
		specs[a] = each
	return specs

## Pontuação de especificações (0-100), sem equipe nem sorte.
func spec_score(cat_id: String, specs: Dictionary) -> float:
	var cat: Dictionary = GameData.category(cat_id)
	var score := 0.0
	for a in cat.axes:
		var pts := float(specs.get(a, 0))
		score += float(cat.axes[a]) * pow(clampf(pts / float(Rules.SPEC_AXIS_MAX), 0.0, 1.0), 0.7)
	return score * 100.0

func team_factor() -> float:
	var sum := 0.0
	var n := 0
	for prof in ["engineer", "programmer"]:
		for e in staff_of(prof):
			sum += float(e.craft)
			n += 1
	if n == 0:
		return 0.75
	return 0.75 + 0.5 * clampf(sum / float(n) / 100.0, 0.0, 1.0)

func design_bonus() -> float:
	var b := effect("design_bonus")
	for e in staff_of("designer"):
		b += 0.03 * float(e.insight) / 50.0
	return minf(b, 0.5)

## Estimativa mostrada ao jogador antes de iniciar (sem o fator sorte).
func estimate_quality(cat_id: String, specs: Dictionary) -> float:
	return spec_score(cat_id, specs) * (1.0 + effect("tech_level")) * team_factor() * (1.0 + design_bonus())

func estimate_unit_cost(cat_id: String, specs: Dictionary) -> float:
	var cat: Dictionary = GameData.category(cat_id)
	var load_f := 0.0
	for a in cat.axes:
		load_f += float(cat.axes[a]) * float(specs.get(a, 0)) / float(Rules.SPEC_AXIS_MAX)
	var disc: float = minf(0.5, effect("unit_cost_discount"))
	return float(cat.unit_cost) * (0.6 + 0.8 * load_f) * (1.0 - disc)

func fair_price(cat_id: String, quality: float) -> float:
	return float(GameData.category(cat_id).fair_price) * (0.5 + quality / 100.0)

func suggested_product_name(cat_id: String) -> String:
	var n: Dictionary = GameData.names()
	return "%s %s%d" % [n.product[rng.randi() % n.product.size()], cat_id.substr(0, 1).to_upper(), rng.randi_range(1, 9)]

func dev_products() -> Array:
	return products.filter(func(p): return p.state == Product.STATE_DEV)

func create_product(pname: String, cat_id: String, specs: Dictionary, price: float = 0.0) -> Dictionary:
	var cat: Dictionary = GameData.category(cat_id)
	if cat.is_empty():
		return _fail("Categoria inválida")
	if not category_unlocked(cat_id):
		return _fail("Categoria ainda não desbloqueada")
	if dev_products().size() >= Rules.MAX_DEV_PRODUCTS:
		return _fail("Limite de projetos em desenvolvimento")
	var missing := missing_professions(cat_id)
	if not missing.is_empty():
		var names: Array = []
		for m in missing:
			names.append(GameData.profession(m).singular)
		return _fail("Contrate: " + ", ".join(names))
	if specs_used(specs) > spec_budget():
		return _fail("Pontos de especificação acima do limite")
	var cost := float(cat.dev_cost)
	if money < cost:
		return _fail("Dinheiro insuficiente")
	_expense(cost)
	var p := Product.new()
	p.id = _new_id()
	p.pname = pname if pname != "" else suggested_product_name(cat_id)
	p.category = cat_id
	p.specs = specs.duplicate()
	p.price = price
	p.unit_cost = estimate_unit_cost(cat_id, specs)
	p.work_required = float(cat.work)
	p.dev_cost = cost
	p.state = Product.STATE_DEV
	products.append(p)
	add_log("Iniciou o desenvolvimento de %s" % p.pname, "info", "success")
	return _ok("", {"product": p})

## Trabalho total gerado por dia pela equipe de desenvolvimento.
func dev_work_per_day() -> float:
	var work := 0.0
	for prof in DEV_PROFESSIONS:
		for e in staff_of(prof):
			work += (0.5 + float(e.pace) / 100.0) * (0.7 + 0.3 * e.morale / 100.0)
	return work * (1.0 + effect("dev_speed"))

func _develop() -> void:
	var devs := dev_products()
	if devs.is_empty():
		return
	var work := dev_work_per_day()
	var share := work / float(devs.size())
	for p in devs:
		if not missing_professions(p.category).is_empty():
			continue
		p.work_done += share
		if p.work_done >= p.work_required:
			_finish_dev(p)

func _finish_dev(p: Product) -> void:
	p.work_done = p.work_required
	p.quality = clampf(estimate_quality(p.category, p.specs) + rng.randf_range(-2.0, 2.0), 5.0, 250.0)
	p.state = Product.STATE_READY
	if p.price <= 0.0:
		p.price = roundf(fair_price(p.category, p.quality))
	add_log("%s está pronto para lançamento (qualidade %d)" % [p.pname, int(round(p.quality))], "good", "ready")

func release(prod_id: int, price: float = -1.0) -> Dictionary:
	var p: Variant = _find_in(products, prod_id)
	if p == null:
		return _fail("Produto não encontrado")
	if p.state != Product.STATE_READY:
		return _fail("Produto não está pronto")
	if price > 0.0:
		p.price = price
	p.state = Product.STATE_RELEASED
	p.release_day = day
	add_log("%s foi lançado por %s!" % [p.pname, Fmt.money(p.price)], "good", "release")
	return _ok()

func set_price(prod_id: int, price: float) -> Dictionary:
	var p: Variant = _find_in(products, prod_id)
	if p == null or price <= 0.0:
		return _fail("Preço inválido")
	p.price = price
	return _ok()

func retire(prod_id: int) -> Dictionary:
	var p: Variant = _find_in(products, prod_id)
	if p == null:
		return _fail("Produto não encontrado")
	p.state = Product.STATE_RETIRED
	add_log("%s saiu de linha" % p.pname, "info")
	return _ok()

# ───────────────────────── vendas ─────────────────────────

## Quão atraente é o produto no mercado (>0). Qualidade vs expectativa, preço vs valor justo,
## envelhecimento, impulso de lançamento e reputação.
func attractiveness(p: Product) -> float:
	var cat: Dictionary = GameData.category(p.category)
	var exp_q := market.expectation(day)
	var q_factor := pow(clampf(p.quality / exp_q, 0.0, 3.0), 3.0)
	var fair := fair_price(p.category, p.quality)
	var price_factor := clampf(pow(fair / maxf(p.price, 1.0), 2.2), 0.0, 4.0)
	var age := day - p.release_day
	var dec := Market.decay(age, float(cat.lifetime))
	var hype := 1.0 + 0.6 * maxf(0.0, 1.0 - float(age) / 30.0) * (1.0 + effect("hype"))
	var rep_factor := 0.5 + reputation / 100.0
	return q_factor * price_factor * dec * hype * rep_factor

func _sell() -> void:
	var by_cat := {}
	for p in products:
		if p.state == Product.STATE_RELEASED:
			if not by_cat.has(p.category):
				by_cat[p.category] = []
			by_cat[p.category].append(p)
	var exp_q := market.expectation(day)
	for cat_id in by_cat:
		var list: Array = by_cat[cat_id]
		var size := market.market_size(cat_id, day)
		var comp := market.competitor_attractiveness(cat_id, day)
		var attr := {}
		var sum_mine := 0.0
		for p in list:
			var a := attractiveness(p)
			attr[p.id] = a
			sum_mine += a
		var denom := Rules.OUTSIDE_OPTION + sum_mine + comp
		for p in list:
			var share: float = float(attr[p.id]) / denom
			var units_f: float = size * share * rng.randf_range(0.85, 1.15) + p.units_carry
			var units := int(floor(units_f))
			p.units_carry = units_f - float(units)
			if units > 0:
				var revenue: float = float(units) * p.price
				var cost: float = float(units) * p.unit_cost
				_income(revenue)
				_expense(cost)
				p.units_total += units
				p.revenue_total += revenue
				p.cost_total += cost
			p.ema_units = p.ema_units * 0.9 + float(units) * 0.1
			var ratio: float = p.quality / exp_q
			if ratio > 1.1:
				reputation = minf(100.0, reputation + 0.01)
			elif ratio < 0.7:
				reputation = maxf(0.0, reputation - 0.01)

# ───────────────────────── tempo ─────────────────────────

func advance_day() -> void:
	if game_over:
		return
	day += 1
	_develop()
	_research_tick()
	_sell()
	market.tick(day)
	for e in staff:
		e.morale = lerpf(e.morale, 75.0, 0.02)
	if day % Rules.DAYS_IN_MONTH == 0:
		_month_end()
	day_advanced.emit(day)

func _month_end() -> void:
	var payroll := monthly_payroll()
	var rent := monthly_rent()
	_expense(payroll + rent)
	last_income = income_month
	last_expense = expense_month
	var profit := last_income - last_expense
	add_log("Fechamento do mês: %s %s" % ["lucro" if profit >= 0.0 else "prejuízo", Fmt.money(absf(profit))],
		"good" if profit >= 0.0 else "bad", "month" if profit >= 0.0 else "")
	income_month = 0.0
	expense_month = 0.0
	if rng.randf() < 0.4:
		_random_event()
	if money < Rules.BANKRUPT_LIMIT:
		game_over = true
		add_log("Sua empresa faliu.", "bad", "bankrupt")

func _random_event() -> void:
	var pool: Array = GameData.events()
	var total := 0.0
	for ev in pool:
		total += float(ev.weight)
	var roll := rng.randf() * total
	var picked: Dictionary = pool[0]
	for ev in pool:
		roll -= float(ev.weight)
		if roll <= 0.0:
			picked = ev
			break
	var eff: Dictionary = picked.effect
	if eff.has("money"):
		if float(eff.money) >= 0.0:
			_income(float(eff.money))
		else:
			_expense(-float(eff.money))
	if eff.has("reputation"):
		reputation = clampf(reputation + float(eff.reputation), 0.0, 100.0)
	if eff.has("research_points"):
		research_points += float(eff.research_points)
	var unlocked: Array = []
	for c in GameData.categories():
		if category_unlocked(c.id):
			unlocked.append(c.id)
	if eff.has("trend"):
		var t: Dictionary = eff.trend
		var cat_id: String = str(t.cat)
		if cat_id == "random":
			cat_id = unlocked[rng.randi() % unlocked.size()]
		market.add_trend(cat_id, float(t.mult), int(t.days), day)
	if eff.has("comp_launch"):
		market.launch_competitor(unlocked[rng.randi() % unlocked.size()], day)
	add_log("%s: %s" % [picked.name, picked.text], str(picked.kind),
		"event_good" if str(picked.kind) == "good" else "event_bad")

# ───────────────────────── resumo e save ─────────────────────────

func released_products() -> Array:
	return products.filter(func(p): return p.state == Product.STATE_RELEASED)

func daily_sales_estimate() -> float:
	var t := 0.0
	for p in released_products():
		t += p.ema_units * (p.price - p.unit_cost)
	return t

func to_dict() -> Dictionary:
	var staff_d: Array = []
	for e in staff:
		staff_d.append(e.to_dict())
	var cand_d: Array = []
	for e in candidates:
		cand_d.append(e.to_dict())
	var prod_d: Array = []
	for p in products:
		prod_d.append(p.to_dict())
	return {
		"version": SAVE_VERSION, "name": company_name, "day": day, "money": money, "reputation": reputation,
		"rp": research_points, "staff": staff_d, "candidates": cand_d, "office": office_level,
		"research": research_levels, "products": prod_d, "market": market.to_dict(),
		"seed": seed_value, "rng_state": str(rng.state), "next_id": next_id, "game_over": game_over,
		"log": log_entries, "income_month": income_month, "expense_month": expense_month,
		"last_income": last_income, "last_expense": last_expense,
	}

## Devolve null se o save for de uma versão futura (evita corromper dados).
static func from_dict(d: Dictionary) -> Company:
	if int(d.get("version", 1)) > SAVE_VERSION:
		push_warning("Save de versão mais nova que o jogo")
		return null
	var c := Company.new(int(d.get("seed", 1)))
	c.company_name = str(d.get("name", "Minha Empresa"))
	c.day = int(d.get("day", 0))
	c.money = float(d.get("money", Rules.START_MONEY))
	c.reputation = float(d.get("reputation", Rules.START_REPUTATION))
	c.research_points = float(d.get("rp", 0.0))
	for ed in d.get("staff", []):
		c.staff.append(Employee.from_dict(ed))
	for ed in d.get("candidates", []):
		c.candidates.append(Employee.from_dict(ed))
	var off: Dictionary = d.get("office", {})
	for k in off:
		c.office_level[k] = int(off[k])
	var res: Dictionary = d.get("research", {})
	for k in res:
		c.research_levels[k] = int(res[k])
	for pd in d.get("products", []):
		c.products.append(Product.from_dict(pd))
	c.market.load_dict(d.get("market", {}))
	c.next_id = int(d.get("next_id", 1))
	c.game_over = bool(d.get("game_over", false))
	c.log_entries = d.get("log", []).duplicate(true)
	c.income_month = float(d.get("income_month", 0.0))
	c.expense_month = float(d.get("expense_month", 0.0))
	c.last_income = float(d.get("last_income", 0.0))
	c.last_expense = float(d.get("last_expense", 0.0))
	c.rng.state = str(d.get("rng_state", "0")).to_int()
	return c
