extends Page
## Escritório 3D: representação visual da empresa. Mostra a equipe real (Employee) trabalhando;
## toque num funcionário para ver seus atributos. Não há construção: o cenário cresce sozinho.

const PROF_COLORS := {
	"engineer": Color("ff9a2e"), "programmer": Color("5aa9ff"),
	"designer": Color("c792ea"), "researcher": Color("3fcfb4"),
}

var scene: OfficeScene
var _title: Label
var _stage_l: Label
var _legend: HBoxContainer
var _card: PanelContainer
var _card_body: VBoxContainer
var _status_l: Label
var _acc: float = 0.0
var _sel: int = -1
var _edit: bool = false
var _dl: Dictionary = {}
var _dd: Dictionary = {}
var _panel: ScrollContainer
var _pbody: VBoxContainer

func build() -> void:
	var root := UI.vbox(12)
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	var head := UI.hbox(14)
	root.add_child(head)
	_title = UI.label("Escritório", 34, Palette.TEXT)
	head.add_child(_title)
	_stage_l = UI.label("", 26, Palette.ACCENT)
	head.add_child(_stage_l)
	head.add_child(UI.spacer())
	head.add_child(UI.button("−", func(): scene.set_zoom(scene.zoom / 1.3), "normal", 68, 84))
	head.add_child(UI.button("+", func(): scene.set_zoom(scene.zoom * 1.3), "normal", 68, 84))
	head.add_child(UI.button("Centralizar", func(): scene.reset_view(), "normal", 68))
	head.add_child(UI.button("Personalizar", func(): _toggle_edit(), "good", 68))
	head.add_child(UI.button("Equipe", func(): Game.ui_request.emit("goto_team", 0), "info", 68))

	var row := UI.hbox(12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)
	_panel = UI.scroll()
	_panel.custom_minimum_size = Vector2(640, 0)
	_panel.size_flags_horizontal = Control.SIZE_FILL
	_panel.visible = false
	row.add_child(_panel)
	_pbody = UI.vbox(12)
	_pbody.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.add_child(_pbody)
	var frame := PanelContainer.new()
	var fs := Palette.box(Color("0b0f1c"), 22, 0)
	fs.border_color = Palette.PANEL_ALT
	fs.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", fs)
	frame.clip_contents = true
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(frame)
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_child(stack)
	scene = OfficeScene.new()
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(scene)
	scene.worker_selected.connect(_on_selected)

	_card = UI.card(Color(0.114, 0.125, 0.161, 0.94), 18)
	_card.anchor_left = 0.0
	_card.anchor_top = 1.0
	_card.anchor_right = 0.0
	_card.anchor_bottom = 1.0
	_card.offset_left = 18
	_card.offset_bottom = -18
	_card.offset_top = -330
	_card.offset_right = 560
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.visible = false
	stack.add_child(_card)
	_card_body = UI.vbox(8)
	_card.add_child(_card_body)

	_legend = UI.hbox(24)
	root.add_child(_legend)

func signature() -> String:
	var c := company
	var parts: Array = [_sel, c.released_products().size() > 0]
	for e in c.staff:
		parts.append("%d%s%d" % [e.id, str(e.profession)[0], e.total()])
	for p in GameData.professions():
		parts.append(int(c.office_level.get(str(p.id), 1)))
	return str(parts)

func rebuild() -> void:
	var c := company
	scene.sync(c)
	_stage_l.text = "· " + str(OfficeScene.STAGE_NAMES[scene.layout.stage])
	UI.clear(_legend)
	for p in GameData.professions():
		var n := c.staff_of(str(p.id)).size()
		var dot := ColorRect.new()
		dot.color = PROF_COLORS.get(str(p.id), Palette.MUTED)
		dot.custom_minimum_size = Vector2(22, 22)
		var box := UI.hbox(8)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		var dc := CenterContainer.new()
		dc.add_child(dot)
		box.add_child(dc)
		box.add_child(UI.label("%s: %d" % [p.name, n], 24, Palette.TEXT))
		_legend.add_child(box)
	_legend.add_child(UI.spacer())
	var extra := "  (+%d fora de vista)" % scene.hidden_staff if scene.hidden_staff > 0 else ""
	_legend.add_child(UI.label("Equipe: %d%s" % [c.staff.size(), extra], 24, Palette.MUTED))
	if c.staff.is_empty():
		_legend.add_child(UI.label("  Contrate pessoas na aba Equipe", 24, Palette.WARN))
	_fill_card()

func _on_selected(id: int) -> void:
	_sel = id
	_last_sig = "\u0001"
	refresh()

func _employee(id: int) -> Employee:
	for e in company.staff:
		if e.id == id:
			return e
	return null

func _fill_card() -> void:
	UI.clear(_card_body)
	_status_l = null
	var e := _employee(_sel) if _sel != -1 else null
	_card.visible = e != null
	if e == null:
		return
	var c := company
	var pinfo := {}
	for p in GameData.professions():
		if str(p.id) == e.profession:
			pinfo = p
	var top := UI.hbox(12)
	_card_body.add_child(top)
	top.add_child(UI.label(e.emp_name, 32, Palette.TEXT))
	top.add_child(UI.spacer())
	top.add_child(UI.button("×", func(): scene.select(-1), "normal", 56, 64))
	var sub := UI.hbox(12)
	_card_body.add_child(sub)
	sub.add_child(UI.label(str(pinfo.get("singular", e.profession)), 25, PROF_COLORS.get(e.profession, Palette.MUTED)))
	_status_l = UI.label("", 24, Palette.GOOD)
	sub.add_child(_status_l)
	for pair in [["Técnica", e.craft, Palette.INFO], ["Ritmo", e.pace, Palette.ACCENT], ["Visão", e.insight, Color("c792ea")]]:
		var row := UI.hbox(10)
		var nl := UI.label(str(pair[0]), 23, Palette.MUTED)
		nl.custom_minimum_size = Vector2(120, 0)
		row.add_child(nl)
		row.add_child(UI.bar(float(pair[1]) / 100.0, pair[2], 14))
		var vl := UI.label(str(int(pair[1])), 23, Palette.TEXT)
		vl.custom_minimum_size = Vector2(52, 0)
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(vl)
		_card_body.add_child(row)
	var days := maxi(0, c.day - e.hired_day)
	var exp := "%d dias" % days if days < 60 else Fmt.dec(float(days) / 365.0, 1) + " anos"
	_card_body.add_child(UI.kv("Na empresa", exp, Palette.TEXT, 23))
	var mrow := UI.hbox(10)
	var ml := UI.label("Moral", 23, Palette.MUTED)
	ml.custom_minimum_size = Vector2(120, 0)
	mrow.add_child(ml)
	mrow.add_child(UI.bar(e.morale / 100.0, Palette.GOOD if e.morale >= 50.0 else Palette.WARN, 14))
	var mv := UI.label("%d" % int(e.morale), 23, Palette.TEXT)
	mv.custom_minimum_size = Vector2(52, 0)
	mv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mrow.add_child(mv)
	_card_body.add_child(mrow)
	_card_body.add_child(UI.kv("Salário", Fmt.money(e.salary()) + "/mês", Palette.TEXT, 23))
	_update_status()

func _update_status() -> void:
	if _status_l == null or _sel == -1:
		return
	var w: OfficeWorker = scene.workers.get(_sel, null)
	var st := w.status_text() if w != null else "Ativo"
	_status_l.text = "· " + st
	_status_l.add_theme_color_override("font_color", Palette.GOOD if st == "Ativo" else Palette.WARN)

func _process(delta: float) -> void:
	_acc += delta
	if _acc > 0.3 and visible:
		_acc = 0.0
		_update_status()


# ───────────── identidade e decoração ─────────────

func _toggle_edit() -> void:
	if _edit:
		_cancel()
		return
	_edit = true
	_dl = company.logo.duplicate()
	_dd = company.decor.duplicate()
	scene.preview_style = true
	_panel.visible = true
	_fill_edit()

func _cancel() -> void:
	_edit = false
	_panel.visible = false
	scene.preview_style = false
	scene.set_style(company.logo, company.decor)

func _draft_changed() -> void:
	scene.set_style(_dl, _dd)
	var keep := _panel.scroll_vertical
	_fill_edit()
	for i in 2:
		await get_tree().process_frame
		_panel.scroll_vertical = keep

func _fill_edit() -> void:
	UI.clear(_pbody)
	var cat := GameData.identity()
	var c := company
	_pbody.add_child(UI.label("Identidade da empresa", 30, Palette.ACCENT))
	# pré-visualizações do logotipo: fachada, embalagem e interface
	var mocks := UI.hbox(10)
	_pbody.add_child(mocks)
	var nm := c.company_name
	var facade := PanelContainer.new()
	facade.add_theme_stylebox_override("panel", Palette.box(Color(str(_dl.c2)), 10, 10))
	facade.add_child(LogoView.new().setup(_dl, 44.0, nm.get_slice(" ", 0)))
	(facade.get_child(0) as LogoView).plate = false
	mocks.add_child(_mock("Fachada", facade))
	var pack := PanelContainer.new()
	var ps := Palette.box(Color(str(_dl.c2)), 6, 8)
	ps.border_color = Color(str(_dl.c1))
	ps.set_border_width_all(3)
	pack.add_theme_stylebox_override("panel", ps)
	var pv := UI.vbox(2)
	pack.add_child(pv)
	var pl := LogoView.new().setup(_dl, 56.0)
	pl.plate = false
	pl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pv.add_child(pl)
	var pn := UI.label(Identity.format_name(nm.get_slice(" ", 0), str(_dl.style)), 16, Color(str(_dl.c1)))
	pn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(pn)
	mocks.add_child(_mock("Embalagem", pack))
	var ui := PanelContainer.new()
	ui.add_theme_stylebox_override("panel", Palette.box(Palette.PANEL_DEEP, 10, 8))
	var uh := UI.hbox(8)
	ui.add_child(uh)
	uh.add_child(LogoView.new().setup(_dl, 40.0))
	uh.add_child(UI.label(nm, 20, Color(str(_dl.c1))))
	mocks.add_child(_mock("Interface", ui))

	_pbody.add_child(UI.label("Símbolo", 24, Palette.MUTED))
	var sf := HFlowContainer.new()
	sf.add_theme_constant_override("h_separation", 8)
	sf.add_theme_constant_override("v_separation", 8)
	_pbody.add_child(sf)
	for sy in cat.symbols:
		var sid: String = sy.id
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(80, 80)
		Palette.style_button(b, "primary" if sid == str(_dl.symbol) else "normal")
		var lv := LogoView.new().setup({"symbol": sid, "c1": _dl.c1, "c2": _dl.c2, "style": _dl.style}, 56.0)
		lv.plate = false
		lv.position = Vector2(12, 12)
		lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(lv)
		b.pressed.connect(func(): _dl["symbol"] = sid; _draft_changed())
		sf.add_child(b)
	for pair in [["c1", "Cor primária"], ["c2", "Cor secundária"]]:
		var key: String = pair[0]
		_pbody.add_child(UI.label(str(pair[1]), 24, Palette.MUTED))
		var cf := HFlowContainer.new()
		cf.add_theme_constant_override("h_separation", 8)
		cf.add_theme_constant_override("v_separation", 8)
		_pbody.add_child(cf)
		for hx in cat.colors:
			var hex: String = hx
			var sw := Button.new()
			sw.focus_mode = Control.FOCUS_NONE
			sw.custom_minimum_size = Vector2(52, 52)
			var sb := Palette.box(Color(hex), 10, 0)
			if hex == str(_dl[key]):
				sb.border_color = Color.WHITE
				sb.set_border_width_all(4)
			for st in ["normal", "hover", "pressed"]:
				sw.add_theme_stylebox_override(st, sb)
			sw.pressed.connect(func(): _dl[key] = hex; _draft_changed())
			cf.add_child(sw)
	_pbody.add_child(UI.label("Tipografia", 24, Palette.MUTED))
	var tf := HFlowContainer.new()
	tf.add_theme_constant_override("h_separation", 8)
	_pbody.add_child(tf)
	for st in cat.styles:
		var stid: String = st.id
		tf.add_child(UI.button(str(st.name), func(): _dl["style"] = stid; _draft_changed(), "primary" if stid == str(_dl.style) else "normal", 60))

	_pbody.add_child(UI.label("Mobiliário e decoração", 30, Palette.ACCENT))
	for g in cat.decor:
		var gk: String = g.group
		_pbody.add_child(UI.label(str(g.name), 24, Palette.MUTED))
		var gf := HFlowContainer.new()
		gf.add_theme_constant_override("h_separation", 8)
		gf.add_theme_constant_override("v_separation", 8)
		_pbody.add_child(gf)
		for o in g.options:
			var oid: String = o.id
			var cost := float(o.cost)
			var label := str(o.name) + ("" if oid == str(c.decor.get(gk, "")) or cost == 0.0 else "  " + Fmt.money(cost))
			gf.add_child(UI.button(label, func(): _dd[gk] = oid; _draft_changed(), "primary" if oid == str(_dd[gk]) else "normal", 60))

	var total := Identity.change_cost(c.logo, _dl, c.decor, _dd)
	var changed := _dl != c.logo or _dd != c.decor
	_pbody.add_child(UI.kv("Custo das mudanças", Fmt.money(total), Palette.WARN if total <= c.money else Palette.BAD, 26))
	var hb := UI.hbox(10)
	_pbody.add_child(hb)
	var ok := UI.button("Confirmar", func():
		var r := c.apply_identity(_dl, _dd)
		if r.ok:
			_cancel()
		act(r), "good", 76)
	ok.disabled = not changed or total > c.money
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(ok)
	hb.add_child(UI.button("Cancelar", func(): _cancel(), "normal", 76))

func _mock(title: String, node: Control) -> Control:
	var v := UI.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.label(title, 18, Palette.MUTED))
	v.add_child(node)
	return v
