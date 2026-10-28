extends Page
## Produtos: projetar (distribuir pontos de especificação), acompanhar o desenvolvimento,
## lançar e ajustar preço.

var _cat_id: String = "phone"
var _specs: Dictionary = {}
var _pname: String = ""
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
	_form = UI.vbox(12)
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.size_flags_stretch_ratio = 1.0
	cols.add_child(_form)
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
	_pname = company.suggested_product_name(_cat_id)

# ── formulário: reconstruído quando o projeto em edição muda ──
func signature() -> String:
	var c := company
	return "%s|%s|%s|%d|%d|%d|%d" % [_cat_id, str(_specs), _pname, c.spec_budget(), c.dev_products().size(),
		1 if c.money >= float(GameData.category(_cat_id).dev_cost) else 0, c.staff.size()]

func rebuild() -> void:
	UI.clear(_form)
	var c := company
	var cat: Dictionary = GameData.category(_cat_id)
	_form.add_child(UI.heading("Novo produto"))

	var tabs := GridContainer.new()
	tabs.columns = 4
	tabs.add_theme_constant_override("h_separation", 8)
	_form.add_child(tabs)
	for k in GameData.categories():
		var unlocked := c.category_unlocked(k.id)
		var b := UI.button(str(k.name), func(): _pick_category(k.id), "primary" if k.id == _cat_id else "normal", 70,
			0, str(k.id) if unlocked else "lock", "nav")
		b.disabled = not unlocked
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 22)
		tabs.add_child(b)

	var nrow := UI.hbox(10)
	_form.add_child(nrow)
	nrow.add_child(UI.label(_pname, 32))
	nrow.add_child(UI.spacer())
	nrow.add_child(UI.button("Sortear nome", func(): _reroll(), "normal", 64))

	var used := c.specs_used(_specs)
	var budget := c.spec_budget()
	_form.add_child(UI.kv("Pontos de especificação", "%d / %d" % [used, budget], Palette.ACCENT if used <= budget else Palette.BAD, 28))
	for a in cat.axes:
		var row := UI.hbox(8)
		_form.add_child(row)
		var l := UI.label(str(GameData.AXIS_LABELS.get(a, a)), 26)
		l.custom_minimum_size = Vector2(210, 0)
		row.add_child(l)
		row.add_child(UI.button("−", func(): _adjust(a, -Rules.SPEC_STEP), "normal", 70, 80))
		var val := UI.label(str(int(_specs.get(a, 0))), 30, Palette.ACCENT)
		val.custom_minimum_size = Vector2(70, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(val)
		var plus := UI.button("+", func(): _adjust(a, Rules.SPEC_STEP), "normal", 70, 80)
		plus.disabled = used + Rules.SPEC_STEP > budget or int(_specs.get(a, 0)) >= Rules.SPEC_AXIS_MAX
		row.add_child(plus)
		row.add_child(UI.bar(float(_specs.get(a, 0)) / float(Rules.SPEC_AXIS_MAX), Palette.INFO, 16))

	var q := c.estimate_quality(_cat_id, _specs)
	var uc := c.estimate_unit_cost(_cat_id, _specs)
	var fp := c.fair_price(_cat_id, q)
	var exp_q := c.market.expectation(c.day)
	var qcolor := Palette.GOOD if q >= exp_q * 1.1 else (Palette.TEXT if q >= exp_q * 0.8 else Palette.BAD)
	var est := UI.card(Palette.PANEL_ALT, 16)
	_form.add_child(est)
	var ev := UI.vbox(4)
	est.add_child(ev)
	ev.add_child(UI.kv("Qualidade estimada", "%d  (mercado espera %d)" % [int(q), int(exp_q)], qcolor))
	ev.add_child(UI.kv("Custo de produção", Fmt.money(uc) + " /un."))
	ev.add_child(UI.kv("Preço justo", Fmt.money(fp)))
	ev.add_child(UI.kv("Custo de desenvolvimento", Fmt.money(float(cat.dev_cost))))
	var per_day := c.dev_work_per_day() / float(c.dev_products().size() + 1)
	ev.add_child(UI.kv("Prazo estimado", "~%d dias" % int(ceil(float(cat.work) / maxf(per_day, 0.01))) if per_day > 0.0 else "sem equipe"))

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
		go.disabled = c.money < float(cat.dev_cost) or c.dev_products().size() >= Rules.MAX_DEV_PRODUCTS
		_form.add_child(go)
		if c.dev_products().size() >= Rules.MAX_DEV_PRODUCTS:
			_form.add_child(UI.wrap("Limite de %d projetos simultâneos." % Rules.MAX_DEV_PRODUCTS, 24, Palette.MUTED))

func live() -> void:
	_update_viewer()
	_refresh_list()

func _update_viewer() -> void:
	var c := company
	var ratio := c.estimate_quality(_cat_id, _specs) / c.market.expectation(c.day)
	_viewer.set_device(_cat_id, _specs, ratio)

# ── lista de produtos: estrutura só muda quando há mudança de estado/preço ──
func _refresh_list() -> void:
	var c := company
	var parts: Array = []
	for p in c.products:
		if p.state != Product.STATE_RETIRED:
			parts.append("%d:%s:%d" % [p.id, p.state, int(p.price)])
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
		_list.add_child(UI.wrap("Nenhum produto ainda. Monte o primeiro ao lado."))

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
	head.add_child(UI.label(str(cat.name), 24, Palette.MUTED))
	v.add_child(head)
	var w := {}
	if p.state == Product.STATE_DEV:
		w["bar"] = UI.bar(p.progress(), Palette.ACCENT, 18)
		v.add_child(w.bar)
		w["label"] = UI.label(_stats_text(p), 24, Palette.MUTED)
		v.add_child(w.label)
	else:
		v.add_child(UI.kv("Qualidade", str(int(round(p.quality)))))
		var fair := c.fair_price(p.category, p.quality)
		var ratio := p.price / maxf(fair, 1.0)
		var tag := "justo" if ratio > 0.9 and ratio < 1.1 else ("caro" if ratio >= 1.1 else "barato")
		var pr := UI.hbox(8)
		pr.add_child(UI.label("Preço", 26, Palette.MUTED))
		pr.add_child(UI.spacer())
		pr.add_child(UI.button("−10%", func(): act(c.set_price(p.id, maxf(1.0, roundf(p.price * 0.9)))), "normal", 64, 110))
		pr.add_child(UI.label("%s (%s)" % [Fmt.money(p.price), tag], 26, Palette.ACCENT))
		pr.add_child(UI.button("+10%", func(): act(c.set_price(p.id, roundf(p.price * 1.1))), "normal", 64, 110))
		v.add_child(pr)
		if p.state == Product.STATE_READY:
			v.add_child(UI.label("Pronto! Ajuste o preço e lance.", 24, Palette.GOOD))
			v.add_child(UI.button("Lançar", func(): act(c.release(p.id)), "good", 80))
		else:
			w["label"] = UI.label(_stats_text(p), 24, Palette.MUTED)
			v.add_child(w.label)
			v.add_child(UI.button("Tirar de linha", func(): act(c.retire(p.id)), "danger", 64))
	_live[p.id] = w
	return card

# ── ações do formulário ──
func _pick_category(id: String) -> void:
	_cat_id = id
	_specs = company.default_specs(id)
	_pname = company.suggested_product_name(id)
	_last_sig = "\u0001"
	refresh()

func _adjust(axis: String, delta: int) -> void:
	var cur: int = int(_specs.get(axis, 0))
	var nv: int = clampi(cur + delta, 0, Rules.SPEC_AXIS_MAX)
	if delta > 0 and company.specs_used(_specs) + (nv - cur) > company.spec_budget():
		return
	_specs[axis] = nv
	_last_sig = "\u0001"
	refresh()

func _reroll() -> void:
	_pname = company.suggested_product_name(_cat_id)
	_last_sig = "\u0001"
	refresh()

func _start() -> void:
	var res := company.create_product(_pname, _cat_id, _specs)
	if res.ok:
		_pname = company.suggested_product_name(_cat_id)
	act(res)
