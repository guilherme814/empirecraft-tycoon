class_name Portrait
extends Control
## Retrato 2D de um funcionário, desenhado por código a partir de Look (a mesma pessoa do boneco 3D).
## Borda por senioridade (bronze/prata/ouro) e expressão pelo moral.

const BG := {
	"engineer": Color("3b2f1c"), "programmer": Color("1f2f4d"),
	"designer": Color("372552"), "researcher": Color("1d3b3a"),
}
const SHIRT := {
	"engineer": Color("2b3f6b"), "programmer": Color("4a4f5c"),
	"designer": Color("7a4fb8"), "researcher": Color("eef1f6"),
}
const TIER_COLORS := [Color("5d6577"), Color("c58a52"), Color("c9d2e0"), Color("ffd23f")]

var _lk: Dictionary = {}
var _prof: String = "engineer"
var _morale: float = 80.0
var _tier: int = 0
var _blink: float = 0.0

static func make(e: Employee, px: int = 120) -> Portrait:
	var p := Portrait.new()
	p.custom_minimum_size = Vector2(px, px)
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	p.set_employee(e)
	return p

func set_employee(e: Employee) -> void:
	_lk = Look.of(e.id, e.emp_name, e.profession)
	_prof = e.profession
	_morale = e.morale
	_tier = Look.tier(e.total())
	queue_redraw()

func _ready() -> void:
	# piscadinha ocasional (barata: só redesenha por ~120 ms)
	var t := Timer.new()
	t.wait_time = 2.6 + float(absi(hash(str(get_instance_id()))) % 20) / 10.0
	t.autostart = true
	t.timeout.connect(func():
		_blink = 1.0
		queue_redraw()
		get_tree().create_timer(0.12).timeout.connect(func():
			_blink = 0.0
			queue_redraw()))
	add_child(t)

func _ell(c: Vector2, rx: float, ry: float, col: Color, s: float, steps: int = 28) -> void:
	var pts := PackedVector2Array()
	for i in steps:
		var a := TAU * float(i) / float(steps)
		pts.append(Vector2(c.x + cos(a) * rx, c.y + sin(a) * ry) * s)
	draw_colored_polygon(pts, col)

func _draw() -> void:
	if _lk.is_empty():
		return
	var s := minf(size.x, size.y)
	var skin: Color = Look.SKIN[int(_lk.skin_i)]
	var hair: Color = Look.HAIR[int(_lk.hair_i)]
	var shirt: Color = SHIRT.get(_prof, SHIRT.engineer)
	var accent := Color("ffd23f") if _prof == "engineer" else (Color("5aa9ff") if _prof == "programmer" else (Color("d94f8a") if _prof == "designer" else Color("2fa59a")))
	if bool(_lk.dye):
		hair = Color("9b59d6")
	var bg: Color = BG.get(_prof, BG.engineer)
	# fundo com brilho
	var box := Palette.box(bg, int(s * 0.16))
	draw_style_box(box, Rect2(Vector2.ZERO, Vector2(s, s)))
	_ell(Vector2(0.5, 0.42), 0.46, 0.5, Color(1, 1, 1, 0.07), s, 36)
	_ell(Vector2(0.5, 0.38), 0.30, 0.34, Color(1, 1, 1, 0.07), s, 36)
	# cabelo de trás (longo/coque/cacheado)
	var style: int = int(_lk.style)
	if style == 2:
		_ell(Vector2(0.5, 0.52), 0.245, 0.32, hair, s)
	elif style == 4:
		_ell(Vector2(0.5, 0.40), 0.27, 0.27, hair, s)
	# ombros / roupa
	_ell(Vector2(0.5, 1.04), 0.36, 0.30, shirt, s)
	if _prof == "programmer":
		_ell(Vector2(0.5, 0.76), 0.2, 0.09, Color("686d7c"), s)               # capuz
	elif _prof == "designer":
		draw_rect(Rect2(Vector2(0.34, 0.74) * s, Vector2(0.32, 0.055) * s), accent)   # lenço
	# pescoço
	draw_rect(Rect2(Vector2(0.44, 0.60) * s, Vector2(0.12, 0.17) * s), skin.darkened(0.10))
	if _prof == "researcher":
		# gola do jaleco + crachá
		draw_colored_polygon(PackedVector2Array([Vector2(0.42, 0.74) * s, Vector2(0.5, 0.92) * s, Vector2(0.36, 0.95) * s]), Color("dfe5ee"))
		draw_colored_polygon(PackedVector2Array([Vector2(0.58, 0.74) * s, Vector2(0.5, 0.92) * s, Vector2(0.64, 0.95) * s]), Color("dfe5ee"))
		draw_rect(Rect2(Vector2(0.62, 0.88) * s, Vector2(0.07, 0.09) * s), accent)
	elif _prof == "engineer":
		draw_rect(Rect2(Vector2(0.28, 0.90) * s, Vector2(0.44, 0.03) * s), Color("e9ecf2"))     # faixa refletiva
		draw_rect(Rect2(Vector2(0.38, 0.78) * s, Vector2(0.05, 0.22) * s), Color("ff8a1f"))
		draw_rect(Rect2(Vector2(0.57, 0.78) * s, Vector2(0.05, 0.22) * s), Color("ff8a1f"))
	# orelhas e cabeça
	_ell(Vector2(0.295, 0.47), 0.035, 0.05, skin.darkened(0.06), s, 14)
	_ell(Vector2(0.705, 0.47), 0.035, 0.05, skin.darkened(0.06), s, 14)
	_ell(Vector2(0.5, 0.45), 0.205, 0.245, skin, s, 36)
	_ell(Vector2(0.5, 0.50), 0.19, 0.19, skin.lightened(0.04), s, 30)
	if bool(_lk.freckles):
		for fx in [0.40, 0.44, 0.56, 0.60]:
			draw_circle(Vector2(fx, 0.55) * s, s * 0.006, skin.darkened(0.25))
	# barba
	var beard: int = int(_lk.beard)
	if beard == 1:
		_ell(Vector2(0.5, 0.60), 0.17, 0.13, hair.lerp(skin, 0.6), s)
		_ell(Vector2(0.5, 0.455), 0.185, 0.10, skin.lightened(0.04), s)
	elif beard == 2:
		_ell(Vector2(0.5, 0.62), 0.195, 0.145, hair, s)
		_ell(Vector2(0.5, 0.455), 0.19, 0.10, skin.lightened(0.04), s)
		_ell(Vector2(0.5, 0.60), 0.075, 0.03, skin.lightened(0.04), s, 16)
	# cabelo da frente
	if _prof != "engineer":
		match style:
			0, 2, 3:
				_ell(Vector2(0.5, 0.285), 0.225, 0.135, hair, s)
				draw_rect(Rect2(Vector2(0.285, 0.30) * s, Vector2(0.03, 0.14) * s), hair)
				draw_rect(Rect2(Vector2(0.685, 0.30) * s, Vector2(0.03, 0.14) * s), hair)
				if style == 3:
					_ell(Vector2(0.5, 0.115), 0.075, 0.075, hair, s, 20)
			1:
				_ell(Vector2(0.5, 0.295), 0.205, 0.10, hair, s)
			4:
				_ell(Vector2(0.5, 0.27), 0.25, 0.15, hair, s)
				for ang in [-0.8, -0.4, 0.0, 0.4, 0.8]:
					draw_circle(Vector2(0.5 + sin(ang) * 0.25, 0.22 - cos(ang) * 0.05 + 0.04) * s, s * 0.055, hair)
			5:
				_ell(Vector2(0.5, 0.285), 0.225, 0.135, hair, s)
				_ell(Vector2(0.44, 0.19), 0.14, 0.07, hair, s, 24)
	else:
		# capacete
		_ell(Vector2(0.5, 0.29), 0.245, 0.15, Color("ffd23f"), s)
		draw_rect(Rect2(Vector2(0.24, 0.335) * s, Vector2(0.52, 0.04) * s), Color("e6b800"))
		draw_rect(Rect2(Vector2(0.47, 0.14) * s, Vector2(0.06, 0.13) * s), Color("e6b800"))
	if _prof == "programmer":
		# fone de ouvido
		draw_arc(Vector2(0.5, 0.40) * s, 0.235 * s, PI * 1.08, PI * 1.92, 24, accent, s * 0.025)
		_ell(Vector2(0.27, 0.47), 0.04, 0.065, accent, s, 16)
		_ell(Vector2(0.73, 0.47), 0.04, 0.065, accent, s, 16)
	# olhos
	var blink: bool = _blink > 0.5
	var eyec: Color = Look.EYES[int(_lk.eye_i)]
	for ex in [0.41, 0.59]:
		if blink:
			draw_line(Vector2(ex - 0.04, 0.485) * s, Vector2(ex + 0.04, 0.485) * s, Color("1c1c24"), s * 0.012)
		else:
			_ell(Vector2(ex, 0.485), 0.042, 0.032, Color("f4f6fa"), s, 16)
			draw_circle(Vector2(ex, 0.487) * s, s * 0.022, eyec)
			draw_circle(Vector2(ex, 0.487) * s, s * 0.011, Color("0e0e12"))
			draw_circle(Vector2(ex + 0.008, 0.478) * s, s * 0.006, Color(1, 1, 1, 0.9))
	# sobrancelhas (inclinam com o moral)
	var tilt := clampf((_morale - 55.0) / 45.0, -1.0, 1.0) * 0.012
	var brow := hair.darkened(0.15)
	draw_line(Vector2(0.365, 0.435 + tilt) * s, Vector2(0.455, 0.43 - tilt) * s, brow, s * 0.014)
	draw_line(Vector2(0.545, 0.43 - tilt) * s, Vector2(0.635, 0.435 + tilt) * s, brow, s * 0.014)
	# nariz
	draw_arc(Vector2(0.5, 0.545) * s, 0.02 * s, 0.2 * PI, 0.8 * PI, 8, skin.darkened(0.2), s * 0.008)
	# bochechas
	if _morale >= 60.0:
		_ell(Vector2(0.36, 0.565), 0.04, 0.025, Color(1.0, 0.45, 0.45, 0.22), s, 12)
		_ell(Vector2(0.64, 0.565), 0.04, 0.025, Color(1.0, 0.45, 0.45, 0.22), s, 12)
	# boca
	var lip := Color("9a4a4a")
	if _morale >= 65.0:
		draw_arc(Vector2(0.5, 0.585) * s, 0.065 * s, PI * 0.18, PI * 0.82, 14, lip, s * 0.012)
	elif _morale >= 35.0:
		draw_line(Vector2(0.455, 0.63) * s, Vector2(0.545, 0.63) * s, lip, s * 0.012)
	else:
		draw_arc(Vector2(0.5, 0.67) * s, 0.055 * s, PI * 1.2, PI * 1.8, 12, lip, s * 0.012)
	if beard == 3 or beard == 2:
		draw_line(Vector2(0.44, 0.60) * s, Vector2(0.56, 0.60) * s, hair, s * 0.02)
	# óculos
	if bool(_lk.glasses):
		var fc := accent if _prof != "researcher" else Color("2a2a30")
		for ex in [0.41, 0.59]:
			draw_rect(Rect2(Vector2(ex - 0.06, 0.45) * s, Vector2(0.12, 0.08) * s), Color(0.85, 0.93, 1.0, 0.16))
			draw_rect(Rect2(Vector2(ex - 0.06, 0.45) * s, Vector2(0.12, 0.08) * s), fc, false, s * 0.01)
		draw_line(Vector2(0.47, 0.475) * s, Vector2(0.53, 0.475) * s, fc, s * 0.01)
	if _prof == "designer":
		draw_circle(Vector2(0.295, 0.53) * s, s * 0.012, Color("ffd23f"))      # brinco
	# borda de senioridade
	var rim := StyleBoxFlat.new()
	rim.bg_color = Color(0, 0, 0, 0)
	rim.set_border_width_all(maxi(2, int(s * (0.035 if _tier >= 2 else 0.022))))
	rim.border_color = TIER_COLORS[_tier]
	rim.set_corner_radius_all(int(s * 0.16))
	draw_style_box(rim, Rect2(Vector2.ZERO, Vector2(s, s)))
	if _tier == 3:
		# estrelinha de mestre
		draw_circle(Vector2(0.86, 0.14) * s, s * 0.07, Color("ffd23f"))
		draw_circle(Vector2(0.86, 0.14) * s, s * 0.035, Color("fff2b0"))
