extends Page
## Estúdio de produtos: design (formato, medidas, acabamento, cor), hardware, sistema e produção.
## À direita: pré-visualização 3D e a lista de produtos (lançar, preço, trocar SO/fábrica, nova versão).

const STEPS := ["Forma", "Estilo", "Hardware", "Sistema", "Produção"]

var _step: int = 0
var _cat_id: String = "phone"
var _specs: Dictionary = {}
var _design: Dictionary = {}
var _os: String = "droidix"
var _mfr: String = "fabrix"
var _pname: String = ""
var _preview_pid: int = 0
var _form: VBoxContainer
var _list: VBoxContainer
var _viewer: DeviceViewer
var _list_sig: String = "\u0001"
var _live: Dictionary = {}   # product id -> {"bar": ProgressBar, "label": Label}

func build() -> void:
	var sc := UI.scroll()
	add_child(sc)
	var cols := UI.hbox(16)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(cols)
	var panel := UI.blueprint(16)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.15
	panel.custom_minimum_size.x = 0
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cols.add_child(panel)
	_form = UI.vbox(12)
	panel.add_child(_form)
	var right := UI.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var vcard := UI.card(Palette.PANEL_DEEP, 10)
	right.add_child(vcard)
	var vbox := UI.vbox(4)
	vcard.add_child(vbox)
	vbox.add_child(UI.label("Pré-visualização 3D (arraste para girar)", 22, Palette.MUTED))
	_viewer = DeviceViewer.new()
	vbox.add_child(_viewer)
	_list = UI.vbox(12)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_list)
	_reset_form()

func _reset_form() -> void:
	if company == null:
		return
	if not company.category_unlocked(_cat_id):
		_cat_id = "phone"
	_specs = company.default_specs(_cat_id)
	_design = company.default_design(_cat_id)
	_os = company.default_os()
	_mfr = company.default_mfr()
	_pname = company.suggested_product_name(_cat_id)

func _touch() -> void:
	_preview_pid = 0
	_last_sig = "\u0001"
	refresh()

# ── formulário ──
func signature() -> String:
	var c := company
	var rl := 0
	for r in GameData.research():
		rl += c.research_level(r.id)
	return "%d|%s|%s|%s|%s|%s|%s|%d|%d|%d|%d|%d|%d" % [_step, _cat_id, str(_specs), str(_design), _os, _mfr, _pname,
		c.spec_budget(), c.dev_products().size(), 1 if c.money >= float(GameData.category(_cat_id).dev_cost) else 0,
		c.staff.size(), rl, c.factory_level + int(c.own_os.get("version", 0)) * 10 + int(c.reputation / 5.0)]

func rebuild() -> void:
	UI.clear(_form)
	var c := company
	var head := UI.hbox(8)
	_form.add_child(head)
	head.add_child(UI.label("Estúdio de design", 34, Color("bfe0ff")))
	head.add_child(UI.spacer())
	for i in STEPS.size():
		var b := UI.button(str(i + 1), func(): _go(i), "info" if i == _step else "normal", 60, 66)
		head.add_child(b)
	_form.add_child(UI.label(STEPS[_step], 28, Color("ffd9a0")))

	var tabs := GridContainer.new()
	tabs.columns = 4
	tabs.add_theme_constant_override("h_separation", 8)
	_form.add_child(tabs)
	for k in GameData.categories():
		var unlocked := c.category_unlocked(k.id)
		var b := UI.button(str(k.name), func(): _pick_category(k.id), "primary" if k.id == _cat_id else "normal", 66,
			0, str(k.id) if unlocked else "lock", "nav")
		b.disabled = not unlocked
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 21)
		tabs.add_child(b)

	match _step:
		0: _step_shape()
		1: _step_style()
		2: _step_hardware()
		3: _step_system()
		_: _step_production()
	_form.add_child(_stat_bar())

	var nav := UI.hbox(10)
	_form.add_child(nav)
	var back := UI.button("Voltar", func(): _go(_step - 1), "normal", 76)
	back.disabled = _step == 0
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(back)
	if _step < STEPS.size() - 1:
		var nx := UI.button("Avançar", func(): _go(_step + 1), "primary", 76)
		nx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav.add_child(nx)

func _go(i: int) -> void:
	_step = clampi(i, 0, STEPS.size() - 1)
	_touch()

func _opt(text: String, selected: bool, locked: String, cb: Callable) -> Button:
	var b := UI.button(text, cb, "primary" if selected else "normal", 70, 0, "lock" if locked != "" else "", "nav")
	b.disabled = locked != ""
	b.clip_text = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.x = 0
	b.add_theme_font_size_override("font_size", 22)
	if locked != "":
		_locked_hints[locked] = true
	return b

var _locked_hints: Dictionary = {}

func _hints_note() -> void:
	if not _locked_hints.is_empty():
		_form.add_child(UI.wrap("Bloqueado: " + ", ".join(_locked_hints.keys()) + ".", 21, Color("9fc0e8")))
		_locked_hints.clear()

func _lock_text(item: Dictionary) -> String:
	if company.design_item_unlocked(item):
		return ""
	return "%s nv.%d" % [str(GameData.research_item(str(item.req)).get("name", "?")), int(item.lvl)]

func _grid(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	_form.add_child(g)
	return g

func _fmt_mod(q: float, _cost: float) -> String:
	return "%+d%%" % int(round(q * 100.0))

func _step_shape() -> void:
	_locked_hints.clear()
	_form.add_child(UI.label("Formato", 24, Palette.MUTED))
	var g := _grid(2)
	for it in GameData.designs().shapes.get(_cat_id, []):
		g.add_child(_opt("%s  %s" % [it.name, _fmt_mod(float(it.q), float(it.cost))], str(_design.shape) == str(it.id), _lock_text(it),
			func(): _design["shape"] = str(it.id); _touch()))
	_hints_note()
	_form.add_child(UI.label("Medidas", 24, Palette.MUTED))
	var dims: Array = [["w", "Largura"], ["h", "Altura"], ["d", "Espessura"], ["corner", "Curvatura"]]
	if _cat_id == "watch":
		dims.append(["strap", "Largura da pulseira"])
	for dm in dims:
		var key: String = dm[0]
		var v: int = int(_design.get(key, 5))
		_form.add_child(UI.stepper(str(dm[1]), str(v), func(): _design[key] = maxi(1, int(_design.get(key, 5)) - 1); _touch(),
			func(): _design[key] = mini(9, int(_design.get(key, 5)) + 1); _touch(), v > 1, v < 9, 300))
	_form.add_child(UI.wrap("Maior = mais qualidade e custo. Mais fino = mais elegante e mais caro de produzir.", 21, Color("9fc0e8")))

func _swatches(key: String) -> void:
	var sw := UI.hbox(8)
	_form.add_child(sw)
	var fashion := str(company.market.fashion.get("color", ""))
	for col in GameData.designs().colors:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(64, 64)
		var sel: bool = str(_design.get(key, "")) == str(col.id)
		var sb := Palette.box(Color(str(col.hex)), 32, 0)
		sb.border_color = Palette.ACCENT if sel else (Palette.GOOD if (key == "color" and str(col.id) == fashion) else Color("0e1016"))
		sb.set_border_width_all(6 if sel else (4 if (key == "color" and str(col.id) == fashion) else 2))
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, sb)
		b.pressed.connect(func(): Sfx.play("click"); _design[key] = str(col.id); _touch())
		sw.add_child(b)

func _choice_row(label_text: String, key: String, items: Array) -> void:
	_form.add_child(UI.label(label_text, 24, Palette.MUTED))
	var g := _grid(mini(4, maxi(items.size(), 1)))
	for it in items:
		g.add_child(_opt(str(it.name), str(_design.get(key, "")) == str(it.id), "", func(): _design[key] = str(it.id); _touch()))

func _step_style() -> void:
	_locked_hints.clear()
	_form.add_child(UI.label("Acabamento", 24, Palette.MUTED))
	var g2 := _grid(2)
	for it in GameData.designs().finishes:
		g2.add_child(_opt("%s  %s" % [it.name, _fmt_mod(float(it.q), float(it.cost))], str(_design.finish) == str(it.id), _lock_text(it),
			func(): _design["finish"] = str(it.id); _touch()))
	_hints_note()
	var fashion := str(company.market.fashion.get("color", ""))
	var fname := ""
	for col in GameData.designs().colors:
		if str(col.id) == fashion:
			fname = str(col.name)
	_form.add_child(UI.label("Cor do corpo" + ("   (em alta: %s, +4%% vendas)" % fname if fname != "" else ""), 24, Palette.MUTED))
	_swatches("color")
	_form.add_child(UI.label("Cor de detalhes", 24, Palette.MUTED))
	_swatches("trim")
	_choice_row("Papel de parede", "wall", GameData.designs().wallpapers)
	match _cat_id:
		"phone":
			_choice_row("Câmera traseira", "cam", GameData.designs().camera_layouts)
			_choice_row("Recorte da tela", "notch", GameData.designs().notches)
		"watch":
			_choice_row("Material da pulseira", "band", GameData.designs().bands)
		_:
			_form.add_child(UI.label("Cor do LED / teclado", 24, Palette.MUTED))
			_swatches("led")
	_form.add_child(UI.label("Embalagem", 24, Palette.MUTED))
	var pg := _grid(2)
	for it in GameData.designs().packages:
		pg.add_child(_opt("%s  %s" % [it.name, _fmt_mod(float(it.q), float(it.cost))], str(_design.get("package", "basic")) == str(it.id), _lock_text(it),
			func(): _design["package"] = str(it.id); _touch()))
	_form.add_child(UI.label("Acessórios na caixa", 24, Palette.MUTED))
	var ag := _grid(2)
	var accs: Array = _design.get("acc", [])
	for it in GameData.designs().accessories:
		if not (it.cats as Array).has(_cat_id):
			continue
		var on := accs.has(str(it.id))
		ag.add_child(_opt("%s%s  %s" % ["✓ " if on else "", it.name, _fmt_mod(float(it.q), float(it.cost))], on, _lock_text(it),
			func():
				var l: Array = _design.get("acc", [])
				if l.has(str(it.id)):
					l.erase(str(it.id))
				else:
					l.append(str(it.id))
				_design["acc"] = l
				_touch()))
	_hints_note()
	var brand_on: bool = bool(_design.get("brand", true))
	_form.add_child(_opt("Nome da marca no aparelho: " + ("sim" if brand_on else "não"), brand_on, "", func(): _design["brand"] = not brand_on; _touch()))

func _step_hardware() -> void:
	_locked_hints.clear()
	var c := company
	var cat: Dictionary = GameData.category(_cat_id)
	var used := c.specs_used(_specs)
	var budget := c.spec_budget()
	_form.add_child(UI.kv("Pontos de especificação", "%d / %d" % [used, budget], Palette.ACCENT if used <= budget else Palette.BAD, 26))
	for a in cat.axes:
		var v: int = int(_specs.get(a, 0))
		var row := UI.stepper(str(GameData.AXIS_LABELS.get(a, a)), str(v), func(): _adjust(a, -Rules.SPEC_STEP),
			func(): _adjust(a, Rules.SPEC_STEP), v > 0, used + Rules.SPEC_STEP <= budget and v < Rules.SPEC_AXIS_MAX, 210)
		row.add_child(UI.bar(float(v) / float(Rules.SPEC_AXIS_MAX), Palette.INFO, 14))
		_form.add_child(row)
	_form.add_child(UI.label("Recursos extras", 24, Palette.MUTED))
	var g := _grid(2)
	var feats: Array = _design.get("features", [])
	for it in GameData.features(_cat_id):
		var on := feats.has(str(it.id))
		g.add_child(_opt("%s%s  %s" % ["✓ " if on else "", it.name, _fmt_mod(float(it.q), float(it.cost))], on, _lock_text(it),
			func(): _toggle_feature(str(it.id))))
	_hints_note()
	_form.add_child(UI.label("Processador", 24, Palette.MUTED))
	var cg := _grid(1)
	var cur_chip := int(_design.get("chip", 0))
	cg.add_child(_opt("SoC genérico  (padrão)", cur_chip == 0, "", func(): _design["chip"] = 0; _touch()))
	for ch in c.chips:
		var thr := Chips.throttle(c, ch, _cat_id, _specs)
		var st := Chips.chip_stats(ch)
		var txt := "%s  ·  %.2f×  ·  sustenta %d%%  ·  %s" % [str(ch.name), float(st.index), int(thr * 100.0), Fmt.money(float(st.unit_cost))]
		cg.add_child(_opt(txt, cur_chip == int(ch.id), "", func(): _design["chip"] = int(ch.id); _touch()))
	if c.chips.is_empty():
		_form.add_child(UI.wrap("Projete processadores próprios na aba Hardware.", 20, Color("9fc0e8")))

func _step_system() -> void:
	var c := company
	_locked_hints.clear()
	_form.add_child(UI.label("Sistema operacional", 24, Palette.MUTED))
	for o in GameData.os_data().licensed:
		_form.add_child(_opt(str(o.name), _os == str(o.id), "", func(): _os = str(o.id); _touch()))
		_form.add_child(UI.wrap("qual. ×%.2f · royalty %d%% — %s" % [float(o.q), int(float(o.royalty) * 100.0), o.desc], 20, Color("9fc0e8")))
	var oi := c.os_info("own")
	if c.os_available("own"):
		_form.add_child(_opt("%s v%d (seu)" % [oi.name, int(oi.version)], _os == "own", "", func(): _os = "own"; _touch()))
		_form.add_child(UI.wrap("qual. ×%.2f · sem royalty" % c.os_mult("own", _cat_id), 20, Color("9fc0e8")))
	else:
		_form.add_child(UI.wrap("Sistema próprio: pesquise \"Sistema Operacional Próprio\" e desenvolva-o na aba Operações.", 22, Palette.MUTED))

func _step_production() -> void:
	var c := company
	_locked_hints.clear()
	_form.add_child(UI.label("Quem fabrica", 24, Palette.MUTED))
	if c.factory_level > 0:
		var st := c.mfr_stats("own")
		_form.add_child(_opt("Fábrica própria (nv.%d)" % c.factory_level, _mfr == "own", "", func(): _mfr = "own"; _touch()))
		_form.add_child(UI.wrap("custo ×%.2f · qual. ×%.2f · sem defeitos" % [float(st.cost), float(st.q)], 20, Color("9fc0e8")))
	for k in GameData.manufacturers().contractors:
		var lock := "" if c.reputation >= float(k.rep) else "reputação %d" % int(k.rep)
		_form.add_child(_opt(str(k.name), _mfr == str(k.id), lock, func(): _mfr = str(k.id); _touch()))
		_form.add_child(UI.wrap("custo ×%.2f · qual. ×%.2f · defeito %d%% · taxa %s%s" % [float(k.cost), float(k.q),
			int(round(float(k.risk) * 100.0)), Fmt.money(float(k.fee)), "" if lock == "" else " · exige " + lock], 20, Color("9fc0e8")))
	var cat: Dictionary = GameData.category(_cat_id)
	var q := c.estimate_final_quality(_cat_id, _specs, _design, _os, _mfr)
	var uc := c.estimate_final_cost(_cat_id, _specs, _design, _os, _mfr)
	var fp := c.fair_price(_cat_id, q)
	var exp_q := c.market.expectation(c.day)
	var qcolor := Palette.GOOD if q >= exp_q * 1.1 else (Palette.TEXT if q >= exp_q * 0.8 else Palette.BAD)
	var est := UI.card(Color("0f2447"), 16)
	_form.add_child(est)
	var ev := UI.vbox(4)
	est.add_child(ev)
	ev.add_child(UI.kv("Qualidade final", "%d  (mercado espera %d)" % [int(q), int(exp_q)], qcolor))
	ev.add_child(UI.kv("Custo de produção", Fmt.money(uc) + " /un."))
	ev.add_child(UI.kv("Preço justo", Fmt.money(fp)))
	ev.add_child(UI.kv("Margem no preço justo", "%d%%" % int(100.0 * (fp - uc) / maxf(fp, 1.0))))
	var fee := c.mfr_fee(_mfr)
	ev.add_child(UI.kv("Desenvolvimento + taxa", Fmt.money(float(cat.dev_cost) + fee)))
	var per_day := c.dev_work_per_day() / float(c.dev_products().size() + 1)
	ev.add_child(UI.kv("Prazo estimado", "~%d dias" % int(ceil(float(cat.work) / maxf(per_day, 0.01))) if per_day > 0.0 else "sem equipe"))
	var nrow := UI.hbox(10)
	_form.add_child(nrow)
	nrow.add_child(UI.label(_pname, 30))
	nrow.add_child(UI.spacer())
	nrow.add_child(UI.button("Sortear nome", func(): _pname = c.suggested_product_name(_cat_id); _touch(), "normal", 64))
	var go := UI.button("Iniciar desenvolvimento", func(): _start(), "primary", 90)
	var missing := c.missing_professions(_cat_id)
	if not missing.is_empty():
		var names: Array = []
		for m in missing:
			names.append(GameData.profession(m).singular)
		go.disabled = true
		_form.add_child(go)
		_form.add_child(UI.wrap("Contrate: " + ", ".join(names), 24, Palette.BAD))
	else:
		go.disabled = c.money < float(cat.dev_cost) + fee or c.dev_products().size() >= Rules.MAX_DEV_PRODUCTS \
			or not c.design_valid(_cat_id, _design)
		_form.add_child(go)
		if c.dev_products().size() >= Rules.MAX_DEV_PRODUCTS:
			_form.add_child(UI.wrap("Limite de %d projetos simultâneos." % Rules.MAX_DEV_PRODUCTS, 24, Palette.MUTED))

## Barra fixa de estatísticas (como na bancada de montagem): muda ao vivo com cada escolha.
func _stat_bar() -> Control:
	var c := company
	var st := c.device_stats(_cat_id, _specs, _design, _os, _mfr)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", Palette.box(Color("0b1830"), 14, 12))
	var h := UI.hbox(8)
	bar.add_child(h)
	var exp_q := c.market.expectation(c.day)
	var qc := Palette.GOOD if float(st.quality) >= exp_q * 1.1 else (Palette.TEXT if float(st.quality) >= exp_q * 0.8 else Palette.BAD)
	for it in [["QUALIDADE", str(int(st.quality)), qc], ["CUSTO", Fmt.money(float(st.unit_cost)), Palette.TEXT],
			["PREÇO JUSTO", Fmt.money(float(st.fair_price)), Palette.ACCENT], ["MARGEM", "%d%%" % int(float(st.margin) * 100.0), Palette.GOOD if float(st.margin) > 0.2 else Palette.BAD]]:
		var v := UI.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.label(str(it[0]), 17, Color("8fb4e8")))
		v.add_child(UI.label(str(it[1]), 27, it[2]))
		h.add_child(v)
	return bar

func live() -> void:
	_update_viewer()
	_refresh_list()

func _view_design(design: Dictionary, os_id: String) -> Dictionary:
	var d := design.duplicate()
	d["brand_name"] = company.company_name
	if os_id == "own":
		d["accent"] = company.os_accent()
	return d

func _update_viewer() -> void:
	var c := company
	if _preview_pid > 0:
		var p: Variant = c._find_in(c.products, _preview_pid)
		if p != null:
			_viewer.set_device(p.category, p.specs, c.effective_quality(p) / c.market.expectation(c.day), _view_design(p.design, p.os_id))
			return
	var ratio := c.estimate_final_quality(_cat_id, _specs, _design, _os, _mfr) / c.market.expectation(c.day)
	_viewer.set_device(_cat_id, _specs, ratio, _view_design(_design, _os))

# ── lista de produtos ──
func _refresh_list() -> void:
	var c := company
	var parts: Array = []
	for p in c.products:
		if p.state != Product.STATE_RETIRED:
			parts.append("%d:%s:%d:%s:%s:%s" % [p.id, p.state, int(p.price), p.os_id, p.mfr, str(p.design.get("color", ""))])
	var s := str(parts)
	if s != _list_sig:
		_list_sig = s
		_rebuild_list()
	for id in _live:
		var p: Variant = c._find_in(c.products, int(id))
		if p == null:
			continue
		var w: Dictionary = _live[id]
		if w.has("bar"):
			(w.bar as ProgressBar).value = p.progress()
		if w.has("label"):
			(w.label as Label).text = _stats_text(p)

func _stats_text(p: Product) -> String:
	if p.state == Product.STATE_DEV:
		return "Desenvolvimento %d%%" % int(p.progress() * 100.0)
	return "Vendeu %s un.  ·  ~%.1f/dia  ·  lucro %s" % [Fmt.thousands(p.units_total), p.ema_units, Fmt.money(p.profit_total())]

func _rebuild_list() -> void:
	var saved := {}
	for sc in _scrolls(self):
		saved[sc] = sc.scroll_vertical
	UI.clear(_list)
	_live.clear()
	var c := company
	_list.add_child(UI.heading("Seus produtos"))
	var shown := 0
	for p in c.products:
		if p.state == Product.STATE_RETIRED:
			continue
		shown += 1
		_list.add_child(_product_card(p))
	if shown == 0:
		_list.add_child(UI.wrap("Nenhum produto ainda. Monte o primeiro no estúdio ao lado."))
	_restore_scrolls(saved)

func _name_of_os(id: String) -> String:
	return str(company.os_info(id).get("name", id))

func _name_of_mfr(id: String) -> String:
	if id == "own":
		return "Fábrica própria"
	return str(company.contractor(id).get("name", id))

func _cycle(list: Array, cur: String) -> String:
	if list.is_empty():
		return cur
	var i := list.find(cur)
	return str(list[(i + 1) % list.size()])

func _product_card(p: Product) -> Control:
	var c := company
	var cat: Dictionary = GameData.category(p.category)
	var card := UI.card(Palette.PANEL, 18)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(8)
	card.add_child(v)
	var head := UI.hbox(8)
	head.add_child(UI.icon_label(p.category, p.pname, 30, Palette.TEXT, Palette.ACCENT))
	head.add_child(UI.spacer())
	head.add_child(UI.button("Ver 3D", func(): _preview_pid = p.id; refresh(), "normal", 56, 120))
	v.add_child(head)
	v.add_child(UI.label("%s · %s · %s" % [cat.name, _name_of_os(p.os_id), _name_of_mfr(p.mfr)], 22, Palette.MUTED))
	var w := {}
	if p.state == Product.STATE_DEV:
		w["bar"] = UI.bar(p.progress(), Palette.ACCENT, 18)
		v.add_child(w.bar)
		w["label"] = UI.label(_stats_text(p), 24, Palette.MUTED)
		v.add_child(w.label)
	else:
		var eq := c.effective_quality(p)
		v.add_child(UI.kv("Qualidade", "%d  (base %d)" % [int(round(eq)), int(round(p.quality))]))
		v.add_child(UI.kv("Custo atual", Fmt.money(c.current_unit_cost(p)) + " /un."))
		var fair := c.fair_price(p.category, eq)
		var ratio := p.price / maxf(fair, 1.0)
		var tag := "justo" if ratio > 0.9 and ratio < 1.1 else ("caro" if ratio >= 1.1 else "barato")
		var pr := UI.hbox(8)
		pr.add_child(UI.label("Preço", 26, Palette.MUTED))
		pr.add_child(UI.spacer())
		pr.add_child(UI.button("−10%", func(): act(c.set_price(p.id, maxf(1.0, roundf(p.price * 0.9)))), "normal", 64, 110))
		pr.add_child(UI.label("%s (%s)" % [Fmt.money(p.price), tag], 26, Palette.ACCENT))
		pr.add_child(UI.button("+10%", func(): act(c.set_price(p.id, roundf(p.price * 1.1))), "normal", 64, 110))
		v.add_child(pr)
		var opts := UI.hbox(8)
		opts.add_child(UI.button("Trocar SO", func(): act(c.set_os(p.id, _cycle(c.os_option_ids(), p.os_id))), "normal", 60, 0))
		opts.add_child(UI.button("Trocar fábrica", func(): act(c.set_manufacturer(p.id, _cycle(c.mfr_option_ids(), p.mfr))), "normal", 60, 0))
		var cols: Array = []
		for col in GameData.designs().colors:
			cols.append(str(col.id))
		opts.add_child(UI.button("Cor", func(): act(c.set_product_color(p.id, _cycle(cols, str(p.design.get("color", "graphite"))))), "normal", 60, 0))
		for ch in opts.get_children():
			ch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(opts)
		if p.state == Product.STATE_READY:
			v.add_child(UI.label("Pronto! Ajuste o preço e lance.", 24, Palette.GOOD))
			v.add_child(UI.button("Lançar", func(): Game.ui_request.emit("launch", p.id), "good", 80))
		else:
			var open_f := Lab.severity_sum(p)
			if open_f > 0:
				v.add_child(UI.label("Defeitos abertos (gravidade %d): corrija no Laboratório" % open_f, 21, Palette.BAD))
			var rr := UI.hbox(10)
			rr.add_child(UI.label("★ %.1f" % p.rating, 26, Palette.WARN))
			rr.add_child(UI.label("crítica %d" % int(p.critic), 24, Palette.MUTED))
			rr.add_child(UI.spacer())
			rr.add_child(UI.button("Avaliações", func(): Game.ui_request.emit("reviews_list", p.id), "normal", 52, 170))
			v.add_child(rr)
			w["label"] = UI.label(_stats_text(p), 24, Palette.MUTED)
			v.add_child(w.label)
			var last := UI.hbox(8)
			last.add_child(UI.button("Nova versão", func(): _load_from(p), "info", 64))
			last.add_child(UI.button("Tirar de linha", func(): act(c.retire(p.id)), "danger", 64))
			for ch in last.get_children():
				ch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.add_child(last)
	_live[p.id] = w
	return card

func _load_from(p: Product) -> void:
	_cat_id = p.category
	_specs = p.specs.duplicate()
	_design = p.design.duplicate(true)
	if _design.is_empty():
		_design = company.default_design(p.category)
	_os = p.os_id if company.os_available(p.os_id) else company.default_os()
	_mfr = p.mfr if company.mfr_available(p.mfr) else company.default_mfr()
	_pname = p.pname + " II"
	_step = 0
	Game.notice.emit("Projeto copiado para o estúdio", "good")
	_touch()

# ── ações do formulário ──
func _pick_category(id: String) -> void:
	_cat_id = id
	_specs = company.default_specs(id)
	_design = company.default_design(id)
	_pname = company.suggested_product_name(id)
	_touch()

func _adjust(axis: String, delta: int) -> void:
	var cur: int = int(_specs.get(axis, 0))
	var nv: int = clampi(cur + delta, 0, Rules.SPEC_AXIS_MAX)
	if delta > 0 and company.specs_used(_specs) + (nv - cur) > company.spec_budget():
		return
	_specs[axis] = nv
	_touch()

func _toggle_feature(id: String) -> void:
	var feats: Array = _design.get("features", []).duplicate()
	if feats.has(id):
		feats.erase(id)
	else:
		feats.append(id)
	_design["features"] = feats
	_touch()

func _start() -> void:
	var res := company.create_product(_pname, _cat_id, _specs, 0.0, _design, _os, _mfr)
	if res.ok:
		_pname = company.suggested_product_name(_cat_id)
		_step = 0
	act(res)
