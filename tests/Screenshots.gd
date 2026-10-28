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
			v.set_device(cat.id, specs, combo[1])
			v._yaw = 0.7
	await _shot("3d_showcase")
	get_tree().quit()

func _shot(name: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
