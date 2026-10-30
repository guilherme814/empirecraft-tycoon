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
				ok(_count(model, false) > 3, "modelo 3D %s nível %d tem peças" % [cat.id, level])
				ok(_count(model, true) > 3, "modelo 3D %s tem malhas válidas" % cat.id)
				model.queue_free()
	var slab := RoundedSlab.build(1.0, 2.0, 0.1, 0.2, 0.01, 6)
	ok(slab.get_surface_count() == 1 and slab.surface_get_array_len(0) > 100, "RoundedSlab gera malha")
	prods._pick_category("phone")
	prods._adjust("battery", 5)
	for st in 5:
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
				ok(_count(d, false) > 3, "modelo %s/%s/%s" % [cat.id, sh.id, fin.id])
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
	# v0.4: marketing, laboratório, hardware, feedback e software
	c.money += 2000000.0
	c.research_points += 5000.0
	for rid in ["res_tech", "res_tech", "res_tech", "res_specs", "res_hype", "res_design", "res_os", "res_marketing", "res_lab", "res_chips", "res_software", "res_package"]:
		for i in 4:
			c.research_points += 800.0
			c.do_research(rid)
	var rel: Array = c.released_products()
	ok(not rel.is_empty(), "há produto lançado para testar as páginas novas")
	screen._show_page("lab")
	await get_tree().process_frame
	var lab_pg: Control = screen._pages["lab"]
	lab_pg.act(Lab.run_test(c, rel[0].id, "drop"))
	lab_pg.act(Lab.start_beta(c, rel[0].id))
	for i in 12:
		Game.advance_day()
	await get_tree().process_frame
	ok(rel[0].tests.has("drop"), "ensaio concluído")
	ok(not rel[0].beta.is_empty(), "beta concluído")
	screen._show_page("marketing")
	await get_tree().process_frame
	var mk: Control = screen._pages["marketing"]
	mk.act(Marketing.start(c, rel[0].id, "web", ["na", "eu"], 1000.0, 10))
	await get_tree().process_frame
	ok(c.campaigns.size() == 1, "campanha ativa")
	screen._show_page("chips")
	await get_tree().process_frame
	var cp: Control = screen._pages["chips"]
	var cd := Chips.default_design(c)
	cd["name"] = "Teste X1"
	cp.act(Chips.start(c, cd))
	for i in 400:
		Game.advance_day()
		if c.chip_dev == null:
			break
	await get_tree().process_frame
	ok(c.chips.size() == 1, "chip projetado")
	prods.refresh()
	if c.chips.is_empty():
		print("chip falhou: ", Chips.blocker(c, cd))
		get_tree().quit(1)
		return
	prods._design["chip"] = int(c.chips[0].id)
	prods._go(2)
	await get_tree().process_frame
	prods._go(1)
	await get_tree().process_frame
	screen._show_page("feedback")
	await get_tree().process_frame
	screen._pages["feedback"]._tab = 1
	screen._pages["feedback"]._touch()
	await get_tree().process_frame
	screen._pages["feedback"]._tab = 0
	screen._pages["feedback"]._touch()
	await get_tree().process_frame
	screen._show_page("ops")
	await get_tree().process_frame
	c.own_os["version"] = 1
	var tf := c.toggle_os_feature("dark")
	ok(tf.ok, "recurso de software ativado")
	screen._pages["ops"].act(tf)
	await get_tree().process_frame
	# salvar e carregar
	var saved_day := c.day
	Game.save()
	# escritório 3D: funcionários aparecem, sentam, trabalham, saem; toque seleciona
	var oc: Company = Game.company
	oc.money = 2000000.0
	for prof in ["engineer", "programmer", "designer"]:
		oc.auto_fill(prof, 0, 0.0)
	screen._show_page("office")
	Game.changed.emit()
	await get_tree().process_frame
	var op: Control = screen._pages["office"]
	var osc: OfficeScene = op.scene
	ok(osc.layout != null and osc.workers.size() == mini(oc.staff.size(), OfficeLayout.MAX_VISIBLE), "escritório mostra a equipe (%d)" % osc.workers.size())
	var seated := true
	for id in osc.workers:
		var w: OfficeWorker = osc.workers[id]
		if w.mode != "work" or w.position.distance_to(w.seat.pos) > 0.05:
			seated = false
	ok(seated, "equipe inicial já aparece sentada na mesa")
	var before_staff := oc.staff.size()
	for prof in ["researcher", "engineer"]:
		oc.office_level[prof] = 3
		oc.search_agency(1, prof)
		oc.auto_fill(prof, 1, 0.0)
	ok(oc.staff.size() > before_staff, "contratações novas feitas")
	Game.changed.emit()
	await get_tree().process_frame
	var newbies := 0
	for id in osc.workers:
		if (osc.workers[id] as OfficeWorker).kind == "enter":
			newbies += 1
	ok(newbies > 0, "recém-contratados entram pela porta")
	for i in 1200:
		osc.step(0.1)
	var settled := true
	for id in osc.workers:
		var w2: OfficeWorker = osc.workers[id]
		if w2.kind == "enter":
			settled = false
	ok(settled, "recém-contratados chegam à própria mesa")
	var seen_break := false
	var seen_chat := false
	var chat_pairs_ok := true
	for i in 6000:
		osc.step(0.1)
		var k := osc.counts_by_kind()
		if int(k.break) > 0:
			seen_break = true
		if int(k.chat) > 0:
			seen_chat = true
		if i % 50 == 0:
			var away := int(k.break) + int(k.chat)
			if away > maxi(1, int(osc.workers.size() * 0.3)) + 1:
				chat_pairs_ok = false
	ok(seen_break and seen_chat, "funcionários fazem pausas e conversam")
	ok(chat_pairs_ok, "só uma parte da equipe sai das mesas ao mesmo tempo")
	osc.events_enabled = false
	for i in 1500:
		osc.step(0.1)
	var all_back := true
	for id in osc.workers:
		var w4: OfficeWorker = osc.workers[id]
		if w4.mode != "work" or w4.position.distance_to(w4.seat.pos) > 0.06:
			all_back = false
	if not all_back:
		for id in osc.workers:
			var wd: OfficeWorker = osc.workers[id]
			if wd.mode != "work" or wd.position.distance_to(wd.seat.pos) > 0.06:
				print("   preso: ", wd.emp_name, " modo=", wd.mode, " tipo=", wd.kind, " pos=", wd.position, " seat=", wd.seat.pos, " path_i=", wd.path_i, "/", wd.path.size(), " after=", wd.after)
	ok(all_back, "todos voltam ao trabalho depois das pausas")
	osc.events_enabled = true
	# toque seleciona o funcionário certo
	var target_id: int = osc.workers.keys()[0]
	var tw: OfficeWorker = osc.workers[target_id]
	var scr := osc._cam.unproject_position(tw.global_position + Vector3(0, 0.55, 0))
	ok(osc.pick(scr) == target_id, "toque seleciona o funcionário")
	osc.select(target_id)
	await get_tree().process_frame
	ok(op._card.visible, "card do funcionário aparece")
	# demissão: sai andando e some
	var fire_id := -1
	for pr in ["engineer", "programmer", "designer", "researcher"]:
		var lst: Array = oc.staff_of(pr)
		if lst.size() >= 2 and lst.size() % 2 == 0 and fire_id == -1:
			for em in lst:
				var fw: OfficeWorker = osc.workers.get((em as Employee).id, null)
				if fw != null and fw.mode == "work" and fire_id == -1:
					fire_id = (em as Employee).id
	ok(fire_id != -1, "há quem demitir sem mudar a planta")
	oc.fire(fire_id)
	Game.changed.emit()
	await get_tree().process_frame
	if not (osc.workers.has(fire_id) and (osc.workers[fire_id] as OfficeWorker).kind == "leave"):
		print("   demitido: tem=", osc.workers.has(fire_id), " layout=", osc._layout_sig, " staff=", oc.staff.size())
	ok(osc.workers.has(fire_id) and (osc.workers[fire_id] as OfficeWorker).kind == "leave", "demitido caminha para a saída")
	for i in 1500:
		osc.step(0.1)
	ok(not osc.workers.has(fire_id), "demitido some do escritório")
	ok(osc.workers.size() == mini(oc.staff.size(), OfficeLayout.MAX_VISIBLE), "escritório acompanha a equipe após demissão")
	screen._show_page("dash")
	# lojas: abrir em vários países, vender, custo mensal, personalizar, fechar, página e prévia 3D
	oc.money = 5000000.0
	oc.reputation = 60.0
	var open_money := oc.money
	var r1 := Stores.open(oc, {"country": "br", "city": "São Paulo", "size": "store", "facade": "luxury", "staff": 3, "name": ""})
	var r2 := Stores.open(oc, {"country": "jp", "city": GameData.country("jp").cities[0], "size": "kiosk", "facade": "tech", "staff": 1, "name": "Tokyo Kiosk"})
	ok(r1.ok and r2.ok and oc.stores.size() == 2, "abre lojas em países diferentes")
	ok(oc.money < open_money, "abrir loja gasta caixa")
	ok(not Stores.open(oc, {"country": "xx", "city": "?", "size": "store", "facade": "luxury", "staff": 1}).ok, "país inválido é recusado")
	oc.reputation = 0.0
	ok(not Stores.open(oc, {"country": "us", "city": GameData.country("us").cities[0], "size": "flagship", "facade": "tech", "staff": 4}).ok, "reputação baixa bloqueia loja grande")
	oc.reputation = 60.0
	var pn := oc.products.size()
	var rel_l := oc.released_products()
	if rel_l.is_empty():
		for pr in oc.products:
			if pr.state == Product.STATE_READY:
				oc.release(pr.id)
	var sold0 := 0
	for i in 40:
		oc.advance_day()
	for st in oc.stores:
		sold0 += int(st.units)
	if not oc.released_products().is_empty():
		ok(sold0 > 0, "lojas vendem produtos lançados (%d un.)" % sold0)
	var cash0 := oc.money
	for i in 31:
		oc.advance_day()
	var up := Stores.update(oc, int(oc.stores[0].id), "industrial", 2)
	ok(up.ok and oc.stores[0].facade == "industrial" and int(oc.stores[0].staff) == 2, "personaliza fachada e equipe")
	var sv := oc.to_dict()
	var rc := Company.from_dict(JSON.parse_string(JSON.stringify(sv)))
	ok(rc.stores.size() == 2 and rc.stores[1].country == "jp" and int(rc.stores[0].id) == int(oc.stores[0].id), "lojas sobrevivem ao save/load")
	var oldd := sv.duplicate()
	oldd.erase("stores")
	oldd["version"] = 4
	ok(Company.from_dict(oldd).stores.is_empty(), "save antigo sem lojas carrega")
	screen._show_page("stores")
	Game.changed.emit()
	await get_tree().process_frame
	var sp: Control = screen._pages["stores"]
	ok(sp._scene.workers.size() > 0, "prévia 3D da loja tem funcionários")
	for z in 30:
		sp._scene.step(0.1)
	sp._sel = int(oc.stores[0].id)
	sp._last_sig = "\u0001"
	sp.refresh()
	await get_tree().process_frame
	var cl := Stores.close(oc, int(oc.stores[0].id))
	ok(cl.ok and oc.stores.size() == 1, "fecha loja")
	sp._sel = -1
	screen._show_page("dash")
	ok(Saves.has_save(), "save gravado")
	ok(Game.load_game(), "save carregado")
	ok(Game.company.day == saved_day, "dia preservado no save")
	ok(Game.company.chips.size() == 1 and Game.company.campaigns.size() >= 0, "chips e campanhas preservados no save")
	Saves.delete_save()
	# backup do save: grava duas vezes e o anterior fica guardado; principal corrompido recupera do backup
	var bk := Company.new(51)
	bk.day = 10
	Saves.save_company(bk)
	bk.day = 20
	Saves.save_company(bk)
	ok(FileAccess.file_exists(Saves.BACKUP_PATH), "backup criado ao regravar")
	var f := FileAccess.open(Saves.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{corrompido")
	f.close()
	var restored := Saves.load_company()
	ok(restored != null and restored.day == 10, "recupera do backup quando o save principal está corrompido")
	Saves.delete_save()
	if FileAccess.file_exists(Saves.BACKUP_PATH):
		DirAccess.remove_absolute(Saves.BACKUP_PATH)
	print("UI smoke: %s" % ("OK" if failures == 0 else "%d falha(s)" % failures))
	get_tree().quit(0 if failures == 0 else 1)

func _count(n: Node, meshes_only: bool) -> int:
	var k := 0
	for ch in n.get_children():
		if not meshes_only or (ch is MeshInstance3D and (ch as MeshInstance3D).mesh != null):
			k += 1
		k += _count(ch, meshes_only)
	return k
