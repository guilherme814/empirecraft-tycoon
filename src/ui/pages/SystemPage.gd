extends Page
## Sistema: ambiente do sistema operacional próprio. Prévia ao vivo da tela do celular, personalização
## (tema, papel de parede, ícones, dock, relógio, widget, notificações), desenvolvimento e recursos.

var _body: HBoxContainer
var _left: VBoxContainer
var _right: VBoxContainer
var _os_bar: ProgressBar
var _os_label: Label
var _os_name: String = "NovaOS"

func build() -> void:
	_body = UI.hbox(16)
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_body)
	var lsc := UI.scroll()
	lsc.size_flags_stretch_ratio = 0.62
	_body.add_child(lsc)
	_left = UI.vbox(12)
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lsc.add_child(_left)
	var rsc := UI.scroll()
	_body.add_child(rsc)
	_right = UI.vbox(14)
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rsc.add_child(_right)

func signature() -> String:
	var c := company
	var dev: Variant = c.own_os.get("dev", null)
	var last := 0
	if not c.log_entries.is_empty():
		last = int(c.log_entries[-1].get("n", 0))
	return "%d|%s|%d|%s|%s|%d|%d|%d" % [int(c.own_os.get("version", 0)), str(c.own_os.get("focus", {})) + str(c.own_os.get("features", [])) + str(c.research_level("res_software")),
		1 if dev != null else 0, str(c.os_look()), c.os_accent(), c.research_level("res_os"), int(c.money / 20000.0), last]

func rebuild() -> void:
	UI.clear(_left)
	UI.clear(_right)
	_os_bar = null
	_os_label = null
	_build_preview(_left)
	_build_look(_right)
	_build_os(_right)

func _build_preview(parent: Control) -> void:
	var c := company
	var notes: Array = []
	var ents: Array = c.log_entries.duplicate()
	ents.reverse()
	for e in ents:
		notes.append(e)
		if notes.size() >= 2:
			break
	if notes.is_empty():
		notes = [{"text": "Bem-vindo ao seu sistema!", "kind": "info"}]
	var nm := str(c.own_os.get("name", _os_name)) if c.own_os.has("name") else "Seu sistema"
	var card := UI.blueprint(14)
	parent.add_child(card)
	var v := UI.vbox(8)
	card.add_child(v)
	v.add_child(UI.label("Prévia ao vivo · notificações no sino", 22, Color("bfe0ff")))
	var pv := OSPreview.new().setup(c.os_look(), c.os_accent(), notes, nm)
	pv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(pv)

func _look_row(parent: Control, title: String, key: String, items: Array) -> void:
	parent.add_child(UI.label(title, 24, Palette.MUTED))
	var g := GridContainer.new()
	g.columns = mini(4, maxi(items.size(), 1))
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	parent.add_child(g)
	var cur := str(company.os_look().get(key, ""))
	for it in items:
		var b := UI.button(str(it.name), func(): Sfx.play("click"); company.set_os_look(key, str(it.id)); _last_sig = "\u0001"; Game.changed.emit(),
			"primary" if cur == str(it.id) else "normal", 66)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.x = 0
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 22)
		g.add_child(b)

func _build_look(parent: Control) -> void:
	var c := company
	var L: Dictionary = GameData.os_data().look
	var card := UI.blueprint(18)
	parent.add_child(card)
	var v := UI.vbox(10)
	card.add_child(v)
	v.add_child(UI.label("Personalizar o sistema", 34, Color("bfe0ff")))
	if c.research_level("res_os") < 1:
		v.add_child(UI.wrap("Você já pode experimentar a aparência. Pesquise \"Sistema Operacional Próprio\" para usá-la nos seus aparelhos.", 22, Color("9fc0e8")))
	_look_row(v, "Tema", "theme", L.themes)
	v.add_child(UI.label("Papel de parede", 24, Palette.MUTED))
	var wg := GridContainer.new()
	wg.columns = 3
	wg.add_theme_constant_override("h_separation", 8)
	wg.add_theme_constant_override("v_separation", 8)
	v.add_child(wg)
	var curw := str(c.os_look().wall)
	for w in GameData.designs().wallpapers:
		var b := UI.button(str(w.name), func(): Sfx.play("click"); c.set_os_look("wall", str(w.id)); _last_sig = "\u0001"; Game.changed.emit(),
			"primary" if curw == str(w.id) else "normal", 66)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.x = 0
		b.add_theme_font_size_override("font_size", 22)
		wg.add_child(b)
	_look_row(v, "Ícones", "icons", L.icons)
	_look_row(v, "Dock", "dock", L.docks)
	_look_row(v, "Relógio", "clock", L.clocks)
	_look_row(v, "Widget da tela inicial", "widget", L.widgets)
	_look_row(v, "Estilo das notificações", "notif", L.notifs)
	v.add_child(UI.label("Cor de destaque (também usada na tela dos aparelhos)", 24, Palette.MUTED))
	var sw := UI.hbox(8)
	v.add_child(sw)
	for col in GameData.designs().colors:
		var hexs := str(col.hex)
		var b2 := Button.new()
		b2.focus_mode = Control.FOCUS_NONE
		b2.custom_minimum_size = Vector2(64, 64)
		var sel := c.os_accent() == hexs
		var sb := Palette.box(Color(hexs), 32, 0)
		sb.border_color = Palette.ACCENT if sel else Color("0e1016")
		sb.set_border_width_all(6 if sel else 2)
		for st in ["normal", "hover", "pressed"]:
			b2.add_theme_stylebox_override(st, sb)
		b2.pressed.connect(func(): Sfx.play("click"); c.set_os_accent(hexs); _last_sig = "\u0001"; Game.changed.emit())
		sw.add_child(b2)

# ── Sistema operacional próprio ──
func _build_os(parent: Control) -> void:
	var c := company
	var d: Dictionary = GameData.os_data().own
	var card := UI.blueprint(18)
	parent.add_child(card)
	var v := UI.vbox(10)
	card.add_child(v)
	v.add_child(UI.label("Seu sistema operacional", 34, Color("bfe0ff")))
	if c.research_level(str(d.req)) < 1:
		v.add_child(UI.wrap("Pesquise \"Sistema Operacional Próprio\" para criar o seu. Ele elimina royalties e cresce com o número de aparelhos vendidos.", 24, Color("9fc0e8")))
		return
	var ver := int(c.own_os.get("version", 0))
	var dev: Variant = c.own_os.get("dev", null)
	if ver == 0 and dev == null:
		var le := LineEdit.new()
		le.text = _os_name
		le.custom_minimum_size = Vector2(0, 70)
		le.add_theme_font_size_override("font_size", 28)
		le.text_changed.connect(func(t: String): _os_name = t.strip_edges())
		v.add_child(UI.label("Nome do sistema", 24, Palette.MUTED))
		v.add_child(le)
	else:
		var oi := c.os_info("own")
		v.add_child(UI.kv("Sistema", ("%s v%d" % [oi.name, ver]) if ver > 0 else ("%s (v1 em desenvolvimento)" % oi.name), Palette.ACCENT, 28))
		v.add_child(UI.kv("Qualidade (base)", "×%.2f" % float(oi.q)))
		v.add_child(UI.kv("Bônus de ecossistema", "+%d%%  (%s aparelhos)" % [int(float(oi.eco) * 100.0), Fmt.thousands(int(c.os_ecosystem()))]))
		v.add_child(UI.label("Foco de desenvolvimento  (%d / %d pontos)" % [c.os_focus_used(), c.os_focus_budget()], 24, Palette.MUTED))
		var f := c.os_focus()
		for ax in Company.OS_AXES:
			var val: int = int(f[ax])
			v.add_child(UI.stepper(str(Company.OS_AXIS_NAMES[ax]), str(val),
				func(): act(c.set_os_focus(ax, -1)), func(): act(c.set_os_focus(ax, 1)),
				val > 0, val < 10 and c.os_focus_used() < c.os_focus_budget(), 330))
	if dev != null:
		_os_bar = UI.bar(float(dev.work) / float(dev.req), Palette.ACCENT, 18)
		v.add_child(_os_bar)
		_os_label = UI.label("", 24, Palette.MUTED)
		v.add_child(_os_label)
	else:
		var why := c.os_dev_blocker()
		var btn := UI.button("Desenvolver v%d  —  %s" % [ver + 1, Fmt.money(c.os_dev_cost())],
			func(): act(c.start_os_dev(_os_name)), "primary", 84)
		btn.disabled = why != "" or c.money < c.os_dev_cost()
		v.add_child(btn)
		if why != "":
			v.add_child(UI.label(why, 24, Palette.BAD))
	if ver >= 1:
		v.add_child(UI.label("Recursos de software  (%d / %d espaços)" % [(c.own_os.get("features", []) as Array).size(), c.os_feature_slots()], 24, Palette.MUTED))
		var fg := GridContainer.new()
		fg.columns = 2
		fg.add_theme_constant_override("h_separation", 8)
		fg.add_theme_constant_override("v_separation", 8)
		v.add_child(fg)
		for ft in GameData.os_data().features:
			var on: bool = (c.own_os.get("features", []) as Array).has(str(ft.id))
			var owned: bool = (c.own_os.get("owned", []) as Array).has(str(ft.id))
			var why := c.os_feature_blocker(str(ft.id))
			var label := "%s%s  +%d %s" % ["✓ " if on else "", str(ft.name), int(ft.pts), str(Company.OS_AXIS_NAMES[str(ft.axis)]).substr(0, 4)]
			if not on and not owned:
				label += "  " + Fmt.money(float(ft.cost))
			var fb := UI.button(label, func(): act(c.toggle_os_feature(str(ft.id))), "primary" if on else "normal", 66, 0, "lock" if why != "" and not on and not why.begins_with("Custa") and not why.begins_with("Sem espaço") else "")
			fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fb.clip_text = true
			fb.disabled = why != "" and not on
			fb.add_theme_font_size_override("font_size", 21)
			fb.tooltip_text = str(ft.desc)
			fg.add_child(fb)
		v.add_child(UI.wrap("Cada recurso ativo soma pontos ao foco do sistema (bônus de qualidade por categoria). Ative até %d por vez; os já comprados podem ser trocados de graça." % c.os_feature_slots(), 20, Color("9fc0e8")))
	v.add_child(UI.wrap("Cada versão aumenta a qualidade. O foco define em quais aparelhos o sistema brilha: Visual (celulares/relógios), Desempenho (notebooks/consoles).", 21, Color("9fc0e8")))


func live() -> void:
	var c := company
	var dev: Variant = c.own_os.get("dev", null)
	if dev != null and _os_bar != null:
		_os_bar.value = float(dev.work) / float(dev.req)
		_os_label.text = "Desenvolvendo v%d: %d%%" % [int(c.own_os.get("version", 0)) + 1, int(100.0 * float(dev.work) / float(dev.req))]
