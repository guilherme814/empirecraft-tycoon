class_name DeviceModel
extends Node3D
## Modelo 3D procedural de um dispositivo. As especificações escolhidas mudam a forma:
##   Bateria -> espessura, Tela -> moldura, Câmera -> nº de lentes, Térmica -> aberturas,
##   Desempenho -> brilho do núcleo/logo, Design/Sensores/Armazenamento/Áudio -> detalhes.
## O design (formato, medidas, acabamento, cores, papel de parede, câmera, pulseira, LED) vem de `design`.
## Sem design, o acabamento sobe de nível conforme a qualidade em relação ao mercado.

const TIER_COLORS := [Color("5d6472"), Color("4b73b0"), Color("cfd4de"), Color("2d313c"), Color("dcae4f")]
const TIER_METAL := [0.15, 0.45, 0.85, 0.7, 0.9]
const TIER_ROUGH := [0.65, 0.40, 0.28, 0.30, 0.22]
const ACCENT := Color("ff9a2e")
const APP_COLORS := [Color("ff9a2e"), Color("4cd18a"), Color("5aa9ff"), Color("ff5d6c"), Color("c792ea")]

static var _wall_cache: Dictionary = {}
static var _font: Font = null

var _tier: int = 1
var _design: Dictionary = {}
var _cat: String = "phone"
var floor_y: float = -0.8   # altura do "chão" para a sombra de contato

## Distância de câmera sugerida para enquadrar cada categoria.
static func camera_distance(cat: String) -> float:
	match cat:
		"watch": return 3.6
		"laptop": return 4.2
		"console": return 4.1
		_: return 3.2

static func tier_for(ratio: float) -> int:
	if ratio < 0.8: return 0
	if ratio < 1.1: return 1
	if ratio < 1.5: return 2
	if ratio < 2.0: return 3
	return 4

func build(cat: String, specs: Dictionary, quality_ratio: float, design: Dictionary = {}) -> void:
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()
	_design = design
	_cat = cat
	scale = Vector3.ONE
	rotation_degrees = Vector3.ZERO
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

func _opt(key: String, fallback: String) -> String:
	return str(_design.get(key, fallback))

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

func _trim_color() -> Color:
	return _color_of(_opt("trim", "silver"), Color("cfd4de"))

func _trim_mat(rough: float = 0.3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = _trim_color()
	m.metallic = 0.8
	m.roughness = rough
	return m

func _corner(base: float) -> float:
	return base * (0.45 + 0.11 * float(_design.get("corner", 5)))

func _has_feature(id: String) -> bool:
	return (_design.get("features", []) as Array).has(id)

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

func _wall_texture() -> GradientTexture2D:
	var id := _opt("wall", "aurora")
	if _wall_cache.has(id):
		return _wall_cache[id]
	var c1 := Color("1b2a6b")
	var c2 := Color("2fd1b4")
	for w in GameData.designs().wallpapers:
		if w.id == id:
			c1 = Color(str(w.c1))
			c2 = Color(str(w.c2))
	var g := Gradient.new()
	g.set_color(0, c1)
	g.set_color(1, c2)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.15, 0.0)
	t.fill_to = Vector2(0.85, 1.0)
	t.width = 128
	t.height = 128
	_wall_cache[id] = t
	return t

func _screen_mat(display: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var tex := _wall_texture()
	m.albedo_texture = tex
	m.albedo_color = Color(0.5, 0.5, 0.55)
	m.emission_enabled = true
	m.emission_texture = tex
	m.emission_energy_multiplier = 0.55 + 0.6 * display
	if _design.has("accent"):
		m.albedo_color = Color(str(_design.accent)).darkened(0.2)
		m.emission_texture = null
		m.emission = Color(str(_design.accent)).darkened(0.1)
	m.roughness = 0.2
	return m

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

func _text(parent: Node3D, text: String, size_px: float, color: Color, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> Label3D:
	if _font == null:
		_font = load("res://assets/fonts/Poppins-Regular.ttf") as Font
	var l := Label3D.new()
	l.text = text
	l.font = _font
	l.font_size = 64
	l.pixel_size = size_px / 64.0
	l.modulate = color
	l.shaded = false
	l.double_sided = false
	l.position = pos
	l.rotation_degrees = rot_deg
	parent.add_child(l)
	return l

## Pontinhos verdes no verso: um por recurso extra escolhido.
func _feature_dots(parent: Node3D, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var feats: Array = _design.get("features", [])
	for i in feats.size():
		_add(parent, _cyl(0.022, 0.01, 10), _glow_mat(Color("4cd18a"), 1.4), pos + Vector3(float(i) * 0.06, 0, 0), rot)

func _brand_text() -> String:
	return str(_design.get("brand_name", "")).to_upper()

## Conteúdo da tela do telefone/relógio: relógio, ícones e barra de status.
func _screen_ui(parent: Node3D, sw: float, sh: float, z: float, big_clock: bool = true) -> void:
	var white := Color(1, 1, 1, 0.92)
	if big_clock:
		_text(parent, "9:41", sw * 0.28, white, Vector3(0, sh * 0.25, z + 0.004))
		_text(parent, "qua, 28 out", sw * 0.075, Color(1, 1, 1, 0.7), Vector3(0, sh * 0.25 - sw * 0.2, z + 0.004))
	# widget
	_add(parent, RoundedSlab.build(sw * 0.8, sh * 0.13, 0.004, 0.04, 0.001, 3), _glow_mat(Color(1, 1, 1), 0.35), Vector3(0, sh * 0.02, z + 0.003))
	# dock
	_add(parent, RoundedSlab.build(sw * 0.9, sh * 0.12, 0.004, 0.06, 0.001, 4), _glow_mat(Color(1, 1, 1), 0.25), Vector3(0, -sh * 0.4, z + 0.003))
	for i in 4:
		var col: Color = APP_COLORS[i % APP_COLORS.size()]
		_add(parent, RoundedSlab.build(sw * 0.17, sw * 0.17, 0.004, sw * 0.045, 0.001, 3), _glow_mat(col, 1.0),
			Vector3((float(i) - 1.5) * sw * 0.21, -sh * 0.4, z + 0.006))
	for r in 2:
		for i in 4:
			var col2: Color = APP_COLORS[(r * 4 + i + 2) % APP_COLORS.size()]
			_add(parent, RoundedSlab.build(sw * 0.17, sw * 0.17, 0.004, sw * 0.045, 0.001, 3), _glow_mat(col2, 0.9),
				Vector3((float(i) - 1.5) * sw * 0.21, -sh * 0.12 - float(r) * sw * 0.23, z + 0.006))
	# barra de status
	_add(parent, _box(Vector3(sw * 0.07, sw * 0.03, 0.004)), _glow_mat(Color(1, 1, 1), 0.9), Vector3(sw * 0.34, sh * 0.47, z + 0.005))

# ───────── smartphone ─────────

## Posições das lentes para cada layout de câmera (relativas ao centro da placa).
func _lens_layout(layout: String, n: int, w: float) -> Dictionary:
	match layout:
		"bar":
			return {"size": Vector2(w * 0.78, 0.22), "pos": _row(n, 0.17, true), "circle": false, "anchor": "top"}
		"circle":
			var ps: Array = []
			if n == 1:
				ps = [Vector2.ZERO]
			else:
				for i in n:
					var a := TAU * float(i) / float(n) + PI * 0.25
					ps.append(Vector2(cos(a), sin(a)) * 0.115)
			return {"size": Vector2(0.46, 0.46), "pos": ps, "circle": true, "anchor": "left"}
		"island":
			return {"size": Vector2(0.2, 0.12 + 0.17 * float(n)), "pos": _row(n, 0.17, false), "circle": false, "anchor": "left"}
		"grid":
			var gp: Array = [Vector2(-0.1, 0.1), Vector2(0.1, 0.1), Vector2(-0.1, -0.1), Vector2(0.1, -0.1)]
			return {"size": Vector2(0.44, 0.44), "pos": gp.slice(0, n), "circle": false, "anchor": "left"}
		_:
			if n == 1:
				return {"size": Vector2(0.3, 0.3), "pos": [Vector2.ZERO], "circle": false, "anchor": "left"}
			if n == 2:
				return {"size": Vector2(0.3, 0.46), "pos": [Vector2(0, 0.08), Vector2(0, -0.08)], "circle": false, "anchor": "left"}
			var tp: Array = [Vector2(-0.07, 0.07), Vector2(0.07, 0.07), Vector2(-0.07, -0.08), Vector2(0.07, -0.08)]
			return {"size": Vector2(0.38, 0.46), "pos": tp.slice(0, n), "circle": false, "anchor": "left"}

func _row(n: int, gap: float, horizontal: bool) -> Array:
	var out: Array = []
	for i in n:
		var o := (float(i) - float(n - 1) * 0.5) * gap
		out.append(Vector2(o, 0) if horizontal else Vector2(0, -o))
	return out

func _phone(s: Dictionary) -> void:
	var w := 0.74 * _dm("w")
	var h := 1.5 * _dm("h")
	var t: float = lerpf(0.07, 0.13, _f(s, "battery")) * _dm("d")
	var shape := _shape()
	if shape == "slim":
		t *= 0.7
	var rad := _corner(0.11) + (0.03 if shape == "edge" else 0.0)
	floor_y = -h * 0.5 - 0.02
	_add(self, RoundedSlab.build(w, h, t, rad, 0.014), _body_mat())
	var bezel: float = lerpf(0.07, 0.022, _f(s, "display")) * (0.45 if shape == "edge" else 1.0)
	var sw := w - bezel * 2.0
	var sh := h - bezel * 2.4
	var z := t * 0.5 + 0.003
	_add(self, RoundedSlab.build(sw, sh, 0.006, maxf(0.025, 0.095 - bezel * 0.6), 0.002), _screen_mat(_f(s, "display")), Vector3(0, 0, z))
	if shape == "fold":
		_add(self, _box(Vector3(w * 0.98, 0.012, t + 0.02)), _dark_mat(0.5), Vector3(0, 0, 0))
		_add(self, _box(Vector3(sw, 0.01, 0.01)), _dark_mat(0.8), Vector3(0, 0, z + 0.008))
	_screen_ui(self, sw, sh, z)
	# recorte da tela
	match _opt("notch", "punch"):
		"punch":
			_add(self, _cyl(0.022, 0.01, 14), _dark_mat(0.2), Vector3(0, sh * 0.5 - 0.06, z + 0.008), Vector3(90, 0, 0))
		"notch":
			_add(self, RoundedSlab.build(sw * 0.38, 0.075, 0.01, 0.03, 0.002, 4), _dark_mat(0.2), Vector3(0, sh * 0.5 - 0.035, z + 0.008))
		"island":
			_add(self, RoundedSlab.build(sw * 0.28, 0.06, 0.01, 0.03, 0.002, 4), _dark_mat(0.2), Vector3(0, sh * 0.5 - 0.06, z + 0.008))
	# botões laterais e porta
	_add(self, _box(Vector3(0.02, 0.2, t * 0.55)), _trim_mat(0.4), Vector3(w * 0.5 + 0.004, 0.25, 0))
	_add(self, _box(Vector3(0.02, 0.14, t * 0.55)), _trim_mat(0.4), Vector3(-w * 0.5 - 0.004, 0.3, 0))
	_add(self, _box(Vector3(0.02, 0.14, t * 0.55)), _trim_mat(0.4), Vector3(-w * 0.5 - 0.004, 0.1, 0))
	_add(self, RoundedSlab.build(0.1, 0.02, 0.02, 0.008, 0.001, 3), _dark_mat(), Vector3(0, -h * 0.5 - 0.003, 0), Vector3(90, 0, 0))
	for i in 4:
		_add(self, _cyl(0.008, 0.02, 8), _dark_mat(), Vector3(-0.2 + float(i) * 0.05 - 0.05, -h * 0.5 - 0.003, 0), Vector3(90, 0, 0))
	# antenas no verso
	for yy in [h * 0.5 - 0.1, -h * 0.5 + 0.1]:
		_add(self, _box(Vector3(w * 0.96, 0.008, 0.004)), _dark_mat(0.6), Vector3(0, yy, -t * 0.5 - 0.001))
	# câmera traseira
	var lenses: int = 1 + int(_f(s, "camera") * 3.99)
	var lay := _lens_layout(_opt("cam", "plate"), lenses, w)
	var psz: Vector2 = lay.size
	var anchor: String = lay.anchor
	var cx0 := (-w * 0.5 + psz.x * 0.5 + 0.1) if anchor == "left" else 0.0
	var cy0 := h * 0.5 - psz.y * 0.5 - 0.1
	var zb := -t * 0.5 - 0.012
	var plate_mesh: Mesh = RoundedSlab.build(psz.x, psz.y, 0.024, psz.x * 0.5 if bool(lay.circle) else 0.07, 0.004, 10 if bool(lay.circle) else 6)
	_add(self, plate_mesh, _trim_mat(0.35) if _opt("trim", "") != "" else _dark_mat(0.5), Vector3(cx0, cy0, zb))
	for o in lay.pos:
		var lp := Vector3(cx0 + (o as Vector2).x, cy0 + (o as Vector2).y, zb - 0.02)
		_add(self, _cyl(0.062, 0.016), _dark_mat(0.3), lp, Vector3(90, 0, 0))
		_add(self, _cyl(0.046, 0.02), _glow_mat(Color(0.2, 0.3, 0.9), 0.5), lp + Vector3(0, 0, -0.004), Vector3(90, 0, 0))
		_add(self, _cyl(0.014, 0.022), _glow_mat(Color(1, 1, 1), 0.9), lp + Vector3(0.02, 0.02, -0.012), Vector3(90, 0, 0))
	_add(self, _cyl(0.018, 0.016), _glow_mat(Color("fff2c0"), 1.2), Vector3(cx0 + psz.x * 0.5 + 0.06, cy0 + psz.y * 0.3, zb - 0.004), Vector3(90, 0, 0))
	# faixa de desempenho e marca
	_add(self, RoundedSlab.build(0.34, 0.03, 0.004, 0.012, 0.001, 3), _glow_mat(ACCENT, 0.4 + 2.2 * _f(s, "performance")),
		Vector3(0, -0.4, -t * 0.5 - 0.003))
	if bool(_design.get("brand", true)) and _brand_text() != "":
		_text(self, _brand_text(), 0.075, _trim_color(), Vector3(0, -0.12, -t * 0.5 - 0.004), Vector3(0, 180, 0))
	_feature_dots(self, Vector3(-0.15, -0.58, -t * 0.5 - 0.006), Vector3(90, 0, 0))

# ───────── smartwatch ─────────

func _watch(s: Dictionary) -> void:
	var shape := _shape()
	var t: float = lerpf(0.20, 0.32, _f(s, "battery")) * _dm("d") * (1.3 if shape == "sport" else 1.0)
	var cw := 0.82 * _dm("w")
	var ch := 0.98 * _dm("h")
	var srad := 0.49 * minf(cw, ch) if shape == "round" else _corner(0.27)
	var strap_w := 0.58 * (0.7 + 0.06 * float(_design.get("strap", 5)))
	var strap_col := _trim_color().darkened(0.15) if not _design.is_empty() else Color("2a2f3d").lerp(ACCENT, _f(s, "design"))
	var band := _opt("band", "silicone")
	floor_y = -1.78
	var strap := StandardMaterial3D.new()
	strap.albedo_color = strap_col
	strap.roughness = 0.7 if band == "silicone" else (0.45 if band == "leather" else 0.3)
	strap.metallic = 0.95 if band == "mesh" else 0.0
	if shape == "sport":
		strap.albedo_color = ACCENT
	for sgn in [1.0, -1.0]:
		var piece := _add(self, RoundedSlab.build(strap_w, 0.9, 0.05, 0.05, 0.008), strap, Vector3(0, sgn * 0.82, -0.02))
		piece.rotation_degrees = Vector3(-sgn * 12.0, 0, 0)
		var detail := _dark_mat(0.8)
		for i in 5:
			var yy: float = sgn * (0.62 + float(i) * 0.15)
			match band:
				"leather":
					_add(self, _box(Vector3(strap_w * 0.9, 0.006, 0.004)), _glow_mat(Color(0.9, 0.8, 0.6), 0.0), Vector3(0, yy, 0.012 - 0.02 * 0.0), Vector3(-sgn * 12.0, 0, 0))
				"mesh":
					_add(self, _box(Vector3(strap_w * 0.92, 0.008, 0.006)), _trim_mat(0.25), Vector3(0, yy, 0.0), Vector3(-sgn * 12.0, 0, 0))
				_:
					if sgn < 0.0 and i < 3:
						_add(self, _cyl(0.025, 0.02, 10), detail, Vector3(0, yy - 0.04, 0.012), Vector3(90 - sgn * 12.0, 0, 0))
	# fivela
	_add(self, _box(Vector3(strap_w * 1.02, 0.07, 0.05)), _trim_mat(0.3), Vector3(0, 0.62, -0.02), Vector3(-12, 0, 0))
	_add(self, RoundedSlab.build(cw, ch, t, srad, 0.02, 7), _body_mat())
	var bezel: float = lerpf(0.09, 0.03, _f(s, "display"))
	var sw := cw - bezel * 2.0
	var sh := ch - bezel * 2.0
	var z := t * 0.5 + 0.003
	_add(self, RoundedSlab.build(sw, sh, 0.006, maxf(0.05, srad - bezel * 0.8), 0.002, 6), _screen_mat(_f(s, "display")), Vector3(0, 0, z))
	# marcações do aro (redondo/esportivo)
	if shape == "round" or shape == "sport":
		for i in 12:
			var a := TAU * float(i) / 12.0
			_add(self, _box(Vector3(0.025, 0.05, 0.008)), _trim_mat(0.3), Vector3(cos(a) * (cw * 0.5 - 0.03), sin(a) * (ch * 0.5 - 0.03), z + 0.006), Vector3(0, 0, rad_to_deg(a) - 90.0))
	# mostrador
	_text(self, "10:09", sw * 0.3, Color(1, 1, 1, 0.95), Vector3(0, sh * 0.2, z + 0.006))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.11
	ring.outer_radius = 0.14
	_add(self, ring, _glow_mat(ACCENT, 1.4), Vector3(0, -sh * 0.12, z + 0.009), Vector3(90, 0, 0))
	_add(self, _cyl(0.04, 0.012), _glow_mat(Color("4cd18a"), 1.2), Vector3(0, -sh * 0.12, z + 0.009), Vector3(90, 0, 0))
	_add(self, RoundedSlab.build(sw * 0.5, 0.045, 0.006, 0.02, 0.001, 3), _glow_mat(Color("5aa9ff"), 1.0), Vector3(0, -sh * 0.38, z + 0.008))
	# coroa e botão
	_add(self, _cyl(0.07, 0.07), _trim_mat(0.3), Vector3(cw * 0.5 + 0.02, 0.18, 0), Vector3(0, 0, 90))
	_add(self, _box(Vector3(0.03, 0.14, 0.06)), _trim_mat(0.4), Vector3(cw * 0.5 + 0.01, -0.1, 0))
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
	floor_y = -0.5 - t * 0.5
	var flat := Node3D.new()
	flat.rotation_degrees = Vector3(-90, 0, 0)
	flat.position = Vector3(0, -0.45, 0)
	add_child(flat)
	_add(flat, RoundedSlab.build(w, d, t, _corner(0.07), 0.01), _body_mat())
	var top := -0.45 + t * 0.5
	# teclado
	var backlit := _has_feature("backlit")
	var led := _color_of(_opt("led", "blue"), Color("5aa9ff"))
	var keys := MultiMesh.new()
	keys.transform_format = MultiMesh.TRANSFORM_3D
	keys.mesh = _box(Vector3(0.09, 0.012, 0.09))
	var cols := 14
	var rows := 5
	keys.instance_count = cols * rows
	for r in rows:
		for c in cols:
			var p := Vector3((float(c) - float(cols - 1) * 0.5) * 0.108 * (w / 1.7), top + 0.005, -0.28 + float(r) * 0.108 - 0.05)
			keys.set_instance_transform(r * cols + c, Transform3D(Basis().scaled(Vector3(w / 1.7, 1, 1)), p))
	var kmi := MultiMeshInstance3D.new()
	kmi.multimesh = keys
	kmi.material_override = _glow_mat(led, 0.9) if backlit else _dark_mat(0.6)
	add_child(kmi)
	_add(self, RoundedSlab.build(0.6, 0.38, 0.004, 0.03, 0.001, 3), _dark_mat(0.25), Vector3(0, top + 0.002, 0.42), Vector3(-90, 0, 0))
	# aberturas de ventilação (Térmica)
	var vents: int = 3 + int(_f(s, "thermal") * 6.0)
	for i in vents:
		_add(self, _box(Vector3(0.05, 0.006, 0.012)), _dark_mat(), Vector3(-0.55 + float(i) * 0.036, top + 0.003, -0.37))
	# portas laterais (Armazenamento)
	var ports: int = 1 + int(_f(s, "storage") * 2.99)
	for i in ports:
		_add(self, _box(Vector3(0.012, 0.025, 0.07)), _dark_mat(), Vector3(-w * 0.5, -0.45, 0.1 - float(i) * 0.15))
	# pés de borracha
	for fx in [-1.0, 1.0]:
		for fz in [-1.0, 1.0]:
			_add(self, _cyl(0.04, 0.02, 10), _dark_mat(0.9), Vector3(fx * (w * 0.5 - 0.15), -0.45 - t * 0.5 - 0.008, fz * (d * 0.5 - 0.15)))
	# tampa
	var hinge := Node3D.new()
	hinge.position = Vector3(0, top, -d * 0.5 + 0.02)
	hinge.rotation_degrees = Vector3(-62 if shape == "convert" else -14, 0, 0)
	add_child(hinge)
	_add(hinge, _cyl(0.035, w * 0.9, 12), _trim_mat(0.4), Vector3(0, 0, 0), Vector3(0, 0, 90))
	var lid_h := 1.1 * (d / 1.15)
	_add(hinge, RoundedSlab.build(w, lid_h, 0.05, 0.07, 0.008), _body_mat(), Vector3(0, lid_h * 0.5, 0))
	var bezel: float = lerpf(0.09, 0.025, _f(s, "display"))
	var sw := w - bezel * 2.0
	var sh := lid_h - bezel * 2.0
	_add(hinge, RoundedSlab.build(sw, sh, 0.006, 0.04, 0.002, 4), _screen_mat(_f(s, "display")), Vector3(0, lid_h * 0.5, 0.028))
	_add(hinge, _cyl(0.014, 0.01, 10), _dark_mat(0.2), Vector3(0, lid_h * 0.5 + sh * 0.5 - 0.03, 0.034), Vector3(90, 0, 0))
	# desktop: janela, ícones e dock
	_add(hinge, RoundedSlab.build(sw * 0.46, sh * 0.5, 0.004, 0.03, 0.001, 3), _glow_mat(Color(1, 1, 1), 0.35), Vector3(-sw * 0.14, lid_h * 0.5 + sh * 0.06, 0.034))
	_add(hinge, RoundedSlab.build(sw * 0.3, sh * 0.3, 0.004, 0.03, 0.001, 3), _glow_mat(Color(1, 1, 1), 0.2), Vector3(sw * 0.22, lid_h * 0.5 + sh * 0.16, 0.034))
	_add(hinge, RoundedSlab.build(sw * 0.5, 0.06, 0.004, 0.03, 0.001, 3), _glow_mat(Color(1, 1, 1), 0.25), Vector3(0, lid_h * 0.5 - sh * 0.44, 0.034))
	for i in 5:
		_add(hinge, RoundedSlab.build(0.045, 0.045, 0.004, 0.012, 0.001, 3), _glow_mat(APP_COLORS[i], 1.0),
			Vector3((float(i) - 2.0) * 0.085, lid_h * 0.5 - sh * 0.44, 0.04))
	_text(hinge, "9:41", 0.07, Color(1, 1, 1, 0.9), Vector3(sw * 0.4, lid_h * 0.5 + sh * 0.46, 0.036))
	# logo e marca na tampa
	_add(hinge, _cyl(0.11, 0.008, 24), _glow_mat(ACCENT, 0.4 + 2.2 * _f(s, "performance")), Vector3(0, lid_h * 0.5, -0.03), Vector3(90, 0, 0))
	if bool(_design.get("brand", true)) and _brand_text() != "":
		_text(hinge, _brand_text(), 0.08, _trim_color(), Vector3(0, lid_h * 0.5 - 0.22, -0.032), Vector3(0, 180, 0))
	_feature_dots(hinge, Vector3(-0.3, lid_h * 0.5 - 0.35, -0.034), Vector3(90, 0, 0))

# ───────── console ─────────

func _console(s: Dictionary) -> void:
	var w := 1.7 * _dm("w")
	var d := 1.05 * _dm("h")
	var shape := _shape()
	var ht: float = lerpf(0.22, 0.40, _f(s, "thermal")) * _dm("d")
	var led := _color_of(_opt("led", "blue"), Color("5aa9ff")).lerp(Color("c792ea"), _f(s, "graphics") * (0.0 if _design.has("led") else 1.0))
	floor_y = -ht * 0.5 - 0.02
	var body := Node3D.new()
	add_child(body)
	if shape == "compact":
		body.scale = Vector3.ONE * 0.8
	elif shape == "tower":
		body.rotation_degrees = Vector3(0, 0, 90)
		body.scale = Vector3.ONE * 0.85
		floor_y = -w * 0.85 * 0.5 - 0.02
	var flat := Node3D.new()
	flat.rotation_degrees = Vector3(-90, 0, 0)
	body.add_child(flat)
	_add(flat, RoundedSlab.build(w, d, ht, _corner(0.14), 0.02, 8), _body_mat())
	var top := ht * 0.5
	# aberturas de ventilação
	var slits: int = 4 + int(_f(s, "thermal") * 7.0)
	for i in slits:
		_add(body, _box(Vector3(0.62, 0.006, 0.02)), _dark_mat(), Vector3(-0.35, top + 0.003, -0.38 + float(i) * 0.062))
	# núcleo (Desempenho)
	var core := TorusMesh.new()
	core.inner_radius = 0.13
	core.outer_radius = 0.19
	_add(body, core, _glow_mat(ACCENT, 0.4 + 2.4 * _f(s, "performance")), Vector3(0.48, top + 0.008, -0.05))
	_add(body, _cyl(0.07, 0.006), _glow_mat(ACCENT, 0.3 + 1.6 * _f(s, "performance")), Vector3(0.48, top + 0.005, -0.05))
	# faixa de LED frontal (cor escolhida)
	_add(body, _box(Vector3(w * 0.62, 0.02, 0.012)), _glow_mat(led, 1.6), Vector3(0, ht * 0.18, d * 0.5 + 0.002))
	_add(body, _box(Vector3(0.9, 0.034, 0.012)), _dark_mat(), Vector3(0.28, -ht * 0.12, d * 0.5 + 0.002))
	# alto-falantes (Áudio)
	var rws: int = 1 + int(_f(s, "audio") * 2.99)
	for r in rws:
		for c in 5:
			_add(body, _cyl(0.016, 0.006, 10), _dark_mat(), Vector3(0.12 + float(c) * 0.06, top + 0.003, 0.3 - float(r) * 0.06))
	# baias (Armazenamento)
	var bays: int = 1 + int(_f(s, "storage") * 2.99)
	for i in bays:
		_add(body, _box(Vector3(0.1, 0.03, 0.012)), _glow_mat(Color("4cd18a"), 0.9), Vector3(-0.72 + float(i) * 0.14, -ht * 0.12, d * 0.5 + 0.002))
	if bool(_design.get("brand", true)) and _brand_text() != "":
		_text(body, _brand_text(), 0.07, _trim_color(), Vector3(-0.45, top + 0.004, 0.3), Vector3(-90, 0, 0))
	_feature_dots(body, Vector3(-0.6, top + 0.01, 0.35))
	# controle ao lado
	var pad := Node3D.new()
	pad.position = Vector3(0.05, -ht * 0.5 + 0.09, 0.95)
	pad.rotation_degrees = Vector3(0, -12, 0)
	add_child(pad)
	var pad_mat := _body_mat()
	_add(pad, RoundedSlab.build(0.7, 0.34, 0.14, 0.15, 0.02, 8), pad_mat, Vector3.ZERO, Vector3(-90, 0, 0))
	for sx in [-0.17, 0.11]:
		_add(pad, _cyl(0.05, 0.03, 14), _dark_mat(0.5), Vector3(sx, 0.085, 0.0))
	for i in 4:
		var a := TAU * float(i) / 4.0
		_add(pad, _cyl(0.022, 0.02, 10), _glow_mat(APP_COLORS[i], 1.1), Vector3(0.22 + cos(a) * 0.055, 0.075, sin(a) * 0.055))
	_add(pad, _box(Vector3(0.1, 0.02, 0.1)), _dark_mat(0.5), Vector3(-0.24, 0.07, 0.07))
	_add(pad, _box(Vector3(0.22, 0.01, 0.02)), _glow_mat(led, 1.6), Vector3(0, 0.072, -0.13))
