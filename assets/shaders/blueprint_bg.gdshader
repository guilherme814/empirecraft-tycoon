shader_type canvas_item;
// Fundo "planta técnica": grade sutil + vinheta. Barato (sem texturas), bom para celular.

uniform vec4 base_color : source_color = vec4(0.07, 0.078, 0.10, 1.0);
uniform vec4 line_color : source_color = vec4(0.36, 0.42, 0.55, 1.0);
uniform float cell = 64.0;
uniform float line_strength = 0.10;
uniform vec2 rect_size = vec2(1920.0, 1080.0);

void fragment() {
	vec2 p = UV * rect_size;
	vec2 g = abs(fract(p / cell - 0.5) - 0.5) * cell;
	float minor = 1.0 - smoothstep(0.0, 1.4, min(g.x, g.y));
	vec2 g2 = abs(fract(p / (cell * 4.0) - 0.5) - 0.5) * cell * 4.0;
	float major = 1.0 - smoothstep(0.0, 1.8, min(g2.x, g2.y));
	float vig = smoothstep(1.05, 0.15, length(UV - 0.5));
	vec3 c = base_color.rgb + line_color.rgb * line_strength * (minor * 0.6 + major * 1.0);
	c *= mix(0.70, 1.0, vig);
	COLOR = vec4(c, 1.0);
}
