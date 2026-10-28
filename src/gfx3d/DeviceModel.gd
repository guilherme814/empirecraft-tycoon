class_name DeviceModel
extends Node3D
## Modelo 3D procedural de um dispositivo. As especificações escolhidas mudam a forma:
##   Bateria -> espessura, Tela -> moldura, Câmera -> nº de lentes, Térmica -> aberturas,
##   Desempenho -> brilho do núcleo/logo, Design/Sensores/Armazenamento/Áudio -> detalhes.
## O acabamento (cor/metal) sobe de nível conforme a qualidade em relação ao mercado.

const TIER_COLORS := [Color("5d6472"), Color("4b73b0"), Color("cfd4de"), Color("2d313c"), Color("dcae4f")]
const TIER_METAL := [0.15, 0.45, 0.85, 0.7, 0.9]
const TIER_ROUGH := [0.65, 0.40, 0.28, 0.30, 0.22]
const ACCENT := Color("ff9a2e")
const APP_COLORS := [Color("ff9a2e"), Color("4cd18a"), Color("5aa9ff"), Color("ff5d6c"), Color("c792ea")]

var _tier: int = 1
var _design: Dictionary = {}
var _cat: String = "phone"

## Distância de câmera sugerida para enquadrar cada categoria.
static func camera_distance(cat: String) -> float:
	match cat:
		"watch": return 3.5
		"laptop": return 4.1
		"console": return 3.6
		_: return 3.1

static func tier_for(ratio: float) -> int:
	if ratio < 0.8: return 0
	if ratio < 1.1: return 1
	if ratio < 1.5: return 2
	if ratio < 2.0: return 3
	return 4

func build(cat: String, specs: Dictionary, quality_ratio: float, design: Dictionary = {}) -> void:
	_design = design
	_cat = cat
	scale = Vector3.ONE
	rotation_degrees = Vector3.ZERO
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()
	_tier = tier_for(quality_ratio)
	match cat:
		"laptop": _laptop(specs)
		"watch": _watch(specs)
		"console": _console(specs)
		_: _phone(specs)

# ───────── utilidades ─────────

func _f(s: Dictionary, axis: String) -> float:
	return clampf(float(s.get(axis, 40)) / 100.0, 0.0, 1.0)

## Fator de medida (1-9 -> 0.80-1.20).
func _dm(key: String) -> float:
	return 0.8 + 0.05 * (float(_design.get(key, 5)) - 1.0)

func _shape() -> String:
	return str(_design.get("shape", "classic"))

func _color_of(id: String, fallback: Color) -> Color:
	for c in GameData.designs().colors:
		if c.id == id:
			return Color(str(c.hex))
	return fallback

func _body_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if _design.is_empty():
		m.albedo_color = TIER_COLORS[_tier]
		m.metallic = TIER_METAL[_tier]
		m.roughness = TIER_ROUGH[_tier]
		return m
	var metal := 0.5
	var rough := 0.4
	for f in GameData.designs().finishes:
		if f.id == str(_design.get("finish", "alu")):
			metal = float(f.metal)
			rough = float(f.rough)
	m.albedo_color = _color_of(str(_design.get("color", "graphite")), TIER_COLORS[_tier])
	m.metallic = metal
	m.roughness = rough
	return m

func _corner(base: float) -> float:
	return base * (0.45 + 0.11 * float(_design.get("corner", 5)))

## Pontinhos verdes no verso: um por recurso extra escolhido.
func _feature_dots(parent: Node3D, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var feats: Array = _design.get("features", [])
	for i in feats.size():
		_add(parent, _cyl(0.022, 0.01, 10), _glow_mat(Color("4cd18a"), 1.4), pos + Vector3(float(i) * 0.06, 0, 0), rot)

func _dark_mat(rough: float = 0.35) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.03, 0.035, 0.045)
	m.metallic = 0.4
	m.roughness = rough
	return m

func _glow_mat(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color.darkened(0.7)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m

func _screen_mat(display: float) -> StandardMaterial3D:
	var base := Color(0.12, 0.30, 0.62).lerp(Color(0.25, 0.55, 1.0), display)
	if _design.has("accent"):
		base = Color(str(_design.accent)).darkened(0.25).lerp(Color(str(_design.accent)), display)
	return _glow_mat(base, 0.55 + 0.5 * display)

func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO,
		rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

func _cyl(radius: float, height: float, segs: int = 20) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = segs
	c.rings = 1
	return c

# ───────── smartphone ─────────

func _phone(s: Dictionary) -> void:
	var w := 0.74 * _dm("w")
	var h := 1.5 * _dm("h")
	var t: float = lerpf(0.07, 0.13, _f(s, "battery")) * _dm("d")
	var shape := _shape()
	if shape == "slim":
		t *= 0.7
	var rad := _corner(0.11) + (0.03 if shape == "edge" else 0.0)
	var phone_body := _add(self, RoundedSlab.build(w, h, t, rad, 0.014), _body_mat())
	var bezel: float = lerpf(0.07, 0.022, _f(s, "display")) * (0.45 if shape == "edge" else 1.0)
	var sw := w - bezel * 2.0
	var sh := h - bezel * 2.4
	var z := t * 0.5 + 0.003
	if shape == "fold":
		_add(self, _box(Vector3(w * 0.98, 0.012, t + 0.02)), _dark_mat(0.5), Vector3(0, 0, 0))
		_add(self, _box(Vector3(sw, 0.01, 0.01)), _dark_mat(0.8), Vector3(0, 0, z + 0.008))
	_add(self, RoundedSlab.build(sw, sh, 0.006, maxf(0.025, 0.095 - bezel * 0.6), 0.002), _screen_mat(_f(s, "display")), Vector3(0, 0, z))
	# "aplicativos" na tela
	var icon_size := sw * 0.17
	for ry in 5:
		for cx in 4:
			var col: Color = APP_COLORS[(ry * 4 + cx) % APP_COLORS.size()]
			var px := (float(cx) - 1.5) * sw * 0.23
			var py := sh * 0.5 - sh * 0.14 - float(ry) * sh * 0.14
			_add(self, RoundedSlab.build(icon_size, icon_size, 0.004, icon_size * 0.28, 0.001, 3), _glow_mat(col, 0.9), Vector3(px, py, z + 0.005))
	# câmera traseira
	var lenses: int = 1 + int(_f(s, "camera") * 3.99)
	var plate_w := 0.30 if lenses <= 2 else 0.38
	var plate_h := 0.16 + 0.16 * float(mini(lenses, 4) > 2) + 0.14 * float(lenses >= 2)
	var cx0 := -w * 0.5 + 0.26
	var cy0 := h * 0.5 - 0.26
	var zb := -t * 0.5 - 0.012
	_add(self, RoundedSlab.build(plate_w, plate_h, 0.024, 0.07, 0.004), _dark_mat(0.5), Vector3(cx0, cy0 - (plate_h - 0.3) * 0.5, zb))
	var offs := [Vector2(-0.07, 0.06), Vector2(0.07, 0.06), Vector2(-0.07, -0.08), Vector2(0.07, -0.08)]
	if lenses == 1:
		offs = [Vector2(0, 0)]
	elif lenses == 2:
		offs = [Vector2(0, 0.07), Vector2(0, -0.07)]
	for i in lenses:
		var o: Vector2 = offs[i]
		var lp := Vector3(cx0 + o.x, cy0 + o.y - (plate_h - 0.3) * 0.5, zb - 0.02)
		_add(self, _cyl(0.062, 0.016), _body_mat(), lp, Vector3(90, 0, 0))
		_add(self, _cyl(0.046, 0.02), _glow_mat(Color(0.2, 0.3, 0.9), 0.4), lp + Vector3(0, 0, -0.004), Vector3(90, 0, 0))
	# faixa de desempenho (brilho)
	_add(self, RoundedSlab.build(0.34, 0.03, 0.004, 0.012, 0.001, 3), _glow_mat(ACCENT, 0.4 + 2.2 * _f(s, "performance")),
		Vector3(0, -0.35, -t * 0.5 - 0.003))
	_feature_dots(self, Vector3(-0.15, -0.55, -t * 0.5 - 0.006), Vector3(90, 0, 0))

# ───────── smartwatch ─────────

func _watch(s: Dictionary) -> void:
	var shape := _shape()
	var t: float = lerpf(0.20, 0.32, _f(s, "battery")) * _dm("d") * (1.3 if shape == "sport" else 1.0)
	var design := _f(s, "design")
	var cw := 0.82 * _dm("w")
	var ch := 0.98 * _dm("h")
	var srad := 0.49 * minf(cw, ch) if shape == "round" else _corner(0.27)
	var strap_w := 0.58 * (0.7 + 0.06 * float(_design.get("strap", 5)))
	var strap_col := Color("2a2f3d").lerp(ACCENT, design)
	if not _design.is_empty():
		strap_col = _color_of(str(_design.get("color", "graphite")), strap_col).darkened(0.25)
	if shape == "sport":
		strap_col = ACCENT
	var strap := _glow_mat(strap_col, 0.0)
	strap.emission_enabled = false
	strap.albedo_color = strap_col
	strap.roughness = 0.7
	for sgn in [1.0, -1.0]:
		var piece := _add(self, RoundedSlab.build(strap_w, 0.85, 0.05, 0.05, 0.008), strap, Vector3(0, sgn * 0.78, -0.02))
		piece.rotation_degrees = Vector3(-sgn * 12.0, 0, 0)
	_add(self, RoundedSlab.build(cw, ch, t, srad, 0.02, 7), _body_mat())
	var bezel: float = lerpf(0.09, 0.03, _f(s, "display"))
	_add(self, RoundedSlab.build(cw - bezel * 2.0, ch - bezel * 2.0, 0.006, maxf(0.05, srad - bezel * 0.8), 0.002, 6), _screen_mat(_f(s, "display")),
		Vector3(0, 0, t * 0.5 + 0.003))
	# mostrador: anel de atividade
	var ring := TorusMesh.new()
	ring.inner_radius = 0.17
	ring.outer_radius = 0.2
	_add(self, ring, _glow_mat(ACCENT, 1.4), Vector3(0, 0.05, t * 0.5 + 0.009), Vector3(90, 0, 0))
	_add(self, _cyl(0.05, 0.012), _glow_mat(Color("4cd18a"), 1.2), Vector3(0, 0.05, t * 0.5 + 0.009), Vector3(90, 0, 0))
	_add(self, RoundedSlab.build(0.3, 0.05, 0.006, 0.02, 0.001, 3), _glow_mat(Color("5aa9ff"), 1.0), Vector3(0, -0.28, t * 0.5 + 0.008))
	# coroa
	_add(self, _cyl(0.07, 0.07), _body_mat(), Vector3(0.45, 0.18, 0), Vector3(0, 0, 90))
	# sensores no verso
	var sensors: int = 1 + int(_f(s, "sensors") * 3.99)
	for i in sensors:
		var ang := TAU * float(i) / float(maxi(sensors, 2)) + 0.4
		_add(self, _cyl(0.06, 0.02), _glow_mat(Color("4cd18a"), 1.3),
			Vector3(cos(ang) * 0.18, sin(ang) * 0.18, -t * 0.5 - 0.012), Vector3(90, 0, 0))
	_feature_dots(self, Vector3(-0.2, -0.36, -t * 0.5 - 0.02), Vector3(90, 0, 0))

# ───────── notebook ─────────

func _laptop(s: Dictionary) -> void:
	var w := 1.7 * _dm("w")
	var d := 1.15 * _dm("h")
	var shape := _shape()
	var t: float = lerpf(0.06, 0.12, _f(s, "battery")) * _dm("d") * (0.6 if shape == "thin" else 1.0)
	var flat := Node3D.new()
	flat.rotation_degrees = Vector3(-90, 0, 0)
	flat.position = Vector3(0, -0.45, 0)
	add_child(flat)
	_add(flat, RoundedSlab.build(w, d, t, _corner(0.07), 0.01), _body_mat())
	var top := -0.45 + t * 0.5
	# teclado
	var keys := MultiMesh.new()
	keys.transform_format = MultiMesh.TRANSFORM_3D
	keys.mesh = _box(Vector3(0.09, 0.012, 0.09))
	var cols := 14
	var rows := 5
	keys.instance_count = cols * rows
	for r in rows:
		for c in cols:
			var p := Vector3((float(c) - float(cols - 1) * 0.5) * 0.108, top + 0.005, -0.28 + float(r) * 0.108 - 0.05)
			keys.set_instance_transform(r * cols + c, Transform3D(Basis(), p))
	var kmi := MultiMeshInstance3D.new()
	kmi.multimesh = keys
	kmi.material_override = _dark_mat(0.6)
	add_child(kmi)
	_add(self, RoundedSlab.build(0.6, 0.38, 0.004, 0.03, 0.001, 3), _dark_mat(0.25), Vector3(0, top + 0.002, 0.42), Vector3(-90, 0, 0))
	# aberturas de ventilação (Térmica)
	var vents: int = 3 + int(_f(s, "thermal") * 6.0)
	for i in vents:
		_add(self, _box(Vector3(0.05, 0.006, 0.012)), _dark_mat(), Vector3(-0.55 + float(i) * 0.036, top + 0.003, -0.37))
	# portas laterais (Armazenamento)
	var ports: int = 1 + int(_f(s, "storage") * 2.99)
	for i in ports:
		_add(self, _box(Vector3(0.012, 0.025, 0.07)), _dark_mat(), Vector3(-w * 0.5, -0.45 + 0.0, 0.1 - float(i) * 0.15))
	# tampa
	var hinge := Node3D.new()
	hinge.position = Vector3(0, top, -d * 0.5 + 0.02)
	hinge.rotation_degrees = Vector3(-62 if shape == "convert" else -14, 0, 0)
	add_child(hinge)
	var lid_h := 1.1
	_add(hinge, RoundedSlab.build(w, lid_h, 0.05, 0.07, 0.008), _body_mat(), Vector3(0, lid_h * 0.5, 0))
	var bezel: float = lerpf(0.09, 0.025, _f(s, "display"))
	_add(hinge, RoundedSlab.build(w - bezel * 2.0, lid_h - bezel * 2.0, 0.006, 0.04, 0.002, 4), _screen_mat(_f(s, "display")),
		Vector3(0, lid_h * 0.5, 0.028))
	for i in 3:
		_add(hinge, RoundedSlab.build(w * 0.22, 0.05, 0.004, 0.02, 0.001, 3), _glow_mat(APP_COLORS[i], 0.9),
			Vector3(-0.35 + float(i) * 0.35, lid_h * 0.5 + 0.1, 0.034))
	# logo (Desempenho)
	_add(hinge, _cyl(0.11, 0.008, 24), _glow_mat(ACCENT, 0.4 + 2.2 * _f(s, "performance")), Vector3(0, lid_h * 0.5, -0.03), Vector3(90, 0, 0))
	_feature_dots(hinge, Vector3(-0.3, lid_h * 0.5 - 0.25, -0.034), Vector3(90, 0, 0))

# ───────── console ─────────

func _console(s: Dictionary) -> void:
	var w := 1.7 * _dm("w")
	var d := 1.05 * _dm("h")
	var shape := _shape()
	var ht: float = lerpf(0.22, 0.40, _f(s, "thermal")) * _dm("d")
	if shape == "compact":
		scale = Vector3.ONE * 0.8
	elif shape == "tower":
		rotation_degrees = Vector3(0, 0, 90)
		scale = Vector3.ONE * 0.9
	var flat := Node3D.new()
	flat.rotation_degrees = Vector3(-90, 0, 0)
	add_child(flat)
	_add(flat, RoundedSlab.build(w, d, ht, _corner(0.14), 0.02, 8), _body_mat())
	var top := ht * 0.5
	# aberturas de ventilação
	var slits: int = 4 + int(_f(s, "thermal") * 7.0)
	for i in slits:
		_add(self, _box(Vector3(0.62, 0.006, 0.02)), _dark_mat(), Vector3(-0.35, top + 0.003, -0.38 + float(i) * 0.062))
	# núcleo (Desempenho)
	var core := TorusMesh.new()
	core.inner_radius = 0.13
	core.outer_radius = 0.19
	_add(self, core, _glow_mat(ACCENT, 0.4 + 2.4 * _f(s, "performance")), Vector3(0.48, top + 0.008, -0.05))
	_add(self, _cyl(0.07, 0.006), _glow_mat(ACCENT, 0.3 + 1.6 * _f(s, "performance")), Vector3(0.48, top + 0.005, -0.05))
	# faixa de LED frontal (Gráficos)
	var led := Color("5aa9ff").lerp(Color("c792ea"), _f(s, "graphics"))
	_add(self, _box(Vector3(w * 0.62, 0.02, 0.012)), _glow_mat(led, 1.5), Vector3(0, ht * 0.18, d * 0.5 + 0.002))
	_add(self, _box(Vector3(0.9, 0.034, 0.012)), _dark_mat(), Vector3(0.28, -ht * 0.12, d * 0.5 + 0.002))
	# alto-falantes (Áudio)
	var rows: int = 1 + int(_f(s, "audio") * 2.99)
	for r in rows:
		for c in 5:
			_add(self, _cyl(0.016, 0.006, 10), _dark_mat(), Vector3(0.12 + float(c) * 0.06, top + 0.003, 0.3 - float(r) * 0.06))
	# baias (Armazenamento)
	var bays: int = 1 + int(_f(s, "storage") * 2.99)
	for i in bays:
		_add(self, _box(Vector3(0.1, 0.03, 0.012)), _glow_mat(Color("4cd18a"), 0.9), Vector3(-0.72 + float(i) * 0.14, -ht * 0.12, d * 0.5 + 0.002))
	_feature_dots(self, Vector3(-0.6, top + 0.01, 0.35))
