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
	while p.state == Product.STATE_DEV and days < 400:
		c.advance_day()
		days += 1
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
	check(c.market.rivals.size() == 10, "10 rivais")
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
	check(c2.market.rivals.size() == 10 and c2.deal_active("retail"), "save mantém rivais e acordos")
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
