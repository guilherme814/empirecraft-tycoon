class_name WaferView
extends Control
## Desenha um wafer de 300 mm cheio de dies: verdes = bons, vermelhos = defeituosos (rendimento de Murphy).

var area_mm2: float = 50.0
var yield_frac: float = 0.9
var seed_v: int = 1
var wafer_mm: float = 300.0

func _init() -> void:
	custom_minimum_size = Vector2(0, 360)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_chip(area: float, y: float) -> void:
	area_mm2 = maxf(area, 1.0)
	yield_frac = clampf(y, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var side := minf(size.x, size.y) - 8.0
	if side <= 10.0:
		return
	var center := size * 0.5
	var r := side * 0.5
	var scale_px := r / (wafer_mm * 0.5)           # px por mm
	draw_circle(center, r, Color("22314d"))
	draw_arc(center, r, 0.0, TAU, 96, Color("5a7fb8"), 3.0)
	var die := sqrt(area_mm2)
	var step_px := die * scale_px
	# limita o desenho a ~900 dies (em wafers com dies minúsculos, agrupa visualmente)
	var mult := 1.0
	while (PI * r * r) / (step_px * mult * step_px * mult) > 900.0:
		mult += 0.25
	var cell := maxf(step_px * mult, 3.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var n := int(ceil(r / cell)) + 1
	for iy in range(-n, n):
		for ix in range(-n, n):
			var x0 := center.x + float(ix) * cell
			var y0 := center.y + float(iy) * cell
			var corners := [Vector2(x0, y0), Vector2(x0 + cell, y0), Vector2(x0, y0 + cell), Vector2(x0 + cell, y0 + cell)]
			var inside := true
			for cn in corners:
				if (cn as Vector2).distance_to(center) > r - 2.0:
					inside = false
			if not inside:
				continue
			var good := rng.randf() < yield_frac
			var col := Color("4cd18a") if good else Color("ff5d6c")
			col.a = 0.85
			draw_rect(Rect2(x0 + 0.6, y0 + 0.6, cell - 1.2, cell - 1.2), col)
