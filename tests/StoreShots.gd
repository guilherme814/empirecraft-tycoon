extends Node
## Capturas da tela de lojas (xvfb): /tmp/shots/store_*.png
const OUT := "/tmp/shots/"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	Game.new_game("Aurora Tech")
	var c: Company = Game.company
	c.money = 5000000.0
	c.reputation = 60.0
	var screen: Control = load("res://src/scenes/GameScreen.tscn").instantiate()
	add_child(screen)
	screen._show_page("stores")
	await _shot("store_0_novo")
	var p: Control = screen._pages["stores"]
	p._spec = {"country": "jp", "city": "Tóquio", "size": "store", "facade": "luxury", "staff": 4, "name": ""}
	p._last_sig = "x"
	p.refresh()
	await _run(p, 3.0)
	await _shot("store_1_loja_luxo")
	p._spec = {"country": "us", "city": GameData.country("us").cities[0], "size": "flagship", "facade": "tech", "staff": 6, "name": ""}
	p._last_sig = "x"
	p.refresh()
	await _run(p, 3.0)
	await _shot("store_2_flagship")
	Stores.open(c, p._spec)
	Stores.open(c, {"country": "br", "city": "São Paulo", "size": "kiosk", "facade": "industrial", "staff": 1, "name": ""})
	Game.changed.emit()
	p._sel = int(c.stores[0].id)
	p._last_sig = "x"
	p.refresh()
	await _shot("store_3_existente")
	get_tree().quit()

func _run(p: Control, sec: float) -> void:
	var t := 0.0
	while t < sec:
		p._scene.step(0.1)
		t += 0.1
	await get_tree().process_frame

func _shot(n: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + n + ".png")
