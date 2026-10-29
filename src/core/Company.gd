class_name Company
extends RefCounted
## Estado e regras da empresa do jogador. Não depende de nós nem de autoloads,
## então pode ser testado em modo headless (veja tests/).
##
## Toda ação do jogador devolve um Dictionary {ok: bool, msg: String, ...}.

signal log_added(text: String, kind: String, sfx: String)
signal day_advanced(day: int)

const SAVE_VERSION := 2
const TAX_RATE := 0.15
const LOAN_RATE := 0.012
const MAX_DEALS := 4
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
var stocks := Stocks.new()
var own_os: Dictionary = {}       # {"version": int, "dev": {"work": f, "req": f, "money": f} | null}
var factory_level: int = 0
var ledger: Dictionary = {}       # mês atual: categoria -> valor (receita +, despesa -)
var ledger_last: Dictionary = {}  # mês anterior
var loan: float = 0.0
var history: Array = []           # fim de cada mês: {day, money, value}
var deals: Array = []             # {id, until}

# Novos sistemas do jogo
var marketing_budget: float = 15000.0
var marketing_campaigns: Array = []     # {id, product_id, name, channel, target, budget, intensity, created_day}
var customer_feedback: Array = []        # {id, day, product_id, source, sentiment, issue, priority}
var employee_feedback: Array = []       # {id, day, product_id, category, note, morale_impact}
var product_tests: Array = []            # {id, product_id, day, type, objective, score, status}
var navigation: Dictionary = {
	"active": "overview",
	"sections": [
		{"id": "overview", "label": "Visão geral"},
		{"id": "products", "label": "Produtos"},
		{"id": "marketing", "label": "Marketing"},
		{"id": "research", "label": "Pesquisa"},
		{"id": "finance", "label": "Finanças"},
		{"id": "tests", "label": "Testes"}
	]
}

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

func _income(v: float, cat: String = "other") -> void:
	money += v
	income_month += v
	ledger[cat] = float(ledger.get(cat, 0.0)) + v

func _expense(v: float, cat: String = "other") -> void:
	money -= v
	expense_month += v
	ledger[cat] = float(ledger.get(cat, 0.0)) - v

func marketing_channels() -> Array:
	return Rules.MARKETING_CHANNELS

func navigation_sections() -> Array:
	return navigation.get("sections", [])

func set_navigation(section: String) -> Dictionary:
	var sections := navigation_sections()
	for s in sections:
		if str(s.get("id", "")) == section:
			navigation["active"] = section
			return _ok("", {"section": section})
	return _fail("Seção inválida")

# ───────────────────────── marketing e feedback ─────────────────────────

func launch_marketing_campaign(product_id: int, name: String, channel: String, target_segment: String, budget: float) -> Dictionary:
	if not marketing_channels().has(channel):
		return _fail("Canal de marketing inválido")
	if budget <= 0.0:
		return _fail("Orçamento inválido")
	if money < budget:
		return _fail("Dinheiro insuficiente")
	var product: Variant = _find_in(products, product_id)
	if product == null:
		return _fail("Produto não encontrado")
	_expense(budget, "marketing")
	var campaign := {
		"id": _new_id(),
		"product_id": product_id,
		"name": name if name != "" else "%s %s" % [product.pname, channel],
		"channel": channel,
		"target": target_segment,
		"budget": budget,
		"intensity": clampf(budget / 20000.0, 0.5, 2.5),
		"created_day": day,
		"status": "active"
	}
	marketing_campaigns.append(campaign)
	add_log("Campanha de marketing iniciada: %s" % campaign["name"], "good", "marketing")
	return _ok("", {"campaign": campaign})

func add_customer_feedback(product_id: int, source: String, sentiment: float, issue: String = "", priority: String = "medium") -> Dictionary:
	var product: Variant = _find_in(products, product_id)
	if product == null:
		return _fail("Produto não encontrado")
	var feed := {
		"id": _new_id(),
		"day": day,
		"product_id": product_id,
		"source": source,
		"sentiment": clampf(sentiment, -1.0, 1.0),
		"issue": issue,
		"priority": priority
	}
	product.add_feedback(feed)
	customer_feedback.append(feed)
	if customer_feedback.size() > Rules.MAX_FEEDBACK_MEMORY:
		customer_feedback.pop_front()
	if feed["sentiment"] < 0.0:
		reputation = maxf(0.0, reputation - (0.8 if priority == "high" else 0.4))
	add_log("Feedback do cliente: %s (%s)" % [product.pname, source], "info", "feedback")
	return _ok("", {"feedback": feed})

func add_employee_feedback(product_id: int, category: String, note: String, morale_impact: float = 0.0) -> Dictionary:
	var product: Variant = _find_in(products, product_id)
	if product == null:
		return _fail("Produto não encontrado")
	var entry := {
		"id": _new_id(),
		"day": day,
		"product_id": product_id,
		"category": category,
		"note": note,
		"morale_impact": morale_impact
	}
	employee_feedback.append(entry)
	for e in staff:
		e.morale = clampf(e.morale + morale_impact * 0.35, 0.0, 100.0)
	add_log("Feedback interno: %s (%s)" % [product.pname, category], "info", "team")
	return _ok("", {"feedback": entry})

func customize_product(product_id: int, hardware_cfg: Dictionary = {}, software_cfg: Dictionary = {}, style_cfg: Dictionary = {}) -> Dictionary:
	var product: Variant = _find_in(products, product_id)
	if product == null:
		return _fail("Produto não encontrado")
	product.apply_hardware_variant(hardware_cfg)
	product.apply_software_variant(software_cfg)
	product.apply_customization(style_cfg)
	return _ok("", {"product": product})

func begin_product_test(product_id: int, test_type: String = "field", objective: String = "usabilidade") -> Dictionary:
	if not Rules.PRODUCT_TEST_TYPES.has(test_type):
		return _fail("Tipo de teste inválido")
	var product: Variant = _find_in(products, product_id)
	if product == null:
		return _fail("Produto não encontrado")
	var test := {
		"id": _new_id(),
		"product_id": product_id,
		"day": day,
		"type": test_type,
		"objective": objective,
		"score": 0.0,
		"status": "running"
	}
	product_tests.append(test)
	product.tests.append(test)
	return _ok("", {"test": test})

func complete_product_test(product_id: int, test_type: String = "field", objective: String = "usabilidade") -> Dictionary:
	var product: Variant = _find_in(products, product_id)
	if product == null:
		return _fail("Produto não encontrado")
	var test_result := product.run_test(test_type)
	test_result["day"] = day
	test_result["objective"] = objective
	var record := {
		"id": _new_id(),
		"product_id": product_id,
		"day": day,
		"type": test_type,
		"objective": objective,
		"score": float(test_result.get("score", 0.0)),
		"status": "complete"
	}
	product_tests.append(record)
	if product_tests.size() > Rules.MAX_TEST_HISTORY:
		product_tests.pop_front()
	if record["score"] >= 0.75:
		reputation = minf(100.0, reputation + 1.0)
	add_log("Teste de produto concluído: %s (score %.2f)" % [product.pname, record["score"]], "good", "test")
	return _ok("", {"test": record})

# ───────────────────────── resta do arquivo mantido como antes ─────────────────────────

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
	var upkeep := 0.0
	if factory_level > 0:
		upkeep = float(GameData.manufacturers().own_factory.upkeep[factory_level - 1])
	return Rules.RENT_BASE + Rules.RENT_PER_STAFF * float(staff.size()) + upkeep

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
	_expense(cost, "capex")
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
	_expense(price, "hiring")
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
	_expense(severance, "hiring")
	staff.erase(e)
	add_log("Demitiu %s (indenização %s)" % [e.emp_name, Fmt.money(severance)], "bad", "fire")
	return _ok()

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
	_expense(float(cost.money), "training")
	research_points -= float(cost.rp)
	for a in Employee.ATTRS:
		e.set(a, mini(100, int(e.get(a)) + rng.randi_range(3, 9)))
	return _ok()

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
	_expense(float(cost.money), "research")
	research_levels[id] = research_level(id) + 1
	add_log("Pesquisa concluída: %s (nv.%d)" % [r.name, research_levels[id]], "good", "research")
	return _ok()

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

func estimate_quality(cat_id: String, specs: Dictionary, design: Dictionary = {}) -> float:
	return spec_score(cat_id, specs) * (1.0 + effect("tech_level")) * team_factor() * (1.0 + design_bonus()) \
		* (1.0 + float(design_mods(cat_id, design).q))

func estimate_final_quality(cat_id: String, specs: Dictionary, design: Dictionary, os_id: String, mfr_id: String) -> float:
	return estimate_quality(cat_id, specs, design) * os_mult(os_id, cat_id) * float(mfr_stats(mfr_id).q)

func estimate_final_cost(cat_id: String, specs: Dictionary, design: Dictionary, os_id: String, mfr_id: String) -> float:
	var cat: Dictionary = GameData.category(cat_id)
	return estimate_unit_cost(cat_id, specs, design) * float(mfr_stats(mfr_id).cost) * (1.0 - deal_cost_discount()) \
		+ float(os_info(os_id).get("royalty", 0.0)) * float(cat.unit_cost)

func os_option_ids() -> Array:
	var out: Array = []
	for o in GameData.os_data().licensed:
		out.append(str(o.id))
	if os_available("own"):
		out.append("own")
	return out

func mfr_option_ids() -> Array:
	var out: Array = []
	if factory_level > 0:
		out.append("own")
	for c in GameData.manufacturers().contractors:
		if reputation >= float(c.rep):
			out.append(str(c.id))
	return out

func set_product_color(prod_id: int, color_id: String) -> Dictionary:
	var p: Variant = _find_in(products, prod_id)
	if p == null:
		return _fail("Produto não encontrado")
	p.design["color"] = color_id
	return _ok()

func estimate_unit_cost(cat_id: String, specs: Dictionary, design: Dictionary = {}) -> float:
	var cat: Dictionary = GameData.category(cat_id)
	var load_f := 0.0
	for a in cat.axes:
		load_f += float(cat.axes[a]) * float(specs.get(a, 0)) / float(Rules.SPEC_AXIS_MAX)
	var disc: float = minf(0.5, effect("unit_cost_discount"))
	return float(cat.unit_cost) * (0.6 + 0.8 * load_f) * (1.0 - disc) * float(design_mods(cat_id, design).cost)

func fair_price(cat_id: String, quality: float) -> float:
	return float(GameData.category(cat_id).fair_price) * (0.5 + quality / 100.0)

func suggested_product_name(cat_id: String) -> String:
	var n: Dictionary = GameData.names()
	return "%s %s%d" % [n.product[rng.randi() % n.product.size()], cat_id.substr(0, 1).to_upper(), rng.randi_range(1, 9)]

func dev_products() -> Array:
	return products.filter(func(p): return p.state == Product.STATE_DEV)

func create_product(pname: String, cat_id: String, specs: Dictionary, price: float = 0.0,
		design: Dictionary = {}, os_id: String = "", mfr_id: String = "") -> Dictionary:
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
	if design.is_empty():
		design = default_design(cat_id)
	if not design_valid(cat_id, design):
		return _fail("Design ainda não desbloqueado")
	if os_id == "":
		os_id = default_os()
	if not os_available(os_id):
		return _fail("Sistema operacional indisponível")
	if mfr_id == "":
		mfr_id = default_mfr()
	if not mfr_available(mfr_id):
		return _fail("Fabricante indisponível")
	var fee := mfr_fee(mfr_id)
	if money < cost + fee:
		return _fail("Dinheiro insuficiente (taxa do fabricante %s)" % Fmt.money(fee))
	_expense(cost, "dev")
	_expense(fee, "fees")
	var p := Product.new()
	p.id = _new_id()
	p.pname = pname if pname != "" else suggested_product_name(cat_id)
	p.category = cat_id
	p.specs = specs.duplicate()
	p.price = price
	p.unit_cost = estimate_unit_cost(cat_id, specs, design)
	p.design = design.duplicate()
	p.os_id = os_id
	p.mfr = mfr_id
	p.work_required = float(cat.work)
	p.dev_cost = cost
	p.state = Product.STATE_DEV
	products.append(p)
	add_log("Iniciou o desenvolvimento de %s" % p.pname, "info", "success")
	return _ok("", {"product": p})

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
	p.quality = clampf(estimate_quality(p.category, p.specs, p.design) + rng.randf_range(-2.0, 2.0), 5.0, 250.0)
	p.state = Product.STATE_READY
	if p.price <= 0.0:
		p.price = roundf(fair_price(p.category, effective_quality(p)))
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

func attractiveness(p: Product) -> float:
	var cat: Dictionary = GameData.category(p.category)
	var exp_q := market.expectation(day)
	var eq := effective_quality(p)
	var q_factor := pow(clampf(eq / exp_q, 0.0, 3.0), 3.0)
	var fair := fair_price(p.category, eq)
	var price_factor := clampf(pow(fair / maxf(p.price, 1.0), 2.2), 0.0, 4.0)
	var age := day - p.release_day
	var dec := Market.decay(age, float(cat.lifetime))
	var hype := 1.0 + 0.6 * maxf(0.0, 1.0 - float(age) / 30.0) * (1.0 + effect("hype"))
	var rep_factor := 0.5 + reputation / 100.0
	var demand_factor := clampf(market.category_demand(p.category, day) / maxf(1000.0, float(cat.base_demand) * 3.0), 0.35, 2.5)
	var economy_factor := clampf(0.7 + (market.sentiment - 1.0) * 0.8 + (market.macro - 1.0) * 0.9, 0.45, 1.9)
	return q_factor * price_factor * dec * hype * rep_factor * demand_factor * economy_factor * maxf(0.5, p.market_fit)

func _sell() -> void:
	var exp_q := market.expectation(day)
	for cat in GameData.categories():
		var cat_id: String = cat.id
		var list: Array = released_products().filter(func(p): return p.category == cat_id)
		var size := market.market_size(cat_id, day)
		var comp_list: Array = market.comp_products.filter(func(c): return c.cat == cat_id)
		var comp_a: Array = []
		var comp := 0.0
		for cp in comp_list:
			var ca := market.comp_attr(cp, day)
			comp_a.append(ca)
			comp += ca
		var attr := {}
		var sum_mine := 0.0
		for p in list:
			var a := attractiveness(p)
			attr[p.id] = a
			sum_mine += a
		var denom := Rules.OUTSIDE_OPTION + sum_mine + comp
		for i in comp_list.size():
			var cp: Dictionary = comp_list[i]
			market.add_rival_revenue(int(cp.rival), size * float(comp_a[i]) / denom * float(cp.price))
		for p in list:
			var share: float = float(attr[p.id]) / denom
			var units_f: float = size * share * rng.randf_range(0.85, 1.15) * (1.0 + deal_sales_bonus(cat_id)) + p.units_carry
			var units := int(floor(units_f))
			p.units_carry = units_f - float(units)
			if units > 0:
				var revenue: float = float(units) * p.price
				var cost: float = float(units) * current_unit_cost(p)
				_income(revenue, "sales")
				var comm := revenue * deal_commission(cat_id)
				if comm > 0.0:
					_expense(comm, "commission")
				_expense(cost, "cogs")
				p.units_total += units
				p.revenue_total += revenue
				p.cost_total += cost
			p.ema_units = p.ema_units * 0.9 + float(units) * 0.1
			var ratio: float = effective_quality(p) / exp_q
			if ratio > 1.1:
				reputation = minf(100.0, reputation + 0.01)
			elif ratio < 0.7:
				reputation = maxf(0.0, reputation - 0.01)

func advance_day() -> void:
	if game_over:
		return
	day += 1
	_develop()
	_research_tick()
	_os_tick()
	_sell()
	market.tick(day)
	stocks.daily(self)
	for e in staff:
		e.morale = lerpf(e.morale, 75.0, 0.02)
	if day % Rules.DAYS_IN_MONTH == 0:
		_month_end()
	day_advanced.emit(day)

func _month_end() -> void:
	var payroll := monthly_payroll()
	var rent := monthly_rent()
	_expense(payroll, "payroll")
	_expense(rent, "rent")
	_deals_month()
	if loan > 0.0:
		_expense(loan * LOAN_RATE, "interest")
	var pre_tax := income_month - expense_month
	if pre_tax > 0.0:
		_expense(pre_tax * TAX_RATE, "taxes")
	last_income = income_month
	last_expense = expense_month
	ledger_last = ledger.duplicate()
	ledger = {}
	var profit := last_income - last_expense
	add_log("Fechamento do mês: %s %s" % ["lucro" if profit >= 0.0 else "prejuízo", Fmt.money(absf(profit))],
		"good" if profit >= 0.0 else "bad", "month" if profit >= 0.0 else "")
	income_month = 0.0
	expense_month = 0.0
	_recalls()
	stocks.month_end(self)
	history.append({"day": day, "money": money, "value": stocks.value})
	if history.size() > 120:
		history.pop_front()
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
			_income(float(eff.money), "events")
		else:
			_expense(-float(eff.money), "events")
	if eff.has("reputation"):
		reputation = clampf(reputation + float(eff.reputation), 0.0, 100.0)
	if eff.has("research_points"):
		research_points += float(eff.research_points)
	if eff.has("market"):
		var market_effect: Dictionary = eff.market
		market.apply_macro_shift(
			float(market_effect.get("macro", 0.0)),
			float(market_effect.get("sentiment", 0.0)),
			float(market_effect.get("supply_chain", 0.0)),
			float(market_effect.get("inflation", 0.0))
		)
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

func deal_def(id: String) -> Dictionary:
	for d in GameData.deals():
		if d.id == id:
			return d
	return {}

func deal_active(id: String) -> bool:
	for d in deals:
		if d.id == id and int(d.until) > day:
			return true
	return false

func active_deals() -> Array:
	return deals.filter(func(d): return int(d.until) > day)

func deal_blocker(id: String) -> String:
	var d := deal_def(id)
	if d.is_empty():
		return "Acordo inválido"
	if deal_active(id):
		return "Já em vigor"
	if active_deals().size() >= MAX_DEALS:
		return "Limite de %d acordos" % MAX_DEALS
	if reputation < float(d.rep):
		return "Reputação mínima %d" % int(d.rep)
	if money < float(d.fee):
		return "Taxa %s" % Fmt.money(float(d.fee))
	return ""

func sign_deal(id: String) -> Dictionary:
	var why := deal_blocker(id)
	if why != "":
		return _fail(why)
	var d := deal_def(id)
	_expense(float(d.fee), "fees")
	deals = deals.filter(func(x): return x.id != id)
	deals.append({"id": id, "until": day + int(d.days)})
	add_log("Acordo fechado: %s" % d.name, "good", "success")
	return _ok()

func _deal_applies(d: Dictionary, cat_id: String) -> bool:
	return d.cats.is_empty() or d.cats.has(cat_id)

func deal_sales_bonus(cat_id: String) -> float:
	var t := 0.0
	for a in active_deals():
		var d := deal_def(str(a.id))
		if not d.is_empty() and _deal_applies(d, cat_id):
			t += float(d.sales)
	return t

func deal_commission(cat_id: String) -> float:
	var t := 0.0
	for a in active_deals():
		var d := deal_def(str(a.id))
		if not d.is_empty() and _deal_applies(d, cat_id):
			t += float(d.commission)
	return t

func deal_cost_discount() -> float:
	var t := 0.0
	for a in active_deals():
		var d := deal_def(str(a.id))
		if not d.is_empty():
			t += float(d.cost)
	return minf(t, 0.3)

func _deals_month() -> void:
	for a in deals.duplicate():
		var d := deal_def(str(a.id))
		if int(a.until) <= day:
			deals.erase(a)
			add_log("Acordo encerrado: %s" % d.get("name", a.id), "info")
		elif not d.is_empty() and int(d.commit) > 0:
			_expense(float(d.commit), "commission")

func loan_limit() -> float:
	return 50000.0 + 0.4 * stocks.value

func take_loan(amount: float) -> Dictionary:
	if amount <= 0.0 or loan + amount > loan_limit():
		return _fail("Limite de crédito: %s" % Fmt.money(loan_limit()))
	loan += amount
	_income(amount, "loan")
	return _ok("Empréstimo de %s" % Fmt.money(amount))

func repay_loan(amount: float) -> Dictionary:
	amount = minf(amount, loan)
	if amount <= 0.0:
		return _fail("Sem dívida")
	if money < amount:
		return _fail("Dinheiro insuficiente")
	loan -= amount
	_expense(amount, "loan")
	return _ok("Pagou %s da dívida" % Fmt.money(amount))

func net_worth() -> float:
	return money + stocks.portfolio_value(market) - loan

# ───────────────────────── design, SO e produção ─────────────────────────

func default_design(cat_id: String) -> Dictionary:
	var shapes: Array = GameData.designs().shapes.get(cat_id, [])
	return {"shape": str(shapes[0].id) if not shapes.is_empty() else "classic", "finish": "alu", "color": "graphite",
		"w": 5, "h": 5, "d": 5, "corner": 5, "strap": 5, "features": []}

func design_item_unlocked(item: Dictionary) -> bool:
	return str(item.req) == "" or research_level(str(item.req)) >= int(item.lvl)

func shape_item(cat_id: String, id: String) -> Dictionary:
	for it in GameData.designs().shapes.get(cat_id, []):
		if it.id == id:
			return it
	return {}

func finish_item(id: String) -> Dictionary:
	for it in GameData.designs().finishes:
		if it.id == id:
			return it
	return {}

func design_valid(cat_id: String, design: Dictionary) -> bool:
	var sh := shape_item(cat_id, str(design.get("shape", "")))
	var fi := finish_item(str(design.get("finish", "")))
	if sh.is_empty() or fi.is_empty() or not design_item_unlocked(sh) or not design_item_unlocked(fi):
		return false
	for fid in design.get("features", []):
		var ft := feature_item(cat_id, str(fid))
		if ft.is_empty() or not design_item_unlocked(ft):
			return false
	return true

func feature_item(cat_id: String, id: String) -> Dictionary:
	for it in GameData.features(cat_id):
		if it.id == id:
			return it
	return {}

func design_mods(cat_id: String, design: Dictionary) -> Dictionary:
	var q := 0.0
	var cost := 1.0
	var sh := shape_item(cat_id, str(design.get("shape", "")))
	var fi := finish_item(str(design.get("finish", "")))
	if not sh.is_empty():
		q += float(sh.q)
		cost *= float(sh.cost)
	if not fi.is_empty():
		q += float(fi.q)
		cost *= float(fi.cost)
	for fid in design.get("features", []):
		var ft := feature_item(cat_id, str(fid))
		if not ft.is_empty():
			q += float(ft.q)
			cost *= float(ft.cost)
	var size := (float(design.get("w", 5)) + float(design.get("h", 5))) * 0.5
	q += 0.012 * (size - 5.0)
	cost *= 1.0 + 0.04 * (size - 5.0)
	var thin := 5.0 - float(design.get("d", 5))
	q += 0.008 * thin
	cost *= 1.0 + 0.025 * thin
	return {"q": q, "cost": maxf(0.5, cost)}

func os_ecosystem() -> float:
	var base := 0.0
	for p in products:
		if p.os_id == "own":
			base += float(p.units_total)
	return base

func os_info(id: String) -> Dictionary:
	if id == "own":
		var d: Dictionary = GameData.os_data().own
		var v := int(own_os.get("version", 0))
		var eco := minf(0.12, 0.05 * log(1.0 + os_ecosystem() / float(d.eco_base)) / log(10.0)) * (1.0 + 0.15 * float(os_focus().eco))
		return {"id": "own", "name": own_os.get("name", d.name), "q": float(d.base_q) + float(d.q_per_version) * float(maxi(v - 1, 0)) + eco,
			"royalty": 0.0, "version": v, "eco": eco}
	for o in GameData.os_data().licensed:
		if o.id == id:
			return o
	return {}

func os_available(id: String) -> bool:
	if id == "own":
		return int(own_os.get("version", 0)) >= 1
	return not os_info(id).is_empty()

func default_os() -> String:
	return "own" if os_available("own") else "droidix"

func os_mult(id: String, cat_id: String = "") -> float:
	var i := os_info(id)
	if i.is_empty():
		return 1.0
	var q := float(i.q)
	if id == "own" and cat_id != "":
		q += 0.006 * os_focus_relevance(cat_id)
	return q

const OS_AXES := ["perf", "visual", "eco", "secure"]
const OS_AXIS_NAMES := {"perf": "Desempenho", "visual": "Visual", "eco": "Ecossistema de apps", "secure": "Segurança"}
const OS_RELEVANCE := {
	"phone": {"perf": 0.4, "visual": 1.0, "secure": 0.4}, "watch": {"perf": 0.2, "visual": 1.0, "secure": 0.4},
	"laptop": {"perf": 1.0, "visual": 0.4, "secure": 0.4}, "console": {"perf": 1.0, "visual": 0.4, "secure": 0.4}}

func os_focus() -> Dictionary:
	var f: Dictionary = own_os.get("focus", {})
	return {"perf": int(f.get("perf", 0)), "visual": int(f.get("visual", 0)), "eco": int(f.get("eco", 0)), "secure": int(f.get("secure", 0))}

func os_focus_budget() -> int:
	return 8 + 4 * int(own_os.get("version", 0))

func os_focus_used() -> int:
	var t := 0
	for k in os_focus():
		t += int(os_focus()[k])
	return t

func os_focus_relevance(cat_id: String) -> float:
	var f := os_focus()
	var rel: Dictionary = OS_RELEVANCE.get(cat_id, {})
	var t := 0.0
	for k in rel:
		t += float(f[k]) * float(rel[k])
	return t

func set_os_focus(axis: String, delta: int) -> Dictionary:
	if int(own_os.get("version", 0)) < 1 and own_os.get("dev", null) == null:
		return _fail("Comece o desenvolvimento do sistema primeiro")
	var f := os_focus()
	var nv: int = int(f[axis]) + delta
	if nv < 0 or nv > 10:
		return _fail("")
	if delta > 0 and os_focus_used() + delta > os_focus_budget():
		return _fail("Sem pontos de foco livres")
	f[axis] = nv
	own_os["focus"] = f
	return _ok()

func set_os_accent(hex: String) -> void:
	own_os["accent"] = hex

func os_accent() -> String:
	return str(own_os.get("accent", "ff9a2e"))

func set_os(prod_id: int, id: String) -> Dictionary:
	var p: Variant = _find_in(products, prod_id)
	if p == null or not os_available(id):
		return _fail("Sistema indisponível")
	p.os_id = id
	return _ok()

func os_dev_cost() -> float:
	var d: Dictionary = GameData.os_data().own
	var v := int(own_os.get("version", 0))
	return float(d.dev_money[mini(v, d.dev_money.size() - 1)])

func os_dev_blocker() -> String:
	var d: Dictionary = GameData.os_data().own
	if research_level(str(d.req)) < 1:
		return "Pesquise Sistema Operacional Próprio"
	if own_os.get("dev", null) != null:
		return "Em desenvolvimento"
	if int(own_os.get("version", 0)) >= int(d.max_version):
		return "Versão máxima"
	if staff_of("programmer").is_empty():
		return "Contrate programadores"
	return ""

func start_os_dev(os_name: String = "") -> Dictionary:
	var why := os_dev_blocker()
	if why != "":
		return _fail(why)
	var d: Dictionary = GameData.os_data().own
	var money_cost := os_dev_cost()
	if money < money_cost:
		return _fail("Dinheiro insuficiente")
	_expense(money_cost, "research")
	var dev := {"work": 0.0, "req": float(d.dev_work), "money": money_cost}
	own_os["dev"] = dev
	if os_name != "":
		own_os["name"] = os_name
	add_log("Iniciou desenvolvimento do sistema operacional %s" % [own_os.get("name", d.name)], "info", "research")
	return _ok()

func _os_tick() -> void:
	if own_os.get("dev", null) == null:
		return
	var d: Dictionary = GameData.os_data().own
	var work := 0.0
	for e in staff_of("programmer"):
		work += 0.8 + float(e.pace) / 100.0
	own_os["dev"]["work"] += work
	if own_os["dev"]["work"] >= own_os["dev"]["req"]:
		own_os["version"] = int(own_os.get("version", 0)) + 1
		own_os["dev"] = null
		add_log("Sistema operacional atualizado para a versão %d" % [int(own_os.get("version", 0))], "good", "success")
