class_name UIFx
extends RefCounted
## Efeitos de interface baratos (partículas de uma emissão e textos flutuantes).
## A quantidade segue o perfil gráfico: Econômico desliga, Equilibrado padrão, Alto mais denso.

static func level() -> float:
	match Saves.gfx:
		"eco":
			return 0.0
		"high":
			return 1.8
	return 1.0

static func _burst(host: Node, pos: Vector2, amount: int, colors: PackedColorArray, speed: float, grav: float, life: float, size: float) -> void:
	var k := level()
	if k <= 0.0 or not is_instance_valid(host):
		return
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = maxi(4, int(float(amount) * k))
	p.lifetime = life
	p.direction = Vector2(0, -1)
	p.spread = 80.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, grav)
	p.angular_velocity_min = -300.0
	p.angular_velocity_max = 300.0
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(range(colors.size()).map(func(i): return float(i) / maxf(1.0, float(colors.size() - 1))))
	g.colors = colors
	p.color_initial_ramp = g
	p.position = pos
	p.z_index = 100
	host.add_child(p)
	p.emitting = true
	host.get_tree().create_timer(life + 0.3).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free())

static func confetti(host: Node, pos: Vector2) -> void:
	_burst(host, pos, 46, PackedColorArray([Color("ffd23f"), Color("ff6b6b"), Color("5aa9ff"), Color("4cd18a"), Color("c77dff")]), 760.0, 900.0, 1.6, 9.0)

static func coins(host: Node, pos: Vector2) -> void:
	_burst(host, pos, 16, PackedColorArray([Color("ffd23f"), Color("ffb800"), Color("fff2b0")]), 420.0, 700.0, 1.0, 7.0)

static func sparkle(host: Node, pos: Vector2) -> void:
	_burst(host, pos, 14, PackedColorArray([Color("ffffff"), Color("9fd4ff")]), 260.0, 80.0, 0.8, 5.0)

## Texto que sobe e some (ex.: "+ US$ 12.000").
static func float_text(host: Control, pos: Vector2, text: String, color: Color) -> void:
	if level() <= 0.0 or not is_instance_valid(host):
		return
	var l := UI.label(text, 30, color)
	l.position = pos
	l.z_index = 100
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(l)
	var tw := host.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", pos.y - 70.0, 1.1)
	tw.tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)
