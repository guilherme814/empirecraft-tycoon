class_name MeshBuilder
extends RefCounted
## Monta malhas low-poly com cor por vértice (caixas e prismas). Um único material serve para
## centenas de peças, então o cenário inteiro cabe em poucas chamadas de desenho.

# cada face: quatro cantos em sentido anti-horário visto de fora (normal pelo produto vetorial)
const _FACES := [
	[Vector3(1, 0, 0), Vector3(1, -1, 1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1)],
	[Vector3(-1, 0, 0), Vector3(-1, -1, -1), Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(-1, 1, -1)],
	[Vector3(0, 1, 0), Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(-1, 1, -1)],
	[Vector3(0, -1, 0), Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1)],
	[Vector3(0, 0, 1), Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1)],
	[Vector3(0, 0, -1), Vector3(1, -1, -1), Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(1, 1, -1)],
]

static var _mats: Dictionary = {}

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _c := PackedColorArray()
var _i := PackedInt32Array()

func is_empty() -> bool:
	return _v.is_empty()

func vertex_count() -> int:
	return _v.size()

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	var k := _v.size()
	_v.append_array(PackedVector3Array([a, b, c, d]))
	_n.append_array(PackedVector3Array([n, n, n, n]))
	_c.append_array(PackedColorArray([ca, cb, cc, cd]))
	# o Godot usa sentido horário para a face da frente
	_i.append_array(PackedInt32Array([k, k + 2, k + 1, k, k + 3, k + 2]))

## Caixa. `ao` escurece a base das laterais (falso oclusão ambiente). yaw/pitch giram em torno do centro.
func box(center: Vector3, size: Vector3, color: Color, yaw: float = 0.0, ao: float = 0.14, pitch: float = 0.0) -> void:
	var h := size * 0.5
	var bs := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var dark := Color(color.r * (1.0 - ao), color.g * (1.0 - ao), color.b * (1.0 - ao), color.a)
	for f in _FACES:
		var n: Vector3 = bs * (f[0] as Vector3)
		var p: Array = []
		var cs: Array = []
		for k in 4:
			var s: Vector3 = f[k + 1]
			p.append(center + bs * Vector3(s.x * h.x, s.y * h.y, s.z * h.z))
			cs.append(dark if (s.y < 0.0 and absf((f[0] as Vector3).y) < 0.5) else color)
		if (f[0] as Vector3).y < -0.5:
			cs = [dark, dark, dark, dark]
		_quad(p[0], p[1], p[2], p[3], n, cs[0], cs[1], cs[2], cs[3])

## Prisma de N lados (cilindro low-poly) com tampa de cima.
func prism(center: Vector3, radius: float, height: float, sides: int, color: Color, yaw: float = 0.0, top: Color = Color(0, 0, 0, 0), ao: float = 0.12) -> void:
	var hy := height * 0.5
	var dark := Color(color.r * (1.0 - ao), color.g * (1.0 - ao), color.b * (1.0 - ao), color.a)
	var tc := color if top.a == 0.0 else top
	for s in sides:
		var a0 := yaw + TAU * float(s) / float(sides)
		var a1 := yaw + TAU * float(s + 1) / float(sides)
		var p0 := Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1 := Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		var mid := (p0 + p1) * 0.5
		var n := mid.normalized()
		# sentido horário visto de fora
		_quad(center + p1 + Vector3(0, -hy, 0), center + p0 + Vector3(0, -hy, 0), center + p0 + Vector3(0, hy, 0), center + p1 + Vector3(0, hy, 0), n, dark, dark, color, color)
		# tampa: triângulo do centro
		var k := _v.size()
		_v.append_array(PackedVector3Array([center + Vector3(0, hy, 0), center + p0 + Vector3(0, hy, 0), center + p1 + Vector3(0, hy, 0)]))
		_n.append_array(PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP]))
		_c.append_array(PackedColorArray([tc, tc, tc]))
		_i.append_array(PackedInt32Array([k, k + 2, k + 1]))

## Polígono plano (símbolo do logotipo) voltado para +z, no plano XY.
func poly(pts: PackedVector2Array, center: Vector3, scale: float, color: Color) -> void:
	var tri := Geometry2D.triangulate_polygon(pts)
	if tri.size() < 3:
		return
	var k := _v.size()
	for p in pts:
		_v.append(center + Vector3(p.x * scale, -p.y * scale, 0.0))
		_n.append(Vector3(0, 0, 1))
		_c.append(color)
	# triangulate_polygon devolve horário no plano 2D; o eixo y invertido troca o sentido
	for i in range(0, tri.size(), 3):
		_i.append_array(PackedInt32Array([k + tri[i], k + tri[i + 2], k + tri[i + 1]]))

func build() -> ArrayMesh:
	var m := ArrayMesh.new()
	if _v.is_empty():
		return m
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _v
	arr[Mesh.ARRAY_NORMAL] = _n
	arr[Mesh.ARRAY_COLOR] = _c
	arr[Mesh.ARRAY_INDEX] = _i
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

## Materiais compartilhados: "lit" (iluminado), "emissive" (telas/LEDs), "glass" (vidro).
static func material(kind: String) -> Material:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	match kind:
		"lit":
			m.roughness = 0.85
			m.metallic_specular = 0.25
		"emissive":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"glass":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.1
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"worker":
			m.roughness = 0.8
			m.metallic_specular = 0.2
	_mats[kind] = m
	return m
