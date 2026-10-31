extends Page
## Bolsa: ranking de empresas por valor, ações dos concorrentes e abertura de capital.

var _body: VBoxContainer
var _refs: Dictionary = {}     # nome -> {"price": Label, "chg": Label, "chart": Chart, "hold": Label}
var _own_refs: Dictionary = {}
var _head_l: Label

func build() -> void:
	var sc := UI.scroll()
	add_child(sc)
	_body = UI.vbox(14)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_body)

func signature() -> String:
	var c := company
	var h: Array = []
	for k in c.stocks.holdings:
		h.append("%s:%d" % [k, int(c.stocks.holdings[k].n)])
	return "%s|%d|%d|%s" % [str(h), int(c.stocks.public_pct * 100.0), int(c.money / 10000.0), c.stocks.can_ipo(c)]

func _mood() -> String:
	var m := company.market.macro
	if m > 1.12: return "Euforia"
	if m > 1.03: return "Otimismo"
	if m > 0.97: return "Neutro"
	if m > 0.88: return "Cautela"
	return "Pânico"

func _change(hist: Array, days: int = 30) -> float:
	if hist.size() < 2:
		return 0.0
	var i := maxi(0, hist.size() - 1 - days)
	return float(hist[hist.size() - 1]) / maxf(float(hist[i]), 0.0001) - 1.0

func rebuild() -> void:
	UI.clear(_body)
	_refs.clear()
	_own_refs.clear()
	var c := company
	var m := c.market
	var top := UI.hbox(14)
	_body.add_child(top)
	var info := [["Valor da sua empresa", Fmt.money(c.stocks.value), Palette.ACCENT],
		["Suas ações (carteira)", Fmt.money(c.stocks.portfolio_value(m)), Palette.INFO],
		["Humor do mercado", _mood(), Palette.GOOD if m.macro >= 1.0 else Palette.BAD]]
	for it in info:
		var card := UI.card(Palette.PANEL, 16)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(card)
		var v := UI.vbox(2)
		card.add_child(v)
		v.add_child(UI.label(str(it[0]), 22, Palette.MUTED))
		v.add_child(UI.label(str(it[1]), 32, it[2]))

	# ranking
	var rank := UI.card(Palette.PANEL, 18)
	_body.add_child(rank)
	var rv := UI.vbox(6)
	rank.add_child(rv)
	rv.add_child(UI.heading("Maiores empresas"))
	var list: Array = [{"name": c.company_name + " (você)", "value": c.stocks.value, "me": true}]
	for r in m.rivals:
		list.append({"name": r.name, "value": float(r.value), "me": false})
	list.sort_custom(func(a, b): return float(a.value) > float(b.value))
	for i in list.size():
		var it: Dictionary = list[i]
		rv.add_child(UI.kv("%d.  %s" % [i + 1, it.name], Fmt.money(float(it.value)), Palette.ACCENT if it.me else Palette.TEXT, 26))

	_build_own(c)
	_body.add_child(UI.heading("Ações dos concorrentes"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(grid)
	for r in m.rivals:
		grid.add_child(_rival_card(r))
	_body.add_child(UI.wrap("Preços seguem o valor da empresa (vendas e lucro), com ruído e o humor geral do mercado. Cada compra/venda paga 1% de corretagem.", 21))

func _rival_card(r: Dictionary) -> Control:
	var c := company
	var name := str(r.name)
	var card := UI.card(Palette.PANEL, 16)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(6)
	card.add_child(v)
	var head := UI.hbox(8)
	var fcs: Variant = r.focus
	var ficon: String = str((fcs as Array)[0]) if fcs is Array else str(fcs)
	head.add_child(UI.icon_label(ficon, name, 28, Palette.TEXT, Palette.ACCENT))
	head.add_child(UI.spacer())
	var chg := UI.label("", 26)
	head.add_child(chg)
	v.add_child(head)
	var price := UI.label("", 34, Palette.ACCENT)
	v.add_child(price)
	var chart := Chart.new(120)
	chart.show_range = false
	v.add_child(chart)
	v.add_child(UI.kv("Valor da empresa", Fmt.money(float(r.value)), Palette.TEXT, 22))
	v.add_child(UI.kv("Tecnologia", "×%.2f" % float(r.tech), Palette.TEXT, 22))
	var hold := UI.label("", 22, Palette.MUTED)
	v.add_child(hold)
	var row := UI.hbox(8)
	v.add_child(row)
	var have := c.stocks.holding(name)
	for q in [100, 1000]:
		var b := UI.button("Comprar %d" % q, func(): act(c.stocks.buy(c, name, q)), "primary", 62)
		b.disabled = c.money < float(r.price) * float(q) * 1.01
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	var sb := UI.button("Vender tudo", func(): act(c.stocks.sell(c, name, c.stocks.holding(name))), "danger", 62)
	sb.disabled = have <= 0
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sb)
	_refs[name] = {"price": price, "chg": chg, "chart": chart, "hold": hold}
	return card

func _build_own(c: Company) -> void:
	var st := c.stocks
	var card := UI.blueprint(18)
	_body.add_child(card)
	var v := UI.vbox(8)
	card.add_child(v)
	v.add_child(UI.label("Sua empresa na bolsa", 34, Color("bfe0ff")))
	var price := UI.label("", 32, Palette.ACCENT)
	v.add_child(price)
	var chart := Chart.new(130)
	chart.show_range = false
	v.add_child(chart)
	_own_refs = {"price": price, "chart": chart}
	var why := st.can_ipo(c)
	if st.listed():
		v.add_child(UI.kv("Capital aberto", "%d%% nas mãos do público" % int(st.public_pct * 100.0), Palette.TEXT, 24))
		v.add_child(UI.kv("Dividendos pagos", Fmt.money(st.dividends_paid), Palette.TEXT, 24))
		v.add_child(UI.wrap("Acionistas recebem 25% do lucro mensal proporcional à fatia deles e se irritam com prejuízos.", 21, Color("9fc0e8")))
	var row := UI.hbox(8)
	v.add_child(row)
	var ipo_txt := "Abrir capital (20%)" if not st.listed() else "Vender mais 10%"
	var ipo_pct := 0.2 if not st.listed() else 0.1
	var b := UI.button(ipo_txt, func(): act(st.ipo(c, ipo_pct)), "primary", 72)
	b.disabled = why != ""
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b)
	if st.listed():
		var bb := UI.button("Recomprar 10%", func(): act(st.buyback(c, 0.1)), "normal", 72)
		bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bb)
	if why != "":
		v.add_child(UI.label(why, 22, Palette.MUTED))

func live() -> void:
	var c := company
	var m := c.market
	for r in m.rivals:
		var ref: Variant = _refs.get(str(r.name), null)
		if ref == null:
			continue
		var chg := _change(r.hist)
		(ref.price as Label).text = Fmt.money_exact(float(r.price))
		(ref.chg as Label).text = "%+.1f%%" % (chg * 100.0)
		(ref.chg as Label).add_theme_color_override("font_color", Palette.GOOD if chg >= 0.0 else Palette.BAD)
		(ref.chart as Chart).set_series(r.hist, Palette.GOOD if chg >= 0.0 else Palette.BAD)
		var n := c.stocks.holding(str(r.name))
		if n > 0:
			var h: Dictionary = c.stocks.holdings[str(r.name)]
			var val := float(n) * float(r.price)
			(ref.hold as Label).text = "Você tem %s ações (%s, %+.1f%%)" % [Fmt.thousands(n), Fmt.money(val), 100.0 * (val / maxf(float(h.cost), 1.0) - 1.0)]
		else:
			(ref.hold as Label).text = "Você não tem ações"
	if not _own_refs.is_empty():
		var st := c.stocks
		(_own_refs.price as Label).text = Fmt.money_exact(float(st.price)) + " por ação"
		(_own_refs.chart as Chart).set_series(st.hist, Palette.ACCENT)
