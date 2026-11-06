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
	for gi in range(1, 4):
		var gy := size.y * float(gi) / 4.0
		draw_line(Vector2(0, gy), Vector2(size.x, gy), Color(1, 1, 1, 0.045), 1.0)
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
			var cols := PackedColorArray()
			for q in poly:
				var t := clampf((q.y - pad) / h, 0.0, 1.0)
				cols.append(Color(c.r, c.g, c.b, 0.34 * (1.0 - t) + 0.02))
			draw_polygon(poly, cols)
		var cl: Color = s.color
		if Saves.gfx != "eco":
			draw_polyline(pts, Color(cl.r, cl.g, cl.b, 0.16), 9.0, true)
		draw_polyline(pts, cl, 3.0, true)
		var last: Vector2 = pts[pts.size() - 1]
		draw_circle(last, 7.0, Color(cl.r, cl.g, cl.b, 0.25))
		draw_circle(last, 4.0, cl)
	if show_range:
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(pad + 4, 22), Fmt.money(hi), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.MUTED)
		draw_string(f, Vector2(pad + 4, size.y - 8), Fmt.money(lo), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.MUTED)
