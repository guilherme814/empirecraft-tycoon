class_name PositionPad
extends Control
## Vista traseira do aparelho com duas alças arrastáveis: a câmera e o logo. Valores guardados
## no design: cam_x/logo_x em -1..1 (esquerda..direita do aparelho) e cam_y/logo_y em 0..1 (topo..base).
## `moved(key_prefix, x, y, final)`.

signal moved(prefix: String, x: float, y: float, final: bool)

const PAD_W := 200.0
const PAD_H := 380.0
var design: Dictionary = {}
var _drag: String = ""

func _init() -> void:
	custom_minimum_size = Vector2(PAD_W + 40.0, PAD_H + 20.0)
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_design(d: Dictionary) -> void:
	design = d
	queue_redraw()

func _rect() -> Rect2:
	return Rect2(Vector2((size.x - PAD_W) * 0.5, 10.0), Vector2(PAD_W, PAD_H))

func _handle_pos(prefix: String) -> Vector2:
	var r := _rect()
	var x := float(design.get(prefix + "_x", 0.0 if prefix == "logo" else -0.5))
	var y := float(design.get(prefix + "_y", 0.45 if prefix == "logo" else 0.0))
	# vista traseira: a esquerda do modelo aparece à direita
	return r.position + Vector2((1.0 - (x + 1.0) * 0.5) * (r.size.x - 70.0) + 35.0, y * (r.size.y - 90.0) + 45.0)

func _draw() -> void:
	var r := _rect()
	draw_rect(r.grow(5.0), Color(1, 1, 1, 0.12), true)
	draw_rect(r, Color(0.08, 0.1, 0.17, 0.85))
	draw_rect(r, Color(1, 1, 1, 0.5), false, 3.0)
	var f := ThemeDB.fallback_font
	var pc := _handle_pos("cam")
	draw_rect(Rect2(pc - Vector2(28, 28), Vector2(56, 56)), Color("1b2338"))
	draw_rect(Rect2(pc - Vector2(28, 28), Vector2(56, 56)), Palette.ACCENT, false, 4.0)
	draw_circle(pc, 12.0, Color("3a6cff"))
	draw_string(f, pc + Vector2(-26, 50), "Câmera", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.ACCENT)
	var pl := _handle_pos("logo")
	draw_circle(pl, 22.0, Color(1, 1, 1, 0.14))
	draw_arc(pl, 22.0, 0.0, TAU, 32, Color("7fe0ff"), 4.0)
	draw_string(f, pl + Vector2(-20, 6), "logo", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("7fe0ff"))
	draw_string(f, r.position + Vector2(10, r.size.y - 12), "traseira", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.MUTED)

func _gui_input(e: InputEvent) -> void:
	var pos := Vector2.ZERO
	var down := false
	var up := false
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		pos = e.position
		down = e.pressed
		up = not e.pressed
	elif e is InputEventMouseMotion and _drag != "":
		pos = e.position
	elif e is InputEventScreenTouch:
		pos = e.position
		down = e.pressed
		up = not e.pressed
	elif e is InputEventScreenDrag and _drag != "":
		pos = e.position
	else:
		return
	if down:
		var dc := pos.distance_to(_handle_pos("cam"))
		var dl := pos.distance_to(_handle_pos("logo"))
		_drag = "cam" if dc <= dl else "logo"
	if _drag == "":
		return
	var r := _rect()
	var nx := clampf((pos.x - r.position.x - 35.0) / maxf(r.size.x - 70.0, 1.0), 0.0, 1.0)
	var ny := clampf((pos.y - r.position.y - 45.0) / maxf(r.size.y - 90.0, 1.0), 0.0, 1.0)
	var mx := (1.0 - nx) * 2.0 - 1.0
	design[_drag + "_x"] = mx
	design[_drag + "_y"] = ny
	var k := _drag
	if up:
		_drag = ""
	queue_redraw()
	moved.emit(k, mx, ny, up)
	accept_event()
