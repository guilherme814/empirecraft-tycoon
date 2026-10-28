class_name DeviceViewer
extends SubViewportContainer
## Visualizador 3D: gira sozinho e responde a arrasto. Só renderiza enquanto está visível
## (economiza bateria). Use set_device() para mostrar uma categoria com suas especificações.

var spin_speed: float = 0.45
var _vp: SubViewport
var _cam: Camera3D
var _pivot: Node3D
var _model: DeviceModel
var _key: String = ""
var _yaw: float = 0.55
var _pitch: float = 0.16
var _idle: float = 0.0
var _dragging: bool = false

func _ready() -> void:
	stretch = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size.y = maxf(custom_minimum_size.y, 360.0)   # respeita um mínimo maior definido por quem usa
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.72)
	env.ambient_light_energy = 0.8
	_cam = Camera3D.new()
	_cam.environment = env
	_cam.fov = 32.0
	_vp.add_child(_cam)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 38, 0)
	sun.light_energy = 1.25
	_vp.add_child(sun)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-2.4, 1.6, -2.2)
	rim.light_color = Color("ff9a2e")
	rim.light_energy = 1.6
	rim.omni_range = 9.0
	_vp.add_child(rim)

	_pivot = Node3D.new()
	_vp.add_child(_pivot)
	_model = DeviceModel.new()
	_pivot.add_child(_model)
	_place_camera("phone")
	gui_input.connect(_on_gui_input)

func _place_camera(cat: String) -> void:
	var dist := DeviceModel.camera_distance(cat)
	_cam.position = Vector3(0, 0.15, dist)
	_cam.look_at(Vector3(0, 0, 0), Vector3.UP)

## quality_ratio = qualidade / expectativa do mercado (define o acabamento).
func set_device(cat: String, specs: Dictionary, quality_ratio: float, design: Dictionary = {}) -> void:
	var tier := DeviceModel.tier_for(quality_ratio)
	var k := "%s|%s|%d|%s" % [cat, str(specs), tier, str(design)]
	if k == _key:
		return
	_key = k
	_model.build(cat, specs, quality_ratio, design)
	_place_camera(cat)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if _idle > 0.0:
		_idle -= delta
	elif spin_speed != 0.0:
		_yaw += delta * spin_speed
	_pivot.rotation = Vector3(_pitch, _yaw, 0)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_yaw += event.relative.x * 0.012
		_pitch = clampf(_pitch + event.relative.y * 0.006, -0.5, 0.7)
		_idle = 2.5
		accept_event()
