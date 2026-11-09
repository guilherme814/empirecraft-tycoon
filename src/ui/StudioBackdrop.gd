class_name StudioBackdrop
extends ColorRect
## Fundo vivo do estúdio de design: degradê que muda de cor a cada etapa, brilhos que flutuam
## devagar e uma grade técnica sutil. Um shader só; custa quase nada na GPU.

const SHADER := """
shader_type canvas_item;
uniform vec4 c1 : source_color = vec4(0.1, 0.2, 0.55, 1.0);
uniform vec4 c2 : source_color = vec4(0.45, 0.1, 0.6, 1.0);
uniform vec4 glow : source_color = vec4(1.0, 0.3, 0.6, 1.0);
uniform float grid_amt = 0.0;
void fragment() {
	vec2 uv = UV;
	vec3 col = mix(c1.rgb, c2.rgb, clamp(uv.y * 0.9 + 0.1 * sin(TIME * 0.2 + uv.x * 3.0), 0.0, 1.0));
	vec2 p1 = vec2(0.25 + 0.15 * sin(TIME * 0.17), 0.35 + 0.12 * cos(TIME * 0.21));
	vec2 p2 = vec2(0.78 + 0.12 * cos(TIME * 0.13), 0.7 + 0.15 * sin(TIME * 0.19));
	col += glow.rgb * 0.38 * smoothstep(0.55, 0.0, distance(uv, p1));
	col += c2.rgb * 0.45 * smoothstep(0.6, 0.0, distance(uv, p2));
	vec2 g = abs(fract(UV * vec2(40.0, 22.0)) - 0.5);
	float line = smoothstep(0.47, 0.5, max(g.x, g.y));
	col += vec3(0.5, 0.7, 1.0) * line * 0.07 * grid_amt;
	col *= 1.0 - 0.35 * pow(distance(uv, vec2(0.5)), 2.0);
	COLOR = vec4(col, 1.0);
}
"""

const THEMES := [
	{"c1": Color("1f3a9a"), "c2": Color("6a1b9a"), "glow": Color("ff3d8a"), "grid": 0.8},   # forma
	{"c1": Color("5a1030"), "c2": Color("5b1f9a"), "glow": Color("ff7a45"), "grid": 0.2},   # estilo
	{"c1": Color("0b3c63"), "c2": Color("0b6b5a"), "glow": Color("2fe0c0"), "grid": 1.0},   # hardware
	{"c1": Color("101a4a"), "c2": Color("2b1a6e"), "glow": Color("4a8cff"), "grid": 1.0},   # sistema
	{"c1": Color("2a1066"), "c2": Color("123b8a"), "glow": Color("b46bff"), "grid": 0.4},   # produção
]

var _mat: ShaderMaterial
var _cur: int = -1

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	material = _mat
	set_look(0, false)

func set_look(i: int, animate: bool = true) -> void:
	i = clampi(i, 0, THEMES.size() - 1)
	if i == _cur:
		return
	_cur = i
	var t: Dictionary = THEMES[i]
	if not animate or Saves.gfx == "eco":
		_mat.set_shader_parameter("c1", t.c1)
		_mat.set_shader_parameter("c2", t.c2)
		_mat.set_shader_parameter("glow", t.glow)
		_mat.set_shader_parameter("grid_amt", t.grid)
		return
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for k in ["c1", "c2", "glow"]:
		var from: Color = _mat.get_shader_parameter(k)
		tw.tween_method(func(v: Color): _mat.set_shader_parameter(k, v), from, t[k], 0.6)
	tw.tween_method(func(v: float): _mat.set_shader_parameter("grid_amt", v), float(_mat.get_shader_parameter("grid_amt")), float(t.grid), 0.6)
