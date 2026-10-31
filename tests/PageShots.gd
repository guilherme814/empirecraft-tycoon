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
	get_tree().quit()

func _shot(n: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + n + ".png")
