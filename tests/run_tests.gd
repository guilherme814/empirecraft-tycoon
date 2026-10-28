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
	print("Executando testes do EmpireCraft...")
	test_data()
	test_hiring()
	test_training_research()
	test_product_flow()
	test_save_roundtrip()
	test_determinism()
	test_bankruptcy()
	test_v3_systems()
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
	check(Fmt.money(1500000.0) == "$ 1.50 M", "Fmt.money milhão: " + Fmt.money(1500000.0))
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
	check(c.market.rivals.size() == 5, "5 rivais")
	for rv in c.market.rivals:
		check(float(rv.price) > 0.0 and float(rv.value) > 0.0, "rival com preço/valor positivos")
	check(c.stocks.value > 0.0, "valor da empresa calculado")
	var m0 := c.money
	check(c.stocks.buy(c, "Nova Corp", 100).ok and c.stocks.holding("Nova Corp") == 100, "compra ações")
	check(c.money < m0, "compra custa dinheiro")
	check(c.stocks.sell(c, "Nova Corp", 100).ok and c.stocks.holding("Nova Corp") == 0, "vende ações")
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
	check(c2.market.rivals.size() == 5 and c2.deal_active("retail"), "save mantém rivais e acordos")
	check(c2.products[0].os_id == "lumen" and c2.products[0].design.get("shape", "") == "fold", "save mantém design do produto")
	for i in 60:
		c2.advance_day()
	check(not c2.game_over, "jogo carregado segue funcionando")
