class_name LogoView
extends Control
## Desenha o logotipo da empresa (símbolo sobre placa colorida), opcionalmente com o nome ao lado.

var logo: Dictionary = {}
var show_name: String = ""
var plate: bool = true

func setup(l: Dictionary, size_px: float, name_text: String = "") -> LogoView:
	logo = l
	show_name = name_text
	custom_minimum_size = Vector2(size_px, size_px)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if name_text != "":
		custom_minimum_size.x = size_px + 18.0 + 22.0 * float(name_text.length()) * 0.62
	queue_redraw()
	return self

func _draw() -> void:
	if logo.is_empty():
		return
	var s := minf(size.y, 4000.0)
	var c1 := Color(str(logo.c1))
	var c2 := Color(str(logo.c2))
	if plate:
		_draw_plate(s, c1, c2)
	var pts := Identity.points(str(logo.symbol))
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(s * 0.5 + p.x * s * 0.34, s * 0.5 + p.y * s * 0.34))
	var tri := Geometry2D.triangulate_polygon(out)
	if tri.size() >= 3:
		draw_colored_polygon(out, c1)
	if show_name != "":
		var f := get_theme_default_font()
		draw_string(f, Vector2(s + 14.0, s * 0.68), Identity.format_name(show_name, str(logo.get("style", "caps"))), HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.5), c1)

func _draw_plate(s: float, c1: Color, c2: Color) -> void:
	var shape := str(logo.get("shape", "round"))
	var r := s * (0.5 if shape == "circle" else (0.0 if shape == "square" else 0.22))
	var sb := StyleBoxFlat.new()
	sb.bg_color = c2
	sb.set_corner_radius_all(int(r))
	sb.set_border_width_all(maxi(2, int(s * 0.04)))
	sb.border_color = c1.darkened(0.2)
	draw_style_box(sb, Rect2(0, 0, s, s))
	if str(logo.get("grad", "flat")) == "grad":
		# degradê vertical: tom mais claro no topo (sobreposição com transparência)
		var n := 8
		for i in n:
			var f := float(i) / float(n)
			var col := c1.lerp(c2, 0.5)
			col.a = 0.32 * (1.0 - f)
			var y0 := s * 0.06 + (s * 0.88) * f
			var inset := s * 0.07 if shape != "circle" else s * (0.5 - sqrt(maxf(0.0, 0.25 - pow(f + 0.06 - 0.5, 2.0))))
			draw_rect(Rect2(inset, y0, s - inset * 2.0, s * 0.88 / float(n) + 0.5), col)
	var pc := c1
	pc.a = 0.22
	match str(logo.get("pattern", "none")):
		"dots":
			for ix in 5:
				for iy in 5:
					draw_circle(Vector2(s * (0.14 + 0.18 * float(ix)), s * (0.14 + 0.18 * float(iy))), maxf(1.2, s * 0.025), pc)
		"grid":
			for i in range(1, 5):
				draw_line(Vector2(s * 0.2 * float(i), s * 0.08), Vector2(s * 0.2 * float(i), s * 0.92), pc, maxf(1.0, s * 0.012))
				draw_line(Vector2(s * 0.08, s * 0.2 * float(i)), Vector2(s * 0.92, s * 0.2 * float(i)), pc, maxf(1.0, s * 0.012))
		"stripes":
			for i in range(1, 6):
				draw_line(Vector2(s * 0.08, s * 0.16 * float(i)), Vector2(s * 0.92, s * 0.16 * float(i)), pc, maxf(1.5, s * 0.03))
		"diag":
			var lo := s * 0.08
			var hi := s * 0.92
			for k in range(1, 5):
				var d := s * 0.18 * float(k)
				draw_line(Vector2(lo, minf(hi, lo + d)), Vector2(minf(hi, lo + d), lo), pc, maxf(1.5, s * 0.03))
				draw_line(Vector2(maxf(lo, hi - d), hi), Vector2(hi, maxf(lo, hi - d)), pc, maxf(1.5, s * 0.03))
