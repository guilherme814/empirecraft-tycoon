extends Node
## Capturas do escritório 3D em vários estágios (xvfb): /tmp/shots/office_*.png

const OUT := "/tmp/shots/"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	Game.new_game("Aurora Tech")
	var c: Company = Game.company
	var screen: Control = load("res://src/scenes/GameScreen.tscn").instantiate()
	add_child(screen)
	screen._show_page("office")
	await _shot("office_0_vazio")
	c.money = 3000000.0
	for prof in ["engineer", "programmer"]:
		c.auto_fill(prof, 0, 0.0)
	Game.changed.emit()
	await _run(8.0)
	await _shot("office_1_pequeno")
	c.research_points = 500.0
	for prof in ["engineer", "programmer", "designer", "researcher"]:
		c.office_level[prof] = 4
		c.search_agency(2, prof)
		c.auto_fill(prof, 2, 0.0)
	Game.changed.emit()
	await _run(30.0)
	await _shot("office_2_medio")
	var page: Control = screen._pages["office"]
	page.scene.select(page.scene.workers.keys()[3])
	await _run(1.0)
	await _shot("office_3_selecionado")
	for prof in ["engineer", "programmer", "designer", "researcher"]:
		c.office_level[prof] = 5
		c.search_agency(2, prof)
		c.auto_fill(prof, 2, 0.0)
	Game.changed.emit()
	await _run(40.0)
	await _shot("office_4_grande")
	page.scene.set_zoom(2.8)
	page.scene._pan = Vector2(-1.0, -1.5)
	page.scene._apply_cam()
	await _run(2.0)
	await _shot("office_5_zoom")
	print("staff=", c.staff.size(), " kinds=", page.scene.counts_by_kind())
	get_tree().quit()

func _run(sec: float) -> void:
	var page: Control = get_child(0)._pages["office"]
	var t := 0.0
	while t < sec:
		page.scene.step(0.1)
		t += 0.1
	await get_tree().process_frame
	await get_tree().process_frame

func _shot(n: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + n + ".png")
