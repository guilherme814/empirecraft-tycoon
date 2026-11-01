extends Node
const OUT := "/tmp/logo/"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	Game.new_game("Aurora Tech")
	var c: Company = Game.company
	c.money = 9000000.0
	for prof in ["engineer", "programmer"]:
		c.auto_fill(prof, 0, 0.0)
	var screen: Control = load("res://src/scenes/GameScreen.tscn").instantiate()
	add_child(screen)
	screen._show_page("office")
	var p: Control = screen._pages["office"]
	p._toggle_edit()
	p._dl = {"symbol": "chevron", "c1": "c792ea", "c2": "2d3a6b", "style": "caps", "shape": "circle", "pattern": "diag", "grad": "grad"}
	p._draft_changed()
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + "editor.png")
	screen._show_page("stocks")
	Game.changed.emit()
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + "stocks.png")
	get_tree().quit()
