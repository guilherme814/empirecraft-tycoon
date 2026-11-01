extends Node
## Captura todas as páginas em /tmp/pages/ (xvfb, 2400x1080): xvfb-run -s "-screen 0 2400x1080x24" godot --path . --resolution 2400x1080 res://tests/PageShots.tscn
const OUT := "/tmp/pages/"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	Game.new_game("Aurora Tech")
	var c: Company = Game.company
	var screen: Control = load("res://src/scenes/GameScreen.tscn").instantiate()
	add_child(screen)
	for prof in ["engineer", "programmer", "researcher", "designer"]:
		c.auto_fill(prof, 0, 0.0)
	c.research_points = 600.0
	c.do_research("res_specs")
	screen._show_page("products")
	screen._pages["products"]._start()
	for i in 160:
		Game.advance_day()
		for p in c.products:
			if p.state == Product.STATE_READY:
				c.release(p.id)
	c.money = 900000.0
	Game.notice.emit("Contratados: 2", "good")
	for d in screen.PAGE_DEFS:
		while screen._overlay != null:
			screen._close_overlay()
			await get_tree().process_frame
		screen._show_page(d.id)
		Game.changed.emit()
		await _shot(str(d.id))
	# sistema próprio com outra aparência + central de notificações
	c.research_levels["res_os"] = 1
	c.set_os_look("theme", "light")
	c.set_os_look("icons", "round")
	c.set_os_look("notif", "banner")
	c.set_os_look("wall", "sunset")
	c.set_os_look("clock", "side")
	c.set_os_look("widget", "music")
	c.add_log("Seu produto Vega P6 passou de 1.000 unidades vendidas.", "good")
	c.add_log("Defeito de fábrica detectado no lote 3.", "bad")
	while screen._overlay != null:
		screen._close_overlay()
		await get_tree().process_frame
	screen._show_page("system")
	Game.changed.emit()
	await _shot("system_b")
	screen._open_notifs()
	await _shot("notifs")
	screen._close_overlay()
	await get_tree().process_frame
	for i in 6:
		c.market.react_to_launch("phone", 500.0, 600.0, c.day + i)
	screen._show_page("market")
	screen._pages["market"]._sel = "Apple"
	screen._pages["market"].rebuild()
	await _shot("market")
	c.research_points = 900.0
	c.do_research("res_tech")
	c.do_research("res_tech")
	screen._show_page("research")
	screen._pages["research"].rebuild()
	await _shot("research")
	c.money = 5000000.0
	c.reputation = 60.0
	Stores.open(c, Stores.default_spec("br"))
	Stores.open(c, Stores.default_spec("ar"))
	screen._show_page("stores")
	await _shot("stores_open")
	screen._pages["stores"]._tab = "mine"
	screen._pages["stores"].rebuild()
	await _shot("stores_mine")
	var dp: Product = c.products[0]
	dp.state = Product.STATE_DEV
	dp.work_done = dp.work_required * 0.5
	var rp: Product = c.products[0]
	rp.state = Product.STATE_RELEASED
	rp.stock = 120
	rp.avg_cost = 95.0
	rp.orders = [{"qty": 200, "unit": 95.0, "ready": c.day + 5}]
	screen._show_page("ops")
	screen._pages["ops"].rebuild()
	await _shot("ops_stock")
	screen._show_page("dash")
	screen._pages["dash"].rebuild()
	await _shot("dash")
	get_tree().quit()

func _shot(n: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + n + ".png")
