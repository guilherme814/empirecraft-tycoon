class_name Company
extends RefCounted
## Estado e regras da empresa do jogador. Não depende de nós nem de autoloads,
## então pode ser testado em modo headless (veja tests/).
##
## Toda ação do jogador devolve um Dictionary {ok: bool, msg: String, ...}.

signal log_added(text: String, kind: String, sfx: String)
signal day_advanced(day: int)
signal review_ready(prod_id: int)

const SAVE_VERSION := 6
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
var campaigns: Array = []         # campanhas de marketing ativas
var lab_jobs: Array = []          # ensaios em andamento
var chips: Array = []             # processadores projetados
var chip_dev: Variant = null      # chip em desenvolvimento {design, work, req}
var requests: Array = []          # pedidos da equipe
var loyalty: float = Loyalty.START  # lealdade à marca (0..100)
var loyalty_log: Array = []       # últimas mudanças {day, d, why}
var cash_items: Dictionary = {}     # mês atual: movimentos fora do resultado (empréstimo, bolsa, obras)
var cash_items_last: Dictionary = {}
var logo: Dictionary = Identity.default_logo()      # identidade visual
var decor: Dictionary = Identity.default_decor()    # mobiliário/decoração do escritório
var stores: Array = []            # lojas próprias (Stores)
var market_stats: Dictionary = {}  # último dia por categoria: {size, mine, rivals, none} (transitório)
var cash_start: float = Rules.START_MONEY  # caixa no início do mês (fluxo de caixa)
var cash_flow_last: float = 0.0   # fluxo de caixa do mês passado

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

## Movimentos de caixa que NÃO são receita/despesa (empréstimo, bolsa, obras): entram no fluxo de caixa, não no lucro.
func _cash_in(v: float, cat: String) -> void:
	money += v
	cash_items[cat] = float(cash_items.get(cat, 0.0)) + v

func _cash_out(v: float, cat: String) -> void:
	money -= v
	cash_items[cat] = float(cash_items.get(cat, 0.0)) - v

func _expense(v: float, cat: String = "other") -> void:
	money -= v
	expense_month += v
	ledger[cat] = float(ledger.get(cat, 0.0)) - v

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

## Amortecimento inicial: 50% dos custos fixos nos primeiros 90 dias ou enquanto o escritório é pequeno.
func fixed_cost_factor() -> float:
	var top := 1
	for k in office_level:
		top = maxi(top, int(office_level[k]))
	if day <= Rules.EARLY_DAYS or top <= Rules.EARLY_OFFICE_LEVEL:
		return Rules.EARLY_FIXED_FACTOR
	return 1.0

func monthly_payroll() -> float:
	var t := 0.0
	for e in staff:
		t += e.salary()
	return t * fixed_cost_factor()

func monthly_rent() -> float:
	var upkeep := 0.0
	if factory_level > 0:
		upkeep = float(GameData.manufacturers().own_factory.upkeep[factory_level - 1])
	return (Rules.RENT_BASE + Rules.RENT_PER_STAFF * float(staff.size())) * fixed_cost_factor() + upkeep

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
	_cash_out(cost, "capex")
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
	_expense(float(cost.money), "training")
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
	_expense(float(cost.money), "research")
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
func estimate_quality(cat_id: String, specs: Dictionary, design: Dictionary = {}) -> float:
	return spec_score(cat_id, specs) * (1.0 + effect("tech_level")) * team_factor() * (1.0 + design_bonus()) \
		* (1.0 + float(design_mods(cat_id, design).q))

## Qualidade final esperada, já com sistema e fabricante escolhidos.
func estimate_final_quality(cat_id: String, specs: Dictionary, design: Dictionary, os_id: String, mfr_id: String) -> float:
	return estimate_quality(cat_id, specs, design) * os_mult(os_id, cat_id) * float(mfr_stats(mfr_id).q) * chip_mult(cat_id, specs, design)

## Estatísticas ao vivo do editor (qualidade, custo, preço justo, margem, prazo).
func device_stats(cat_id: String, specs: Dictionary, design: Dictionary, os_id: String, mfr_id: String) -> Dictionary:
	var q := estimate_final_quality(cat_id, specs, design, os_id, mfr_id)
	var uc := estimate_final_cost(cat_id, specs, design, os_id, mfr_id)
	var fp := fair_price(cat_id, q)
	return {"quality": q, "unit_cost": uc, "fair_price": fp, "margin": (fp - uc) / maxf(fp, 1.0)}

func chip_mult(cat_id: String, specs: Dictionary, design: Dictionary) -> float:
	var cid := int(design.get("chip", 0))
	if cid == 0:
		return 1.0
	return Chips.quality_mult(self, Chips.get_chip(self, cid), cat_id, specs)

func chip_cost(cat_id: String, design: Dictionary) -> float:
	var cid := int(design.get("chip", 0))
	return 0.0 if cid == 0 else Chips.cost_delta(Chips.get_chip(self, cid), cat_id)

func estimate_final_cost(cat_id: String, specs: Dictionary, design: Dictionary, os_id: String, mfr_id: String) -> float:
	var cat: Dictionary = GameData.category(cat_id)
	return (estimate_unit_cost(cat_id, specs, design) + chip_cost(cat_id, design)) * float(mfr_stats(mfr_id).cost) * (1.0 - deal_cost_discount()) * market.cost_pressure() \
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
	p.unit_cost = estimate_unit_cost(cat_id, specs, design) + chip_cost(cat_id, design)
	p.design = design.duplicate()
	p.os_id = os_id
	p.mfr = mfr_id
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
	p.quality = clampf(estimate_quality(p.category, p.specs, p.design) + rng.randf_range(-2.0, 2.0), 5.0, 250.0)
	p.state = Product.STATE_READY
	Lab.roll_flaws(self, p)
	if p.price <= 0.0:
		p.price = roundf(fair_price(p.category, effective_quality(p)))
	add_log("%s está pronto para lançamento (qualidade %d)" % [p.pname, int(round(p.quality))], "good", "ready")

const PROMISE_COSTS := {0.0: 0.0, 0.1: 8000.0, 0.25: 25000.0, 0.4: 70000.0}

func release(prod_id: int, price: float = -1.0, promise: float = 0.0) -> Dictionary:
	var p: Variant = _find_in(products, prod_id)
	if p == null:
		return _fail("Produto não encontrado")
	if p.state != Product.STATE_READY:
		return _fail("Produto não está pronto")
	if price > 0.0:
		p.price = price
	var fee: float = float(PROMISE_COSTS.get(promise, -1.0))
	if fee < 0.0:
		return _fail("Promessa inválida")
	if money < fee:
		return _fail("Campanha custa %s" % Fmt.money(fee))
	if fee > 0.0:
		_expense(fee, "fees")
	p.promise = promise
	p.state = Product.STATE_RELEASED
	p.release_day = day
	var best := market.best_quality(p.category)
	var adv: float = effective_quality(p) / maxf(best, 1.0) - 1.0
	p.promise_gap = maxf(0.0, promise - adv) if promise > 0.0 else 0.0
	# fãs compram no primeiro dia e já chegam sabendo do produto (antes das avaliações)
	var fans := Loyalty.preorders(self, p.category)
	p.awareness = maxf(p.awareness, Loyalty.initial_awareness(self))
	if fans > 0:
		_book_sale(p, fans, p.category)
		add_log("%d %s compraram %s no lançamento (lealdade %d%%)" % [fans, "fã" if fans == 1 else "fãs", p.pname, int(loyalty)], "good", "success")
	add_log("%s foi lançado por %s!" % [p.pname, Fmt.money(p.price)], "good", "release")
	Reviews.launch(self, p)
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
	var eq := effective_quality(p)
	var q_factor := pow(clampf(eq / exp_q, 0.0, 3.0), 3.0)
	var fair := fair_price(p.category, eq)
	var price_factor := clampf(pow(fair / maxf(p.price, 1.0), 2.2), 0.0, 4.0)
	var age := day - p.release_day
	var dec := Market.decay(age, float(cat.lifetime))
	var hype := 1.0 + 0.6 * maxf(0.0, 1.0 - float(age) / 30.0) * (1.0 + effect("hype") + 1.5 * p.promise)
	var rep_factor := 0.5 + reputation / 100.0
	return q_factor * price_factor * dec * hype * rep_factor * rating_factor(p) * Loyalty.sales_mult(self) * Marketing.factor(Marketing.awareness_of(self, p)) * (1.04 if is_fashion_color(str(p.design.get("color", ""))) else 1.0)

## Nota dos clientes realimenta as vendas: 1★ = 0.75, 3★ = 1.0, 5★ = 1.25.
func rating_factor(p: Product) -> float:
	if p.rating_n < 3:
		return 1.0
	return lerpf(0.75, 1.25, clampf((p.rating - 1.0) / 4.0, 0.0, 1.0))

func is_fashion_color(color_id: String) -> bool:
	return color_id != "" and color_id == str(market.fashion.get("color", ""))

## Piso de demanda: produtos medianos a preço justo não ficam parados (decai com a idade do produto).
func demand_floor(p: Product, exp_q: float) -> float:
	var eq := effective_quality(p)
	if eq < 0.5 * exp_q or p.price > 1.3 * fair_price(p.category, eq):
		return 0.0
	var cat: Dictionary = GameData.category(p.category)
	return Rules.MIN_DAILY_DEMAND * Market.decay(day - p.release_day, float(cat.lifetime)) * minf(1.0, eq / exp_q)

func _book_sale(p: Product, units: int, cat_id: String) -> void:
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
		var mine_units := 0
		for p in list:
			var share: float = float(attr[p.id]) / denom
			var raw_f: float = size * share * rng.randf_range(0.85, 1.15) * (1.0 + deal_sales_bonus(cat_id))
			raw_f = maxf(raw_f, demand_floor(p, exp_q))
			var units_f: float = raw_f + p.units_carry
			var units := int(floor(units_f))
			p.units_carry = units_f - float(units)
			mine_units += units
			if units > 0:
				_book_sale(p, units, cat_id)
			p.ema_units = p.ema_units * 0.9 + float(units) * 0.1
			# só produtos que ainda vendem mexem na reputação (um catálogo antigo parado não a derruba)
			if units > 0:
				var ratio: float = effective_quality(p) / exp_q
				if ratio > 1.1:
					reputation = minf(100.0, reputation + 0.01)
				elif ratio < 0.7:
					reputation = maxf(0.0, reputation - 0.01)
		var rival_units := size * comp / denom
		var none_units := size * Rules.OUTSIDE_OPTION / denom
		market_stats[cat_id] = {"size": size, "mine": float(mine_units), "rivals": rival_units, "none": none_units,
			"attr": attr, "denom": denom, "share": (float(mine_units) / size) if size > 0.0 else 0.0}

# ───────────────────────── tempo ─────────────────────────

func advance_day() -> void:
	if game_over:
		return
	day += 1
	_develop()
	_research_tick()
	_os_tick()
	Chips.tick(self)
	Marketing.tick(self)
	Lab.tick(self)
	Lab.beta_tick(self)
	_sell()
	Stores.daily(self)
	market.tick(day)
	stocks.daily(self)
	for e in staff:
		e.morale = lerpf(e.morale, 75.0, 0.02)
	if day % Rules.DAYS_IN_MONTH == 0:
		_month_end()
	day_advanced.emit(day)

## Confirma identidade e decoração novas; cobra só o que mudou.
func apply_identity(new_logo: Dictionary, new_decor: Dictionary) -> Dictionary:
	var nl := Identity.clean_logo(new_logo)
	var nd := Identity.clean_decor(new_decor)
	var cost := Identity.change_cost(logo, nl, decor, nd)
	if cost <= 0.0 and nl == logo and nd == decor:
		return _fail("Nada mudou")
	if money < cost:
		return _fail("Caixa insuficiente: %s" % Fmt.money(cost))
	if cost > 0.0:
		_cash_out(cost, "capex")
	logo = nl
	decor = nd
	return _ok("Identidade atualizada")

func _month_end() -> void:
	var payroll := monthly_payroll()
	var rent := monthly_rent()
	_expense(payroll, "payroll")
	_expense(rent, "rent")
	_deals_month()
	Stores.monthly(self)
	if loan > 0.0:
		_expense(loan * LOAN_RATE, "interest")
	var pre_tax := income_month - expense_month
	if pre_tax > 0.0:
		_expense(pre_tax * TAX_RATE, "taxes")
	last_income = income_month
	last_expense = expense_month
	ledger_last = ledger.duplicate()
	ledger = {}
	cash_items_last = cash_items.duplicate()
	cash_items = {}
	cash_flow_last = money - cash_start
	cash_start = money
	var profit := last_income - last_expense
	add_log("Fechamento do mês: %s %s" % ["lucro" if profit >= 0.0 else "prejuízo", Fmt.money(absf(profit))],
		"good" if profit >= 0.0 else "bad", "month" if profit >= 0.0 else "")
	income_month = 0.0
	expense_month = 0.0
	_recalls()
	Reviews.monthly(self)
	Feedback.monthly(self)
	Loyalty.monthly(self)
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
	if eff.has("market"):
		var me: Dictionary = eff.market
		market.apply_macro_shift(float(me.get("macro", 0.0)), float(me.get("sentiment", 0.0)),
			float(me.get("supply_chain", 0.0)), float(me.get("inflation", 0.0)))
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

# ───────────────────────── acordos, empréstimos e finanças ─────────────────────────

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
	_cash_in(amount, "loan")
	return _ok("Empréstimo de %s" % Fmt.money(amount))

func repay_loan(amount: float) -> Dictionary:
	amount = minf(amount, loan)
	if amount <= 0.0:
		return _fail("Sem dívida")
	if money < amount:
		return _fail("Dinheiro insuficiente")
	loan -= amount
	_cash_out(amount, "loan")
	return _ok("Pagou %s da dívida" % Fmt.money(amount))

func net_worth() -> float:
	return money + stocks.portfolio_value(market) - loan

# ───────────────────────── design, SO e produção ─────────────────────────

func default_design(cat_id: String) -> Dictionary:
	var shapes: Array = GameData.designs().shapes.get(cat_id, [])
	return {"shape": str(shapes[0].id) if not shapes.is_empty() else "classic", "finish": "alu", "color": "graphite",
		"w": 5, "h": 5, "d": 5, "corner": 5, "strap": 5, "features": [],
		"trim": "silver", "wall": "aurora", "cam": "plate", "notch": "punch", "band": "silicone", "led": "blue", "brand": true,
		"package": "basic", "acc": [], "chip": 0}

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
	var pk := package_item(str(design.get("package", "basic")))
	if pk.is_empty() or not design_item_unlocked(pk):
		return false
	for aid in design.get("acc", []):
		var ac := accessory_item(str(aid))
		if ac.is_empty() or not design_item_unlocked(ac) or not (ac.cats as Array).has(cat_id):
			return false
	var cid := int(design.get("chip", 0))
	if cid != 0 and Chips.get_chip(self, cid).is_empty():
		return false
	return true

func package_item(id: String) -> Dictionary:
	for x in GameData.designs().get("packages", []):
		if x.id == id:
			return x
	return {}

func accessory_item(id: String) -> Dictionary:
	for x in GameData.designs().get("accessories", []):
		if x.id == id:
			return x
	return {}

func feature_item(cat_id: String, id: String) -> Dictionary:
	for it in GameData.features(cat_id):
		if it.id == id:
			return it
	return {}

## Bônus de qualidade e fator de custo do design (formato + acabamento).
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
	var pk := package_item(str(design.get("package", "basic")))
	if not pk.is_empty():
		q += float(pk.q)
		cost *= float(pk.cost)
	for aid in design.get("acc", []):
		var ac := accessory_item(str(aid))
		if not ac.is_empty():
			q += float(ac.q)
			cost *= float(ac.cost)
	# medidas (1-9): maior = mais qualidade e mais custo; mais fino = mais caro e mais elegante
	var size := (float(design.get("w", 5)) + float(design.get("h", 5))) * 0.5
	q += 0.012 * (size - 5.0)
	cost *= 1.0 + 0.04 * (size - 5.0)
	var thin := 5.0 - float(design.get("d", 5))
	q += 0.008 * thin
	cost *= 1.0 + 0.025 * thin
	return {"q": q, "cost": maxf(0.5, cost)}

# Sistema operacional
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
		var eco := minf(0.12, 0.05 * log(1.0 + os_ecosystem() / float(d.eco_base)) / log(10.0)) * (1.0 + 0.15 * float(os_axis_totals().eco))
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

## Foco + pontos dos recursos ativos de software.
func os_axis_totals() -> Dictionary:
	var f := os_focus()
	for fid in own_os.get("features", []):
		var ft := os_feature(str(fid))
		if not ft.is_empty():
			f[str(ft.axis)] = int(f[str(ft.axis)]) + int(ft.pts)
	return f

func os_feature(id: String) -> Dictionary:
	for ft in GameData.os_data().get("features", []):
		if ft.id == id:
			return ft
	return {}

func os_feature_slots() -> int:
	return 1 + int(own_os.get("version", 0))

func os_feature_blocker(id: String) -> String:
	var ft := os_feature(id)
	if ft.is_empty():
		return "Recurso inválido"
	if int(own_os.get("version", 0)) < 1:
		return "Lance a v1 do seu sistema"
	if research_level("res_software") < int(ft.res):
		return "Pesquise Engenharia de Software nv.%d" % int(ft.res)
	if (own_os.get("features", []) as Array).has(id):
		return ""
	if (own_os.get("features", []) as Array).size() >= os_feature_slots():
		return "Sem espaço (%d recursos)" % os_feature_slots()
	if not (own_os.get("owned", []) as Array).has(id) and money < float(ft.cost):
		return "Custa %s" % Fmt.money(float(ft.cost))
	return ""

func toggle_os_feature(id: String) -> Dictionary:
	var why := os_feature_blocker(id)
	if why != "":
		return _fail(why)
	var act_list: Array = own_os.get("features", [])
	var owned: Array = own_os.get("owned", [])
	if act_list.has(id):
		act_list.erase(id)
	else:
		if not owned.has(id):
			_expense(float(os_feature(id).cost), "dev")
			owned.append(id)
		act_list.append(id)
	own_os["features"] = act_list
	own_os["owned"] = owned
	return _ok()

func os_focus_relevance(cat_id: String) -> float:
	var f := os_axis_totals()
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
	var v := int(own_os.get("version", 0))
	var cost := os_dev_cost()
	if money < cost:
		return _fail("Dinheiro insuficiente")
	_expense(cost, "dev")
	if os_name != "" and v == 0:
		own_os["name"] = os_name
	if not own_os.has("focus"):
		own_os["focus"] = {"perf": 2, "visual": 2, "eco": 2, "secure": 2}
	own_os["version"] = v
	own_os["dev"] = {"work": 0.0, "req": float(d.dev_work[mini(v, d.dev_work.size() - 1)])}
	add_log("Começou o desenvolvimento do %s v%d" % [own_os.get("name", d.name), v + 1], "info", "success")
	return _ok()

func _os_tick() -> void:
	var dev: Variant = own_os.get("dev", null)
	if dev == null:
		return
	var work := 0.0
	for e in staff_of("programmer"):
		work += (0.5 + float(e.pace) / 100.0) * (0.7 + 0.3 * e.morale / 100.0)
	dev["work"] = float(dev.work) + work * 0.6 * (1.0 + effect("dev_speed"))
	if float(dev.work) >= float(dev.req):
		own_os["version"] = int(own_os.get("version", 0)) + 1
		own_os["dev"] = null
		add_log("%s v%d foi lançado!" % [own_os.get("name", "Sistema próprio"), int(own_os.version)], "good", "release")

# Produção
func factory_info() -> Dictionary:
	return GameData.manufacturers().own_factory

func factory_blocker() -> String:
	var f := factory_info()
	if research_level(str(f.req)) < 1:
		return "Pesquise Manufatura Própria"
	if factory_level >= f.build.size():
		return "Fábrica no nível máximo"
	if money < float(f.build[factory_level]):
		return "Dinheiro insuficiente"
	return ""

func build_factory() -> Dictionary:
	var why := factory_blocker()
	if why != "":
		return _fail(why)
	var f := factory_info()
	_cash_out(float(f.build[factory_level]), "capex")
	factory_level += 1
	add_log("Fábrica própria nível %d inaugurada" % factory_level, "good", "success")
	return _ok()

func contractor(id: String) -> Dictionary:
	for c in GameData.manufacturers().contractors:
		if c.id == id:
			return c
	return {}

func mfr_available(id: String) -> bool:
	if id == "own":
		return factory_level > 0
	var c := contractor(id)
	return not c.is_empty() and reputation >= float(c.rep)

func default_mfr() -> String:
	return "own" if factory_level > 0 else "fabrix"

func mfr_fee(id: String) -> float:
	return 0.0 if id == "own" else float(contractor(id).get("fee", 0))

## {cost, q, risk} do fabricante (cai para o contratado padrão se a fábrica sumir).
func mfr_stats(id: String) -> Dictionary:
	if id == "own" and factory_level > 0:
		var f := factory_info()
		return {"cost": float(f.cost[factory_level - 1]), "q": float(f.q[factory_level - 1]), "risk": 0.0}
	var c := contractor(id if id != "own" else "fabrix")
	return {"cost": float(c.cost), "q": float(c.q), "risk": float(c.risk)}

func set_manufacturer(prod_id: int, id: String) -> Dictionary:
	var p: Variant = _find_in(products, prod_id)
	if p == null or not mfr_available(id):
		return _fail("Fabricante indisponível")
	if p.mfr == id:
		return _ok()
	var fee := mfr_fee(id)
	if money < fee:
		return _fail("Taxa de contrato: %s" % Fmt.money(fee))
	_expense(fee, "fees")
	p.mfr = id
	return _ok("Contrato com %s fechado" % (contractor(id).get("name", "fábrica própria")))

func effective_quality(p: Product) -> float:
	return p.quality * os_mult(p.os_id, p.category) * float(mfr_stats(p.mfr).q) * chip_mult(p.category, p.specs, p.design)

func current_unit_cost(p: Product) -> float:
	var cat: Dictionary = GameData.category(p.category)
	var royalty := float(os_info(p.os_id).get("royalty", 0.0)) * float(cat.unit_cost)
	return p.unit_cost * float(mfr_stats(p.mfr).cost) * (1.0 - deal_cost_discount()) * market.cost_pressure() + royalty

## Defeitos de fábrica: chance mensal por produto, maior em terceirizadas baratas.
func _recalls() -> void:
	for p in released_products():
		var risk: float = float(mfr_stats(p.mfr).risk) + 0.012 * float(Lab.severity_sum(p))
		if risk > 0.0 and rng.randf() < risk:
			var loss: float = maxf(2000.0, p.ema_units * 30.0 * current_unit_cost(p) * 0.4)
			_expense(loss, "recall")
			reputation = maxf(0.0, reputation - 2.0)
			Loyalty.on_recall(self, p)
			for i in 3:
				p.reviews.append(Reviews.customer(self, p, true))
				p.rating = lerpf(p.rating, 1.5, 0.15)
			add_log("Defeito de fábrica em %s (recall: %s)" % [p.pname, Fmt.money(loss)], "bad", "event_bad")

func company_value() -> float:
	return stocks.value

# ───────────────────────── resumo e save ─────────────────────────

func get_product(prod_id: int) -> Product:
	return _find_in(products, prod_id)

func released_products() -> Array:
	return products.filter(func(p): return p.state == Product.STATE_RELEASED)

func daily_sales_estimate() -> float:
	var t := 0.0
	for p in released_products():
		t += p.ema_units * (p.price - current_unit_cost(p))
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
		"stocks": stocks.to_dict(), "own_os": own_os, "factory": factory_level,
		"ledger": ledger, "ledger_last": ledger_last, "history": history, "loan": loan, "deals": deals,
		"campaigns": campaigns, "lab_jobs": lab_jobs, "chips": chips, "chip_dev": chip_dev, "requests": requests,
		"loyalty": loyalty, "loyalty_log": loyalty_log, "cash_start": cash_start, "cash_flow_last": cash_flow_last,
		"cash_items": cash_items, "cash_items_last": cash_items_last, "stores": stores, "logo": logo, "decor": decor,
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
	c.logo = Identity.clean_logo(d.get("logo", {}))
	c.decor = Identity.clean_decor(d.get("decor", {}))
	for sd in d.get("stores", []):
		var st: Dictionary = (sd as Dictionary).duplicate(true)
		st["id"] = int(st.get("id", 0))
		st["staff"] = int(st.get("staff", 1))
		st["units"] = int(st.get("units", 0))
		st["revenue"] = float(st.get("revenue", 0.0))
		st["carry"] = st.get("carry", {})
		c.stores.append(st)
	c.game_over = bool(d.get("game_over", false))
	c.log_entries = d.get("log", []).duplicate(true)
	c.income_month = float(d.get("income_month", 0.0))
	c.expense_month = float(d.get("expense_month", 0.0))
	c.last_income = float(d.get("last_income", 0.0))
	c.last_expense = float(d.get("last_expense", 0.0))
	c.stocks.load_dict(d.get("stocks", {}))
	c.own_os = d.get("own_os", {}).duplicate(true)
	c.factory_level = int(d.get("factory", 0))
	c.ledger = d.get("ledger", {}).duplicate()
	c.ledger_last = d.get("ledger_last", {}).duplicate()
	c.loan = float(d.get("loan", 0.0))
	c.history = d.get("history", []).duplicate(true)
	c.deals = d.get("deals", []).duplicate(true)
	c.campaigns = d.get("campaigns", []).duplicate(true)
	c.lab_jobs = d.get("lab_jobs", []).duplicate(true)
	c.chips = d.get("chips", []).duplicate(true)
	c.chip_dev = d.get("chip_dev", null)
	c.requests = d.get("requests", []).duplicate(true)
	c.loyalty = float(d.get("loyalty", Loyalty.START))
	c.loyalty_log = d.get("loyalty_log", []).duplicate(true)
	c.cash_start = float(d.get("cash_start", c.money))
	c.cash_flow_last = float(d.get("cash_flow_last", 0.0))
	c.cash_items = d.get("cash_items", {}).duplicate()
	c.cash_items_last = d.get("cash_items_last", {}).duplicate()
	c.rng.state = str(d.get("rng_state", "0")).to_int()
	return c
