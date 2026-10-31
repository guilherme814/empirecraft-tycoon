extends Node
## Variações de design dos aparelhos: /tmp/dev/*.png (xvfb-run ... res://tests/DeviceShots.tscn)
const OUT := "/tmp/dev/"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	Game.new_game("Aurora Tech")
	var c: Company = Game.company
	var specs := {"performance": 70, "battery": 60, "display": 70, "camera": 99, "design": 60, "sensors": 60, "storage": 60, "audio": 60, "thermal": 60, "graphics": 70}
	await _sheet("phone_back", "phone", specs, PI + 0.35, [
		{"cam": "plate"}, {"cam": "pill", "back": "stripe"}, {"cam": "diagonal", "back": "split"}, {"cam": "center", "back": "ring"},
		{"cam": "ring", "bio": "back"}, {"cam": "circle", "back": "stripe"}, {"cam": "island", "back": "split"}, {"cam": "grid", "bio": "back"}], c)
	await _sheet("phone_front", "phone", specs, -0.5, [
		{"notch": "punch", "buttons": "classic"}, {"notch": "teardrop", "buttons": "right"}, {"notch": "corner", "buttons": "action"},
		{"notch": "dual", "buttons": "camkey"}, {"notch": "notch", "buttons": "minimal"}, {"notch": "island", "bio": "side"}, {"notch": "none"}, {"notch": "punch", "shape": "edge"}], c)
	await _sheet("watch", "watch", specs, 0.5, [
		{"face": "digital", "band": "silicone", "crown": "classic"}, {"face": "analog", "band": "link", "crown": "dial"},
		{"face": "minimal", "band": "nylon", "crown": "dual"}, {"face": "analog", "band": "leather", "crown": "none", "shape": "round"}], c)
	await _sheet("laptop", "laptop", specs, 0.4, [
		{"kbd": "standard", "webcam": "dot", "lid": "logo"}, {"kbd": "round", "webcam": "notch", "lid": "stripe"},
		{"kbd": "split", "webcam": "bar", "lid": "ring", "features": ["backlit"]}, {"kbd": "standard", "webcam": "none", "lid": "plain"}], c)
	await _sheet("console", "console", specs, 0.4, [
		{"vent": "slats", "glow": "bar", "pad": "classic"}, {"vent": "grille", "glow": "dots", "pad": "mini"},
		{"vent": "diagonal", "glow": "edge", "pad": "pro"}, {"vent": "grille", "glow": "bar", "pad": "pro", "shape": "tower"}], c)
	get_tree().quit()

func _sheet(name: String, cat: String, specs: Dictionary, yaw: float, variants: Array, c: Company) -> void:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(grid)
	for v in variants:
		var d: Dictionary = c.default_design(cat)
		d["brand_name"] = "AURORA"
		for k in v:
			d[k] = v[k]
		d["color"] = ["graphite", "blue", "silver", "red"][randi() % 4]
		var dv := DeviceViewer.new()
		dv.custom_minimum_size = Vector2(600, 540)
		dv.spin_speed = 0.0
		dv._yaw = yaw
		grid.add_child(dv)
		dv.set_device(cat, specs, 1.2, d)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
	grid.queue_free()
	await get_tree().process_frame
