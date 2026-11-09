class_name ChipView
extends Control
## Chip em perspectiva isométrica com borda luminosa e a "planta da pastilha" (die): cada bloco
## (núcleos, cache, NPU, GPU, memória, ISP) aparece de acordo com o projeto, ao vivo.

const ARCH_RIM := {"eff": Color("3df0a0"), "bal": Color("5aa9ff"), "perf": Color("ff7a2e")}
var design: Dictionary = {}
var _t: float = 0.0

func _init(h: int = 380) -> void:
	custom_minimum_size = Vector2(0, h)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_design(d: Dictionary) -> void:
	design = d
	queue_redraw()

func _process(delta: float) -> void:
	if Saves.gfx == "eco" or not is_visible_in_tree():
		return
	_t += delta
	queue_redraw()

func _block(r: Rect2, col: Color) -> void:
	draw_rect(r, col.darkened(0.45))
	draw_rect(r.grow(-2.0), col)
	draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6.0, 3.0)), Color(1, 1, 1, 0.25))

## Distribui `n` blocos numa área em grade.
func _grid(area: Rect2, n: int, col: Color) -> void:
	if n <= 0:
		return
	var cols := int(ceil(sqrt(float(n) * area.size.x / maxf(area.size.y, 1.0))))
	cols = clampi(cols, 1, n)
	var rows := int(ceil(float(n) / float(cols)))
	var cw := area.size.x / float(cols)
	var ch := area.size.y / float(rows)
	for i in n:
		var cx := i % cols
		var cy := i / cols
		_block(Rect2(area.position + Vector2(float(cx) * cw, float(cy) * ch), Vector2(cw, ch)).grow(-3.0), col)

func _draw() -> void:
	var w := size.x
	var h := size.y
	# fundo: placa de circuito com trilhas discretas
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.09, 0.16, 0.55))
	for i in 9:
		var y := h * (0.1 + 0.1 * float(i))
		var x0 := fmod(float(i) * 97.0, w * 0.4)
		draw_polyline(PackedVector2Array([Vector2(0, y), Vector2(x0 + 60.0, y), Vector2(x0 + 100.0, y + 30.0), Vector2(x0 + 220.0, y + 30.0)]), Color(0.3, 0.8, 0.9, 0.07), 2.0)
		draw_polyline(PackedVector2Array([Vector2(w, y + 20.0), Vector2(w - x0 - 60.0, y + 20.0), Vector2(w - x0 - 100.0, y - 10.0), Vector2(w - x0 - 200.0, y - 10.0)]), Color(0.3, 0.8, 0.9, 0.07), 2.0)
	if design.is_empty():
		return
	var rim: Color = ARCH_RIM.get(str(design.get("arch", "bal")), ARCH_RIM.bal)
	var S := minf(w * 0.5, h * 0.82)
	var sway := 0.05 * sin(_t * 0.7) if Saves.gfx != "eco" else 0.0
	var center := Vector2(w * 0.5, h * 0.52)
	var ax := Vector2(0.86, 0.43 + sway)
	var ay := Vector2(-0.86, 0.43 - sway)
	# espessura: camadas empilhadas para baixo
	for k in range(10, 0, -1):
		draw_set_transform_matrix(Transform2D(ax, ay, center + Vector2(0, float(k) * 2.2)))
		draw_rect(Rect2(-S * 0.5, -S * 0.5, S, S), Color(0.05, 0.06, 0.1).lerp(Color(0.12, 0.14, 0.2), 1.0 - float(k) / 10.0))
	draw_set_transform_matrix(Transform2D(ax, ay, center))
	var pk := Rect2(-S * 0.5, -S * 0.5, S, S)
	draw_rect(pk, Color("1b2030"))
	# pinos
	var npin := 16
	for i in npin:
		var f := -S * 0.5 + S * (float(i) + 0.5) / float(npin)
		for sgn in [-1.0, 1.0]:
			draw_rect(Rect2(f - 3.0, sgn * S * 0.5 - (6.0 if sgn > 0 else 0.0) + (0.0 if sgn > 0 else -6.0), 6.0, 12.0), Color("c9a24a"))
			draw_rect(Rect2(sgn * S * 0.5 - (6.0 if sgn > 0 else 0.0) + (0.0 if sgn > 0 else -6.0), f - 3.0, 12.0, 6.0), Color("c9a24a"))
	draw_rect(pk, Color("232a3d"))
	# borda luminosa
	var pulse := 0.5 + 0.5 * sin(_t * 2.2) if Saves.gfx != "eco" else 0.6
	for g in 4:
		draw_rect(pk.grow(float(g) * 3.0), Color(rim.r, rim.g, rim.b, (0.20 - float(g) * 0.04) * (0.6 + 0.4 * pulse)), false, 5.0)
	draw_rect(pk, rim, false, 4.0)
	# die
	var die := pk.grow(-S * 0.14)
	draw_rect(die, Color("0d1118"))
	draw_rect(die, Color(rim.r, rim.g, rim.b, 0.5), false, 2.0)
	var inner := die.grow(-8.0)
	var cores := int(design.get("cores", 4))
	var ecores := int(design.get("ecores", 0))
	var cache := int(design.get("cache", 4))
	var npu := int(design.get("npu", 0))
	var gpu := int(design.get("gpu", 0))
	var mem := int(design.get("mem", 2))
	var isp := bool(design.get("isp", false))
	var top_h := inner.size.y * 0.16
	var bot_h := inner.size.y * (0.12 + 0.2 * clampf(float(cache) / float(Chips.MAX_CACHE), 0.0, 1.0))
	var mid := Rect2(inner.position + Vector2(0, top_h + 6.0), Vector2(inner.size.x, inner.size.y - top_h - bot_h - 12.0))
	_grid(Rect2(inner.position, Vector2(inner.size.x, top_h)), mem, Color("8a93a8"))
	var has_gpu := gpu > 0
	var has_acc := npu > 0 or isp
	var cpu_w := mid.size.x * (0.5 if has_gpu else (0.68 if has_acc else 1.0))
	var cpu := Rect2(mid.position, Vector2(cpu_w - 4.0, mid.size.y))
	var ecore_h := cpu.size.y * (0.28 if ecores > 0 else 0.0)
	_grid(Rect2(cpu.position, Vector2(cpu.size.x, cpu.size.y - ecore_h - (4.0 if ecores > 0 else 0.0))), cores, Color("4a8cff"))
	if ecores > 0:
		_grid(Rect2(cpu.position + Vector2(0, cpu.size.y - ecore_h), Vector2(cpu.size.x, ecore_h)), ecores, Color("2fd0b0"))
	var rx := mid.position.x + cpu_w
	var rw := mid.size.x - cpu_w
	if has_gpu:
		var gh := mid.size.y * (0.64 if has_acc else 1.0)
		_grid(Rect2(Vector2(rx, mid.position.y), Vector2(rw, gh)), gpu, Color("ff9a2e"))
		if has_acc:
			var ay2 := mid.position.y + gh + 4.0
			var acc_r := Rect2(Vector2(rx, ay2), Vector2(rw, mid.size.y - gh - 4.0))
			_grid(acc_r, npu + (1 if isp else 0), Color("b46bff") if npu > 0 else Color("ff6aa8"))
	elif has_acc:
		_grid(Rect2(Vector2(rx, mid.position.y), Vector2(rw, mid.size.y)), npu + (1 if isp else 0), Color("b46bff"))
	draw_rect(Rect2(Vector2(inner.position.x, inner.end.y - bot_h), Vector2(inner.size.x, bot_h)), Color("6f4bd8").darkened(0.5))
	_block(Rect2(Vector2(inner.position.x, inner.end.y - bot_h), Vector2(inner.size.x, bot_h)).grow(-2.0), Color("6f4bd8"))
	# nome do chip e legenda (fora da perspectiva)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var f := ThemeDB.fallback_font
	var nm := str(design.get("name", ""))
	draw_string(f, Vector2(18, h - 16), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.9))
	var legend := [["Núcleos", Color("4a8cff")], ["Efic.", Color("2fd0b0")], ["GPU", Color("ff9a2e")], ["NPU", Color("b46bff")], ["Cache", Color("6f4bd8")], ["Memória", Color("8a93a8")]]
	var lx := 18.0
	for it in legend:
		draw_rect(Rect2(lx, 16, 16, 16), it[1])
		draw_string(f, Vector2(lx + 22, 30), str(it[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.MUTED)
		lx += 30.0 + f.get_string_size(str(it[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 16.0
