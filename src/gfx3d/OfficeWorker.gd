class_name OfficeWorker
extends Node3D
## Funcionário low-poly do escritório. Esqueleto simples (quadril, tronco, cabeça, braços, coxas e
## canelas) animado por código: digitar sentado, andar, levantar/sentar, conversar e beber café.
## As malhas são geradas uma vez por "estilo" e reaproveitadas por todos.

const SKIN := [Color("f2c9a0"), Color("d9a574"), Color("b27c52"), Color("7d5236")]
const HAIR := [Color("2b2118"), Color("5a3b22"), Color("c79a54"), Color("1c1c24"), Color("8a3b2a")]
const WALK_SPEED := 1.15
const HIP_STAND := 0.48
const HIP_SIT := 0.31

# aparência por profissão
const LOOK := {
	"engineer": {"shirt": Color("6f7f55"), "extra": Color("ff9a2e"), "pants": Color("39435c"), "shoe": Color("2a2a30")},
	"programmer": {"shirt": Color("2c3f78"), "extra": Color("5aa9ff"), "pants": Color("2f323c"), "shoe": Color("e9ecf2")},
	"designer": {"shirt": Color("2fa59a"), "extra": Color("c792ea"), "pants": Color("4a3f63"), "shoe": Color("ff7aa8")},
	"researcher": {"shirt": Color("eef1f6"), "extra": Color("d6dbe6"), "pants": Color("404859"), "shoe": Color("2a2a30")},
}

static var _meshes: Dictionary = {}
static var _shadow_mesh: QuadMesh = null
static var _shadow_mat: StandardMaterial3D = null

var emp_id: int = -1
var prof: String = "engineer"
var emp_name: String = ""
var seat: Dictionary = {}

var mode: String = "work"           # work | standing_up | walking | sitting_down | at_spot | gone
var after: String = ""              # o que fazer ao terminar a rota: spot | seat | leave
var path: Array = []
var path_i: int = 0
var spot: Dictionary = {}
var spot_time: float = 0.0
var return_path: Array = []
var kind: String = ""               # work | break | chat | enter | leave
var partner: OfficeWorker = null
var event_timer: float = 20.0
var sit_t: float = 1.0
var walk_amt: float = 0.0
var walk_phase: float = 0.0
var speak_offset: float = 0.0
var yaw_target: float = 0.0
var flag_gone: bool = false

var _t: float = 0.0
var _ph: float = 0.0
var _hip: Node3D
var _upper: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D
var _cup: MeshInstance3D
var _bubble: Label3D
var _sit_pose: bool = true
var _seat_kind: bool = false

func setup(id: int, profession: String, nm: String) -> void:
	emp_id = id
	prof = profession
	emp_name = nm
	_ph = float(id % 97) * 0.37
	var skin_i := id % SKIN.size()
	var hair_i := (id / 3) % HAIR.size()
	var key := "%s|%d|%d" % [prof, skin_i, hair_i]
	var look: Dictionary = LOOK.get(prof, LOOK.engineer)

	if _shadow_mesh == null:
		_shadow_mesh = QuadMesh.new()
		_shadow_mesh.size = Vector2(0.62, 0.62)
		_shadow_mat = StandardMaterial3D.new()
		_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		grad.colors = PackedColorArray([Color(0, 0, 0, 0.42), Color(0, 0, 0, 0.16), Color(0, 0, 0, 0.0)])
		var gt := GradientTexture2D.new()
		gt.gradient = grad
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		_shadow_mat.albedo_texture = gt
	var sh := MeshInstance3D.new()
	sh.mesh = _shadow_mesh
	sh.material_override = _shadow_mat
	sh.rotation_degrees = Vector3(-90, 0, 0)
	sh.position = Vector3(0, 0.012, 0)
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sh)

	_hip = Node3D.new()
	add_child(_hip)
	_upper = Node3D.new()
	_hip.add_child(_upper)
	var mat := MeshBuilder.material("worker")
	_upper.add_child(_mi(_torso_mesh(key, skin_i, hair_i, look)))
	_head = Node3D.new()
	_head.position = Vector3(0, 0.31, 0)
	_upper.add_child(_head)
	_head.add_child(_mi(_head_mesh(key, skin_i, hair_i, look)))
	_arm_l = _limb(_upper, Vector3(-0.17, 0.27, 0), _arm_mesh(key, skin_i, look))
	_arm_r = _limb(_upper, Vector3(0.17, 0.27, 0), _arm_mesh(key, skin_i, look))
	_leg_l = _limb(_hip, Vector3(-0.065, 0, 0), _thigh_mesh(key, look))
	_leg_r = _limb(_hip, Vector3(0.065, 0, 0), _thigh_mesh(key, look))
	_knee_l = _limb(_leg_l, Vector3(0, -0.2, 0), _shin_mesh(key, look))
	_knee_r = _limb(_leg_r, Vector3(0, -0.2, 0), _shin_mesh(key, look))
	# caneca de café na mão direita (só aparece nas pausas)
	var cb := MeshBuilder.new()
	cb.prism(Vector3(0, 0, 0), 0.035, 0.07, 8, Color("f4f1ea"))
	cb.prism(Vector3(0, 0.036, 0), 0.03, 0.005, 8, Color("5b3a22"))
	_cup = _mi(cb.build())
	_cup.position = Vector3(0, -0.29, -0.04)
	_cup.visible = false
	_arm_r.add_child(_cup)
	_bubble = Label3D.new()
	_bubble.text = "..."
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.font_size = 72
	_bubble.pixel_size = 0.0085
	_bubble.modulate = Color("ffffff")
	_bubble.outline_modulate = Color("14161c")
	_bubble.outline_size = 14
	_bubble.no_depth_test = true
	_bubble.position = Vector3(0.0, 1.22, 0.0)
	_bubble.visible = false
	add_child(_bubble)
	_pose(0.0)

func _mi(mesh: Mesh) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = MeshBuilder.material("worker")
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m

func _limb(parent: Node3D, pos: Vector3, mesh: Mesh) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	n.add_child(_mi(mesh))
	return n

# ───────────── malhas (cache por estilo) ─────────────

static func _torso_mesh(key: String, skin_i: int, hair_i: int, look: Dictionary) -> Mesh:
	var k := "t|" + key
	if _meshes.has(k):
		return _meshes[k]
	var b := MeshBuilder.new()
	var shirt: Color = look.shirt
	var prof_id := key.get_slice("|", 0)
	b.box(Vector3(0, -0.02, 0), Vector3(0.23, 0.12, 0.16), look.pants)               # pélvis
	if prof_id == "researcher":
		b.box(Vector3(0, 0.0, 0), Vector3(0.28, 0.5, 0.18), shirt, 0.0, 0.18)       # jaleco comprido
		b.box(Vector3(0, 0.12, -0.092), Vector3(0.05, 0.2, 0.01), Color("2fa59a"))  # crachá/faixa
	else:
		b.box(Vector3(0, 0.16, 0), Vector3(0.26, 0.30, 0.17), shirt)
	match prof_id:
		"engineer":
			b.box(Vector3(0, 0.17, -0.005), Vector3(0.275, 0.26, 0.18), look.extra)  # colete
			b.box(Vector3(0, 0.15, -0.092), Vector3(0.27, 0.035, 0.012), Color("e9ecf2"))  # faixa refletiva
		"programmer":
			b.box(Vector3(0, 0.30, 0.07), Vector3(0.2, 0.08, 0.08), shirt.darkened(0.2))  # capuz
			b.box(Vector3(0, 0.12, -0.092), Vector3(0.1, 0.04, 0.012), look.extra)         # logo
		"designer":
			b.box(Vector3(0, 0.25, -0.088), Vector3(0.26, 0.06, 0.02), look.extra)         # lenço
	_meshes[k] = b.build()
	return _meshes[k]

static func _head_mesh(key: String, skin_i: int, hair_i: int, look: Dictionary) -> Mesh:
	var k := "h|" + key
	if _meshes.has(k):
		return _meshes[k]
	var b := MeshBuilder.new()
	var skin: Color = SKIN[skin_i]
	var hair: Color = HAIR[hair_i]
	var prof_id := key.get_slice("|", 0)
	b.box(Vector3(0, 0.0, 0), Vector3(0.07, 0.04, 0.07), skin.darkened(0.08))          # pescoço
	b.box(Vector3(0, 0.12, 0), Vector3(0.21, 0.21, 0.20), skin, 0.0, 0.0)
	b.box(Vector3(-0.05, 0.135, -0.101), Vector3(0.028, 0.034, 0.008), Color("1c1c24"), 0.0, 0.0)  # olhos
	b.box(Vector3(0.05, 0.135, -0.101), Vector3(0.028, 0.034, 0.008), Color("1c1c24"), 0.0, 0.0)
	b.box(Vector3(0, 0.085, -0.101), Vector3(0.05, 0.012, 0.008), skin.darkened(0.3), 0.0, 0.0)   # boca
	match prof_id:
		"engineer":
			b.prism(Vector3(0, 0.235, 0), 0.125, 0.07, 8, Color("ffd23f"))             # capacete
			b.box(Vector3(0, 0.215, -0.1), Vector3(0.21, 0.02, 0.07), Color("e6b800"))
		"programmer":
			b.box(Vector3(0, 0.235, 0.0), Vector3(0.22, 0.06, 0.21), hair)
			b.box(Vector3(0, 0.138, -0.106), Vector3(0.19, 0.012, 0.004), Color("5aa9ff"))  # óculos
			b.box(Vector3(-0.075, 0.138, -0.106), Vector3(0.07, 0.05, 0.004), Color(0.35, 0.66, 1.0, 1.0))
			b.box(Vector3(0.075, 0.138, -0.106), Vector3(0.07, 0.05, 0.004), Color(0.35, 0.66, 1.0, 1.0))
		"designer":
			b.box(Vector3(0, 0.235, 0.0), Vector3(0.23, 0.07, 0.22), look.extra)       # cabelo roxo
			b.box(Vector3(0, 0.14, 0.11), Vector3(0.23, 0.2, 0.05), look.extra)        # franja/trás
			b.box(Vector3(0.085, 0.16, 0.0), Vector3(0.05, 0.16, 0.2), look.extra)
		"researcher":
			b.box(Vector3(0, 0.235, 0.0), Vector3(0.22, 0.06, 0.21), hair)
			b.box(Vector3(0, 0.138, -0.106), Vector3(0.17, 0.01, 0.004), Color("2a2a30"))
			b.box(Vector3(-0.065, 0.138, -0.106), Vector3(0.06, 0.045, 0.004), Color(0.9, 0.95, 1.0, 1.0))
			b.box(Vector3(0.065, 0.138, -0.106), Vector3(0.06, 0.045, 0.004), Color(0.9, 0.95, 1.0, 1.0))
	_meshes[k] = b.build()
	return _meshes[k]

static func _arm_mesh(key: String, skin_i: int, look: Dictionary) -> Mesh:
	var k := "a|" + key
	if _meshes.has(k):
		return _meshes[k]
	var b := MeshBuilder.new()
	var prof_id := key.get_slice("|", 0)
	var sleeve: Color = look.shirt if prof_id != "engineer" else look.shirt
	b.box(Vector3(0, -0.085, 0), Vector3(0.075, 0.17, 0.075), sleeve)
	b.box(Vector3(0, -0.225, 0), Vector3(0.062, 0.11, 0.062), SKIN[skin_i], 0.0, 0.0)
	_meshes[k] = b.build()
	return _meshes[k]

static func _thigh_mesh(key: String, look: Dictionary) -> Mesh:
	var k := "l|" + key
	if _meshes.has(k):
		return _meshes[k]
	var b := MeshBuilder.new()
	b.box(Vector3(0, -0.1, 0), Vector3(0.095, 0.21, 0.105), look.pants)
	_meshes[k] = b.build()
	return _meshes[k]

static func _shin_mesh(key: String, look: Dictionary) -> Mesh:
	var k := "s|" + key
	if _meshes.has(k):
		return _meshes[k]
	var b := MeshBuilder.new()
	b.box(Vector3(0, -0.115, 0), Vector3(0.088, 0.23, 0.095), look.pants)
	b.box(Vector3(0, -0.255, -0.022), Vector3(0.094, 0.055, 0.15), look.shoe)
	_meshes[k] = b.build()
	return _meshes[k]

# ───────────── comandos ─────────────

func place_seated(s: Dictionary) -> void:
	seat = s
	position = s.pos
	yaw_target = float(s.yaw)
	rotation.y = yaw_target
	mode = "work"
	kind = "work"
	sit_t = 1.0
	_seat_kind = true
	walk_amt = 0.0
	path = []
	partner = null
	_cup.visible = false
	_bubble.visible = false

## Rota até um ponto de pausa/conversa; ao chegar fica `time` segundos e volta por `back`.
func go_spot(route: Array, sp: Dictionary, time: float, back: Array, k: String) -> void:
	spot = sp
	spot_time = time
	return_path = back
	kind = k
	_start(route, "spot")

func go_seat(route: Array) -> void:
	kind = "work"
	_start(route, "seat")

## Rota de chegada (recém-contratado) ou de saída (demitido).
func go_path(route: Array, then: String) -> void:
	kind = "enter" if then == "seat" else "leave"
	_start(route, then)

func _start(route: Array, then: String) -> void:
	path = route
	path_i = 1 if route.size() > 1 and (route[0] as Vector3).distance_to(position) < 0.05 else 0
	after = then
	if sit_t > 0.05:
		mode = "standing_up"
	else:
		mode = "walking"

## Em pé parado (vendedores e clientes da loja).
func place_standing(pos: Vector3, yaw: float) -> void:
	position = pos
	yaw_target = yaw
	rotation.y = yaw
	mode = "stand"
	kind = "work"
	sit_t = 0.0
	walk_amt = 0.0

func is_away() -> bool:
	return mode != "work"

func status_text() -> String:
	match kind:
		"break": return "Pausa"
		"chat": return "Conversando"
		"enter": return "Chegando"
		"leave": return "Saindo"
	return "Ativo" if mode == "work" else "Caminhando"

func head_point() -> Vector3:
	return global_position + Vector3(0, 0.95 if sit_t < 0.5 else 0.82, 0)

# ───────────── animação ─────────────

func tick(dt: float, now: float) -> void:
	_t = now
	match mode:
		"work":
			sit_t = minf(1.0, sit_t + dt * 3.0)
			walk_amt = move_toward(walk_amt, 0.0, dt * 6.0)
			event_timer -= dt
		"stand":
			sit_t = maxf(0.0, sit_t - dt * 3.0)
			walk_amt = move_toward(walk_amt, 0.0, dt * 6.0)
		"standing_up":
			sit_t = maxf(0.0, sit_t - dt * 2.8)
			if sit_t <= 0.0:
				mode = "walking"
		"walking":
			sit_t = maxf(0.0, sit_t - dt * 3.0)
			walk_amt = move_toward(walk_amt, 1.0, dt * 6.0)
			_walk(dt)
		"sitting_down":
			sit_t = minf(1.0, sit_t + dt * 2.8)
			walk_amt = move_toward(walk_amt, 0.0, dt * 6.0)
			if sit_t >= 1.0:
				if after == "seat":
					mode = "work"
					kind = "work"
					event_timer = randf_range(18.0, 50.0)
				else:
					mode = "at_spot"
		"at_spot":
			walk_amt = move_toward(walk_amt, 0.0, dt * 6.0)
			if bool(spot.get("sit", false)):
				sit_t = minf(1.0, sit_t + dt * 3.0)
			spot_time -= dt
			if spot_time <= 0.0:
				var back := return_path
				_start(back, "seat")
	_bubble.visible = kind == "chat" and mode == "at_spot" and _speaking()
	_cup.visible = kind == "break" and mode == "at_spot" and str(spot.get("tag", "")) != "cooler"
	if mode != "gone":
		rotation.y = lerp_angle(rotation.y, yaw_target, minf(1.0, dt * 9.0))
	_pose(dt)

func _speaking() -> bool:
	return fmod(_t * 0.5 + speak_offset, 2.0) < 1.0

func _walk(dt: float) -> void:
	if path_i >= path.size():
		_arrive()
		return
	var target: Vector3 = path[path_i]
	var d := Vector3(target.x - position.x, 0.0, target.z - position.z)
	var dist := d.length()
	var step := WALK_SPEED * dt
	walk_phase += dt * 9.0
	if dist <= step:
		position.x = target.x
		position.z = target.z
		path_i += 1
		if path_i >= path.size():
			_arrive()
	else:
		position += d / dist * step
		yaw_target = atan2(-d.x, -d.z)

func _arrive() -> void:
	match after:
		"spot":
			yaw_target = float(spot.yaw)
			rotation.y = yaw_target
			mode = "sitting_down" if bool(spot.get("sit", false)) else "at_spot"
			if mode == "sitting_down":
				after = "spot"
		"seat":
			yaw_target = float(seat.yaw)
			rotation.y = yaw_target
			mode = "sitting_down"
		"leave":
			mode = "gone"
			flag_gone = true
			visible = false

func _pose(dt: float) -> void:
	var s := smoothstep(0.0, 1.0, sit_t)
	var swing := sin(walk_phase) * walk_amt
	var typing := 1.0 if (mode == "work" and kind != "break") else 0.0
	var t := _t + _ph
	# quadril e pernas
	var bob := absf(sin(walk_phase)) * 0.02 * walk_amt
	_hip.position.y = lerpf(HIP_STAND, HIP_SIT, s) + bob
	var th := deg_to_rad(38.0) * swing
	_leg_l.rotation.x = lerpf(th, deg_to_rad(90.0), s)
	_leg_r.rotation.x = lerpf(-th, deg_to_rad(90.0), s)
	_knee_l.rotation.x = lerpf(-deg_to_rad(30.0) * maxf(0.0, -swing), -deg_to_rad(90.0), s)
	_knee_r.rotation.x = lerpf(-deg_to_rad(30.0) * maxf(0.0, swing), -deg_to_rad(90.0), s)
	# braços
	var al := -swing * 0.55
	var ar := swing * 0.55
	var arz_r := 0.05
	if mode == "at_spot":
		if kind == "chat":
			var talking := _speaking()
			ar = deg_to_rad(-30.0) + (sin(t * 6.0) * 0.35 if talking else 0.0)
			arz_r = -0.25 if talking else 0.05
			al = deg_to_rad(-12.0) + (sin(t * 4.3) * 0.15 if talking else 0.0)
		elif kind == "break":
			var sip := smoothstep(0.55, 0.9, 0.5 + 0.5 * sin(t * 0.9))
			ar = lerpf(deg_to_rad(-20.0), deg_to_rad(105.0), sip)
			al = deg_to_rad(-8.0)
	var work_x := deg_to_rad(80.0)
	_arm_l.rotation.x = lerpf(al, work_x + sin(t * 13.0) * 0.07 * typing, s * typing + (1.0 - typing) * s * 0.35)
	_arm_r.rotation.x = lerpf(ar, work_x + sin(t * 17.0 + 1.3) * 0.07 * typing, s * typing + (1.0 - typing) * s * 0.35)
	_arm_r.rotation.z = arz_r
	_arm_l.rotation.z = -0.05
	# tronco e cabeça
	_upper.rotation.x = -0.14 * s * typing + sin(t * 0.5) * 0.012
	_head.rotation.x = sin(t * 0.8) * 0.04 + 0.06 * s * typing
	var look := 0.0
	if mode == "work":
		look = sin(t * 0.23) * 0.5 * (1.0 if sin(t * 0.11) > 0.6 else 0.0)
	elif mode == "at_spot" and kind == "chat":
		look = sin(t * 1.3) * 0.12
	_head.rotation.y = look
