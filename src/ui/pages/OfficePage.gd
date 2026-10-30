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
	head.add_child(UI.button("Equipe", func(): Game.ui_request.emit("goto_team", 0), "info", 68))

	var frame := PanelContainer.new()
	var fs := Palette.box(Color("0b0f1c"), 22, 0)
	fs.border_color = Palette.PANEL_ALT
	fs.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", fs)
	frame.clip_contents = true
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(frame)
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
