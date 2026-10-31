class_name StoreScene
extends OfficeScene
## Prévia 3D de uma loja: tamanho, fachada e equipe mudam o cenário. Reaproveita câmera, malhas e
## funcionários do escritório. Só visual: a economia da loja vive em Stores.

const THEMES := {
	"minimal": {"floor_a": Color("c9ced8"), "floor_b": Color("bfc5d1"), "wall": Color("eceff5"), "accent": Color("5aa9ff"), "sign": Color("20263a"), "shelf": Color("d9dde6")},
	"industrial": {"floor_a": Color("4a4d57"), "floor_b": Color("42454f"), "wall": Color("6d717d"), "accent": Color("ff9a2e"), "sign": Color("23262e"), "shelf": Color("2d3039")},
	"luxury": {"floor_a": Color("d8c8a8"), "floor_b": Color("cdbb98"), "wall": Color("1f2a4a"), "accent": Color("e0b252"), "sign": Color("141b33"), "shelf": Color("7a5a3a")},
	"tech": {"floor_a": Color("262b36"), "floor_b": Color("2c323f"), "wall": Color("3a4150"), "accent": Color("4cd18a"), "sign": Color("171b24"), "shelf": Color("e6eaf2")},
}
const DIMS := {"kiosk": Vector2(5.0, 4.6), "store": Vector2(8.0, 6.6), "flagship": Vector2(11.0, 8.6)}

var _key: String = ""

func _tick_only(dt: float) -> void:
	_now += dt
	for id in workers:
		(workers[id] as OfficeWorker).tick(dt, _now)

func step(dt: float) -> void:
	_tick_only(dt)

func show_store(spec: Dictionary, released: int, country_color: Color) -> void:
	var key := "%s|%d|%s" % [str(spec), released, str(logo)]
	if key == _key or _static_root == null:
		return
	_key = key
	for id in workers.keys():
		(workers[id] as OfficeWorker).queue_free()
	workers.clear()
	for ch in _static_root.get_children():
		_static_root.remove_child(ch)
		ch.queue_free()
	var th: Dictionary = THEMES.get(str(spec.facade), THEMES.minimal)
	var dim: Vector2 = DIMS.get(str(spec.size), DIMS.kiosk)
	var W := dim.x
	var D := dim.y
	room_w = W
	room_d = D
	var f := MeshBuilder.new()
	var e := MeshBuilder.new()
	var g := MeshBuilder.new()
	var acc: Color = th.accent
	# laje, piso xadrez e faixa com a cor do país
	f.box(Vector3(W * 0.5, -0.2, D * 0.5), Vector3(W + 0.44, 0.34, D + 0.44), Color("171c2e"), 0.0, 0.0)
	var t := 1.0
	for i in int(ceil(W / t)):
		for j in int(ceil(D / t)):
			var w := minf(t, W - float(i) * t)
			var d := minf(t, D - float(j) * t)
			f.box(Vector3(float(i) * t + w * 0.5, -0.004, float(j) * t + d * 0.5), Vector3(w, 0.008, d), th.floor_a if (i + j) % 2 == 0 else th.floor_b, 0.0, 0.0)
	e.box(Vector3(W * 0.5, 0.03, D + 0.1), Vector3(W + 0.44, 0.05, 0.06), country_color, 0.0, 0.0)
	e.box(Vector3(W + 0.1, 0.03, D * 0.5), Vector3(0.06, 0.05, D + 0.44), country_color, 0.0, 0.0)
	# paredes (fundo e lateral) com vitrine de vidro na lateral
	var H := 2.1
	f.box(Vector3(W * 0.5, H * 0.5, -0.11), Vector3(W + 0.22, H, 0.22), th.wall, 0.0, 0.05)
	f.box(Vector3(-0.11, H * 0.5, D * 0.5), Vector3(0.22, H, D + 0.22), th.wall, 0.0, 0.05)
	f.box(Vector3(-0.11, 0.3, D * 0.5), Vector3(0.24, 0.6, D), th.wall.darkened(0.15), 0.0, 0.0)
	g.box(Vector3(-0.02, 1.25, D * 0.5), Vector3(0.05, 1.3, D - 0.8), Color(0.62, 0.8, 1.0, 0.22), 0.0, 0.0)
	# letreiro com o logotipo da empresa
	var sw := minf(W - 0.8, 4.2)
	var c1 := Color(str(logo.c1))
	f.box(Vector3(W * 0.5, 1.75, 0.04), Vector3(sw, 0.5, 0.08), Color(str(logo.c2)), 0.0, 0.0)
	e.box(Vector3(W * 0.5, 1.48, 0.085), Vector3(sw, 0.035, 0.01), c1, 0.0, 0.0)
	e.poly(Identity.points(str(logo.symbol)), Vector3(W * 0.5 - sw * 0.5 + 0.33, 1.76, 0.09), 0.17, c1)
	var L := Label3D.new()
	L.text = Identity.format_name(str(spec.name) if str(spec.name) != "" else "LOJA", str(logo.style))
	L.font_size = 96
	L.pixel_size = clampf((sw - 0.9) / (0.62 * 96.0 * float(maxi(L.text.length(), 4))), 0.002, 0.0075)
	L.modulate = c1
	L.shaded = false
	L.position = Vector3(W * 0.5 + 0.25, 1.78, 0.095)
	_static_root.add_child(L)
	# prateleiras de produtos na parede do fundo
	var shelves := {"kiosk": 1, "store": 2, "flagship": 3}[str(spec.size)] as int
	for k in shelves:
		var x := W * (float(k) + 0.5) / float(shelves)
		if str(spec.size) == "kiosk":
			x = W * 0.5
		f.box(Vector3(x, 0.7, 0.3), Vector3(minf(2.0, W / float(shelves) - 0.3), 1.4, 0.4), th.shelf, 0.0, 0.1)
		for r in 3:
			f.box(Vector3(x, 0.3 + float(r) * 0.4, 0.5), Vector3(minf(1.9, W / float(shelves) - 0.4), 0.03, 0.34), th.shelf.darkened(0.25), 0.0, 0.0)
			for d in 4:
				var dx := x - 0.7 + float(d) * 0.46
				if dx > x + minf(1.9, W / float(shelves) - 0.4) * 0.5:
					continue
				e.box(Vector3(dx, 0.4 + float(r) * 0.4, 0.515), Vector3(0.16, 0.2, 0.02), acc if (d + r + k) % 2 == 0 else Color("5aa9ff"), 0.0, 0.0)
	# mesas de demonstração
	var tables := {"kiosk": 0, "store": 1, "flagship": 2}[str(spec.size)] as int
	for k in tables:
		var tx := W * (0.3 + 0.4 * float(k)) if tables == 2 else W * 0.35
		var tz := D * 0.5
		f.box(Vector3(tx, 0.42, tz), Vector3(1.6, 0.06, 0.8), Color("e9ecf2"), 0.0, 0.0)
		f.box(Vector3(tx, 0.2, tz), Vector3(1.4, 0.4, 0.6), th.sign.lightened(0.1), 0.0, 0.1)
		for d in 3:
			f.box(Vector3(tx - 0.5 + float(d) * 0.5, 0.47, tz), Vector3(0.22, 0.02, 0.16), Color("1c2030"), 0.0, 0.0)
			e.box(Vector3(tx - 0.5 + float(d) * 0.5, 0.485, tz), Vector3(0.2, 0.005, 0.14), acc, 0.0, 0.0)
	# balcão do caixa
	var cx := W - 1.7
	var cz := D * 0.42
	f.box(Vector3(cx, 0.3, cz), Vector3(2.0, 0.6, 0.6), th.sign.lightened(0.08), 0.0, 0.1)
	f.box(Vector3(cx, 0.62, cz), Vector3(2.08, 0.05, 0.68), th.shelf, 0.0, 0.0)
	e.box(Vector3(cx, 0.3, cz + 0.305), Vector3(1.4, 0.18, 0.01), acc, 0.0, 0.0)
	f.box(Vector3(cx - 0.5, 0.78, cz), Vector3(0.28, 0.2, 0.04), Color("20242e"))
	# plantas, capacho, placa na calçada
	for pos in [Vector3(W - 0.5, 0, 0.6), Vector3(0.6, 0, D - 0.6), Vector3(W - 0.5, 0, D - 0.6)]:
		_store_plant(f, pos)
	f.box(Vector3(W * 0.5, 0.02, D - 0.4), Vector3(1.4, 0.02, 0.6), th.sign, 0.0, 0.0)
	f.box(Vector3(W * 0.5, 0.032, D - 0.4), Vector3(1.2, 0.01, 0.4), acc, 0.0, 0.0)
	for pair in [[f, "lit"], [e, "emissive"], [g, "glass"]]:
		var b: MeshBuilder = pair[0]
		if b.is_empty():
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = b.build()
		mi.material_override = MeshBuilder.material(pair[1])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_static_root.add_child(mi)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(W * 0.5, 1.8, D * 0.5)
	lamp.light_color = Color("ffe2b8")
	lamp.light_energy = 0.8
	lamp.omni_range = maxf(W, D)
	_static_root.add_child(lamp)
	# equipe atrás do balcão e clientes
	var staff := int(spec.staff)
	for i in staff:
		var w := _person(7000 + i, "programmer" if i % 2 == 0 else "designer", "Vendedor")
		w.place_standing(Vector3(cx - 0.8 + float(i % 3) * 0.8, 0, cz - 0.65 - float(i / 3) * 0.7), PI)
	var cust := {"kiosk": 1, "store": 2, "flagship": 4}[str(spec.size)] as int
	for i in cust:
		var w := _person(8000 + i * 5, "engineer" if i % 2 == 0 else "researcher", "Cliente")
		var cxp := 1.2 + float(i) * 1.15 if str(spec.size) != "kiosk" else W * 0.4
		w.place_standing(Vector3(cxp, 0, D * 0.62 + float(i % 2) * 0.7), PI + 0.4 * float(i % 3 - 1))
	_fit()

func _person(id: int, prof: String, nm: String) -> OfficeWorker:
	var w := OfficeWorker.new()
	_world.add_child(w)
	w.setup(id, prof, nm)
	workers[id] = w
	return w

func _store_plant(f: MeshBuilder, pos: Vector3) -> void:
	f.prism(pos + Vector3(0, 0.12, 0), 0.15, 0.24, 8, Color("d8d4cc"), 0.0, Color("3a2a20"))
	for k in 6:
		var a := TAU * float(k) / 6.0 + 0.3
		f.box(pos + Vector3(cos(a) * 0.11, 0.36 + 0.05 * float(k % 3), sin(a) * 0.11), Vector3(0.1, 0.34, 0.1), Color("4aa65e") if k % 2 == 0 else Color("2f8a4a"), a, 0.0, 0.35)
