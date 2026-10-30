class_name Fx
extends RefCounted
## Efeitos visuais baratos para as cenas 3D (modo Compatibilidade, sem glow nativo):
## halos de luz aditivos, feixes de sol, poeira, vapor, confete e shaders de tela/LED/cidade.

static var _cache: Dictionary = {}
static var _night: float = 0.0

const EMISSIVE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;
uniform float boost = 1.0;
vec3 s2l(vec3 c) { return pow(c, vec3(2.2)); }
void fragment() {
	float a = COLOR.a;
	float k = 1.0;
	if (a < 0.99) { k = 0.25 + 0.75 * step(0.5, fract(TIME * 0.8 + a * 13.0)); }
	ALBEDO = s2l(COLOR.rgb) * k * boost;
}
"""

const SCREEN_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;
varying vec3 wp;
vec3 s2l(vec3 c) { return pow(c, vec3(2.2)); }
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float scan = 0.9 + 0.1 * sin(wp.y * 110.0 - TIME * 5.0);
	float pulse = 0.93 + 0.07 * sin(TIME * 2.3 + wp.x * 4.0 + wp.z * 3.0);
	ALBEDO = s2l(COLOR.rgb) * scan * pulse * 1.15;
}
"""

const CITY_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;
uniform float night = 0.0;
varying vec3 wp;
varying vec3 nrm;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; nrm = NORMAL; }
void fragment() {
	vec3 base = COLOR.rgb;
	vec3 day = mix(vec3(0.50, 0.58, 0.74), base, 0.45) * (0.7 + 0.3 * clamp(wp.y / 8.0, 0.0, 1.0));
	vec3 ngt = base * 0.16 + vec3(0.01, 0.015, 0.03);
	vec3 col = mix(day, ngt, night);
	if (abs(nrm.y) < 0.5) {
		float u = abs(nrm.x) > 0.5 ? wp.z : wp.x;
		vec2 g = vec2(fract(u * 1.5), fract(wp.y * 1.2));
		float inside = step(0.22, g.x) * step(g.x, 0.78) * step(0.25, g.y) * step(g.y, 0.75);
		float id = floor(u * 1.5) + floor(wp.y * 1.2) * 17.0 + floor(wp.x) * 3.0;
		float lit = step(0.5, fract(sin(id * 12.9898) * 43758.5453));
		vec3 win = mix(vec3(0.62, 0.78, 0.98) * 0.7, vec3(1.0, 0.8, 0.42), night);
		col = mix(col, win, inside * (night * lit + (1.0 - night) * 0.5 * lit));
	}
	ALBEDO = pow(col, vec3(2.2));
}
"""

const SHAFT_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(1.0, 0.92, 0.7, 0.35);
uniform float power = 1.0;
void fragment() {
	float f = 1.0 - UV.y;
	float stripes = 0.75 + 0.25 * sin(UV.x * 18.0 + TIME * 0.25);
	ALBEDO = tint.rgb * tint.a * f * f * stripes * power;
	ALPHA = 1.0;
}
"""

static func shader_mat(kind: String) -> ShaderMaterial:
	if _cache.has(kind):
		return _cache[kind]
	var sh := Shader.new()
	match kind:
		"emissive": sh.code = EMISSIVE_SHADER
		"screen": sh.code = SCREEN_SHADER
		"city": sh.code = CITY_SHADER
		"shaft": sh.code = SHAFT_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	if kind == "city":
		m.set_shader_parameter("night", _night)
	if kind == "shaft":
		m.render_priority = 1
	_cache[kind] = m
	return m

## 0 = dia, 1 = noite: atualiza os materiais que dependem disso.
static func set_night(n: float) -> void:
	_night = clampf(n, 0.0, 1.0)
	(shader_mat("city") as ShaderMaterial).set_shader_parameter("night", _night)
	(shader_mat("shaft") as ShaderMaterial).set_shader_parameter("power", 1.0 - _night)

static func night() -> float:
	return _night

## Fator de noite pela hora do relógio do aparelho (0..24, com fração).
static func night_for_hour(h: float) -> float:
	if h >= 20.0 or h < 5.0:
		return 1.0
	if h >= 18.0:
		return (h - 18.0) / 2.0
	if h < 7.0:
		return 1.0 - (h - 5.0) / 2.0
	return 0.0

static func system_hour() -> float:
	var t := Time.get_time_dict_from_system()
	return float(t.hour) + float(t.minute) / 60.0

static func _radial_tex(inner: float) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, inner, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	return gt

static func halo_material(color: Color) -> StandardMaterial3D:
	var k := "halo|" + color.to_html()
	if _cache.has(k):
		return _cache[k]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = color
	m.albedo_texture = _radial_tex(0.18)
	m.no_depth_test = false
	m.disable_receive_shadows = true
	_cache[k] = m
	return m

## Halo (brilho) aditivo voltado para a câmera.
static func halo(parent: Node, pos: Vector3, color: Color, size: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	mi.material_override = halo_material(color)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("halo_base", 0.0)
	parent.add_child(mi)
	return mi

## Feixe de luz (paralelogramo da janela até o chão).
static func shaft(parent: Node, top_a: Vector3, top_b: Vector3, floor_shift: Vector3) -> MeshInstance3D:
	var m := ArrayMesh.new()
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	var fa := Vector3(top_a.x, 0.02, top_a.z) + floor_shift
	var fb := Vector3(top_b.x, 0.02, top_b.z) + floor_shift
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([top_a, top_b, fb, fa])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = shader_mat("shaft")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func _soft_particle_mat(color: Color) -> StandardMaterial3D:
	var k := "pm|" + color.to_html()
	if _cache.has(k):
		return _cache[k]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = _radial_tex(0.3)
	m.albedo_color = color
	_cache[k] = m
	return m

## Partículas de poeira flutuando num volume.
static func dust(parent: Node, center: Vector3, extents: Vector3, amount: int = 36) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3(0.3, 0.2, 0.3)
	p.spread = 180.0
	p.initial_velocity_min = 0.02
	p.initial_velocity_max = 0.07
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	p.mesh = q
	p.material_override = _soft_particle_mat(Color(1.0, 0.93, 0.78, 0.55))
	p.position = center
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = g
	parent.add_child(p)
	return p

## Vapor subindo (café).
static func steam(parent: Node, pos: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 7
	p.lifetime = 2.2
	p.direction = Vector3(0, 1, 0)
	p.spread = 14.0
	p.initial_velocity_min = 0.12
	p.initial_velocity_max = 0.2
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	p.mesh = q
	p.material_override = _soft_particle_mat(Color(0.9, 0.95, 1.0, 0.5))
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	p.color_ramp = g
	p.position = pos
	parent.add_child(p)
	return p

## Explosão única de confete/faíscas; chame burst.restart() para repetir.
static func burst(parent: Node, pos: Vector3, colors: Array, amount: int = 70, power: float = 3.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 2.2
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = false
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = power * 0.5
	p.initial_velocity_max = power
	p.gravity = Vector3(0, -4.2, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.angle_max = 360.0
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	p.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	p.material_override = m
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offs.append(float(i) / float(maxi(colors.size() - 1, 1)))
		cols.append(colors[i])
	g.offsets = offs
	g.colors = cols
	p.color_initial_ramp = g
	p.position = pos
	parent.add_child(p)
	return p

## Texto flutuante que sobe e some ("+R$ 1.200").
static func float_text(parent: Node, pos: Vector3, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.0065
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = color
	l.outline_size = 14
	l.outline_modulate = Color(0.04, 0.05, 0.09, 0.9)
	l.position = pos
	parent.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", pos.y + 1.1, 1.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 1.6).set_delay(0.6)
	tw.chain().tween_callback(l.queue_free)
