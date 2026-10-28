class_name Chart
extends Control
## Gráfico de linha simples (preços, caixa). Desenha com _draw, sem texturas.

var series: Array = []          # lista de {"values": Array, "color": Color}
var fill: bool = true
var show_range: bool = true
var _font: Font

func _init(h: int = 150) -> void:
	custom_minimum_size = Vector2(0, h)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_series(values: Array, color: Color = Palette.ACCENT) -> void:
	series = [{"values": values, "color": color}]
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.PANEL_DEEP)
	if series.is_empty():
		return
	var lo := INF
	var hi := -INF
	for s in series:
		for v in s.values:
			lo = minf(lo, float(v))
			hi = maxf(hi, float(v))
	if lo == INF or hi - lo < 0.0001:
		hi = lo + 1.0
	var pad := 8.0
	var w := size.x - pad * 2.0
	var h := size.y - pad * 2.0
	for s in series:
		var vals: Array = s.values
		if vals.size() < 2:
			continue
		var pts := PackedVector2Array()
		for i in vals.size():
			pts.append(Vector2(pad + w * float(i) / float(vals.size() - 1), pad + h * (1.0 - (float(vals[i]) - lo) / (hi - lo))))
		if fill:
			var poly := PackedVector2Array(pts)
			poly.append(Vector2(pts[pts.size() - 1].x, pad + h))
			poly.append(Vector2(pts[0].x, pad + h))
			var c: Color = s.color
			draw_colored_polygon(poly, Color(c.r, c.g, c.b, 0.14))
		draw_polyline(pts, s.color, 3.0, true)
	if show_range:
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(pad + 4, 22), Fmt.money(hi), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.MUTED)
		draw_string(f, Vector2(pad + 4, size.y - 8), Fmt.money(lo), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.MUTED)
