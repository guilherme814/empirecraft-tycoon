extends Page
## Lojas: abra lojas nos países que quiser e personalize (tamanho, fachada, equipe). Prévia 3D ao lado.

var _spec: Dictionary = {}
var _draft: Dictionary = {}
var _sel: int = -1          # loja existente selecionada (-1 = nova)
var _scene: StoreScene
var _body: VBoxContainer
var _tab: String = "open"     # "open" = abrir (países) | "mine" = minhas lojas

func build() -> void:
	_spec = Stores.default_spec("br")
	var row := UI.hbox(14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	var sc := UI.scroll()
	sc.size_flags_stretch_ratio = 1.0
	row.add_child(sc)
	_body = UI.vbox(12)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_body)
	var frame := PanelContainer.new()
	var fs := Palette.box(Color("0b0f1c"), 22, 0)
	fs.border_color = Palette.PANEL_ALT
	fs.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", fs)
	frame.clip_contents = true
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.size_flags_stretch_ratio = 1.15
	row.add_child(frame)
	_scene = StoreScene.new()
	frame.add_child(_scene)

func signature() -> String:
	var c := company
	var parts: Array = [_tab, str(_spec), str(_draft), _sel, int(c.reputation / 5.0), c.money >= 100000.0, c.money >= 500000.0]
	for s in c.stores:
		parts.append("%d%s%d%s" % [s.id, s.facade, s.staff, int(s.units) / 200])
	return str(parts)

func _cur() -> Dictionary:
	if _sel != -1:
		var s: Variant = Stores.get_store(company, _sel)
		if s != null:
			var d: Dictionary = (s as Dictionary).duplicate()
			for k in _draft:
				d[k] = _draft[k]
			return d
		_sel = -1
	return _spec

func _pick(k: String, v: Variant) -> void:
	_spec[k] = v
	if k == "size":
		_spec.staff = clampi(int(_spec.staff), 1, int(GameData.store_opt("sizes", str(v)).max_staff))
	if k == "country":
		_spec.city = str(GameData.country(str(v)).cities[0])
	_last_sig = "\u0001"
	refresh()

func rebuild() -> void:
	var c := company
	UI.clear(_body)
	var cur := _cur()
	var editing := _sel != -1
	var ct := GameData.country(str(cur.country))
	_body.add_child(UI.label("Lojas (%d)  ·  %s/mês" % [c.stores.size(), Fmt.money(Stores.total_monthly(c))], 30, Palette.TEXT))

	_tabs_and_countries(cur, editing)

	# lista de lojas abertas
	if not c.stores.is_empty():
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", 8)
		chips.add_theme_constant_override("v_separation", 8)
		_body.add_child(chips)
		for s in c.stores:
			var sid: int = s.id
			var cn := GameData.country(str(s.country))
			chips.add_child(UI.button("%s · %s" % [cn.name, s.city], func(): _sel = sid; _draft = {}; _last_sig = "\u0001"; refresh(), "primary" if sid == _sel else "normal", 64))
		chips.add_child(UI.button("+ Nova", func(): _sel = -1; _draft = {}; _last_sig = "\u0001"; refresh(), "good" if not editing else "normal", 64))

	var card := UI.card(Palette.PANEL, 16)
	_body.add_child(card)
	var v := UI.vbox(10)
	card.add_child(v)
	if editing:
		v.add_child(UI.label(str(cur.name), 28, Palette.ACCENT))
		v.add_child(UI.label("%s · %s · %s" % [ct.name, cur.city, GameData.store_opt("sizes", str(cur.size)).name], 24, Palette.MUTED))
	else:
		v.add_child(UI.label("Nova loja", 28, Palette.ACCENT))
		v.add_child(UI.label("Cidade", 24, Palette.MUTED))
		var cy := HBoxContainer.new()
		cy.add_theme_constant_override("separation", 8)
		v.add_child(cy)
		for city in ct.cities:
			var cs: String = city
			cy.add_child(UI.button(cs, func(): _pick("city", cs), "primary" if cs == str(cur.city) else "normal", 60))
		v.add_child(UI.label("Tamanho", 24, Palette.MUTED))
		var sz := HBoxContainer.new()
		sz.add_theme_constant_override("separation", 8)
		v.add_child(sz)
		for k in GameData.stores().sizes:
			var sid2: String = k.id
			var b2 := UI.button(str(k.name), func(): _pick("size", sid2), "primary" if sid2 == str(cur.size) else "normal", 60)
			b2.disabled = c.reputation < float(k.rep)
			sz.add_child(b2)
	v.add_child(UI.label("Fachada", 24, Palette.MUTED))
	var fc := HBoxContainer.new()
	fc.add_theme_constant_override("separation", 8)
	v.add_child(fc)
	for k in GameData.stores().facades:
		var fid: String = k.id
		fc.add_child(UI.button(str(k.name), func(): _facade(fid), "primary" if fid == str(cur.facade) else "normal", 60))
	var size := GameData.store_opt("sizes", str(cur.size))
	v.add_child(UI.stepper("Equipe", "%d / %d" % [int(cur.staff), int(size.max_staff)],
		func(): _staff(-1), func(): _staff(1), int(cur.staff) > 1, int(cur.staff) < int(size.max_staff), 160))

	# números
	var forecast := Stores.forecast(c, cur)
	v.add_child(UI.kv("Abertura", Fmt.money(Stores.open_cost(cur)), Palette.TEXT, 24))
	v.add_child(UI.kv("Custo mensal", Fmt.money(Stores.monthly_cost(cur)), Palette.WARN, 24))
	v.add_child(UI.kv("Vendas previstas", "%s un./dia" % Fmt.dec(forecast, 1) if not c.released_products().is_empty() else "lance um produto", Palette.GOOD, 24))
	v.add_child(UI.kv("Experiência da loja", "%d%%" % int(Stores.experience(cur) * 100.0), Palette.INFO, 24))
	if editing:
		v.add_child(UI.kv("Vendidas / receita", "%d un. · %s" % [int(cur.units), Fmt.money(float(cur.revenue))], Palette.TEXT, 24))
		var hb := UI.hbox(10)
		v.add_child(hb)
		hb.add_child(UI.button("Aplicar mudanças", func(): var r2 := Stores.update(c, _sel, str(cur.facade), int(cur.staff)); if r2.ok: _draft = {}; act(r2), "primary", 72))
		hb.add_child(UI.button("Fechar loja", func(): var r := Stores.close(c, _sel); _sel = -1; act(r), "danger", 72))
	else:
		var why := Stores.blocker(c, cur)
		if why != "":
			v.add_child(UI.label(why, 24, Palette.BAD))
		var ob := UI.button("Abrir loja", func(): var r := Stores.open(c, _spec); if r.ok: _spec = Stores.default_spec(str(_spec.country)); act(r), "good", 76)
		ob.disabled = why != ""
		v.add_child(ob)
	var view := cur.duplicate()
	if str(view.get("name", "")).strip_edges() == "":
		view["name"] = "%s %s" % [c.company_name, view.city]
	_scene.logo = c.logo
	_scene.show_store(view, c.released_products().size(), Color(str(ct.color)))

func _facade(fid: String) -> void:
	if _sel != -1:
		_draft["facade"] = fid
		_last_sig = "\u0001"
		refresh()
	else:
		_pick("facade", fid)

func _staff(d: int) -> void:
	if _sel != -1:
		var cur := _cur()
		var mx := int(GameData.store_opt("sizes", str(cur.size)).max_staff)
		_draft["staff"] = clampi(int(cur.staff) + d, 1, mx)
		_last_sig = "\u0001"
		refresh()
	else:
		_pick("staff", int(_spec.staff) + d)

func _tabs_and_countries(cur: Dictionary, editing: bool) -> void:
	var c := company
	var tabs := UI.hbox(8)
	_body.add_child(tabs)
	tabs.add_child(UI.button("Abrir loja", func(): _tab = "open"; _last_sig = "\u0001"; refresh(), "primary" if _tab == "open" else "normal", 64, 220))
	tabs.add_child(UI.button("Minhas lojas (%d)" % c.stores.size(), func(): _tab = "mine"; _last_sig = "\u0001"; refresh(), "primary" if _tab == "mine" else "normal", 64, 280))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_body.add_child(grid)
	if _tab == "mine":
		var sm := Stores.country_summary(c)
		if sm.is_empty():
			_body.add_child(UI.wrap("Nenhuma loja aberta ainda. Escolha um país na aba Abrir loja.", 24, Palette.MUTED))
		for e in sm:
			var eid := str(e.id)
			var t := _tile(str(e.name), "x%d" % int(e.count), "%s/mês" % Fmt.money(float(e.net)), Color(str(e.color)),
				Palette.GOOD if float(e.net) >= 0.0 else Palette.BAD, false)
			t.pressed.connect(func():
				for s in c.stores:
					if str(s.country) == eid:
						_sel = int(s.id)
						break
				_draft = {}
				_last_sig = "\u0001"
				refresh())
			grid.add_child(t)
		return
	for k in GameData.countries():
		var cid: String = k.id
		var locked := c.reputation < float(k.rep)
		var n := Stores.count_in(c, cid)
		var sub := "reputação %d" % int(k.rep) if locked else ("%d aberta%s" % [n, "" if n == 1 else "s"] if n > 0 else "livre")
		var t := _tile(str(k.name), "x%d" % n if n > 0 else "", sub, Color(str(k.color)), Palette.MUTED if locked else Palette.TEXT, cid == str(cur.country) and not editing)
		t.disabled = locked
		t.pressed.connect(func():
			_sel = -1
			_draft = {}
			_pick("country", cid))
		grid.add_child(t)

func _tile(title: String, badge: String, sub: String, col: Color, sub_col: Color, selected: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 78)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Palette.style_button(b, "primary" if selected else "normal")
	b.text = "%s %s\n%s" % [title, badge, sub]
	b.add_theme_font_size_override("font_size", 23)
	b.add_theme_color_override("font_color", Palette.TEXT)
	b.add_theme_color_override("font_disabled_color", Palette.MUTED)
	var st := Palette.box(col.darkened(0.6), 12)
	st.border_color = col
	st.border_width_left = 8
	b.add_theme_stylebox_override("normal", st if not selected else Palette.box(col, 12))
	return b
