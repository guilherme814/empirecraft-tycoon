extends Page
## Laboratório de hardware: projete processadores (nó, núcleos, clock, cache, NPU, fundição).
## Mostra área do die, rendimento do wafer (modelo de Murphy), custo por chip bom, desempenho e calor.

var _d: Dictionary = {}
var _left: VBoxContainer
var _right: VBoxContainer
var _wafer: WaferView
var _dev_bar: ProgressBar
var _dev_label: Label
var _name_edit: LineEdit

func build() -> void:
	var sc := UI.scroll()
	add_child(sc)
	var cols := UI.hbox(16)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(cols)
	var panel := UI.blueprint(16)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cols.add_child(panel)
	_left = UI.vbox(10)
	panel.add_child(_left)
	_right = UI.vbox(12)
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(_right)
	_d = Chips.default_design(company)
	_d["name"] = "%s C%d" % [company.company_name.split(" ")[0], company.chips.size() + 1]

func _touch() -> void:
	_last_sig = "\u0001"
	refresh()

func signature() -> String:
	var c := company
	return "%s|%d|%d|%d|%d" % [str(_d), c.research_level("res_chips"), c.chips.size(), 1 if c.chip_dev != null else 0, int(c.money / 5000.0) + int(c.reputation / 5.0) * 100000]

func rebuild() -> void:
	var c := company
	UI.clear(_left)
	UI.clear(_right)
	_dev_bar = null
	_left.add_child(UI.label("Projeto de processador", 36, Color("bfe0ff")))
	if c.research_level("res_chips") < 1:
		_left.add_child(UI.wrap("Pesquise \"Projeto de Chips\" na aba Pesquisa para criar seus próprios processadores. Chips próprios melhoram desempenho e margem, mas esquentam e podem ter bugs.", 24, Color("9fc0e8")))
		_right_side()
		return
	_name_edit = LineEdit.new()
	_name_edit.text = str(_d.name)
	_name_edit.custom_minimum_size = Vector2(0, 66)
	_name_edit.add_theme_font_size_override("font_size", 26)
	_name_edit.text_changed.connect(func(t: String): _d.name = t)
	_left.add_child(_name_edit)
	_left.add_child(UI.label("Nó de fabricação", 22, Palette.MUTED))
	var ng := GridContainer.new()
	ng.columns = 3
	ng.add_theme_constant_override("h_separation", 8)
	ng.add_theme_constant_override("v_separation", 8)
	for n in GameData.chips().nodes:
		var ok := Chips.node_unlocked(c, n)
		var b := UI.button(str(n.name), func(): _d.node = str(n.id); _touch(), "primary" if str(n.id) == str(_d.node) else "normal", 58, 0, "" if ok else "lock")
		b.disabled = not ok
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ng.add_child(b)
	_left.add_child(ng)
	_left.add_child(UI.label("Fundição", 22, Palette.MUTED))
	var fg := GridContainer.new()
	fg.columns = 3
	fg.add_theme_constant_override("h_separation", 8)
	for f in GameData.chips().foundries:
		var ok2 := c.reputation >= float(f.rep)
		var b2 := UI.button(str(f.name).split(" ")[0], func(): _d.foundry = str(f.id); _touch(), "primary" if str(f.id) == str(_d.foundry) else "normal", 58, 0, "" if ok2 else "lock")
		b2.disabled = not ok2
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fg.add_child(b2)
	_left.add_child(fg)
	_left.add_child(UI.wrap(str(Chips.foundry(str(_d.foundry)).desc), 20, Color("9fc0e8")))
	_left.add_child(UI.stepper("Núcleos", str(int(_d.cores)), func(): _d.cores = maxi(1, int(_d.cores) - 1); _touch(), func(): _d.cores = mini(Chips.MAX_CORES, int(_d.cores) + 1); _touch(), int(_d.cores) > 1, int(_d.cores) < Chips.MAX_CORES, 200))
	_left.add_child(UI.stepper("Clock", "%.1f GHz" % float(_d.clock), func(): _d.clock = snappedf(maxf(Chips.CLOCK_MIN, float(_d.clock) - 0.1), 0.1); _touch(), func(): _d.clock = snappedf(minf(Chips.CLOCK_MAX, float(_d.clock) + 0.1), 0.1); _touch(), float(_d.clock) > Chips.CLOCK_MIN + 0.01, float(_d.clock) < Chips.CLOCK_MAX - 0.01, 200))
	_left.add_child(UI.stepper("Cache", "%d MB" % int(_d.cache), func(): _d.cache = maxi(1, int(_d.cache) / 2); _touch(), func(): _d.cache = mini(Chips.MAX_CACHE, int(_d.cache) * 2); _touch(), int(_d.cache) > 1, int(_d.cache) < Chips.MAX_CACHE, 200))
	_left.add_child(UI.stepper("NPU (IA)", str(int(_d.npu)), func(): _d.npu = maxi(0, int(_d.npu) - 1); _touch(), func(): _d.npu = mini(Chips.MAX_NPU, int(_d.npu) + 1); _touch(), int(_d.npu) > 0, int(_d.npu) < Chips.MAX_NPU, 200))
	var st := Chips.stats(_d)
	var box := UI.card(Color("0b1830"), 14)
	_left.add_child(box)
	var gv := UI.vbox(2)
	box.add_child(gv)
	gv.add_child(UI.kv("Transistores", "%.1f bi" % float(st.transistors), Palette.TEXT, 24))
	gv.add_child(UI.kv("Área do die", "%.0f mm²" % float(st.area), Palette.TEXT, 24))
	gv.add_child(UI.kv("Dies por wafer", "%d" % int(st.dpw), Palette.TEXT, 24))
	gv.add_child(UI.kv("Rendimento (Murphy)", "%d%%" % int(float(st.yield) * 100.0), Palette.GOOD if float(st.yield) > 0.7 else (Palette.WARN if float(st.yield) > 0.45 else Palette.BAD), 24))
	gv.add_child(UI.kv("Custo por chip bom", Fmt.money(float(st.unit_cost)), Palette.ACCENT, 26))
	gv.add_child(UI.kv("Desempenho", "%.2f× referência" % float(st.index), Palette.INFO, 24))
	gv.add_child(UI.kv("Consumo (TDP)", "%.1f W" % float(st.tdp), Palette.TEXT, 24))
	gv.add_child(UI.kv("Risco de bug no tape-out", "%d%%" % int(float(st.bug) * 100.0), Palette.WARN if float(st.bug) > 0.12 else Palette.TEXT, 24))
	var caps := ""
	for cat in GameData.categories():
		caps += "%s %.0fW · " % [str(cat.name), Chips.thermal_cap(str(cat.id), {"thermal": 25})]
	gv.add_child(UI.wrap("Calor suportado (térmica padrão): " + caps.trim_suffix(" · "), 19, Color("9fc0e8")))
	_wafer = WaferView.new()
	_wafer.seed_v = int(_d.cores) * 31 + int(_d.cache) + int(float(_d.clock) * 10.0)
	_wafer.set_chip(float(st.area), float(st.yield))
	_left.add_child(_wafer)
	var why := Chips.blocker(c, _d)
	var btn := UI.button("Desenvolver  —  %s · %d trabalho" % [Fmt.money(Chips.dev_cost(_d)), int(Chips.dev_work(_d))], func(): act(Chips.start(c, _d)), "good", 84)
	btn.disabled = why != ""
	_left.add_child(btn)
	if why != "":
		_left.add_child(UI.label(why, 22, Palette.BAD))
	_right_side()

func _right_side() -> void:
	var c := company
	if c.chip_dev != null:
		var card := UI.card(Palette.PANEL, 18)
		_right.add_child(card)
		var v := UI.vbox(8)
		card.add_child(v)
		v.add_child(UI.heading("Em desenvolvimento: %s" % str(c.chip_dev.design.name)))
		_dev_bar = UI.bar(0.0, Palette.ACCENT, 18)
		v.add_child(_dev_bar)
		_dev_label = UI.label("", 22, Palette.MUTED)
		v.add_child(_dev_label)
	var lst := UI.card(Palette.PANEL, 18)
	_right.add_child(lst)
	var lv := UI.vbox(10)
	lst.add_child(lv)
	lv.add_child(UI.heading("Seus processadores"))
	if c.chips.is_empty():
		lv.add_child(UI.wrap("Nenhum chip ainda. Escolha um chip no passo Hardware do estúdio de produtos."))
	for ch in c.chips:
		var st := Chips.chip_stats(ch)
		var thr := ""
		for cat in GameData.categories():
			thr += "%s %d%%  " % [str(cat.name), int(Chips.throttle(c, ch, str(cat.id), {"thermal": 25}) * 100.0)]
		var box := UI.card(Palette.PANEL_ALT, 14)
		lv.add_child(box)
		var bv := UI.vbox(4)
		box.add_child(bv)
		var h := UI.hbox(8)
		h.add_child(UI.label(str(ch.name), 28, Palette.ACCENT))
		h.add_child(UI.spacer())
		h.add_child(UI.button("Descartar", func(): act(Chips.delete_chip(c, int(ch.id))), "danger", 54, 160))
		bv.add_child(h)
		bv.add_child(UI.label("%s · %d núcleos · %.1f GHz · %d MB · NPU %d" % [str(Chips.node(str(ch.node)).name), int(ch.cores), float(ch.clock), int(ch.cache), int(ch.npu)], 22, Palette.MUTED))
		bv.add_child(UI.label("custo %s · rendimento %d%% · %.1f W · desempenho %.2f×" % [Fmt.money(float(st.unit_cost)), int(float(st.yield) * 100.0), float(st.tdp), float(st.index)], 22, Palette.TEXT))
		bv.add_child(UI.label("Desempenho sustentado: " + thr, 20, Palette.MUTED))
		bv.add_child(UI.label("Bug no tape-out: %d%%" % int(float(ch.bug) * 100.0), 20, Palette.WARN if float(ch.bug) > 0.12 else Palette.MUTED))
	lv.add_child(UI.wrap("Chips grandes têm rendimento menor e custo explosivo; clock alto esquenta e estrangula em aparelhos pequenos. Equilibre!", 21))

func live() -> void:
	var c := company
	if c.chip_dev != null and _dev_bar != null:
		_dev_bar.value = float(c.chip_dev.work) / float(c.chip_dev.req)
		_dev_label.text = "%d%% — engenheiros trabalham no projeto" % int(100.0 * float(c.chip_dev.work) / float(c.chip_dev.req))
