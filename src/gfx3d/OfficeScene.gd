class_name OfficeScene
extends SubViewportContainer
## Escritório 3D da empresa: cenário compacto em câmera isométrica, montado sozinho a partir da
## equipe. Não tem construção livre: baias, decoração e áreas comuns crescem com a empresa.
## Não depende dos autoloads: a página chama sync(company) quando algo muda.

signal worker_selected(emp_id: int)

const PROF_COLORS := {
	"engineer": Color("ff9a2e"), "programmer": Color("5aa9ff"),
	"designer": Color("c792ea"), "researcher": Color("3fcfb4"),
}
const FLOOR_A := Color("2a3350")
const FLOOR_B := Color("2f3858")
const WALL := Color("c6d0e2")
const WALL_TRIM := Color("8f9bb3")
const DESK := Color("e6eaf2")
const DESK_EDGE := Color("aeb8cc")
const METAL := Color("1f2430")
const WOOD := Color("a87c58")
const ACCENT := Color("ff9a2e")
const STAGE_NAMES := ["Início", "Crescimento", "Empresa avançada", "Grande empresa"]
const PITCH_DEG := 32.0
const YAW_DEG := 45.0

var layout: OfficeLayout
var workers: Dictionary = {}
var rng := RandomNumberGenerator.new()
var zoom: float = 1.0
var selected_id: int = -1
var company_name: String = "Device Empire"
var hidden_staff: int = 0
var events_enabled: bool = true   # pausas e conversas (desligável nos testes)

var _vp: SubViewport
var _cam: Camera3D
var _world: Node3D
var _static_root: Node3D
var _screens_mi: MeshInstance3D
var _ring: MeshInstance3D
var _sel_label: Label3D
var _lights: Array = []
var _now: float = 0.0
var _first: bool = true
var _layout_sig: String = ""
var _staff_sig: String = ""
var _pan: Vector2 = Vector2.ZERO
var _ext: Vector2 = Vector2(10, 10)
var _center2: Vector2 = Vector2.ZERO
var _spot_busy: Dictionary = {}
var _seat_of: Dictionary = {}     # emp id -> índice do assento (estável enquanto a planta não muda)
var _seat_prof: Dictionary = {}   # seat index -> emp id (ocupação)
var _released: int = 0
var _press_pos: Vector2 = Vector2.ZERO
var _press_t: int = 0
var _dragging: bool = false
var _staff_total: int = 0
var room_w: float = 10.0
var room_d: float = 10.0


func _ready() -> void:
	stretch = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(300, 300)
	rng.seed = 20260101
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_vp)
	_world = Node3D.new()
	_vp.add_child(_world)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0b0f1c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.66, 0.70, 0.84)
	env.ambient_light_energy = 0.82
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	_cam = Camera3D.new()
	_cam.environment = env
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.near = 0.1
	_cam.far = 300.0
	_cam.basis = Basis.from_euler(Vector3(deg_to_rad(-PITCH_DEG), deg_to_rad(YAW_DEG), 0.0))
	_vp.add_child(_cam)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 28, 0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.05
	_vp.add_child(sun)

	_static_root = Node3D.new()
	_world.add_child(_static_root)
	_screens_mi = MeshInstance3D.new()
	_screens_mi.material_override = MeshBuilder.material("emissive")
	_screens_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(_screens_mi)

	_ring = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	_ring.mesh = q
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.62, 0.74, 0.92, 1.0])
	grad.colors = PackedColorArray([Color(1, 0.6, 0.18, 0.0), Color(1, 0.6, 0.18, 0.0), Color(1, 0.6, 0.18, 0.95), Color(1, 0.6, 0.18, 0.85), Color(1, 0.6, 0.18, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	rm.albedo_texture = gt
	_ring.material_override = rm
	_ring.rotation_degrees = Vector3(-90, 0, 0)
	_ring.visible = false
	_world.add_child(_ring)
	_sel_label = Label3D.new()
	_sel_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sel_label.font_size = 64
	_sel_label.pixel_size = 0.0075
	_sel_label.outline_size = 16
	_sel_label.outline_modulate = Color("0b0f1c")
	_sel_label.modulate = Color("ffd9a8")
	_sel_label.no_depth_test = true
	_sel_label.visible = false
	_world.add_child(_sel_label)

	gui_input.connect(_on_gui_input)
	resized.connect(_fit)

# ───────────── sincronização com a empresa ─────────────

func sync(c: Company) -> void:
	company_name = c.company_name
	var order: Array = []
	var raw := {}
	var lvl := 1
	for p in GameData.professions():
		order.append(str(p.id))
		raw[str(p.id)] = c.staff_of(str(p.id)).size()
		lvl = maxi(lvl, int(c.office_level.get(str(p.id), 1)))
	_staff_total = c.staff.size()
	var stage := OfficeLayout.stage_for(_staff_total, lvl)
	var lim := OfficeLayout.limit_counts(raw, order, OfficeLayout.MAX_VISIBLE)
	hidden_staff = _staff_total - _sum(lim)
	var rel := 0
	for p in c.released_products():
		rel += 1
	var psig: Array = []
	for pid in order:
		psig.append((int(lim[pid]) + 1) / 2)
	var lsig := "%s|%d|%d" % [str(psig), stage, mini(rel, 4)]
	var rebuilt := false
	if lsig != _layout_sig or layout == null:
		_layout_sig = lsig
		_released = mini(rel, 4)
		layout = OfficeLayout.build(raw, order, stage)
		rebuilt = true
		_spot_busy.clear()
		room_w = layout.width
		room_d = layout.depth
		_build_static()
		_fit()
	_sync_workers(c, order, lim, rebuilt)
	_first = false

func _sum(d: Dictionary) -> int:
	var n := 0
	for k in d:
		n += int(d[k])
	return n

func _sync_workers(c: Company, order: Array, lim: Dictionary, rebuilt: bool) -> void:
	var want := {}
	if rebuilt:
		_seat_of.clear()
	_seat_prof.clear()
	for prof in order:
		var list: Array = c.staff_of(prof).duplicate()
		list.sort_custom(func(a, b): return a.id < b.id)
		var n := mini(list.size(), int(lim.get(prof, 0)))
		var seats: Array = layout.seats_by_prof.get(prof, [])
		var used := {}
		for i in n:
			var sid: int = int((_seat_of.get(list[i].id, -1)))
			if sid != -1 and seats.has(sid) and not used.has(sid):
				used[sid] = true
		for i in n:
			var e: Employee = list[i]
			var si: int = int(_seat_of.get(e.id, -1))
			if si == -1 or not seats.has(si) or _seat_prof.has(si):
				si = -1
				for cand in seats:
					if not used.has(int(cand)) and not _seat_prof.has(int(cand)):
						si = int(cand)
						break
				if si == -1:
					continue
				used[si] = true
			_seat_of[e.id] = si
			want[e.id] = true
			_seat_prof[si] = e.id
			var seat: Dictionary = layout.seats[si]
			var w: OfficeWorker = workers.get(e.id, null)
			if w == null:
				w = _spawn(e)
				if _first:
					w.place_seated(seat)
				else:
					w.seat = seat
					w.position = layout.door.pos
					w.sit_t = 0.0
					w.mode = "walking"
					w.go_path(OfficeLayout.route_spot_to_seat(layout.door, seat), "seat")
			else:
				w.emp_name = e.emp_name
				var moved := int(w.seat.get("i", -1)) != si or rebuilt
				w.seat = seat
				if moved and w.kind != "leave":
					w.place_seated(seat)
					w.event_timer = rng.randf_range(10.0, 40.0)
	for id in _seat_of.keys():
		if not want.has(id):
			_seat_of.erase(id)
	# quem saiu da equipe caminha até a porta e some
	for id in workers.keys():
		if want.has(id):
			continue
		var w: OfficeWorker = workers[id]
		if w.kind == "leave":
			continue
		if rebuilt or w.is_away() or _first:
			_remove(id)
			continue
		_release_spots_of(id)
		w.go_path(OfficeLayout.route_seat_to(w.seat, layout.door), "leave")
	if selected_id != -1 and not workers.has(selected_id):
		select(-1)
	_build_screens()

func _spawn(e: Employee) -> OfficeWorker:
	var w := OfficeWorker.new()
	_world.add_child(w)
	w.setup(e.id, e.profession, e.emp_name)
	w.event_timer = rng.randf_range(8.0, 40.0)
	workers[e.id] = w
	return w

func _remove(id: int) -> void:
	var w: OfficeWorker = workers.get(id, null)
	if w != null:
		w.queue_free()
	workers.erase(id)
	_release_spots_of(id)

func _release_spots_of(id: int) -> void:
	for sid in _spot_busy.keys():
		if int(_spot_busy[sid]) == id:
			_spot_busy.erase(sid)

# ───────────── câmera ─────────────

func _fit() -> void:
	if _cam == null:
		return
	var cb := _cam.basis
	var right := cb.x
	var up := cb.y
	var W := room_w
	var D := room_d + 2.2
	var corners: Array = []
	for x in [-0.3, W]:
		for z in [-0.3, D]:
			for y in [-0.35, OfficeLayout.WALL_H]:
				corners.append(Vector3(x, y, z))
	var rmin := 1e9
	var rmax := -1e9
	var umin := 1e9
	var umax := -1e9
	for p in corners:
		var r := (p as Vector3).dot(right)
		var u := (p as Vector3).dot(up)
		rmin = minf(rmin, r)
		rmax = maxf(rmax, r)
		umin = minf(umin, u)
		umax = maxf(umax, u)
	_center2 = Vector2((rmin + rmax) * 0.5, (umin + umax) * 0.5)
	_ext = Vector2(rmax - rmin, umax - umin)
	_apply_cam()

func _apply_cam() -> void:
	var vs := Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))
	var sz := maxf(_ext.y, _ext.x * vs.y / vs.x) * 1.07 / zoom
	_cam.size = sz
	var lim := Vector2(_ext.x, _ext.y) * 0.5
	_pan.x = clampf(_pan.x, -lim.x, lim.x)
	_pan.y = clampf(_pan.y, -lim.y, lim.y)
	var fwd := -_cam.basis.z
	var target := _cam.basis.x * (_center2.x + _pan.x) + _cam.basis.y * (_center2.y + _pan.y)
	_cam.position = target - fwd * 80.0

func set_zoom(z: float) -> void:
	zoom = clampf(z, 1.0, 3.5)
	if zoom <= 1.001:
		_pan = Vector2.ZERO
	_apply_cam()

func reset_view() -> void:
	_pan = Vector2.ZERO
	set_zoom(1.0)

# ───────────── entrada ─────────────

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press_pos = mb.position
				_press_t = Time.get_ticks_msec()
				_dragging = false
			else:
				if not _dragging and Time.get_ticks_msec() - _press_t < 500:
					_tap(mb.position)
				_dragging = false
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			set_zoom(zoom * 1.12)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			set_zoom(zoom / 1.12)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		var mm := event as InputEventMouseMotion
		if _dragging or mm.position.distance_to(_press_pos) > 14.0:
			_dragging = true
			var upp := _cam.size / maxf(size.y, 1.0)
			_pan -= Vector2(mm.relative.x, -mm.relative.y) * upp
			_apply_cam()
		accept_event()
	elif event is InputEventMagnifyGesture:
		set_zoom(zoom * (event as InputEventMagnifyGesture).factor)
		accept_event()

func _tap(pos: Vector2) -> void:
	select(pick(pos))

## Funcionário mais próximo do ponto da tela (em pixels do próprio quadro), ou -1.
func pick(pos: Vector2) -> int:
	var best := -1
	var best_d := 1e9
	var px_per_unit := maxf(size.y, 1.0) / maxf(_cam.size, 0.1)
	var radius := maxf(30.0, 0.6 * px_per_unit)
	for id in workers:
		var w: OfficeWorker = workers[id]
		if not w.visible:
			continue
		var sp := _cam.unproject_position(w.global_position + Vector3(0, 0.55, 0))
		var d := sp.distance_to(pos)
		if d < radius and d < best_d:
			best_d = d
			best = int(id)
	return best

func select(id: int) -> void:
	selected_id = id
	_ring.visible = id != -1
	_sel_label.visible = id != -1
	if id != -1 and workers.has(id):
		_sel_label.text = (workers[id] as OfficeWorker).emp_name
	worker_selected.emit(id)

# ───────────── simulação visual ─────────────

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	step(minf(delta, 0.1))

func step(dt: float) -> void:
	if layout == null:
		return
	_now += dt
	for id in workers.keys():
		var w: OfficeWorker = workers[id]
		w.tick(dt, _now)
		if w.flag_gone:
			_remove(id)
	for sid in _spot_busy.keys():
		var w2: OfficeWorker = workers.get(_spot_busy[sid], null)
		if w2 == null or (w2.mode == "work" and w2.kind == "work"):
			_spot_busy.erase(sid)
	for id in workers.keys():
		var w3: OfficeWorker = workers[id]
		if events_enabled and w3.mode == "work" and w3.event_timer <= 0.0:
			_try_event(w3)
	if selected_id != -1 and workers.has(selected_id):
		var sw: OfficeWorker = workers[selected_id]
		_ring.position = Vector3(sw.position.x, 0.03, sw.position.z)
		_sel_label.position = sw.global_position + Vector3(0, 1.18, 0)

func _away_count() -> int:
	var n := 0
	for id in workers:
		var w: OfficeWorker = workers[id]
		if w.kind == "break" or w.kind == "chat":
			n += 1
	return n

func _try_event(w: OfficeWorker) -> void:
	w.event_timer = rng.randf_range(18.0, 50.0)
	if _away_count() >= maxi(1, int(float(workers.size()) * 0.3)):
		return
	if rng.randf() < 0.45 and _try_chat(w):
		return
	_try_break(w)

func _free_spots(kind: String) -> Array:
	var out: Array = []
	for s in layout.spots:
		if str(s.kind) == kind and not _spot_busy.has(int(s.id)):
			out.append(s)
	return out

func _try_break(w: OfficeWorker) -> bool:
	var free := _free_spots("break")
	if free.is_empty():
		return false
	var sp: Dictionary = free[rng.randi() % free.size()]
	_spot_busy[int(sp.id)] = w.emp_id
	w.go_spot(OfficeLayout.route_seat_to(w.seat, sp), sp, rng.randf_range(9.0, 18.0),
		OfficeLayout.route_spot_to_seat(sp, w.seat), "break")
	return true

func _try_chat(w: OfficeWorker) -> bool:
	var cands: Array = []
	for id in workers:
		var o: OfficeWorker = workers[id]
		if o != w and o.mode == "work" and o.kind == "work":
			cands.append(o)
	if cands.is_empty():
		return false
	var pairs: Array = []
	for s in _free_spots("chat"):
		var other := int(s.pair)
		if other > int(s.id) and not _spot_busy.has(other):
			pairs.append(s)
	if pairs.is_empty():
		return false
	var a: Dictionary = pairs[rng.randi() % pairs.size()]
	var b: Dictionary = layout.spots[int(a.pair)]
	var p: OfficeWorker = cands[rng.randi() % cands.size()]
	var dur := rng.randf_range(8.0, 14.0)
	_spot_busy[int(a.id)] = w.emp_id
	_spot_busy[int(b.id)] = p.emp_id
	w.partner = p
	p.partner = w
	w.speak_offset = 0.0
	p.speak_offset = 1.0
	w.go_spot(OfficeLayout.route_seat_to(w.seat, a), a, dur, OfficeLayout.route_spot_to_seat(a, w.seat), "chat")
	p.go_spot(OfficeLayout.route_seat_to(p.seat, b), b, dur, OfficeLayout.route_spot_to_seat(b, p.seat), "chat")
	return true

func counts_by_kind() -> Dictionary:
	var out := {"work": 0, "break": 0, "chat": 0, "enter": 0, "leave": 0}
	for id in workers:
		var k := (workers[id] as OfficeWorker).kind
		out[k] = int(out.get(k, 0)) + 1
	return out

# ───────────── cenário ─────────────

func _build_static() -> void:
	for ch in _static_root.get_children():
		_static_root.remove_child(ch)
		ch.queue_free()
	_lights.clear()
	var f := MeshBuilder.new()   # móveis (iluminado)
	var e := MeshBuilder.new()   # luzes e telas fixas
	var g := MeshBuilder.new()   # vidro
	_floor(f, e)
	_walls(f, g, e)
	for pod in layout.pods:
		_pod(f, pod)
	_common_areas(f, e, g)
	_decor(f, e)
	_sign_board(f, e)
	for pair in [[f, "lit"], [e, "emissive"], [g, "glass"]]:
		var b: MeshBuilder = pair[0]
		if b.is_empty():
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = b.build()
		mi.material_override = MeshBuilder.material(pair[1])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_static_root.add_child(mi)
	_add_labels()
	_add_lights()

func _add_lights() -> void:
	var fl := layout.front_lane
	var spots: Array = [Vector3(layout.slot_center_x(0), 1.5, fl + 2.0), Vector3(layout.slot_center_x(1), 1.4, fl + 1.2)]
	if layout.stage >= 3:
		spots.append(Vector3(layout.slot_center_x(mini(4, layout.cols - 1)), 1.6, fl + 2.0))
	for p in spots:
		var l := OmniLight3D.new()
		l.position = p
		l.light_color = Color("ffc58a")
		l.light_energy = 0.9
		l.omni_range = 3.8
		_static_root.add_child(l)

func _sign_board(f: MeshBuilder, e: MeshBuilder) -> void:
	var sw := minf(3.6, layout.width * 0.4)
	f.box(Vector3(layout.width * 0.5, 1.9, 0.03), Vector3(sw, 0.34, 0.06), Color("1b2036"), 0.0, 0.0)
	e.box(Vector3(layout.width * 0.5, 1.7, 0.062), Vector3(sw, 0.03, 0.01), ACCENT, 0.0, 0.0)

func _add_labels() -> void:
	var L := Label3D.new()
	L.text = company_name.to_upper()
	L.font_size = 96
	var sw := minf(3.6, layout.width * 0.4)
	L.pixel_size = clampf(sw * 0.9 / (0.62 * 96.0 * float(maxi(company_name.length(), 4))), 0.002, 0.0075)
	L.modulate = Color("ffb35c")
	L.outline_size = 0
	L.shaded = false
	L.double_sided = false
	L.position = Vector3(layout.width * 0.5, 1.9, 0.075)
	_static_root.add_child(L)

func _floor(f: MeshBuilder, e: MeshBuilder) -> void:
	var W := layout.width
	var D := layout.depth
	# laje
	f.box(Vector3(W * 0.5, -0.2, D * 0.5), Vector3(W + 0.44, 0.34, D + 0.44), Color("171c2e"), 0.0, 0.0)
	# carpete xadrez
	var t := 1.3
	var nx := int(ceil(W / t))
	var nz := int(ceil(D / t))
	for i in nx:
		for j in nz:
			var w := minf(t, W - float(i) * t)
			var d := minf(t, D - float(j) * t)
			f.box(Vector3(float(i) * t + w * 0.5, -0.004, float(j) * t + d * 0.5), Vector3(w, 0.008, d), FLOOR_A if (i + j) % 2 == 0 else FLOOR_B, 0.0, 0.0)
	# tapetes coloridos sob cada baia
	for pod in layout.pods:
		var col: Color = PROF_COLORS.get(str(pod.prof), Color("39415f"))
		col = col.darkened(0.55) if str(pod.prof) != "" else Color("333b57")
		f.box(Vector3(float(pod.cx), 0.011, float(pod.cz)), Vector3(2.2, 0.01, 2.9), col, 0.0, 0.0)
	# faixa laranja na borda da frente
	e.box(Vector3(W * 0.5, 0.03, D + 0.1), Vector3(W + 0.44, 0.05, 0.06), ACCENT.darkened(0.15), 0.0, 0.0)
	e.box(Vector3(W + 0.1, 0.03, D * 0.5), Vector3(0.06, 0.05, D + 0.44), ACCENT.darkened(0.15), 0.0, 0.0)
	# capacho da entrada
	f.box(Vector3(OfficeLayout.OX, 0.02, D - 0.35), Vector3(1.1, 0.02, 0.6), Color("20242e"), 0.0, 0.0)
	f.box(Vector3(OfficeLayout.OX, 0.032, D - 0.35), Vector3(0.9, 0.01, 0.4), ACCENT.darkened(0.3), 0.0, 0.0)

func _wall_run(f: MeshBuilder, g: MeshBuilder, e: MeshBuilder, along_x: bool, length: float) -> void:
	# parede com janelas ao longo de `length`. along_x: parede em z=0; senão em x=0.
	var H := OfficeLayout.WALL_H
	var th := 0.22
	var n := maxi(1, int(floor((length - 0.5) / 2.1)))
	var step := (length - 0.5) / float(n)
	var pier := 0.5
	for k in n + 1:
		var a := float(k) * step
		_wbox(f, along_x, a + pier * 0.5, pier, 0.0, H, th, WALL)
	for k in n:
		var a := float(k) * step + pier
		var wl := step - pier
		_wbox(f, along_x, a + wl * 0.5, wl, 0.0, 0.55, th, WALL)
		_wbox(f, along_x, a + wl * 0.5, wl, 1.7, H, th, WALL)
		# vidro e peitoril
		_wbox(g, along_x, a + wl * 0.5, wl, 0.55, 1.7, 0.05, Color(0.62, 0.8, 1.0, 0.26))
		_wbox(f, along_x, a + wl * 0.5, wl + 0.04, 0.53, 0.58, th + 0.1, Color("e6ebf5"))
		# céu/cidade ao fundo da janela (atrás do vidro, sem brigar com ele)
		_wbox(e, along_x, a + wl * 0.5, wl, 0.55, 1.7, 0.01, Color("2c4272"), 0.12)
		_wbox(e, along_x, a + wl * 0.5, wl, 0.55, 0.9, 0.01, Color("21335c"), 0.13)
	# rodapé e capa
	var cap := WALL_TRIM
	if along_x:
		f.box(Vector3(length * 0.5 - 0.11, H + 0.03, -th * 0.5), Vector3(length + th, 0.07, th + 0.04), Color("e8edf7"), 0.0, 0.0)
		f.box(Vector3(length * 0.5, 0.1, 0.03), Vector3(length, 0.2, 0.06), cap, 0.0, 0.0)
	else:
		f.box(Vector3(-th * 0.5, H + 0.03, length * 0.5 - 0.11), Vector3(th + 0.04, 0.07, length + th), Color("e8edf7"), 0.0, 0.0)
		f.box(Vector3(0.03, 0.1, length * 0.5), Vector3(0.06, 0.2, length), cap, 0.0, 0.0)

func _wbox(b: MeshBuilder, along_x: bool, mid: float, len: float, y0: float, y1: float, th: float, col: Color, off: float = 0.0) -> void:
	var h := y1 - y0
	if along_x:
		b.box(Vector3(mid, y0 + h * 0.5, -th * 0.5 - off), Vector3(len, h, th), col, 0.0, 0.05)
	else:
		b.box(Vector3(-th * 0.5 - off, y0 + h * 0.5, mid), Vector3(th, h, len), col, 0.0, 0.05)

func _walls(f: MeshBuilder, g: MeshBuilder, e: MeshBuilder) -> void:
	_wall_run(f, g, e, true, layout.width)
	_wall_run(f, g, e, false, layout.depth)
	# canto
	f.box(Vector3(-0.11, OfficeLayout.WALL_H * 0.5, -0.11), Vector3(0.26, OfficeLayout.WALL_H + 0.07, 0.26), Color("e8edf7"), 0.0, 0.0)

func _chair(f: MeshBuilder, pos: Vector3, yaw: float, col: Color) -> void:
	# `yaw` aponta para onde a pessoa olha; o encosto fica atrás
	var back := Vector3(sin(yaw), 0, cos(yaw))   # direção de trás (oposta à frente)
	f.prism(pos + Vector3(0, 0.1, 0), 0.19, 0.025, 6, METAL.lightened(0.1))
	f.prism(pos + Vector3(0, 0.17, 0), 0.03, 0.15, 6, METAL.lightened(0.2))
	f.box(pos + Vector3(0, 0.255, 0), Vector3(0.44, 0.07, 0.44), col, yaw, 0.1)
	f.box(pos + back * 0.2 + Vector3(0, 0.5, 0), Vector3(0.42, 0.42, 0.06), col, yaw, 0.1)

func _pod(f: MeshBuilder, pod: Dictionary) -> void:
	var cx: float = pod.cx
	var cz: float = pod.cz
	var prof: String = pod.prof
	var pc: Color = PROF_COLORS.get(prof, Color("7a859f"))
	for si in 2:
		var s := 1.0 if si == 0 else -1.0
		# mesa
		f.box(Vector3(cx, 0.49, cz + s * 0.43), Vector3(1.7, 0.05, 0.76), DESK, 0.0, 0.0)
		f.box(Vector3(cx - 0.8, 0.245, cz + s * 0.43), Vector3(0.05, 0.49, 0.66), DESK_EDGE)
		f.box(Vector3(cx + 0.8, 0.245, cz + s * 0.43), Vector3(0.05, 0.49, 0.66), DESK_EDGE)
		# monitor (moldura); a tela acesa vem em _build_screens
		var wide := 0.76 if prof == "programmer" else 0.62
		f.box(Vector3(cx, 0.545, cz + s * 0.3), Vector3(0.24, 0.02, 0.15), METAL)
		f.box(Vector3(cx, 0.62, cz + s * 0.3), Vector3(0.05, 0.14, 0.04), METAL)
		f.box(Vector3(cx, 0.8, cz + s * 0.3), Vector3(wide, 0.36, 0.03), METAL.lightened(0.05), 0.0, 0.0)
		# teclado, mouse
		f.box(Vector3(cx - 0.05, 0.52, cz + s * 0.6), Vector3(0.38, 0.016, 0.12), Color("3a4152"))
		f.box(Vector3(cx + 0.3, 0.52, cz + s * 0.6), Vector3(0.06, 0.018, 0.09), Color("3a4152"))
		# adereços por profissão
		var seed_v := int(pod.i) * 2 + si
		match prof:
			"engineer":
				f.box(Vector3(cx - 0.55, 0.53, cz + s * 0.45), Vector3(0.22, 0.02, 0.16), Color("2fa45a"))   # placa de circuito
				f.box(Vector3(cx - 0.55, 0.545, cz + s * 0.45), Vector3(0.07, 0.015, 0.07), Color("20242e"))
				f.prism(Vector3(cx + 0.58, 0.545, cz + s * 0.35), 0.06, 0.07, 6, Color("ffd23f"))             # mini capacete
			"programmer":
				f.prism(Vector3(cx - 0.6, 0.545, cz + s * 0.5), 0.04, 0.08, 8, Color("f4f1ea"))               # caneca
				f.box(Vector3(cx + 0.55, 0.52, cz + s * 0.5), Vector3(0.18, 0.012, 0.14), Color("8d94a6"), 0.0, 0.0)  # bloco
			"designer":
				f.box(Vector3(cx - 0.55, 0.52, cz + s * 0.5), Vector3(0.26, 0.012, 0.18), Color("f4f1ea"), 0.2, 0.0)  # mesa digitalizadora
				for k in 4:
					f.box(Vector3(cx + 0.45 + float(k) * 0.045, 0.53, cz + s * 0.42), Vector3(0.035, 0.03, 0.035), [Color("ff5d6c"), Color("ffc857"), Color("4cd18a"), Color("5aa9ff")][k], 0.0, 0.0)
			"researcher":
				f.prism(Vector3(cx - 0.58, 0.55, cz + s * 0.45), 0.045, 0.1, 8, Color(0.6, 0.9, 0.95, 1.0))   # béquer
				f.box(Vector3(cx + 0.5, 0.53, cz + s * 0.45), Vector3(0.2, 0.025, 0.28), Color("e9ecf2"), 0.15)  # pranchetas
		if seed_v % 3 == 0:
			f.prism(Vector3(cx + 0.62, 0.545, cz + s * 0.6), 0.04, 0.08, 8, Color("ff9a2e") if seed_v % 2 == 0 else Color("f4f1ea"))
		# cadeira atrás de quem trabalha
		_chair(f, Vector3(cx, 0, cz + s * OfficeLayout.SEAT_Z), 0.0 if s > 0.0 else PI, pc.darkened(0.45) if prof != "" else Color("3a4152"))
	# divisória baixa no meio da baia
	f.box(Vector3(cx, 0.6, cz), Vector3(1.7, 0.22, 0.04), pc.darkened(0.3) if prof != "" else Color("5a6480"), 0.0, 0.0)
	f.box(Vector3(cx, 0.36, cz), Vector3(1.7, 0.18, 0.2), DESK_EDGE.darkened(0.2))

func _plant(f: MeshBuilder, pos: Vector3, s: float = 1.0, palm: bool = false) -> void:
	f.prism(pos + Vector3(0, 0.12 * s, 0), 0.15 * s, 0.24 * s, 8, Color("d8d4cc") if not palm else Color("b5683b"), 0.0, Color("3a2a20"))
	if palm:
		f.prism(pos + Vector3(0, 0.55 * s, 0), 0.035 * s, 0.7 * s, 6, Color("7a5a3a"))
		for k in 7:
			var a := TAU * float(k) / 7.0
			f.box(pos + Vector3(cos(a) * 0.2 * s, 1.0 * s, sin(a) * 0.2 * s), Vector3(0.5 * s, 0.03, 0.12 * s), Color("3f9a54") if k % 2 == 0 else Color("2f7f45"), -a, 0.0, 0.5)
	else:
		for k in 6:
			var a := TAU * float(k) / 6.0 + 0.3
			f.box(pos + Vector3(cos(a) * 0.11 * s, (0.36 + 0.05 * float(k % 3)) * s, sin(a) * 0.11 * s), Vector3(0.1 * s, 0.34 * s, 0.1 * s), Color("4aa65e") if k % 2 == 0 else Color("2f8a4a"), a, 0.0, 0.35)

func _rack(f: MeshBuilder, e: MeshBuilder, pos: Vector3, seed_v: int) -> void:
	f.box(pos + Vector3(0, 0.62, 0), Vector3(0.62, 1.24, 0.58), METAL, 0.0, 0.1)
	f.box(pos + Vector3(0.311, 0.62, 0), Vector3(0.01, 1.14, 0.5), Color("11141c"), 0.0, 0.0)
	for r in 9:
		var y := 0.18 + float(r) * 0.115
		f.box(pos + Vector3(0.32, y, 0), Vector3(0.012, 0.075, 0.46), Color("2b303d"), 0.0, 0.0)
		var on := (seed_v + r * 7) % 5
		var c := Color("4cd18a") if on != 0 else Color("ff9a2e")
		e.box(pos + Vector3(0.327, y, -0.18), Vector3(0.008, 0.02, 0.03), c, 0.0, 0.0)
		e.box(pos + Vector3(0.327, y, -0.13), Vector3(0.008, 0.02, 0.03), Color("5aa9ff") if (seed_v + r) % 3 != 0 else Color("20304a"), 0.0, 0.0)

func _sofa(f: MeshBuilder, pos: Vector3, col: Color) -> void:
	# de frente para -z (costas em +z)
	f.box(pos + Vector3(0, 0.15, 0), Vector3(2.0, 0.3, 0.8), col, 0.0, 0.1)
	f.box(pos + Vector3(0, 0.45, 0.31), Vector3(2.0, 0.5, 0.2), col.darkened(0.08), 0.0, 0.1)
	f.box(pos + Vector3(-0.96, 0.33, 0), Vector3(0.14, 0.2, 0.8), col.darkened(0.12), 0.0, 0.1)
	f.box(pos + Vector3(0.96, 0.33, 0), Vector3(0.14, 0.2, 0.8), col.darkened(0.12), 0.0, 0.1)
	f.box(pos + Vector3(-0.5, 0.33, -0.04), Vector3(0.8, 0.08, 0.6), col.lightened(0.12), 0.0, 0.0)
	f.box(pos + Vector3(0.5, 0.33, -0.04), Vector3(0.8, 0.08, 0.6), col.lightened(0.12), 0.0, 0.0)
	f.box(pos + Vector3(-0.78, 0.5, 0.1), Vector3(0.3, 0.3, 0.1), ACCENT, 0.2, 0.0)

func _common_areas(f: MeshBuilder, e: MeshBuilder, g: MeshBuilder) -> void:
	var fl := layout.front_lane
	for k in layout.cols:
		var cx := layout.slot_center_x(k)
		match str(layout.slots[k]):
			"lounge":
				f.box(Vector3(cx, 0.014, fl + 1.9), Vector3(2.3, 0.012, 2.4), Color("3b2f4a"), 0.0, 0.0)
				_sofa(f, Vector3(cx, 0, fl + 2.55), Color("3d5a8c"))
				f.box(Vector3(cx, 0.26, fl + 1.45), Vector3(0.7, 0.04, 0.5), WOOD, 0.0, 0.0)
				for lx in [-0.3, 0.3]:
					f.box(Vector3(cx + lx, 0.13, fl + 1.45), Vector3(0.04, 0.26, 0.04), METAL)
				f.prism(Vector3(cx - 0.15, 0.31, fl + 1.45), 0.04, 0.07, 8, Color("f4f1ea"))
				# abajur de piso
				f.prism(Vector3(cx + 1.15, 0.7, fl + 3.1), 0.025, 1.4, 6, METAL)
				e.prism(Vector3(cx + 1.15, 1.5, fl + 3.1), 0.14, 0.2, 8, Color("ffd59a"), 0.0, Color("fff0cf"), 0.0)
				_plant(f, Vector3(cx - 1.1, 0, fl + 3.15), 1.0)
			"pantry":
				f.box(Vector3(cx, 0.28, fl + 1.65), Vector3(2.2, 0.56, 0.5), Color("d9dfeb"), 0.0, 0.1)
				f.box(Vector3(cx, 0.575, fl + 1.65), Vector3(2.24, 0.04, 0.54), Color("2a2f3d"), 0.0, 0.0)
				# bebedouro
				f.box(Vector3(cx - 0.55, 0.9, fl + 1.62), Vector3(0.3, 0.6, 0.28), Color("e9ecf2"))
				f.prism(Vector3(cx - 0.55, 1.34, fl + 1.62), 0.11, 0.3, 8, Color(0.55, 0.78, 1.0, 1.0))
				# cafeteira
				f.box(Vector3(cx + 0.5, 0.78, fl + 1.65), Vector3(0.34, 0.36, 0.28), Color("20242e"))
				e.box(Vector3(cx + 0.5, 0.88, fl + 1.5), Vector3(0.06, 0.03, 0.01), Color("ff5d6c"), 0.0, 0.0)
				f.box(Vector3(cx + 0.9, 0.7, fl + 1.65), Vector3(0.22, 0.2, 0.22), Color("e6eaf2"))     # micro-ondas
				_plant(f, Vector3(cx - 1.05, 0, fl + 2.7), 0.9)
				_plant(f, Vector3(cx + 1.05, 0, fl + 2.7), 0.9)
			"meeting":
				var mx := cx
				var mz := fl + 2.15
				f.box(Vector3(mx, 0.014, mz), Vector3(2.3, 0.012, 2.6), Color("313a56"), 0.0, 0.0)
				f.box(Vector3(mx, 0.46, mz), Vector3(1.5, 0.05, 0.8), Color("e6eaf2"), 0.0, 0.0)
				f.box(Vector3(mx, 0.23, mz), Vector3(0.14, 0.46, 0.5), METAL)
				for cxo in [-0.5, 0.0, 0.5]:
					_chair(f, Vector3(mx + cxo, 0, mz - 0.7), PI, Color("3a4a78"))
					_chair(f, Vector3(mx + cxo, 0, mz + 0.7), 0.0, Color("3a4a78"))
				# paredes de vidro (frente, lados)
				g.box(Vector3(mx, 0.6, mz + 1.3), Vector3(2.3, 1.2, 0.04), Color(0.62, 0.8, 1.0, 0.25), 0.0, 0.0)
				g.box(Vector3(mx - 1.15, 0.6, mz), Vector3(0.04, 1.2, 2.6), Color(0.62, 0.8, 1.0, 0.25), 0.0, 0.0)
				g.box(Vector3(mx + 1.15, 0.6, mz), Vector3(0.04, 1.2, 2.6), Color(0.62, 0.8, 1.0, 0.25), 0.0, 0.0)
				for post in [[-1.15, 1.3], [1.15, 1.3], [-1.15, -1.3], [1.15, -1.3]]:
					f.box(Vector3(mx + post[0], 0.62, mz + post[1]), Vector3(0.06, 1.24, 0.06), METAL.lightened(0.15), 0.0, 0.0)
				# tela de apresentação
				e.box(Vector3(mx, 0.9, mz - 1.28), Vector3(1.1, 0.55, 0.03), Color("172036"), 0.0, 0.0)
				for b in 4:
					e.box(Vector3(mx - 0.38 + float(b) * 0.25, 0.7 + float(b) * 0.04, mz - 1.255), Vector3(0.14, 0.12 + float(b) * 0.08, 0.01), ACCENT if b % 2 == 0 else Color("5aa9ff"), 0.0, 0.0)
			"reception":
				f.box(Vector3(cx, 0.014, fl + 2.0), Vector3(2.3, 0.012, 2.6), Color("4a3a2a"), 0.0, 0.0)
				f.box(Vector3(cx, 0.3, fl + 2.1), Vector3(2.0, 0.6, 0.55), Color("2a2f3d"), 0.0, 0.1)
				f.box(Vector3(cx, 0.62, fl + 2.1), Vector3(2.08, 0.05, 0.62), WOOD, 0.0, 0.0)
				e.box(Vector3(cx, 0.32, fl + 1.82), Vector3(1.2, 0.2, 0.02), ACCENT, 0.0, 0.0)
				f.box(Vector3(cx + 0.5, 0.76, fl + 2.1), Vector3(0.3, 0.2, 0.04), METAL)
				_plant(f, Vector3(cx - 1.1, 0, fl + 2.1), 1.1, true)
				_plant(f, Vector3(cx + 1.1, 0, fl + 3.1), 1.0)
			"chat":
				_plant(f, Vector3(cx - 1.0, 0, fl + 3.2), 1.0, k % 2 == 0)
				if k % 2 == 1:
					_plant(f, Vector3(cx + 1.0, 0, fl + 3.2), 0.9)

func _decor(f: MeshBuilder, e: MeshBuilder) -> void:
	var W := layout.width
	var D := layout.depth
	var st := layout.stage
	# racks de servidores junto da parede lateral (x = 0)
	var racks: int = [0, 1, 3, 5][st]
	var rack_end := layout.front_lane - 0.6
	var z := OfficeLayout.OZ + 0.45
	for r in racks:
		if z + 0.4 > rack_end:
			break
		_rack(f, e, Vector3(0.45, 0, z), r * 3 + 1)
		z += 0.78
	# parede do fundo: um item por coluna
	for k in layout.cols:
		var x := layout.slot_center_x(k)
		match k % 4:
			0:
				_plant(f, Vector3(x, 0, 0.5), 1.1, st >= 1)
			1:
				if st >= 1:
					f.box(Vector3(x, 0.45, 0.35), Vector3(1.3, 0.9, 0.4), Color("d9dfeb"), 0.0, 0.1)
					f.box(Vector3(x, 0.92, 0.35), Vector3(1.34, 0.04, 0.44), WOOD, 0.0, 0.0)
					f.box(Vector3(x - 0.35, 1.05, 0.3), Vector3(0.3, 0.2, 0.2), Color("20242e"))
				else:
					_plant(f, Vector3(x, 0, 0.5), 0.9)
			2:
				if st >= 1:
					# quadro branco
					f.box(Vector3(x, 1.12, 0.03), Vector3(1.5, 0.8, 0.03), Color("f1f3f8"), 0.0, 0.0)
					f.box(Vector3(x, 1.12, 0.045), Vector3(1.56, 0.86, 0.01), METAL, 0.0, 0.0)
					for ln in 3:
						f.box(Vector3(x - 0.2 + float(ln) * 0.08, 1.12 + 0.2 - float(ln) * 0.17, 0.052), Vector3(0.8 - float(ln) * 0.15, 0.025, 0.004), [ACCENT, Color("5aa9ff"), Color("4cd18a")][ln], 0.0, 0.0)
				_plant(f, Vector3(x + 0.9, 0, 0.5), 1.0)
			3:
				if st >= 2:
					# estante de produtos lançados
					f.box(Vector3(x, 0.55, 0.3), Vector3(1.5, 1.1, 0.34), Color("2a2f3d"), 0.0, 0.1)
					for sh in 2:
						f.box(Vector3(x, 0.55 + float(sh) * 0.5, 0.33), Vector3(1.4, 0.03, 0.3), Color("aeb8cc"), 0.0, 0.0)
					for d in _released:
						f.box(Vector3(x - 0.5 + float(d) * 0.33, 0.66, 0.34), Vector3(0.14, 0.2, 0.02), Color("0e1016"), 0.0, 0.0)
						e.box(Vector3(x - 0.5 + float(d) * 0.33, 0.66, 0.352), Vector3(0.12, 0.18, 0.004), Color("5aa9ff") if d % 2 == 0 else ACCENT, 0.0, 0.0)
				else:
					_plant(f, Vector3(x, 0, 0.5), 1.0)
	# televisão na parede lateral (fase avançada)
	if st >= 2:
		var tz := layout.front_lane * 0.5 + 1.0
		f.box(Vector3(0.06, 1.25, tz), Vector3(0.06, 0.8, 1.45), METAL, 0.0, 0.0)
		e.box(Vector3(0.1, 1.25, tz), Vector3(0.02, 0.72, 1.36), Color("12203a"), 0.0, 0.0)
		for b in 6:
			var h := 0.1 + 0.07 * float((b * 5) % 7)
			e.box(Vector3(0.115, 0.98 + h * 0.5, tz - 0.5 + float(b) * 0.2), Vector3(0.012, h, 0.12), ACCENT if b % 2 == 0 else Color("5aa9ff"), 0.0, 0.0)
	# quadros decorativos
	if st >= 1:
		var qz := layout.front_lane * 0.5 - 1.2
		f.box(Vector3(0.05, 1.3, qz), Vector3(0.04, 0.6, 0.9), Color("f1f3f8"), 0.0, 0.0)
		e.box(Vector3(0.075, 1.3, qz), Vector3(0.01, 0.5, 0.8), ACCENT.darkened(0.2), 0.0, 0.0)
	# plantas nos cantos da frente
	_plant(f, Vector3(W - 0.55, 0, D - 0.55), 1.2, true)
	_plant(f, Vector3(0.6, 0, D - 0.6), 1.1, st >= 1)

# ───────────── telas dos computadores (mudam com a ocupação) ─────────────

func _build_screens() -> void:
	if layout == null:
		return
	var b := MeshBuilder.new()
	for seat in layout.seats:
		var pod: Dictionary = layout.pods[int(seat.pod)]
		var cx: float = pod.cx
		var cz: float = pod.cz
		var s := 1.0 if (seat.pos as Vector3).z > cz else -1.0
		var prof: String = seat.prof
		var occupied := _seat_prof.has(int(seat.i))
		var wide := 0.7 if prof == "programmer" else 0.56
		var zf := cz + s * 0.3 + s * 0.017   # frente da tela (voltada ao funcionário)
		var c: Color = PROF_COLORS.get(prof, Color("7a859f"))
		if not occupied:
			b.box(Vector3(cx, 0.8, zf), Vector3(wide, 0.3, 0.004), Color("161b27"), 0.0, 0.0)
			continue
		b.box(Vector3(cx, 0.8, zf), Vector3(wide, 0.3, 0.004), Color("0e1830"), 0.0, 0.0)
		var sd := int(seat.i) * 13 + 5
		var zl := zf + s * 0.004
		match prof:
			"programmer":
				for ln in 7:
					var ind := 0.0 if (ln + sd) % 3 != 0 else 0.08
					var len := 0.15 + 0.06 * float((ln * 7 + sd) % 5)
					b.box(Vector3(cx - wide * 0.5 + 0.05 + ind + len * 0.5, 0.8 + 0.115 - float(ln) * 0.037, zl), Vector3(len, 0.014, 0.003), [c, Color("4cd18a"), Color("ffc857"), Color("ff7aa8")][(ln + sd) % 4], 0.0, 0.0)
			"designer":
				b.box(Vector3(cx - 0.12, 0.8, zl), Vector3(0.22, 0.2, 0.003), c, 0.0, 0.0)
				b.box(Vector3(cx + 0.1, 0.84, zl), Vector3(0.16, 0.12, 0.003), Color("ff7aa8"), 0.0, 0.0)
				b.box(Vector3(cx + 0.12, 0.74, zl), Vector3(0.2, 0.05, 0.003), Color("ffc857"), 0.0, 0.0)
			"engineer":
				for ln in 4:
					b.box(Vector3(cx - 0.12, 0.8 + 0.1 - float(ln) * 0.06, zl), Vector3(0.22, 0.012, 0.003), c.darkened(0.2), 0.0, 0.0)
				for k in 7:
					var h := 0.04 + 0.025 * float((k * 3 + sd) % 5)
					b.box(Vector3(cx + 0.06 + float(k) * 0.03, 0.72 + h * 0.5, zl), Vector3(0.018, h, 0.003), c, 0.0, 0.0)
			_:
				for k in 8:
					var h := 0.05 + 0.03 * float((k * 5 + sd) % 5)
					b.box(Vector3(cx - 0.2 + float(k) * 0.05, 0.69 + h * 0.5, zl), Vector3(0.03, h, 0.003), c, 0.0, 0.0)
	_screens_mi.mesh = b.build()
