extends Control

var _name_edit: LineEdit
var _viewer: DeviceViewer
var _ci: int = 0
const SHOWCASE := ["phone", "watch", "laptop", "console"]

func _ready() -> void:
	theme = Palette.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UI.background())

	# vitrine 3D à direita; menu à esquerda
	_viewer = DeviceViewer.new()
	_viewer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewer.anchor_left = 0.56
	_viewer.offset_left = 0.0
	_viewer.offset_top = 40.0
	_viewer.offset_bottom = -40.0
	add_child(_viewer)
	var timer := Timer.new()
	timer.wait_time = 4.5
	timer.autostart = true
	timer.timeout.connect(_next_device)
	add_child(timer)
	_show_device()

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.anchor_right = 0.6
	add_child(center)
	var v := UI.vbox(18)
	v.custom_minimum_size = Vector2(760, 0)
	center.add_child(v)

	var title := UI.label("DEVICE", 96, Palette.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := UI.label("E M P I R E", 40, Palette.TEXT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var ver := UI.label("v" + Rules.VERSION, 26, Palette.MUTED)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ver)
	v.add_child(Control.new())

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Nome da sua empresa"
	_name_edit.text = "Minha Empresa"
	_name_edit.custom_minimum_size = Vector2(0, 84)
	_name_edit.add_theme_font_size_override("font_size", 32)
	_name_edit.add_theme_stylebox_override("normal", Palette.box(Palette.PANEL, 14, 18))
	_name_edit.add_theme_stylebox_override("focus", Palette.box(Palette.PANEL_ALT, 14, 18))
	_name_edit.max_length = 28
	v.add_child(_name_edit)

	v.add_child(UI.button("Novo jogo", _on_new, "primary", 100))
	var cont := UI.button("Continuar", _on_continue, "normal", 100)
	cont.disabled = not Saves.has_save()
	v.add_child(cont)
	v.add_child(UI.button("Configurações", _on_settings, "normal", 100))

func _show_device() -> void:
	var cat: String = SHOWCASE[_ci]
	var specs := {}
	for a in GameData.category(cat).axes:
		specs[a] = 55 + _ci * 10
	_viewer.set_device(cat, specs, 0.9 + 0.4 * float(_ci))

func _next_device() -> void:
	_ci = (_ci + 1) % SHOWCASE.size()
	_show_device()

func _on_new() -> void:
	Game.new_game(_name_edit.text)
	get_tree().change_scene_to_file("res://src/scenes/GameScreen.tscn")

func _on_continue() -> void:
	if Game.load_game():
		get_tree().change_scene_to_file("res://src/scenes/GameScreen.tscn")

func _on_settings() -> void:
	get_tree().change_scene_to_file("res://src/scenes/SettingsScreen.tscn")
