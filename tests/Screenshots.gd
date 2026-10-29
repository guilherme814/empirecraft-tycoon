extends Node
## Gera capturas de cada tela em /tmp/shots (precisa de display; use xvfb-run).
##   xvfb-run -s "-screen 0 1920x1080x24" godot --path . res://tests/Screenshots.tscn

const OUT := "/tmp/shots/"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var menu: Control = load("res://src/scenes/MainMenu.tscn").instantiate()
	add_child(menu)
	await _shot("menu")
	menu.queue_free()
	Game.new_game("Aurora Tech")
	var c: Company = Game.company
	var screen: Control = load("res://src/scenes/GameScreen.tscn").instantiate()
	add_child(screen)
	await _shot("dash_novo")
	screen._show_page("team")
	await _shot("team_vazio")
	for prof in ["engineer", "programmer", "researcher"]:
		c.auto_fill(prof, 0, 0.0)
	c.search_agency(1, "designer")
	c.research_points = 300.0
	c.do_research("res_specs")
	screen._show_page("products")
	await _shot("products_form")
	screen._pages["products"]._start()
	for i in 200:
		Game.advance_day()
		for p in c.products:
			if p.state == Product.STATE_READY:
				c.release(p.id)
	c.money = 400000.0
	screen._show_page("dash")
	Game.changed.emit()
	await _shot("dash")
	screen._show_page("team")
	Game.changed.emit()
	await _shot("team")
	screen._show_page("products")
	Game.changed.emit()
	await _shot("products")
	screen._show_page("research")
	Game.changed.emit()
	await _shot("research")
	screen._show_page("market")
	Game.changed.emit()
	await _shot("market")
	# v0.3: estúdio e novas páginas
	for id in ["res_tech", "res_tech", "res_tech", "res_design", "res_shapes", "res_finish", "res_features", "res_os", "res_cost", "res_cost", "res_factory", "res_hype", "res_hype", "res_capital"]:
		c.research_points += 400.0
		c.money += 60000.0
		c.do_research(id)
	c.money = 1500000.0
	screen._show_page("products")
	var pp: Control = screen._pages["products"]
	pp._design["shape"] = "slim"
	pp._design["finish"] = "titanium"
	pp._design["color"] = "blue"
	pp._toggle_feature("nfc")
	Game.changed.emit()
	await _shot("studio_design")
	pp._go(1)
	await _shot("studio_style")
	pp._go(2)
	await _shot("studio_hardware")
	pp._go(3)
	await _shot("studio_system")
	pp._go(4)
	await _shot("studio_production")
	c.start_os_dev("Aurora OS")
	for i in 60:
		Game.advance_day()
	screen._show_page("ops")
	Game.changed.emit()
	await _shot("ops")
	c.reputation = 50.0
	c.sign_deal("retail")
	for i in 70:
		Game.advance_day()
	screen._show_page("finance")
	Game.changed.emit()
	await _shot("finance")
	screen._show_page("stocks")
	c.stocks.buy(c, "Nova Corp", 500)
	Game.changed.emit()
	await _shot("stocks")
	# v0.4: laboratório, marketing, hardware, feedback
	for rid in ["res_marketing", "res_lab", "res_chips", "res_chips", "res_chips", "res_software", "res_package"]:
		for i in 3:
			c.research_points += 900.0
			c.money += 100000.0
			c.do_research(rid)
	var rel: Array = c.released_products()
	if not rel.is_empty():
		Lab.run_test(c, rel[0].id, "drop")
		Lab.run_test(c, rel[0].id, "thermal")
		Lab.start_beta(c, rel[0].id)
		Marketing.start(c, rel[0].id, "web", ["na", "eu", "latam"], 2000.0, 30)
	var cd := Chips.default_design(c)
	cd["name"] = "Aurora A1"
	cd["cores"] = 6
	Chips.start(c, cd)
	for i in 60:
		Game.advance_day()
	for k in 3:
		Feedback.monthly(c)
	for pg in [["lab", "lab"], ["marketing", "marketing"], ["chips", "chips"], ["feedback", "feedback"]]:
		screen._show_page(pg[0])
		Game.changed.emit()
		await _shot(pg[1])
	if screen._overlay != null:
		screen._close_overlay()
	var p0: Variant = c.products.filter(func(p): return p.state == Product.STATE_RELEASED)
	# vitrine: cada categoria em dois níveis de especificação/acabamento
	screen.queue_free()
	var show := Control.new()
	show.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	show.theme = Palette.make_theme()
	add_child(show)
	show.add_child(UI.background())
	var grid := GridContainer.new()
	grid.columns = 4
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid.add_theme_constant_override("h_separation", 10)
	show.add_child(grid)
	for combo in [[20, 0.7], [95, 2.2]]:
		for cat in GameData.categories():
			var v := DeviceViewer.new()
			v.custom_minimum_size = Vector2(470, 520)
			v.spin_speed = 0.0
			grid.add_child(v)
			var specs := {}
			for a in cat.axes:
				specs[a] = combo[0]
			var des: Dictionary = {}
			if combo[0] > 50:
				des = c.default_design(cat.id)
				des["color"] = ["blue", "gold", "red", "green"][GameData.categories().find(cat) % 4]
				des["finish"] = "alu"
				des["wall"] = ["sunset", "aurora", "neon", "ocean"][GameData.categories().find(cat) % 4]
				des["cam"] = ["circle", "plate", "bar", "grid"][GameData.categories().find(cat) % 4]
				des["brand_name"] = "Aurora"
				des["features"] = [GameData.features(cat.id)[0].id, GameData.features(cat.id)[1].id]
				des["band"] = "leather"
				des["led"] = "purple"
			v.set_device(cat.id, specs, combo[1], des)
			v._yaw = 0.7
	await _shot("3d_showcase")
	get_tree().quit()

func _shot(name: String) -> void:
	var gs: Node = get_node_or_null("GameScreen")
	for ch in get_children():
		if ch.has_method("_close_overlay") and ch.get("_overlay") != null:
			ch._close_overlay()
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
