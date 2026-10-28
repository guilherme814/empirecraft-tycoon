class_name DeviceViewer
extends SubViewportContainer
## Visualizador 3D: gira sozinho e responde a arrasto. Só renderiza enquanto está visível
## (economiza bateria). Use set_device() para mostrar uma categoria com suas especificações.

var spin_speed: float = 0.45
var _vp: SubViewport
var _cam: Camera3D
var _pivot: Node3D
var _model: DeviceModel
var _shadow: MeshInstance3D
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
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.42, 0.68)
	sky_mat.sky_horizon_color = Color(0.85, 0.88, 0.95)
	sky_mat.ground_horizon_color = Color(0.5, 0.52, 0.6)
	sky_mat.ground_bottom_color = Color(0.1, 0.1, 0.14)
	sky_mat.sun_angle_max = 18.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
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

	# sombra de contato (fixa; não gira com o aparelho)
	_shadow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.6, 2.6)
	_shadow.mesh = q
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 0.85])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0.5), Color(0, 0, 0, 0.12), Color(0, 0, 0, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	sm.albedo_texture = gt
	_shadow.material_override = sm
	_shadow.rotation_degrees = Vector3(-90, 0, 0)
	_vp.add_child(_shadow)
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
	_shadow.position = Vector3(0, _model.floor_y - 0.05, 0)
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
