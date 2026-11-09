class_name ColorPicker2D
extends Control
## Seletor de cor livre: quadrado de saturação/brilho + barra de matiz. Funciona com toque.
## `changed(color, final)`: final=true quando o dedo é solto.

signal changed(color: Color, final: bool)

const SV_H := 230.0
const BAR_H := 52.0
const GAP := 18.0

var hue: float = 0.6
var sat: float = 0.7
var val: float = 0.9
var _drag: String = ""

func _init() -> void:
	custom_minimum_size = Vector2(0, SV_H + GAP + BAR_H + 6.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_color(c: Color) -> void:
	hue = c.h
	sat = c.s
	val = c.v
	queue_redraw()

func color() -> Color:
	return Color.from_hsv(hue, sat, val)

func _draw() -> void:
	var w := size.x
	var r := Rect2(0, 0, w, SV_H)
	# base: branco → matiz puro; por cima: transparente → preto
	var pure := Color.from_hsv(hue, 1.0, 1.0)
	draw_polygon(PackedVector2Array([r.position, Vector2(w, 0), Vector2(w, SV_H), Vector2(0, SV_H)]),
		PackedColorArray([Color.WHITE, pure, pure, Color.WHITE]))
	draw_polygon(PackedVector2Array([r.position, Vector2(w, 0), Vector2(w, SV_H), Vector2(0, SV_H)]),
		PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color.BLACK, Color.BLACK]))
	draw_rect(r, Color(1, 1, 1, 0.25), false, 2.0)
	var p := Vector2(sat * w, (1.0 - val) * SV_H)
	draw_circle(p, 17.0, Color(0, 0, 0, 0.35))
	draw_circle(p, 14.0, Color.WHITE)
	draw_circle(p, 10.0, color())
	# barra de matiz
	var by := SV_H + GAP
	var seg := 12
	for i in seg:
		var x0 := w * float(i) / float(seg)
		var x1 := w * float(i + 1) / float(seg)
		var c0 := Color.from_hsv(float(i) / float(seg), 1, 1)
		var c1 := Color.from_hsv(float(i + 1) / float(seg), 1, 1)
		draw_polygon(PackedVector2Array([Vector2(x0, by), Vector2(x1, by), Vector2(x1, by + BAR_H), Vector2(x0, by + BAR_H)]),
			PackedColorArray([c0, c1, c1, c0]))
	draw_rect(Rect2(0, by, w, BAR_H), Color(1, 1, 1, 0.25), false, 2.0)
	var hx := hue * w
	draw_rect(Rect2(hx - 8.0, by - 6.0, 16.0, BAR_H + 12.0), Color.WHITE)
	draw_rect(Rect2(hx - 5.0, by - 3.0, 10.0, BAR_H + 6.0), Color.from_hsv(hue, 1, 1))

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
		_drag = "sv" if pos.y < SV_H + GAP * 0.5 else "hue"
	if _drag == "":
		return
	if _drag == "sv":
		sat = clampf(pos.x / maxf(size.x, 1.0), 0.0, 1.0)
		val = 1.0 - clampf(pos.y / SV_H, 0.0, 1.0)
	else:
		hue = clampf(pos.x / maxf(size.x, 1.0), 0.0, 0.999)
	queue_redraw()
	if up:
		_drag = ""
	changed.emit(color(), up)
	accept_event()
