extends Node
## Teste de fumaça da interface: abre o jogo, usa cada página e simula meses.
## Rode como cena (autoloads ativos):
##   godot --headless --path . res://tests/UISmoke.tscn

var failures: int = 0

func ok(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("  FALHOU: ", msg)

func _ready() -> void:
	print("UI smoke test...")
	Game.new_game("Teste Corp")
	var screen: Control = load("res://src/scenes/GameScreen.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame
	var c: Company = Game.company
	ok(c != null, "empresa criada")
	# visita todas as páginas
	for pid in ["dash", "team", "products", "research", "ops", "finance", "stocks", "market"]:
		screen._show_page(pid)
		await get_tree().process_frame
		ok(screen._pages.has(pid), "página " + pid + " criada")
	# ações pelas páginas
	var team: Control = screen._pages["team"]
	screen._show_page("team")
	team._select(0)
	team.act(c.auto_fill("engineer", 0, 0.0))
	team._select(1)
	team.act(c.auto_fill("programmer", 0, 0.0))
	team._select(3)
	team.act(c.auto_fill("researcher", 0, 0.0))
	await get_tree().process_frame
	ok(c.staff.size() >= 4, "equipe contratada via UI (%d)" % c.staff.size())
	screen._show_page("products")
	var prods: Control = screen._pages["products"]
	prods._start()
	await get_tree().process_frame
	ok(c.dev_products().size() == 1, "produto iniciado via UI")
	# deixa o tempo correr (inclui refresh de todas as páginas a cada dia)
	for i in 400:
		Game.advance_day()
		if i % 40 == 0:
			for pid in ["dash", "team", "products", "research", "ops", "finance", "stocks", "market"]:
				screen._show_page(pid)
		for p in c.products:
			if p.state == Product.STATE_READY:
				c.release(p.id)
		if i % 20 == 0:
			c.research_all()
		if i % 50 == 0:
			await get_tree().process_frame
	ok(c.day == 400, "400 dias simulados")
	ok(c.released_products().size() >= 1, "produto lançado")
	# modelos 3D: todas as categorias, com especificações mínimas, médias e máximas e todos os acabamentos
	for cat in GameData.categories():
		for level in [0, 50, 100]:
			for ratio in [0.5, 1.0, 1.3, 1.8, 2.5]:
				var specs := {}
				for a in cat.axes:
					specs[a] = level
				var model := DeviceModel.new()
				add_child(model)
				model.build(cat.id, specs, ratio)
				ok(model.get_child_count() > 3, "modelo 3D %s nível %d tem peças" % [cat.id, level])
				var meshes := 0
				for ch in model.get_children():
					if ch is MeshInstance3D and (ch as MeshInstance3D).mesh != null and (ch as MeshInstance3D).mesh.get_surface_count() > 0:
						meshes += 1
				ok(meshes > 3, "modelo 3D %s tem malhas válidas" % cat.id)
				model.queue_free()
	var slab := RoundedSlab.build(1.0, 2.0, 0.1, 0.2, 0.01, 6)
	ok(slab.get_surface_count() == 1 and slab.surface_get_array_len(0) > 100, "RoundedSlab gera malha")
	prods._pick_category("phone")
	prods._adjust("battery", 5)
	for st in 4:
		prods._go(st)
		await get_tree().process_frame
	prods._toggle_feature("nfc")
	prods._start()
	# modelos 3D com todas as combinações de design
	var d := DeviceModel.new()
	add_child(d)
	for cat in GameData.categories():
		for sh in GameData.designs().shapes[cat.id]:
			for fin in GameData.designs().finishes:
				var des: Dictionary = c.default_design(cat.id)
				des.shape = sh.id
				des.finish = fin.id
				des.features = [GameData.features(cat.id)[0].id]
				des.w = 1
				des.d = 9
				d.build(cat.id, c.default_specs(cat.id), 1.2, des)
				ok(d.get_child_count() > 3, "modelo %s/%s/%s" % [cat.id, sh.id, fin.id])
	d.queue_free()
	# páginas novas: interações
	screen._show_page("stocks")
	var stk: Control = screen._pages["stocks"]
	c.money += 200000.0
	stk.act(c.stocks.buy(c, "Orbital", 100))
	await get_tree().process_frame
	screen._show_page("ops")
	await get_tree().process_frame
	screen._show_page("finance")
	await get_tree().process_frame
	ok(c.stocks.holding("Orbital") == 100, "compra de ações via página")
	# salvar e carregar
	Game.save()
	ok(Saves.has_save(), "save gravado")
	ok(Game.load_game(), "save carregado")
	ok(Game.company.day == 400, "dia preservado no save")
	Saves.delete_save()
	print("UI smoke: %s" % ("OK" if failures == 0 else "%d falha(s)" % failures))
	get_tree().quit(0 if failures == 0 else 1)
