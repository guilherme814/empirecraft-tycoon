class_name OSPreview
extends Control
## Tela de celular de prévia do sistema operacional próprio: papel de parede, relógio, widget,
## ícones, dock e notificações reais da empresa, de acordo com a aparência escolhida.

const APPS := [["nav_dash", "Painel", "ff9a2e"], ["nav_team", "Equipe", "5aa9ff"], ["nav_market", "Mercado", "4cd18a"], ["nav_finance", "Contas", "c792ea"],
	["nav_research", "Lab", "3fcfb4"], ["nav_marketing", "Ofertas", "ff5d6c"], ["nav_products", "Loja", "ffc857"], ["nav_feedback", "Chat", "5aa9ff"]]

var look: Dictionary = {}
var accent: Color = Color("ff9a2e")
var notes: Array = []          # últimas notificações {text, kind}
var os_name: String = "Sistema"
var _th: Dictionary = {}

func setup(look_d: Dictionary, accent_hex: String, notes_in: Array, name_in: String) -> OSPreview:
	look = look_d
	accent = Color(accent_hex)
	notes = notes_in
	os_name = name_in
	custom_minimum_size = Vector2(330, 610)
	clip_contents = true
	for t in GameData.os_data().look.themes:
		if str(t.id) == str(look.theme):
			_th = t
	_build()
	return self

func _t(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _tw(text: String, size: int, color: Color) -> Label:
	var l := _t(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _col(hex: String, a: float = 1.0) -> Color:
	var c := Color(hex)
	c.a = a
	return c

func _wall_tex() -> GradientTexture2D:
	var c1 := Color("1b2a6b")
	var c2 := Color("2fd1b4")
	for w in GameData.designs().wallpapers:
		if str(w.id) == str(look.wall):
			c1 = Color(str(w.c1))
			c2 = Color(str(w.c2))
	var g := Gradient.new()
	g.colors = PackedColorArray([c1, c2])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.2, 0.0)
	t.fill_to = Vector2(0.8, 1.0)
	t.width = 128
	t.height = 256
	return t

func _icon_box(col: Color, size: float) -> StyleBoxFlat:
	var sb := Palette.box(col, 0, 0)
	match str(look.icons):
		"round": sb.set_corner_radius_all(int(size * 0.5))
		"square": sb.set_corner_radius_all(int(size * 0.08))
		"drop":
			sb.set_corner_radius_all(int(size * 0.5))
			sb.corner_radius_bottom_right = int(size * 0.1)
		_: sb.set_corner_radius_all(int(size * 0.3))
	return sb

func _build() -> void:
	for ch in get_children():
		ch.queue_free()
	var frame := PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fb := Palette.box(Color("0b0c12"), 40, 8)
	fb.border_color = Color("3a3f4f")
	fb.set_border_width_all(3)
	frame.add_theme_stylebox_override("panel", fb)
	add_child(frame)
	var screen := Control.new()
	screen.clip_contents = true
	frame.add_child(screen)
	var wall := TextureRect.new()
	wall.texture = _wall_tex()
	wall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wall.stretch_mode = TextureRect.STRETCH_SCALE
	wall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(wall)
	var col := UI.vbox(10)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 14
	col.offset_right = -14
	col.offset_top = 10
	col.offset_bottom = -12
	screen.add_child(col)
	var txt := Color(str(_th.text))
	var sub := Color(str(_th.sub))
	var panel_c := _col(str(_th.panel), 0.88)

	# barra de status
	var sb := UI.hbox(6)
	col.add_child(sb)
	sb.add_child(_t("9:41", 20, Color.WHITE))
	sb.add_child(UI.spacer())
	sb.add_child(_t(os_name, 18, Color.WHITE))

	# relógio
	match str(look.clock):
		"small":
			var cl := _t("9:41", 40, Color.WHITE)
			cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(cl)
		"side":
			var h := UI.hbox(10)
			col.add_child(h)
			h.add_child(_t("09", 64, Color.WHITE))
			var v := UI.vbox(0)
			v.add_child(_t("41", 64, accent))
			h.add_child(v)
		_:
			var cl2 := _t("9:41", 72, Color.WHITE)
			cl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(cl2)
	var dt := _t("sábado, 1 de novembro", 20, Color.WHITE)
	dt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(dt)

	# notificações reais
	var shown := 0
	for n in notes:
		if shown >= (1 if str(look.notif) == "cards" else 2):
			break
		shown += 1
		var kcol: Color = Palette.GOOD if str(n.kind) == "good" else (Palette.BAD if str(n.kind) == "bad" else accent)
		var msg := str(n.text)
		if msg.length() > 46:
			msg = msg.substr(0, 44) + "…"
		match str(look.notif):
			"compact":
				var pc := PanelContainer.new()
				pc.add_theme_stylebox_override("panel", Palette.box(panel_c, 14, 8))
				var hh := UI.hbox(8)
				pc.add_child(hh)
				hh.add_child(UI.icon("bell", 20, kcol))
				var ll := _t(msg, 18, txt)
				ll.clip_text = true
				ll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hh.add_child(ll)
				col.add_child(pc)
			"banner":
				var pb := PanelContainer.new()
				var bs := Palette.box(kcol.darkened(0.15), 4, 8)
				pb.add_theme_stylebox_override("panel", bs)
				var bl := _t(msg, 18, Color.WHITE)
				bl.clip_text = true
				pb.add_child(bl)
				col.add_child(pb)
			_:
				var pc2 := PanelContainer.new()
				var cs := Palette.box(panel_c, 18, 10)
				cs.border_color = kcol
				cs.border_width_left = 6
				pc2.add_theme_stylebox_override("panel", cs)
				var vv := UI.vbox(2)
				pc2.add_child(vv)
				vv.add_child(_t(os_name + " · agora", 16, sub))
				var tl := _tw(msg, 18, txt)
				vv.add_child(tl)
				col.add_child(pc2)

	# widget
	match str(look.widget):
		"stats":
			col.add_child(_widget(panel_c, txt, sub, "Resumo", "+12,4% vendas", "Reputação em alta"))
		"weather":
			col.add_child(_widget(panel_c, txt, sub, "Clima", "24°  Ensolarado", "Máx 28° · Mín 17°"))
		"music":
			col.add_child(_widget(panel_c, txt, sub, "Tocando agora", "Neon Skyline", "Aurora Tech Mix"))
	col.add_child(UI.spacer())
	col.get_child(col.get_child_count() - 1).size_flags_vertical = Control.SIZE_EXPAND_FILL

	# ícones
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(grid)
	var is_sq := 58.0
	for a in APPS:
		var vb := UI.vbox(2)
		var pc3 := PanelContainer.new()
		pc3.custom_minimum_size = Vector2(is_sq, is_sq)
		var ibox := _icon_box(Color(str(a[2])), is_sq)
		pc3.add_theme_stylebox_override("panel", ibox)
		var ic := UI.icon(str(a[0]), 34, Color("14161c"))
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pc3.add_child(ic)
		vb.add_child(pc3)
		var nm := _t(str(a[1]), 15, Color.WHITE)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(nm)
		grid.add_child(vb)

	# dock
	if str(look.dock) != "none":
		var dock := PanelContainer.new()
		var radius := 26 if str(look.dock) == "float" else 0
		var ds := Palette.box(panel_c, radius, 8)
		dock.add_theme_stylebox_override("panel", ds)
		if str(look.dock) == "bar":
			dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var dh := UI.hbox(14)
		dh.alignment = BoxContainer.ALIGNMENT_CENTER
		dock.add_child(dh)
		for i in 4:
			var p := PanelContainer.new()
			p.custom_minimum_size = Vector2(46, 46)
			p.add_theme_stylebox_override("panel", _icon_box(Color(str(APPS[(i + 3) % APPS.size()][2])), 46.0))
			dh.add_child(p)
		col.add_child(dock)

func _widget(panel_c: Color, txt: Color, sub: Color, title: String, big: String, small: String) -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", Palette.box(panel_c, 20, 12))
	var v := UI.vbox(2)
	pc.add_child(v)
	v.add_child(_t(title, 16, sub))
	v.add_child(_t(big, 26, txt))
	v.add_child(_t(small, 16, accent))
	return pc
