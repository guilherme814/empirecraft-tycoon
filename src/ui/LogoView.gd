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
		var r := s * 0.22
		var sb := StyleBoxFlat.new()
		sb.bg_color = c2
		sb.set_corner_radius_all(int(r))
		sb.set_border_width_all(maxi(2, int(s * 0.04)))
		sb.border_color = c1.darkened(0.2)
		draw_style_box(sb, Rect2(0, 0, s, s))
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
