class_name TeardownView
extends Control
## Vista explodida do aparelho: camadas empilhadas em diagonal, com a peça de cada eixo.
## A cor da camada indica o nível da peça (básica, boa, avançada, topo/chip próprio).

const TIER_COLORS := [Color("4a5568"), Color("3b82c4"), Color("8b5cf6"), Color("ffb020")]
var _layers: Array = []

func set_layers(layers: Array) -> void:
	_layers = layers
	custom_minimum_size = Vector2(0, 90.0 + 62.0 * float(layers.size()))
	queue_redraw()

func _draw() -> void:
	var n := _layers.size()
	if n == 0:
		return
	var w := size.x
	var plate := Vector2(minf(w * 0.42, 300.0), 40.0)
	var step := 62.0
	for i in n:
		var l: Dictionary = _layers[i]
		var col: Color = TIER_COLORS[clampi(int(l.tier), 0, 3)]
		var off := Vector2(30.0 + float(i) * 14.0, 20.0 + float(i) * step)
		# camada: paralelogramo (topo claro, lateral escura) dando profundidade
		var tl := off
		var tr := off + Vector2(plate.x, 0)
		var br := off + Vector2(plate.x - 26.0, plate.y)
		var bl := off + Vector2(-26.0, plate.y)
		draw_colored_polygon(PackedVector2Array([tl, tr, br, bl]), col)
		draw_colored_polygon(PackedVector2Array([bl, br, br + Vector2(0, 8), bl + Vector2(0, 8)]), col.darkened(0.45))
		draw_polyline(PackedVector2Array([tl, tr, br, bl, tl]), col.lightened(0.3), 2.0)
		# linha de chamada até o rótulo
		var from := tr + Vector2(0, plate.y * 0.5)
		var to := Vector2(plate.x + 90.0 + float(i) * 14.0, from.y)
		draw_line(from, to, Color(1, 1, 1, 0.25), 1.5)
		draw_circle(from, 4.0, col.lightened(0.4))
		var f := ThemeDB.fallback_font
		draw_string(f, to + Vector2(10, -4), str(l.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.MUTED)
		draw_string(f, to + Vector2(10, 22), str(l.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Palette.TEXT)
