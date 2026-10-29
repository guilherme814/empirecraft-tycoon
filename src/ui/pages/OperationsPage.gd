extends Page
## Operações: seu próprio sistema operacional, fábrica/fabricantes e acordos comerciais.

var _body: HBoxContainer
var _left: VBoxContainer
var _right: VBoxContainer
var _os_bar: ProgressBar
var _os_label: Label
var _os_name: String = "NovaOS"
var _bar_sig: String = ""

func build() -> void:
	var sc := UI.scroll()
	add_child(sc)
	_body = UI.hbox(16)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_body)
	_left = UI.vbox(14)
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_left)
	_right = UI.vbox(14)
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_right)

func signature() -> String:
	var c := company
	var rl := 0
	for r in GameData.research():
		rl += c.research_level(r.id)
	var dev: Variant = c.own_os.get("dev", null)
	var deal_ids: Array = []
	for d in c.active_deals():
		deal_ids.append(d.id)
	return "%d|%s|%d|%d|%s|%s|%d|%d|%d" % [int(c.own_os.get("version", 0)), str(c.own_os.get("focus", {})) + str(c.own_os.get("features", [])) + str(c.research_level("res_software")), 1 if dev != null else 0,
		c.factory_level, str(deal_ids), c.os_accent(), rl, int(c.money / 20000.0), int(c.reputation / 5.0)]

func rebuild() -> void:
	UI.clear(_left)
	UI.clear(_right)
	_os_bar = null
	_os_label = null
	_build_os(_left)
	_build_licensed(_left)
	_build_production(_right)
	_build_deals(_right)

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
		v.add_child(UI.label("Cor do sistema (tela dos aparelhos)", 24, Palette.MUTED))
		var sw := UI.hbox(8)
		v.add_child(sw)
		for col in GameData.designs().colors:
			var hexs := str(col.hex)
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(64, 64)
			var sel := c.os_accent() == hexs
			var sb := Palette.box(Color(hexs), 32, 0)
			sb.border_color = Palette.ACCENT if sel else Color("0e1016")
			sb.set_border_width_all(6 if sel else 2)
			for st in ["normal", "hover", "pressed"]:
				b.add_theme_stylebox_override(st, sb)
			b.pressed.connect(func(): Sfx.play("click"); c.set_os_accent(hexs); _last_sig = "\u0001"; Game.changed.emit())
			sw.add_child(b)
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

func _build_licensed(parent: Control) -> void:
	var card := UI.card(Palette.PANEL, 18)
	parent.add_child(card)
	var v := UI.vbox(8)
	card.add_child(v)
	v.add_child(UI.heading("Sistemas licenciados"))
	for o in GameData.os_data().licensed:
		v.add_child(UI.kv(str(o.name), "qual. ×%.2f · royalty %d%%" % [float(o.q), int(float(o.royalty) * 100.0)], Palette.TEXT, 24))
		v.add_child(UI.wrap(str(o.desc), 21))

# ── Produção ──
func _build_production(parent: Control) -> void:
	var c := company
	var f := c.factory_info()
	var card := UI.card(Palette.PANEL, 18)
	parent.add_child(card)
	var v := UI.vbox(10)
	card.add_child(v)
	v.add_child(UI.heading("Produção"))
	if c.factory_level > 0:
		var st := c.mfr_stats("own")
		v.add_child(UI.kv("Fábrica própria", "nível %d" % c.factory_level, Palette.GOOD, 28))
		v.add_child(UI.kv("Custo ×%.2f · qualidade ×%.2f" % [float(st.cost), float(st.q)], "manutenção %s/mês" % Fmt.money(float(f.upkeep[c.factory_level - 1])), Palette.MUTED, 22))
	else:
		v.add_child(UI.wrap("Sem fábrica própria: seus produtos são feitos por terceirizadas.", 24))
	if c.factory_level < f.build.size():
		var why := c.factory_blocker()
		var b := UI.button("Construir fábrica nv.%d  —  %s" % [c.factory_level + 1, Fmt.money(float(f.build[c.factory_level]))],
			func(): act(c.build_factory()), "primary", 80)
		b.disabled = why != ""
		v.add_child(b)
		if why != "" and why != "Dinheiro insuficiente":
			v.add_child(UI.label(why, 24, Palette.BAD))
	v.add_child(UI.label("Fabricantes terceirizados", 26, Palette.MUTED))
	for k in GameData.manufacturers().contractors:
		var ok := c.reputation >= float(k.rep)
		var row := UI.vbox(2)
		row.add_child(UI.label(str(k.name) + ("" if ok else "  (reputação %d)" % int(k.rep)), 26, Palette.TEXT if ok else Palette.MUTED))
		row.add_child(UI.label("custo ×%.2f · qual. ×%.2f · defeitos %d%%/mês · taxa %s" % [float(k.cost), float(k.q),
			int(round(float(k.risk) * 100.0)), Fmt.money(float(k.fee))], 21, Palette.MUTED))
		row.add_child(UI.wrap(str(k.desc), 21))
		v.add_child(row)
	v.add_child(UI.wrap("Escolha o fabricante de cada produto no estúdio (ou troque depois na lista de produtos).", 21))

# ── Acordos comerciais ──
func _build_deals(parent: Control) -> void:
	var c := company
	var card := UI.card(Palette.PANEL, 18)
	parent.add_child(card)
	var v := UI.vbox(10)
	card.add_child(v)
	v.add_child(UI.heading("Acordos comerciais  (%d/%d)" % [c.active_deals().size(), Company.MAX_DEALS]))
	for d in GameData.deals():
		var active := c.deal_active(str(d.id))
		var box := UI.card(Palette.PANEL_ALT, 14)
		v.add_child(box)
		var dv := UI.vbox(4)
		box.add_child(dv)
		dv.add_child(UI.label(str(d.name), 27, Palette.GOOD if active else Palette.TEXT))
		dv.add_child(UI.wrap(str(d.desc), 21))
		var eff: Array = []
		if float(d.sales) > 0.0:
			eff.append("vendas +%d%%" % int(float(d.sales) * 100.0))
		if float(d.commission) > 0.0:
			eff.append("comissão %d%%" % int(float(d.commission) * 100.0))
		if float(d.cost) > 0.0:
			eff.append("custo -%d%%" % int(float(d.cost) * 100.0))
		if int(d.commit) > 0:
			eff.append("mínimo %s/mês" % Fmt.money(float(d.commit)))
		eff.append("%d dias" % int(d.days))
		dv.add_child(UI.label(" · ".join(eff), 21, Palette.INFO))
		if active:
			var until := 0
			for a in c.deals:
				if a.id == d.id:
					until = int(a.until)
			dv.add_child(UI.label("Em vigor até %s" % Fmt.date(until), 22, Palette.GOOD))
		else:
			var why := c.deal_blocker(str(d.id))
			var b := UI.button("Fechar acordo  —  %s" % Fmt.money(float(d.fee)), func(): act(c.sign_deal(str(d.id))), "primary", 66)
			b.disabled = why != ""
			dv.add_child(b)
			if why != "" and not why.begins_with("Taxa"):
				dv.add_child(UI.label(why, 21, Palette.MUTED))

func live() -> void:
	var c := company
	var dev: Variant = c.own_os.get("dev", null)
	if dev != null and _os_bar != null:
		_os_bar.value = float(dev.work) / float(dev.req)
		_os_label.text = "Desenvolvendo v%d: %d%%" % [int(c.own_os.get("version", 0)) + 1, int(100.0 * float(dev.work) / float(dev.req))]
