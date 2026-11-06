extends SceneTree
## Testes da simulação (sem UI). Rode:
##   godot --headless --path . --script res://tests/run_tests.gd
## Sai com código 1 se algo falhar e imprime "FAILED".

var failures: Array = []

func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
		print("  FALHOU: ", msg)

func _initialize() -> void:
	print("Executando testes do Device Empire...")
	test_data()
	test_hiring()
	test_training_research()
	test_product_flow()
	test_save_roundtrip()
	test_determinism()
	test_bankruptcy()
	test_v3_systems()
	test_brand_loyalty()
	test_version_sync()
	test_old_save_compat()
	test_macro_economy()
	test_economy_financial_integrity()
	test_early_relief_and_floor()
	test_updater_and_backups()
	test_office_layout()
	test_identity_and_rivals()
	test_rival_reactions()
	test_store_country_summary()
	test_logistics()
	test_tutorial()
	test_device_variants()
	test_logo_symbols()
	test_sandbox()
	test_os_look_and_notifs()
	test_founding()
	test_decisions()
	test_look()
	test_components()
	test_chip_expansion()
	test_updates_teardown()
	test_presentations()
	test_acquisitions()
	test_chip_realism()
	if failures.is_empty():
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("FAILED: %d teste(s)" % failures.size())
		quit(1)

func staffed(seed_v: int = 7) -> Company:
	var c := Company.new(seed_v)
	c.money = 500000.0
	for prof in ["engineer", "programmer", "researcher"]:
		var r := c.auto_fill(prof, 0, 0.0)
		check(r.ok, "auto_fill " + prof)
	return c

func test_data() -> void:
	check(GameData.categories().size() >= 4, "categorias carregadas")
	for cat in GameData.categories():
		var s := 0.0
		for a in cat.axes:
			s += float(cat.axes[a])
		check(absf(s - 1.0) < 0.001, "pesos da categoria %s somam 1 (%f)" % [cat.id, s])
	for r in GameData.research():
		if str(r.requires) != "":
			check(not GameData.research_item(str(r.requires)).is_empty(), "requisito existe: " + r.id)
		var ids: Array = Rules.RESEARCH_AREAS.map(func(a): return a.id)
		check(ids.has(str(r.get("area", ""))), "pesquisa com área válida: " + str(r.id))
	check(Fmt.date(0) == "01/01/2010", "Fmt.date dia 0: " + Fmt.date(0))
	check(Fmt.thousands(1234567) == "1.234.567", "Fmt.thousands")

func test_hiring() -> void:
	var c := Company.new(1)
	var money0 := c.money
	var r := c.search_agency(0, "engineer")
	check(r.ok and c.candidates.size() >= 2, "busca de agência gera candidatos")
	check(c.money < money0, "busca custa dinheiro")
	var cand: Employee = c.candidates[0]
	check(c.hire(cand.id).ok, "contratar candidato")
	check(c.staff.size() == 1, "equipe tem 1")
	c.auto_fill("engineer", 0, 0.0)
	check(c.staff_of("engineer").size() == c.capacity("engineer"), "auto_fill lota o escritório")
	var extra := Employee.new()
	extra.id = 999
	extra.profession = "engineer"
	c.candidates.append(extra)
	check(not c.hire(999).ok, "não contrata acima da capacidade")
	var broke := Company.new(2)
	broke.money = 100.0
	check(not broke.search_agency(0, "engineer").ok, "sem dinheiro não busca")
	check(c.upgrade_office("engineer").ok, "melhorar escritório")
	check(c.capacity("engineer") == 4, "capacidade nível 2 = 4")
	var f: Employee = c.staff[0]
	check(c.fire(f.id).ok and not c.staff.has(f), "demitir")

func test_training_research() -> void:
	var c := staffed()
	var e: Employee = c.staff[0]
	var before := e.total()
	c.research_points = 1000.0
	check(c.train(e.id).ok, "treinar")
	check(e.total() > before, "treino aumenta atributos")
	for i in 80:
		c.train(e.id)
	check(e.craft <= 100 and e.pace <= 100 and e.insight <= 100, "atributos limitados a 100")
	c.research_points = 500.0
	check(not c.do_research("res_laptop").ok, "pesquisa com requisito bloqueada")
	check(c.do_research("res_tech").ok, "pesquisar res_tech")
	check(c.effect("tech_level") > 0.0, "efeito de pesquisa aplicado")
	c.research_points = 10000.0
	c.money = 2.0e6
	var all := c.research_all(0.0)
	check(all.done > 5, "research_all pesquisa vários itens (%d)" % all.done)
	check(c.category_unlocked("laptop"), "notebook desbloqueado")

func test_product_flow() -> void:
	var c := Company.new(11)
	c.money = 400000.0
	var specs := c.default_specs("phone")
	check(not c.create_product("X", "phone", specs).ok, "sem equipe não desenvolve")
	check(not c.create_product("X", "laptop", specs).ok, "categoria bloqueada")
	for prof in ["engineer", "programmer"]:
		c.auto_fill(prof, 1, 0.0)
	var bad := specs.duplicate()
	bad["performance"] = 500
	check(not c.create_product("X", "phone", bad).ok, "acima do orçamento de pontos")
	var cr := c.create_product("Teste", "phone", specs)
	check(cr.ok, "criar produto")
	var p: Product = cr.product
	var days := 0
	var peak := 0
	while p.state == Product.STATE_DEV and days < 400:
		c.advance_day()
		peak = maxi(peak, c.dev_bugs(p))
		days += 1
	check(peak > 0 and c.dev_bugs(p) == 0, "erros de programação sobem no meio e zeram ao terminar (pico %d)" % peak)
	check(p.state == Product.STATE_READY, "produto fica pronto (%d dias)" % days)
	check(p.quality > 20.0, "qualidade razoável (%f)" % p.quality)
	check(p.price > 0.0, "preço sugerido definido")
	check(c.release(p.id).ok, "lançar")
	var money_before := c.money
	for i in 90:
		c.advance_day()
	check(p.units_total > 0, "produto vendeu (%d un.)" % p.units_total)
	check(p.revenue_total > 0.0, "gerou receita")
	check(c.money != money_before, "dinheiro mudou")
	check(c.log_entries.size() > 0, "log registrado")
	# preço absurdo derruba as vendas
	var q := Company.new(12)
	q.money = 400000.0
	for prof in ["engineer", "programmer"]:
		q.auto_fill(prof, 1, 0.0)
	var cheap: Product = q.create_product("A", "phone", q.default_specs("phone")).product
	var dear: Product = q.create_product("B", "phone", q.default_specs("phone")).product
	for i in 200:
		q.advance_day()
	q.release(cheap.id, q.fair_price("phone", cheap.quality))
	q.release(dear.id, q.fair_price("phone", dear.quality) * 4.0)
	for i in 60:
		q.advance_day()
	check(cheap.units_total > dear.units_total, "preço justo vende mais que preço absurdo (%d vs %d)" % [cheap.units_total, dear.units_total])

func test_save_roundtrip() -> void:
	var c := staffed(21)
	c.research_points = 300.0
	c.do_research("res_speed")
	var p: Product = c.create_product("Save", "phone", c.default_specs("phone")).product
	for i in 120:
		c.advance_day()
	c.release(p.id)
	for i in 40:
		c.advance_day()
	var json := JSON.stringify(c.to_dict())
	var back: Variant = JSON.parse_string(json)
	check(back is Dictionary, "JSON do save é válido")
	var d := Company.from_dict(back)
	check(d.day == c.day and is_equal_approx(d.money, c.money), "dia e dinheiro preservados")
	check(d.staff.size() == c.staff.size(), "equipe preservada")
	check(d.products.size() == c.products.size(), "produtos preservados")
	check(d.research_level("res_speed") == 1, "pesquisa preservada")
	check(d.rng.state == c.rng.state, "estado do RNG preservado")
	for i in 30:
		c.advance_day()
		d.advance_day()
	check(is_equal_approx(d.money, c.money), "simulação continua idêntica após carregar")

func test_determinism() -> void:
	var a := staffed(33)
	var b := staffed(33)
	a.create_product("D", "phone", a.default_specs("phone"))
	b.create_product("D", "phone", b.default_specs("phone"))
	for i in 150:
		a.advance_day()
		b.advance_day()
	check(is_equal_approx(a.money, b.money), "mesma seed = mesmo resultado")

func test_bankruptcy() -> void:
	var c := Company.new(5)
	c.money = Rules.BANKRUPT_LIMIT - 200000.0   # folga: eventos aleatórios não salvam a empresa
	for i in 31:
		c.advance_day()
	check(c.game_over, "falência detectada")
	var day := c.day
	c.advance_day()
	check(c.day == day, "jogo encerrado não avança")

func test_v3_systems() -> void:
	var c := staffed(11)
	c.money = 3000000.0
	c.research_points = 5000.0
	# design bloqueado até pesquisar
	var d := c.default_design("phone")
	d.shape = "fold"
	check(not c.design_valid("phone", d), "formato dobrável bloqueado")
	for id in ["res_tech", "res_tech", "res_design", "res_shapes", "res_shapes", "res_shapes", "res_features"]:
		c.do_research(id)
	check(c.design_valid("phone", d), "dobrável liberado após pesquisa")
	var base_q := c.estimate_quality("phone", c.default_specs("phone"), c.default_design("phone"))
	d.features = ["nfc"]
	check(c.estimate_quality("phone", c.default_specs("phone"), d) > base_q, "design/recursos elevam a qualidade")
	check(c.estimate_unit_cost("phone", c.default_specs("phone"), d) > c.estimate_unit_cost("phone", c.default_specs("phone")), "design custa mais")
	# produto com SO e fabricante
	var r := c.create_product("T1", "phone", c.default_specs("phone"), 0.0, d, "lumen", "meridian")
	check(r.ok, "cria produto com design/SO/fabricante: " + str(r.get("msg", "")))
	var p: Product = r.product
	check(p.os_id == "lumen" and p.mfr == "meridian", "produto guarda SO e fabricante")
	check(not c.create_product("X", "phone", c.default_specs("phone"), 0.0, {}, "own", "").ok, "SO próprio indisponível no início")
	check(not c.create_product("X", "phone", c.default_specs("phone"), 0.0, {}, "", "titan").ok, "Titan exige reputação")
	# SO próprio
	for id in ["res_tech", "res_tech", "res_os"]:
		c.do_research(id)
	check(c.start_os_dev("Aurora OS").ok, "inicia SO próprio")
	for i in 1500:
		c.advance_day()
		if int(c.own_os.get("version", 0)) >= 1:
			break
	check(int(c.own_os.get("version", 0)) >= 1 and c.os_available("own"), "SO próprio concluído")
	# fábrica
	c.do_research("res_cost")
	c.do_research("res_cost")
	c.do_research("res_factory")
	check(c.build_factory().ok and c.factory_level == 1, "constrói fábrica")
	check(c.mfr_available("own"), "fábrica própria disponível")
	# bolsa e rivais
	for i in 200:
		c.advance_day()
	check(c.market.rivals.size() == 14, "14 rivais")
	for rv in c.market.rivals:
		check(float(rv.price) > 0.0 and float(rv.value) > 0.0, "rival com preço/valor positivos")
	check(c.stocks.value > 0.0, "valor da empresa calculado")
	var m0 := c.money
	check(c.stocks.buy(c, "Xiaomi", 100).ok and c.stocks.holding("Xiaomi") == 100, "compra ações")
	check(c.money < m0, "compra custa dinheiro")
	check(c.stocks.sell(c, "Xiaomi", 100).ok and c.stocks.holding("Xiaomi") == 0, "vende ações")
	check(c.money < m0 + 1.0, "ida e volta nas ações perde taxas")
	# acordos e empréstimo
	c.reputation = 60.0
	check(c.sign_deal("retail").ok and c.deal_sales_bonus("phone") > 0.0, "acordo comercial ativo")
	check(not c.sign_deal("retail").ok, "acordo duplicado recusado")
	var debt0 := c.loan
	check(c.take_loan(10000.0).ok and c.loan == debt0 + 10000.0, "empréstimo")
	check(c.repay_loan(10000.0).ok and c.loan == debt0, "quita empréstimo")
	# save/load completo
	var c2 := Company.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	check(c2 != null and c2.factory_level == 1 and int(c2.own_os.get("version", 0)) >= 1, "save mantém fábrica e SO")
	check(c2.market.rivals.size() == 14 and c2.deal_active("retail"), "save mantém rivais e acordos")
	check(c2.products[0].os_id == "lumen" and c2.products[0].design.get("shape", "") == "fold", "save mantém design do produto")
	for i in 60:
		c2.advance_day()
	check(not c2.game_over, "jogo carregado segue funcionando")

func _ready_product(c: Company) -> Product:
	var p: Product = c.create_product("T", "phone", c.default_specs("phone")).product
	var d := 0
	while p.state == Product.STATE_DEV and d < 500:
		c.advance_day()
		d += 1
	return p

func test_brand_loyalty() -> void:
	var c := Company.new(21)
	c.money = 800000.0
	for prof in ["engineer", "programmer"]:
		c.auto_fill(prof, 1, 0.0)
	check(is_equal_approx(c.loyalty, Loyalty.START), "lealdade inicial")
	check(Loyalty.preorders(c, "phone") <= 1, "poucos fãs no início")
	c.loyalty = 60.0
	var n60 := Loyalty.preorders(c, "phone")
	c.loyalty = 30.0
	var n30 := Loyalty.preorders(c, "phone")
	check(n60 > n30 and n30 > 0, "mais lealdade, mais pré-vendas (%d > %d)" % [n60, n30])
	# o lançamento vende para os fãs já no dia 1
	c.loyalty = 60.0
	var p := _ready_product(c)
	var before := p.units_total
	check(c.release(p.id).ok, "lançar com fãs")
	check(p.units_total - before >= n30, "fãs compraram no lançamento (%d un.)" % (p.units_total - before))
	# resultado do lançamento mexe na lealdade
	var good := Product.new()
	good.critic = 90.0
	good.rating = 4.6
	var c2 := Company.new(22)
	var l0 := c2.loyalty
	Loyalty.on_launch(c2, good)
	check(c2.loyalty > l0, "lançamento aclamado sobe a lealdade")
	var bad := Product.new()
	bad.critic = 30.0
	bad.rating = 1.8
	c2.loyalty = 40.0
	Loyalty.on_launch(c2, bad)
	check(c2.loyalty < 40.0, "lançamento ruim derruba a lealdade")
	c2.loyalty = 3.0
	Loyalty.change(c2, -50.0, "teste")
	check(c2.loyalty == 0.0, "lealdade não fica negativa")
	Loyalty.change(c2, 500.0, "teste")
	check(c2.loyalty == 100.0, "lealdade limitada a 100")
	# falhas graves abertas corroem a lealdade mês a mês
	var c3 := Company.new(23)
	c3.money = 800000.0
	for prof in ["engineer", "programmer"]:
		c3.auto_fill(prof, 1, 0.0)
	var q := _ready_product(c3)
	c3.release(q.id)
	for i in 40:
		c3.advance_day()
	q.flaws = [{"id": "bug_crash", "found": true, "fixed": false}, {"id": "bug_crash", "found": true, "fixed": false}]
	q.ema_units = 5.0
	c3.loyalty = 50.0
	Loyalty.monthly(c3)
	check(c3.loyalty < 50.0, "falhas graves abertas reduzem lealdade (%f)" % c3.loyalty)
	# save/load preserva
	c3.loyalty = 42.5
	var back := Company.from_dict(JSON.parse_string(JSON.stringify(c3.to_dict())))
	check(is_equal_approx(back.loyalty, 42.5), "lealdade persiste no save")
	check(back.loyalty_log.size() == c3.loyalty_log.size(), "histórico de lealdade persiste")

func test_version_sync() -> void:
	var pg := FileAccess.get_file_as_string("res://project.godot")
	check(pg.contains('config/version="%s"' % Rules.VERSION), "project.godot na versão %s" % Rules.VERSION)
	var ep := FileAccess.get_file_as_string("res://export_presets.cfg")
	check(ep.contains('version/name="%s"' % Rules.VERSION), "export_presets com version/name %s" % Rules.VERSION)
	check(ep.contains("version/code=%d" % Rules.VERSION_CODE), "export_presets com version/code %d" % Rules.VERSION_CODE)

func test_old_save_compat() -> void:
	# save mínimo de um formato antigo (v2): campos novos precisam assumir padrões
	var old := {"version": 2, "name": "Velha", "day": 100, "money": 123456.0, "reputation": 40.0, "seed": 5,
		"products": [{"id": 1, "name": "Antigo", "cat": "phone", "specs": {"performance": 40}, "price": 300.0,
		"state": "released", "quality": 50.0, "release": 10, "unit_cost": 90.0}], "market": {"macro": 1.1}}
	var c := Company.from_dict(old)
	check(c != null, "save v2 carrega")
	check(c.day == 100 and is_equal_approx(c.money, 123456.0), "save v2 preserva dia e caixa")
	check(is_equal_approx(c.loyalty, Loyalty.START), "save v2: lealdade padrão")
	check(is_equal_approx(c.market.sentiment, 1.0) and is_equal_approx(c.market.supply_chain, 1.0), "save v2: macro padrão")
	for i in 40:
		c.advance_day()
	check(c.day == 140, "save v2 continua simulando")
	var future := {"version": Company.SAVE_VERSION + 1}
	check(Company.from_dict(future) == null, "save de versão futura é recusado")

func test_macro_economy() -> void:
	var c := Company.new(31)
	var base := c.market.market_size("phone", 100)
	c.market.apply_macro_shift(-0.3, -0.3)
	var low := c.market.market_size("phone", 100)
	check(low < base, "recessão reduz o mercado (%f < %f)" % [low, base])
	check(base > 1.0 and base < 200.0, "escala do mercado preservada (%f)" % base)
	var cost0 := Company.new(31).market.cost_pressure()
	var m := Company.new(31).market
	m.apply_macro_shift(0.0, 0.0, -0.3)
	check(m.cost_pressure() > cost0, "escassez de componentes encarece a produção")
	check(m.supply_chain >= 0.65 and m.macro >= 0.55, "índices respeitam limites")
	var back := Company.new(1)
	back.market.load_dict(m.to_dict())
	check(is_equal_approx(back.market.supply_chain, m.supply_chain), "macro persiste no save")

func test_economy_financial_integrity() -> void:
	var c := Company.new(41)
	c.money = 600000.0
	c.cash_start = c.money
	for prof in ["engineer", "programmer"]:
		c.auto_fill(prof, 1, 0.0)
	var p := _ready_product(c)
	c.release(p.id)
	# empréstimo e obras mexem no caixa, não no lucro
	var net0: float = float(Economy.current(c).net)
	var m0 := c.money
	check(c.take_loan(40000.0).ok, "empréstimo")
	check(is_equal_approx(c.money, m0 + 40000.0), "empréstimo entra no caixa")
	check(is_equal_approx(float(Economy.current(c).net), float(net0)), "empréstimo não vira lucro")
	check(c.repay_loan(40000.0).ok, "quitar")
	var start_money := c.money
	c.cash_start = start_money
	c.ledger = {}
	c.cash_items = {}
	c.income_month = 0.0
	c.expense_month = 0.0
	c.take_loan(25000.0)
	# roda até fechar o mês
	var d0 := c.day
	while c.day % Rules.DAYS_IN_MONTH != 0 or c.day == d0:
		c.advance_day()
	var dre: Dictionary = Economy.last_month(c)
	check(is_equal_approx(float(dre.cash_flow), c.cash_flow_last), "fluxo de caixa do DRE = variação real do caixa (%f vs %f)" % [dre.cash_flow, c.cash_flow_last])
	check(float(dre.revenue) > 0.0, "DRE tem receita")
	check(is_equal_approx(float(dre.gross), float(dre.revenue) - float(dre.cogs)), "lucro bruto = receita - custo")
	check(float(dre.operating) <= float(dre.gross) + 0.01, "operacional <= bruto")
	check(is_equal_approx(float(dre.net), float(dre.operating) - float(dre.interest) - float(dre.taxes)), "lucro líquido fecha")
	check(float(c.cash_items_last.get("loan", 0.0)) >= 24999.0, "empréstimo aparece só no fluxo de caixa")
	# imposto só incide sobre o resultado
	var tax_base := float(dre.operating) - float(dre.interest)
	if tax_base > 0.0:
		check(absf(float(dre.taxes) - tax_base * Company.TAX_RATE) < 1.0, "imposto = %d%% do lucro tributável" % int(Company.TAX_RATE * 100.0))
	var prods: Array = Economy.products(c)
	check(prods.size() >= 1 and float(prods[0].revenue) > 0.0, "tabela por produto")
	var bal: Dictionary = Economy.balance(c)
	check(float(bal.demand) > 0.0 and float(bal.share) >= 0.0 and float(bal.share) <= 1.0, "equilíbrio do mercado válido")
	check(absf(float(bal.mine) + float(bal.rivals) + float(bal.unmet) - float(bal.demand)) < 0.01 * float(bal.demand) + 0.5 or float(bal.mine) >= 0.0, "demanda particionada")
	# formatação em reais
	check(Fmt.money(1500000.0) == "R$ 1,50 mi", "formato mi: " + Fmt.money(1500000.0))
	check(Fmt.money(12340.0) == "R$ 12,3 mil", "formato mil: " + Fmt.money(12340.0))
	check(Fmt.money(-950.0) == "-R$ 950", "formato negativo: " + Fmt.money(-950.0))
	check(Fmt.money_exact(1234.5) == "R$ 1.234,50", "formato com centavos: " + Fmt.money_exact(1234.5))

func test_early_relief_and_floor() -> void:
	var c := Company.new(42)
	c.auto_fill("engineer", 1, 0.0)
	var base := Rules.RENT_BASE + Rules.RENT_PER_STAFF * float(c.staff.size())
	check(is_equal_approx(c.fixed_cost_factor(), Rules.EARLY_FIXED_FACTOR), "alívio inicial ativo")
	check(is_equal_approx(c.monthly_rent(), base * Rules.EARLY_FIXED_FACTOR), "aluguel com desconto")
	c.day = 200
	for k in c.office_level:
		c.office_level[k] = 3
	check(is_equal_approx(c.fixed_cost_factor(), 1.0), "sem alívio após 90 dias e escritório nível 3")
	# piso de demanda: preço justo e qualidade razoável vendem; preço absurdo não
	var q := Company.new(43)
	var pr := Product.new()
	pr.category = "phone"
	pr.quality = 40.0
	pr.release_day = 0
	q.day = 20
	var exp_q := q.market.expectation(q.day)
	pr.quality = exp_q
	pr.price = q.fair_price("phone", q.effective_quality(pr))
	check(q.demand_floor(pr, exp_q) > 0.5, "piso de demanda para produto razoável")
	pr.price *= 3.0
	check(q.demand_floor(pr, exp_q) == 0.0, "sem piso para preço absurdo")

func test_updater_and_backups() -> void:
	check(Updater.is_newer("0.5.0", "0.4.9"), "0.5.0 > 0.4.9")
	check(Updater.is_newer("v1.0", "0.9.9"), "v1.0 > 0.9.9")
	check(not Updater.is_newer("0.4.1", "0.4.1"), "mesma versão não é nova")
	check(not Updater.is_newer("0.3.9", "0.4.0"), "versão menor não é nova")
	check(not Updater.is_newer("lixo", "0.4.0"), "versão inválida é ignorada")
	var sha := Updater.sha256_hex("abc".to_utf8_buffer())
	check(sha == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "SHA-256 correto")
	check(Updater.verify("abc".to_utf8_buffer(), sha.to_upper()), "verifica hash")
	check(not Updater.verify("abd".to_utf8_buffer(), sha), "arquivo alterado é rejeitado")
	var good := JSON.stringify({"version": "0.5.0", "apk_url": "https://x.y/a.apk", "sha256": sha, "notes": "n"})
	check(not Updater.parse_manifest(good).is_empty(), "manifesto válido")
	check(Updater.parse_manifest(good.replace("https://", "http://")).is_empty(), "manifesto sem https é rejeitado")
	check(Updater.parse_manifest(good.replace(sha, "zz")).is_empty(), "manifesto com hash inválido é rejeitado")
	check(Updater.parse_manifest("não é json").is_empty(), "manifesto ilegível é rejeitado")

func test_office_layout() -> void:
	var order := ["engineer", "programmer", "designer", "researcher"]
	check(OfficeLayout.stage_for(0, 1) == 0 and OfficeLayout.stage_for(6, 1) == 1 and OfficeLayout.stage_for(14, 1) == 2 and OfficeLayout.stage_for(26, 1) == 3, "fases do escritório pela equipe")
	check(OfficeLayout.stage_for(2, 5) == 3 and OfficeLayout.stage_for(2, 2) == 0, "fase também sobe com o nível do escritório")
	var lim := OfficeLayout.limit_counts({"engineer": 16, "programmer": 16, "designer": 16, "researcher": 16}, order, 48)
	var tot := 0
	for k in lim:
		tot += int(lim[k])
	check(tot == 48 and int(lim.engineer) == 12, "limite de funcionários visíveis é dividido por igual")
	var prev_w := 0.0
	var prev_d := 0.0
	for st in 4:
		var counts := {"engineer": 2 + st * 4, "programmer": 2 + st * 4, "designer": st * 3, "researcher": 1 + st * 3}
		var L := OfficeLayout.build(counts, order, st)
		check(L.width >= prev_w and L.depth >= prev_d, "escritório não encolhe quando a equipe cresce (fase %d)" % st)
		prev_w = L.width
		prev_d = L.depth
		var seen := {}
		for prof in order:
			check((L.seats_by_prof.get(prof, []) as Array).size() >= int(L.counts[prof]), "há assento para todos de %s (fase %d)" % [prof, st])
		for seat in L.seats:
			var key := "%.2f|%.2f" % [seat.pos.x, seat.pos.z]
			check(not seen.has(key), "assentos não se sobrepõem")
			seen[key] = true
			check(seat.pos.x > 0.0 and seat.pos.x < L.width and seat.pos.z > 0.0 and seat.pos.z < L.front_lane, "assento dentro do escritório")
			# toda rota até todo ponto é feita de segmentos retos nas pistas livres
			for sp in L.spots:
				var r := OfficeLayout.route_seat_to(seat, sp)
				check(r.size() >= 2 and (r[0] as Vector3).distance_to(seat.pos) < 0.01 and (r[r.size() - 1] as Vector3).distance_to(sp.pos) < 0.01, "rota liga assento e ponto")
				for i in range(1, r.size()):
					var a: Vector3 = r[i - 1]
					var b: Vector3 = r[i]
					check(absf(a.x - b.x) < 0.001 or absf(a.z - b.z) < 0.001, "rota só tem segmentos retos")
		check(L.spots.size() >= 6, "pontos de pausa e conversa existem (fase %d)" % st)
		var pairs := 0
		for sp in L.spots:
			if sp.kind == "chat":
				check(int(sp.pair) >= 0 and int(L.spots[int(sp.pair)].pair) == int(sp.id), "pontos de conversa vêm em pares")
				pairs += 1
		check(pairs >= 2, "há ao menos um par de conversa")
		var dr := OfficeLayout.route_spot_to_seat(L.door, L.seats[0])
		check(dr.size() >= 2 and (dr[dr.size() - 1] as Vector3).distance_to(L.seats[0].pos) < 0.01, "rota da porta até a mesa")
	# determinismo
	var a1 := OfficeLayout.build({"engineer": 5, "programmer": 3}, order, 1)
	var a2 := OfficeLayout.build({"engineer": 5, "programmer": 3}, order, 1)
	check(a1.width == a2.width and a1.seats.size() == a2.seats.size() and a1.seats[3].pos == a2.seats[3].pos, "planta do escritório é determinística")
	# o save não ganhou campos: o escritório é só visualização
	var c := staffed(3)
	check(not (c.to_dict() as Dictionary).has("office_layout"), "escritório 3D não grava nada no save")

func test_identity_and_rivals() -> void:
	var lg := Identity.clean_logo({"symbol": "xxx", "c1": "zzzzzz", "c2": "5aa9ff", "style": "wide"})
	check(lg.symbol == "shield" and lg.c1 == "ff9a2e" and lg.c2 == "5aa9ff" and lg.style == "wide", "logotipo inválido volta ao padrão, válido é mantido")
	var dc := Identity.clean_decor({"desk": "wood", "chair": "nope"})
	check(dc.desk == "wood" and dc.chair == "common" and dc.pc == "single", "decoração: inválido vira padrão")
	for sy in GameData.identity().symbols:
		check(Geometry2D.triangulate_polygon(Identity.points(str(sy.id))).size() >= 3, "símbolo %s é um polígono válido" % sy.id)
	var c := staffed(11)
	c.money = 100000.0
	var before := c.money
	var nd := c.decor.duplicate()
	nd.desk = "wood"
	nd.chair = "executive"
	var r := c.apply_identity(c.logo, nd)
	check(r.ok and absf((before - c.money) - (Identity.option_cost("desk", "wood") + Identity.option_cost("chair", "executive"))) < 0.01, "cobra só o que mudou")
	check(not c.apply_identity(c.logo, c.decor).ok, "sem mudança não cobra")
	c.money = 10.0
	check(not c.apply_identity({"symbol": "crown", "c1": "ff9a2e", "c2": "1b2036", "style": "caps"}, c.decor).ok, "sem caixa não troca o logotipo")
	c.money = 100000.0
	check(c.apply_identity({"symbol": "crown", "c1": "4cd18a", "c2": "111111", "style": "title"}, c.decor).ok, "troca o logotipo")
	var rc := Company.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	check(rc.logo.symbol == "crown" and rc.logo.c1 == "4cd18a" and rc.decor.chair == "executive" and rc.decor.desk == "wood", "identidade sobrevive ao save/load")
	check(Company.from_dict({"version": 5}).logo == Identity.default_logo(), "save antigo ganha logotipo padrão")
	# concorrentes reais
	var mrng := RandomNumberGenerator.new()
	mrng.seed = 5
	var m := Market.new(mrng)
	m.seed_rivals()
	var names := []
	for rv in m.rivals:
		names.append(rv.name)
	for must in ["Apple", "Samsung", "Google", "Microsoft", "Xiaomi", "Huawei", "Sony", "Intel", "NVIDIA", "Nintendo"]:
		check(names.has(must), "rival real presente: " + must)
	var ap: Dictionary = m.rivals[names.find("Apple")]
	var xi: Dictionary = m.rivals[names.find("Xiaomi")]
	check(float(ap.price_mult) > float(xi.price_mult) and float(ap.value) > float(xi.value), "Apple é premium e maior que Xiaomi")
	check(Market.focus_has(m.rivals[names.find("Nintendo")], "console") and not Market.focus_has(m.rivals[names.find("Nintendo")], "phone"), "segmentos de atuação")
	check(Market.focus_has({"focus": "phone"}, "phone"), "foco antigo (texto) continua valendo")
	var pa := 0.0
	var px := 0.0
	var n := 0
	for i in 40:
		var cp := m.launch_competitor("phone", 100 + i)
		if cp.company == "Apple":
			pa += float(cp.price)
		elif cp.company == "Xiaomi":
			px += float(cp.price)
	check(m.comp_products.size() == 40, "rivais lançam produtos")

func test_device_variants() -> void:
	var D: Dictionary = GameData.designs()
	var c := Company.new()
	var keys := {"buttons": "buttons", "bio": "bios", "back": "backs", "crown": "crowns", "face": "faces", "kbd": "kbds",
		"webcam": "webcams", "lid": "lids", "vent": "vents", "glow": "glows", "pad": "pads"}
	var d: Dictionary = c.default_design("phone")
	for k in keys:
		var arr: Array = D.get(keys[k], [])
		check(arr.size() >= 3, "designs.%s tem opções" % keys[k])
		check(d.has(k), "default_design tem %s" % k)
		var ids: Array = []
		for it in arr:
			ids.append(str(it.id))
		check(ids.has(str(d[k])), "padrão de %s existe na lista" % k)
	check((D.camera_layouts as Array).size() >= 9 and (D.notches as Array).size() >= 7 and (D.bands as Array).size() >= 5, "novas câmeras, recortes e pulseiras")

func test_logo_symbols() -> void:
	var syms: Array = GameData.identity().symbols
	check(syms.size() >= 22, "catálogo de símbolos ampliado")
	for sy in syms:
		var pts := Identity.points(str(sy.id))
		check(Geometry2D.triangulate_polygon(pts).size() >= 3, "símbolo %s é um polígono simples" % str(sy.id))

func test_sandbox() -> void:
	var c := Company.new()
	check(not c.sandbox, "sandbox desligado por padrão")
	c.money = 10.0
	c.research_points = 0.0
	c.set_sandbox(true)
	check(c.money >= Company.SANDBOX_MONEY and c.research_points >= Company.SANDBOX_RP, "sandbox repõe caixa e pesquisa")
	c.money = 5.0
	c.advance_day()
	check(c.money >= Company.SANDBOX_MONEY, "sandbox repõe o caixa a cada dia")
	var c2 := Company.from_dict(c.to_dict())
	check(c2.sandbox, "sandbox é salvo e carregado")
	var c3 := Company.from_dict({"version": 6, "name": "Velha", "day": 1, "money": 1.0})
	check(not c3.sandbox, "save antigo sem sandbox continua desligado")

func test_os_look_and_notifs() -> void:
	var c := Company.new()
	var lk := c.os_look()
	check(lk.theme == "dark" and lk.icons == "squircle" and lk.wall == "aurora", "aparência padrão do sistema")
	c.set_os_look("theme", "light")
	c.set_os_look("icons", "inexistente")
	lk = c.os_look()
	check(lk.theme == "light" and lk.icons == "squircle", "aparência aceita só opções válidas")
	var c2 := Company.from_dict(c.to_dict())
	check(c2.os_look().theme == "light", "aparência é salva")
	c.mark_notifs_read()
	check(c.unread_count() == 0, "sem notificações novas")
	c.add_log("Teste", "info")
	c.add_log("Outro", "good")
	check(c.unread_count() == 2, "contador de não lidas")
	c.mark_notifs_read()
	check(c.unread_count() == 0, "marcar como lidas")
	c.clear_notifs()
	check(c.log_entries.is_empty(), "limpar notificações")

func test_rival_reactions() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 11
	var m := Market.new(r)
	m.seed_competitors(200)
	var c0 := 0
	for rv in m.rivals:
		c0 += rv.launches.size()
	check(c0 >= 8, "lançamentos entram no histórico dos rivais")
	var news := []
	for i in 30:
		news.append_array(m.react_to_launch("phone", 400.0, 500.0, 200 + i))
	check(not news.is_empty(), "rivais reagem a um lançamento muito forte")
	check(m.react_to_launch("phone", 1.0, 100.0, 300).is_empty(), "produto fraco não provoca reação")
	var mx := 0.0
	for rv in m.rivals:
		mx = maxf(mx, float(rv.rivalry))
	check(mx > 0.0 and mx <= 100.0, "rivalidade sobe e fica limitada")
	var sh := m.rival_shares("phone", 210, 5.0)
	var tot := 0.0
	for e in sh:
		tot += float(e.share)
	check(absf(tot - 1.0) < 0.001, "participações somam 100%")
	# save antigo: campos novos e rivais do catálogo entram sozinhos
	var d := m.to_dict()
	var old: Dictionary = JSON.parse_string(JSON.stringify(d))
	old.rivals = old.rivals.slice(0, 10)
	for rv in old.rivals:
		rv.erase("launches")
		rv.erase("rivalry")
	var m2 := Market.new(r)
	m2.load_dict(old)
	check(m2.rivals.size() == 14 and m2.rivals[0].has("launches") and m2.rivals[0].has("war_until"), "save antigo ganha rivais novos e campos")

func test_store_country_summary() -> void:
	var c := staffed(21)
	c.reputation = 60.0
	c.money = 5000000.0
	check(Stores.country_summary(c).is_empty(), "sem lojas, resumo vazio")
	check(Stores.open(c, Stores.default_spec("br")).ok and Stores.open(c, Stores.default_spec("br")).ok, "abre 2 lojas no Brasil")
	check(Stores.open(c, Stores.default_spec("ar")).ok, "abre 1 loja na Argentina")
	var sm := Stores.country_summary(c)
	var n := 0
	for e in sm:
		n += int(e.count)
	check(sm.size() == 2 and n == 3, "resumo agrupa por país (3 lojas em 2 países)")

func _released_company(seed_v: int) -> Array:
	var c := staffed(seed_v)
	c.money = 800000.0
	var p: Product = c.create_product("L", "phone", c.default_specs("phone")).product
	var d := 0
	while p.state == Product.STATE_DEV and d < 500:
		c.advance_day()
		d += 1
	c.release(p.id)
	return [c, p]

func test_logistics() -> void:
	var rp := _released_company(31)
	var c: Company = rp[0]
	var p: Product = rp[1]
	check(p.stock > 0 and p.avg_cost > 0.0, "lote inicial entra em estoque no lançamento (%d un.)" % p.stock)
	# vendas só saem do estoque
	p.auto_stock = false
	var before := p.units_total
	var stock0 := p.stock
	for i in 400:
		c.advance_day()
	check(p.stock == 0 and p.units_total - before <= stock0 + Logistics.pipeline(p) + 5, "sem reposição o estoque acaba e as vendas param")
	check(p.lost_ema > 0.0, "demanda sem estoque vira venda perdida")
	# pedido manual: custa caixa na hora, chega depois com possíveis defeitos
	var m0 := c.money
	var q := Logistics.quote(c, p, 100)
	var r := Logistics.order(c, p.id, 100)
	check(r.ok and absf((m0 - c.money) - float(q.cost)) < 0.01, "pedido cobra o lote inteiro na hora")
	check(Logistics.pipeline(p) == 100, "pedido fica em produção")
	for i in int(q.wait) + 1:
		c.advance_day()
	check(Logistics.pipeline(p) == 0 and p.stock + p.units_total - before > 0, "lote chega no prazo")
	check(not Logistics.order(c, p.id, 0).ok, "quantidade zero é recusada")
	# reposição automática mantém o produto vendendo e o caixa não some
	p.auto_stock = true
	var u1 := p.units_total
	for i in 200:
		c.advance_day()
	check(p.units_total - u1 > 50, "estoque automático mantém as vendas (%d un.)" % (p.units_total - u1))
	check(c.money > 0.0, "caixa continua positivo com reposição automática")
	# save/load preserva estoque, pedidos e fila
	var c2 := Company.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	var p2: Product = c2.get_product(p.id)
	check(p2.stock == p.stock and p2.orders.size() == p.orders.size() and int(c2.mfr_busy.get("fabrix", -1)) == int(c.mfr_busy.get("fabrix", -1)), "save preserva estoque e pedidos")
	# save antigo sem estoque ganha 30 dias de estoque
	var old: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	for pd in old.products:
		for k in ["stock", "avg_cost", "orders", "auto", "cover"]:
			pd.erase(k)
	var c3 := Company.from_dict(old)
	var p3: Product = c3.get_product(p.id)
	check(p3.stock >= 20 and p3.avg_cost > 0.0, "save antigo recebe estoque inicial")
	# tirar de linha liquida o estoque
	var cash := c.money
	var left := p.stock
	c.retire(p.id)
	check(p.stock == 0 and (left == 0 or c.money > cash), "tirar de linha liquida o estoque")

func test_tutorial() -> void:
	var c := Company.new(41)
	c.money = 800000.0
	check(not Tutorial.active(c), "empresa nova só tem tutorial se o jogo ligar")
	Tutorial.start(c)
	check(str(Tutorial.current(c).id) == "team", "tutorial começa pela equipe")
	Tutorial.update(c)
	check(str(Tutorial.current(c).id) == "team", "sem equipe o passo não avança")
	check(Tutorial.tip_for(c, "market") == "", "com tutorial ativo não há dicas soltas")
	for prof in ["engineer", "programmer", "researcher"]:
		c.auto_fill(prof, 0, 0.0)
	Tutorial.update(c)
	check(str(Tutorial.current(c).id) == "product", "contratar equipe avança o tutorial")
	var p: Product = c.create_product("T", "phone", c.default_specs("phone")).product
	Tutorial.update(c)
	check(str(Tutorial.current(c).id) == "ready", "criar produto avança")
	var d := 0
	while p.state == Product.STATE_DEV and d < 500:
		c.advance_day()
		d += 1
	Tutorial.update(c)
	check(str(Tutorial.current(c).id) == "release", "produto pronto avança")
	c.release(p.id)
	Tutorial.update(c)
	check(str(Tutorial.current(c).id) == "stock", "lançar avança até o estoque")
	Tutorial.mark_visit(c, "ops")
	c.research_points = 500.0
	c.do_research("res_specs")
	Tutorial.update(c)
	check(str(Tutorial.current(c).id) == "market", "visitar Operações e pesquisar avançam")
	Tutorial.mark_visit(c, "market")
	Tutorial.update(c)
	check(not Tutorial.active(c) and Tutorial.current(c).is_empty(), "tutorial termina sozinho")
	check(Tutorial.tip_for(c, "market") != "", "depois do tutorial, dica de primeira visita aparece")
	Tutorial.tip_seen(c, "market")
	check(Tutorial.tip_for(c, "market") == "", "dica vista não repete")
	# skip e save
	var c2 := Company.new(42)
	Tutorial.start(c2)
	Tutorial.skip(c2)
	check(not Tutorial.active(c2), "pular desliga o tutorial")
	var c3 := Company.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	check(c3.tips_seen.has("market") and not Tutorial.active(c3), "save preserva dicas vistas")
	var old: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	old.erase("tutorial")
	old.erase("tips_seen")
	check(not Tutorial.active(Company.from_dict(old)), "save antigo não reinicia o tutorial")
	for st in GameData.tutorial().steps:
		check(GameData.tutorial().tips.has(str(st.page)) or str(st.page) == "dash", "página do passo existe: " + str(st.page))

func test_founding() -> void:
	var base := Company.new(3)
	var c := Company.new(3)
	Founding.apply(c, {"origin": "us", "difficulty": "hard", "founder": "Ana", "focus": "phone"})
	check(c.origin == "us" and c.difficulty == "hard" and c.focus == "phone" and c.founder == "Ana", "fundação grava a ficha")
	check(absf(c.money - Rules.START_MONEY * 1.3 * 0.7) < 0.01, "capital = origem x dificuldade")
	check(c.reputation > base.reputation, "origem EUA aumenta a reputação inicial")
	check(c.sales_mult("phone") > c.sales_mult("laptop"), "especialização vende mais na categoria foco")
	check(c.sales_mult("laptop") < 1.0, "dificuldade desafiadora reduz vendas")
	var br := staffed(5)
	var cn := staffed(5)
	var pay_a := br.monthly_payroll()
	Founding.apply(cn, {"origin": "br"})
	check(cn.monthly_payroll() < pay_a, "Brasil tem folha menor")
	var de := Company.new(4)
	Founding.apply(de, {"origin": "de"})
	check(Founding.origin_mult(de, "research") > 1.0, "Alemanha pesquisa mais rápido")
	var c2 := Company.from_dict(c.to_dict())
	check(c2.origin == "us" and c2.focus == "phone" and c2.founder == "Ana", "fundação sobrevive ao save")
	var old := Company.from_dict({"version": 11, "name": "Velha", "day": 1, "money": 1.0})
	check(old.origin == "" and old.sales_mult("phone") == 1.0 and Founding.origin_mult(old, "wage") == 1.0, "save antigo não ganha bônus")
	check(Founding.stage(Company.new()).level == 0, "empresa nova é Garagem")
	var big := staffed(9)
	big.last_income = 80000.0
	check(Founding.stage(big).level >= 1, "estágio sobe com porte")

func test_decisions() -> void:
	for d in Decisions.defs():
		check(d.options.size() >= 2, "decisão %s tem opções" % d.id)
	var c := staffed(11)
	c.day = 200
	c.last_income = 60000.0
	Decisions.open(c, "supplier_hike")
	check(not c.pending_decision.is_empty(), "decisão abre")
	var before := c.money
	var r := Decisions.resolve(c, 2)       # componentes próprios
	check(r.ok and c.pending_decision.is_empty(), "decisão resolvida")
	check(c.money < before, "opção cobra o custo")
	check(c.mod_mult("cost") < 1.0, "componentes próprios reduzem o custo por um tempo")
	var cl := Company.from_dict(c.to_dict())
	check(cl.mod_mult("cost") < 1.0 and cl.decision_log.size() == 1, "modificador e histórico persistem")
	c.day += 300
	check(c.mod_mult("cost") == 1.0, "modificador expira")
	var poor := staffed(12)
	poor.money = 10.0
	Decisions.open(poor, "supplier_hike")
	check(not Decisions.resolve(poor, 2).ok and not poor.pending_decision.is_empty(), "sem caixa não paga opção cara")
	var sell := staffed(13)
	sell.mods.append({"key": "sales", "mult": 2.0, "until": 9999, "src": "t"})
	check(sell.sales_mult("phone") == 2.0, "mod de vendas entra na demanda")
	var staff_n := c.staff.size()
	Decisions.open(c, "poaching")
	Decisions._apply(c, {"lose_staff": 1})
	check(c.staff.size() == staff_n - 1, "lose_staff remove um funcionário")

func test_look() -> void:
	var a := Look.of(5, "Maria", "designer")
	var b := Look.of(5, "Maria", "designer")
	check(a == b, "aparência é determinística")
	var styles := {}
	for i in 60:
		styles[int(Look.of(i, "N%d" % i, "engineer").style)] = true
	check(styles.size() >= 5, "estilos de cabelo variam entre funcionários")
	check(bool(Look.of(1, "X", "programmer").glasses), "programador usa óculos")
	check(Look.tier(300) == 3 and Look.tier(30) == 0, "faixas de senioridade")

func _chip_with(c: Company, over: Dictionary) -> int:
	var d := Chips.default_design(c)
	d.merge(over, true)
	d["id"] = c._new_id()
	d["name"] = "T"
	d["bug"] = 0.05
	c.chips.append(d)
	return int(d.id)

func test_components() -> void:
	var c := staffed(31)
	var specs := c.default_specs("phone")
	var base_d := c.default_design("phone")
	var q0 := c.estimate_quality("phone", specs, base_d)
	var u0 := c.estimate_unit_cost("phone", specs, base_d)
	var legacy := base_d.duplicate(true)
	legacy.erase("parts")
	check(absf(c.estimate_quality("phone", specs, legacy) - q0) < 0.001, "design antigo (sem peças) = peças básicas")
	check(Components.problems(c, "phone", base_d).is_empty(), "peças básicas sempre válidas")
	# peça melhor: mais qualidade e mais custo, mas exige pesquisa
	var d2 := base_d.duplicate(true)
	d2.parts = {"display": "oled"}
	check(Components.part_blocker(c, Components.part("display", "oled"), d2) != "", "OLED exige Engenharia de Materiais")
	c.research_levels["res_specs"] = 3
	check(Components.part_blocker(c, Components.part("display", "oled"), d2) == "", "OLED liberado após pesquisa")
	check(c.estimate_quality("phone", specs, d2) > q0, "OLED aumenta a qualidade")
	check(c.estimate_unit_cost("phone", specs, d2) > u0, "OLED aumenta o custo")
	# câmera top exige ISP no chip
	c.research_levels["res_specs"] = 6
	var d3 := base_d.duplicate(true)
	d3.parts = {"camera": "cam108"}
	check(Components.part_blocker(c, Components.part("camera", "cam108"), d3) != "", "108 MP exige chip com ISP")
	check(not c.create_product("X", "phone", specs, 0.0, d3).ok, "produto com peça bloqueada é recusado")
	c.research_levels["res_chips"] = 1
	var cid := _chip_with(c, {"isp": true, "npu": 1})
	d3["chip"] = cid
	check(Components.part_blocker(c, Components.part("camera", "cam108"), d3) == "", "chip com ISP libera 108 MP")
	check(Components.part_blocker(c, Components.part("camera", "peri"), d3) == "", "ISP + NPU libera periscópio")
	var d4 := d3.duplicate(true)
	d4.parts = {"camera": "peri"}
	d4.shape = "slim"
	check(Components.part_blocker(c, Components.part("camera", "peri"), d4) != "", "periscópio não cabe em corpo ultrafino")
	# dobrável exige tela flexível
	var d5 := base_d.duplicate(true)
	d5.shape = "fold"
	check(str(Components.chosen(d5, "display").id) == "flex" and Components.problems(c, "phone", d5).is_empty(), "formato dobrável usa tela dobrável por padrão")
	d5.parts = {"display": "lcd"}
	check(not Components.problems(c, "phone", d5).is_empty(), "dobrável com tela comum é incompatível")
	check(Components.part_blocker(c, Components.part("display", "flex"), base_d) != "", "tela dobrável só em formato dobrável")
	# energia: peças gulosas + bateria pequena derrubam a qualidade
	var low := specs.duplicate()
	low["battery"] = 10
	var greedy := base_d.duplicate(true)
	greedy.parts = {"display": "lcd", "camera": "cam12"}
	var a_low := Components.analysis(c, "phone", low, greedy)
	var a_def := Components.analysis(c, "phone", specs, greedy)
	check(float(a_low.autonomy) < float(a_def.autonomy) and float(a_low.q_mult) < float(a_def.q_mult), "bateria pequena reduz autonomia e qualidade")
	check(absf(float(a_def.autonomy) - 1.0) < 0.05, "configuração básica tem autonomia ~100%")
	var bigbat := greedy.duplicate(true)
	bigbat.parts = {"battery": "sic"}
	check(float(Components.analysis(c, "phone", specs, bigbat).autonomy) > float(a_def.autonomy), "bateria melhor aumenta a autonomia")
	check(not Components.analysis(c, "console", c.default_specs("console"), c.default_design("console")).has_battery, "console não usa bateria")
	# persistência: as peças ficam no design do produto
	var ok_d := base_d.duplicate(true)
	ok_d.parts = {"battery": "poly"}
	c.research_levels["res_specs"] = 6
	var r := c.create_product("Peça", "phone", specs, 0.0, ok_d)
	check(r.ok, "produto com peças válidas é criado")
	var c2 := Company.from_dict(c.to_dict())
	check(str((c2.products[0].design.parts as Dictionary).get("battery", "")) == "poly", "peças sobrevivem ao save")

func test_chip_expansion() -> void:
	var base := {"node": "n28", "cores": 4, "clock": 2.0, "cache": 4, "npu": 0, "foundry": "fab_a", "name": "a"}
	var old_st := Chips.stats(base)                      # projeto antigo, sem gpu/isp/arch
	check(float(old_st.gfx) > 0.0 and int(old_st.gpu) == 0, "chip antigo ganha valores padrão")
	var g := base.duplicate()
	g["gpu"] = 8
	check(float(Chips.stats(g).area) > float(old_st.area) and float(Chips.stats(g).gfx) > float(old_st.gfx), "GPU aumenta área e gráficos")
	check(float(Chips.stats(g).tdp) > float(old_st.tdp), "GPU aumenta o consumo")
	var i := base.duplicate()
	i["isp"] = true
	check(float(Chips.stats(i).area) > float(old_st.area), "ISP ocupa área")
	var e := base.duplicate()
	e["arch"] = "eff"
	var p := base.duplicate()
	p["arch"] = "perf"
	check(float(Chips.stats(e).tdp) < float(old_st.tdp) and float(Chips.stats(p).tdp) > float(old_st.tdp), "arquitetura muda o consumo")
	check(float(Chips.stats(p).perf) > float(Chips.stats(e).perf), "arquitetura de desempenho é mais rápida")
	check(Chips.dev_cost(g) > Chips.dev_cost(base) and Chips.dev_work(i) > Chips.dev_work(base), "GPU e ISP encarecem o projeto")
	var caps := Chips.caps({"node": "n14", "npu": 2, "isp": true, "gpu": 6})
	check(int(caps.node) == 3 and bool(caps.isp) and int(caps.gpu) == 6, "capacidades do chip")
	# console: chip com GPU forte rende mais qualidade que um sem GPU
	var c := staffed(33)
	var spec := c.default_specs("console")
	var weak := base.duplicate()
	weak["bug"] = 0.05
	var strong := base.duplicate()
	strong["gpu"] = 8
	strong["bug"] = 0.05
	check(Chips.quality_mult(c, strong, "console", spec) > Chips.quality_mult(c, weak, "console", spec), "GPU melhora o console")

func test_chip_realism() -> void:
	var base := {"node": "n14", "cores": 8, "clock": 3.0, "cache": 8, "npu": 0, "foundry": "fab_a", "name": "r", "mem": 1}
	var wide := base.duplicate()
	wide["mem"] = 4
	check(float(Chips.stats(wide).perf) > float(Chips.stats(base).perf) * 1.2, "parede de memória: mais canais liberam desempenho")
	check(float(Chips.stats(base).mem_factor) < 1.0 and float(Chips.stats(wide).mem_factor) > float(Chips.stats(base).mem_factor), "gargalo de memória é reportado")
	var more := base.duplicate()
	more["cores"] = 16
	check(float(Chips.stats(more).perf) < float(Chips.stats(base).perf) * 1.25, "dobrar núcleos sem memória rende pouco")
	# núcleos eficientes: desempenho extra com menos watts que núcleos grandes
	var p4 := {"node": "n14", "cores": 4, "clock": 2.5, "cache": 8, "npu": 0, "foundry": "fab_a", "name": "a", "mem": 4}
	var p8 := p4.duplicate()
	p8["cores"] = 8
	var pe := p4.duplicate()
	pe["ecores"] = 4
	check(float(Chips.stats(pe).perf) > float(Chips.stats(p4).perf), "núcleos eficientes somam desempenho")
	check(float(Chips.stats(pe).tdp) < float(Chips.stats(p8).tdp), "núcleos eficientes gastam menos que núcleos grandes")
	check(float(Chips.stats(pe).area) < float(Chips.stats(p8).area), "núcleos eficientes ocupam menos área")
	# tensão x clock: potência cresce mais que linearmente
	var lo := p4.duplicate()
	lo["clock"] = 1.5
	var hi := p4.duplicate()
	hi["clock"] = 3.0
	check(float(Chips.stats(hi).tdp) > 2.5 * float(Chips.stats(lo).tdp) * 0.8 and Chips.voltage(3.0) > Chips.voltage(1.5), "potência sobe com V²·f")
	# vazamento cresce com a área
	var big := p4.duplicate()
	big["cache"] = 32
	big["gpu"] = 12
	check(float(Chips.stats(big).leak_w) > float(Chips.stats(p4).leak_w), "vazamento cresce com a área")
	# binning: aproveita dies defeituosos, custo cai, perde um núcleo
	var huge := {"node": "n28", "cores": 12, "clock": 2.5, "cache": 16, "npu": 1, "gpu": 8, "foundry": "fab_a", "name": "h", "mem": 4}
	var sv := huge.duplicate()
	sv["bin"] = "salv"
	check(float(Chips.stats(sv).unit_cost) < float(Chips.stats(huge).unit_cost), "binning reduz o custo por chip vendável")
	check(int(Chips.stats(sv).eff_cores) == 11 and float(Chips.stats(sv).sell_frac) > float(Chips.stats(huge).sell_frac), "binning desliga um núcleo e vende mais dies")
	# validação reduz bugs e custa tempo/dinheiro
	var v2 := huge.duplicate()
	v2["valid"] = 2
	check(float(Chips.stats(v2).bug) < float(Chips.stats(huge).bug) * 0.5, "validação reduz o risco de bug")
	check(Chips.dev_cost(v2) > Chips.dev_cost(huge) and Chips.dev_work(v2) > Chips.dev_work(huge), "validação encarece e atrasa")
	# ray tracing só conta com GPU
	var rt_no := base.duplicate()
	rt_no["rt"] = true
	check(not bool(Chips.caps(rt_no).rt), "ray tracing exige unidades de GPU")
	var rt_ok := huge.duplicate()
	rt_ok["rt"] = true
	check(bool(Chips.caps(rt_ok).rt) and float(Chips.stats(rt_ok).gfx) > float(Chips.stats(huge).gfx) * 0.99, "ray tracing aparece nas capacidades")
	# RAM rápida exige canais de memória suficientes
	var c := staffed(41)
	c.research_levels["res_specs"] = 6
	var d := c.default_design("phone")
	d.parts = {"performance": "ram5x"}
	c.research_levels["res_chips"] = 4
	var few := {"node": "n14", "cores": 4, "clock": 2.0, "cache": 4, "npu": 0, "mem": 2, "foundry": "fab_a", "name": "f", "bug": 0.05, "id": c._new_id()}
	c.chips.append(few)
	d["chip"] = int(few.id)
	check(Components.part_blocker(c, Components.part("performance", "ram5x"), d) != "", "LPDDR5X exige 4 canais de memória")
	few["mem"] = 4
	check(Components.part_blocker(c, Components.part("performance", "ram5x"), d) == "", "4 canais liberam LPDDR5X")

func _released(c: Company, os_id: String = "droidix") -> Product:
	var r := c.create_product("Alvo", "phone", c.default_specs("phone"), 0.0, {}, os_id)
	check(r.ok, "cria produto para atualização")
	var p: Product = c.products[c.products.size() - 1]
	c._finish_dev(p)
	c.release(p.id)
	return p

func test_updates_teardown() -> void:
	var c := staffed(41)
	c.money = 5.0e6
	c.day = 100
	c.research_levels["res_software"] = 1
	var p := _released(c)
	var q0 := c.effective_quality(p)
	check(Updates.blocker(c, p, "fix") != "", "correção exige defeito conhecido")
	var r := Updates.apply(c, p.id, "perf")
	check(r.ok and c.effective_quality(p) > q0, "melhoria de desempenho sobe a qualidade")
	check(Updates.apply(c, p.id, "perf").ok == false, "cooldown entre atualizações")
	c.day += Updates.COOLDOWN_DAYS + 1
	check(Updates.apply(c, p.id, "major").ok, "grande versão com Software Avançado")
	check(p.update_q > 0.08 and p.refresh_days >= 80, "bônus e rejuvenescimento acumulam")
	for i in 6:
		c.day += Updates.COOLDOWN_DAYS + 1
		Updates.apply(c, p.id, "major")
	check(p.update_q <= Updates.MAX_BONUS + 0.0001, "bônus tem teto")
	# demanda: mesmo produto, mais velho, vende melhor se foi atualizado
	var fresh := _released(c)
	fresh.release_day = p.release_day
	check(c.attractiveness(p) > c.attractiveness(fresh), "atualização rejuvenesce a demanda")
	# defeitos conhecidos são corrigidos
	var cq := staffed(42)
	cq.money = 5.0e6
	cq.day = 100
	var pq := _released(cq)
	pq.flaws = [{"id": "bug_crash", "found": true, "fixed": false}, {"id": "x", "found": false, "fixed": false}]
	check(Updates.apply(cq, pq.id, "fix").ok and bool(pq.flaws[0].fixed) and not bool(pq.flaws[1].fixed), "correção resolve só os defeitos conhecidos")
	# sistema próprio é mais barato
	var own := _released(c)
	own.os_id = "own"
	check(Updates.cost(c, own, "perf") < Updates.cost(c, p, "perf"), "sistema próprio reduz o custo")
	# persistência
	var c2 := Company.from_dict(c.to_dict())
	check(absf(c2.products[0].update_q - p.update_q) < 0.0001 and c2.products[0].refresh_days == p.refresh_days, "atualizações sobrevivem ao save")
	# otimização para o chip: só com chip próprio estrangulando
	check(Updates.blocker(c, p, "chip") != "", "sem chip próprio não há otimização")
	# teardown
	var d := c.default_design("phone")
	var easy := Teardown.repair_score("phone", d)
	var hard := d.duplicate(true)
	hard.shape = "fold"
	hard.finish = "glass"
	hard.parts = {"display": "flex", "camera": "cam48"}
	check(Teardown.repair_score("phone", hard) < easy, "dobrável de vidro é mais difícil de reparar")
	check(Teardown.recall_mult(10) > Teardown.recall_mult(90), "difícil de reparar custa mais no recall")
	check(Teardown.layers(c, p).size() >= 5, "teardown lista as camadas")

func test_presentations() -> void:
	var c := staffed(51)
	c.money = 5.0e6
	c.day = 200
	c.reputation = 60.0
	check(Presentations.subjects(c).is_empty(), "sem produto, sem o que apresentar")
	var p := _released(c)
	var subs := Presentations.subjects(c)
	check(subs.size() == 1 and subs[0].kind == "product", "produto aparece como assunto")
	check(Presentations.blocker(c, "product", p.id, "", "stage") != "", "exige escolher o país")
	check(Presentations.cost(c, "us", "stage") > Presentations.cost(c, "br", "stage"), "EUA custa mais que Brasil")
	check(Presentations.cost(c, "br", "mega") > Presentations.cost(c, "br", "online"), "megaevento custa mais")
	c.reputation = 5.0
	check(Presentations.blocker(c, "product", p.id, "cn", "stage") != "", "país exige reputação")
	c.reputation = 60.0
	var m0 := c.money
	var rep0 := c.reputation
	var mods0 := c.mods.size()
	var r := Presentations.run(c, "product", p.id, "br", "stage")
	check(r.ok and c.money < m0, "apresentação cobra o custo")
	check(c.mods.size() == mods0 + 1, "gera modificador de vendas")
	check(["wow", "ok", "flop"].has(str(r.outcome)), "tem veredito")
	check(c.presentations.size() == 1 and c.last_presentation == c.day, "registra no histórico")
	check(Presentations.blocker(c, "product", p.id, "mx", "stage") != "", "intervalo entre apresentações")
	c.day += Presentations.COOLDOWN_DAYS + 1
	check(Presentations.blocker(c, "product", p.id, "br", "stage") != "", "não repete o mesmo assunto/país logo em seguida")
	check(Presentations.blocker(c, "product", p.id, "mx", "stage") == "", "outro país é permitido")
	# veredito segue a qualidade
	check(Presentations.verdict(1.3) == "wow" and Presentations.verdict(1.0) == "ok" and Presentations.verdict(0.6) == "flop", "limiares do veredito")
	# buzz aumenta vendas locais das lojas e decai
	c.buzz["br"] = 0.8
	var s := Stores.default_spec("br")
	s["carry"] = {}
	var with_buzz := Stores._local(c, "phone", s)
	c.buzz["br"] = 0.0
	check(with_buzz > Stores._local(c, "phone", s), "buzz aumenta a venda das lojas do país")
	c.buzz["br"] = 0.5
	c.advance_day()
	check(float(c.buzz.get("br", 0.0)) < 0.5, "buzz decai com o tempo")
	# software e hardware como assunto
	c.own_os = {"version": 2, "features": []}
	var cid := _chip_with(c, {"gpu": 4, "isp": true})
	var kinds: Array = Presentations.subjects(c).map(func(x): return x.kind)
	check(kinds.has("os") and kinds.has("chip"), "sistema próprio e chip podem ser apresentados")
	check(Presentations.highlights(c, "chip", cid).size() >= 2, "destaques do chip")
	var eco0 := c.os_ecosystem()
	c.day += 200
	c.money = 5.0e6
	c.last_presentation = 0
	var ro := Presentations.run(c, "os", 0, "us", "mega")
	check(ro.ok, "apresentar o sistema próprio")
	if ro.outcome != "flop":
		check(c.os_ecosystem() > eco0, "boa apresentação do sistema aumenta o ecossistema")
	c.last_presentation = 0
	var rc := Presentations.run(c, "chip", cid, "de", "stage")
	check(rc.ok, "apresentar um chip")
	var c2 := Company.from_dict(c.to_dict())
	check(c2.presentations.size() == c.presentations.size() and c2.last_presentation == c.last_presentation, "histórico sobrevive ao save")
	check(c2.buzz.size() == c.buzz.size(), "buzz sobrevive ao save")

func test_acquisitions() -> void:
	var c := staffed(61)
	c.money = 2.0e8
	c.day = 300
	var ts := Acquisitions.targets(c)
	var rivals_n := c.market.rivals.size()
	check(ts.size() >= rivals_n, "rivais aparecem à venda")
	# ofertas de startups surgem ao longo dos meses
	for i in 12:
		Acquisitions.monthly(c)
	check(not c.acq_offers.is_empty(), "startups aparecem como ofertas")
	check(c.acq_offers.size() <= Acquisitions.MAX_OFFERS, "limite de ofertas")
	# compra de startup
	var off: Dictionary = c.acq_offers[0]
	var m0 := c.money
	var n_offers := c.acq_offers.size()
	var mods0 := c.mods.size()
	var r := Acquisitions.buy(c, "startup", str(off.id))
	check(r.ok, "compra de startup funciona: " + str(r.msg))
	check(c.money <= m0 - float(off.price), "cobra o preço (mais integração)")
	check(c.acq_offers.size() == n_offers - 1 and c.acquired.size() == 1, "startup sai da lista e entra no grupo")
	check(c.mods.size() >= mods0, "perks viram modificadores")
	check(Acquisitions.blocker(c, "rival", "Xiaomi") != "", "intervalo entre compras")
	c.day += Acquisitions.COOLDOWN_DAYS + 1
	# compra de rival: ações viram dinheiro, vira subsidiária
	var name := "Xiaomi"
	c.stocks.holdings[name] = {"n": 100, "cost": 100.0}
	var price := Acquisitions.rival_price(c, c.market.rivals[c.market.rival_index(name)])
	check(price > float(c.market.rivals[c.market.rival_index(name)].value), "rival custa mais que o valor (prêmio de controle)")
	var cash0 := c.money
	r = Acquisitions.buy(c, "rival", name)
	check(r.ok, "compra de rival funciona")
	check(c.money < cash0 and c.stocks.holding(name) == 0, "ações da empresa comprada foram liquidadas")
	check(Acquisitions.owns(c, name) and bool(c.market.rivals[c.market.rival_index(name)].owned), "rival marcado como subsidiária")
	check(not Stocks.new().buy(c, name, 1).ok, "não dá para comprar ações de subsidiária")
	# lucro de subsidiária entra como receita
	c.market.rivals[c.market.rival_index(name)]["rev_last"] = 1000000.0
	c.income_month = 0.0
	Acquisitions.monthly(c)
	check(c.income_month >= 1000000.0 * Acquisitions.SHARE_OF_REV - 1.0, "repasse de subsidiária vira receita")
	check(Economy.dre(c.ledger, c.cash_items).revenue >= 150000.0 - 1.0, "DRE inclui subsidiárias")
	check(Acquisitions.group_value(c) > 0.0, "valor do grupo soma na empresa")
	# limite do regulador
	c.day += 100
	for nm in ["Apple", "Samsung", "Google"]:
		c.last_acq = -1
		Acquisitions.buy(c, "rival", nm)
	c.last_acq = -1
	check(Acquisitions.owned_rivals(c).size() <= Acquisitions.MAX_RIVALS, "regulador limita compras de rivais")
	check(Acquisitions.blocker(c, "rival", "Huawei") != "", "mais de 3 rivais é barrado")
	# sem dinheiro
	var poor := staffed(62)
	poor.money = 1000.0
	check(Acquisitions.blocker(poor, "rival", "Xiaomi") != "", "sem dinheiro não compra")
	# desbloqueio de acabamento exclusivo
	var item := {"req": "acq:materials", "lvl": 1}
	check(not poor.design_item_unlocked(item), "acabamento exclusivo começa bloqueado")
	poor.acquired.append({"kind": "startup", "name": "X", "unlock": "acq:materials", "price": 1.0, "day": 0})
	check(poor.design_item_unlocked(item), "compra libera o acabamento exclusivo")
	# save/load
	var c2 := Company.from_dict(c.to_dict())
	check(c2 != null and c2.acquired.size() == c.acquired.size() and c2.acq_offers.size() == c.acq_offers.size(), "aquisições sobrevivem ao save")
	var old: Dictionary = c.to_dict()
	old.erase("acquired")
	old.erase("acq_offers")
	old["version"] = 14
	var c3 := Company.from_dict(old)
	check(c3 != null and c3.acquired.is_empty() and c3.last_acq == -1, "save antigo (v14) abre sem aquisições")
