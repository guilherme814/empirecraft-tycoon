extends Page
## Operações: fábrica/fabricantes e acordos comerciais (o sistema operacional ficou na aba Sistema).

var _body: HBoxContainer
var _left: VBoxContainer
var _right: VBoxContainer

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
	var stk := ""
	for p in c.released_products():
		stk += "%d:%d:%d:%d,%d;" % [p.id, p.stock / 10, Logistics.pipeline(p) / 10, 1 if p.auto_stock else 0, p.cover_days]
	return stk + "|%d|%s|%d|%d|%s|%s|%d|%d|%d" % [int(c.own_os.get("version", 0)), str(c.own_os.get("focus", {})) + str(c.own_os.get("features", [])) + str(c.research_level("res_software")), 1 if dev != null else 0,
		c.factory_level, str(deal_ids), c.os_accent(), rl, int(c.money / 20000.0), int(c.reputation / 5.0)]

func rebuild() -> void:
	UI.clear(_left)
	UI.clear(_right)
	_build_stock(_left)
	_build_licensed(_left)
	_build_production(_right)
	_build_deals(_right)

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
		row.add_child(UI.label("capacidade %d/dia · prazo %d dias" % [int(k.capacity), int(k.lead)], 21, Palette.INFO))
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

# ── Estoque e pedidos de produção ──
func _build_stock(parent: Control) -> void:
	var c := company
	var card := UI.card(Palette.PANEL, 18)
	parent.add_child(card)
	var v := UI.vbox(8)
	card.add_child(v)
	v.add_child(UI.heading("Estoque e produção"))
	v.add_child(UI.kv("Valor em estoque", Fmt.money(Logistics.value(c)), Palette.INFO, 24))
	v.add_child(UI.wrap("As vendas saem do estoque: sem estoque, a venda se perde. Pedidos custam caixa na hora, entram na fila do fabricante e chegam depois do prazo.", 22))
	var list := c.released_products()
	if list.is_empty():
		v.add_child(UI.wrap("Lance um produto para controlar o estoque.", 23, Palette.MUTED))
	for p in list:
		var pid: int = p.id
		var box := UI.card(Palette.PANEL_ALT, 14)
		v.add_child(box)
		var pv := UI.vbox(6)
		box.add_child(pv)
		var head := UI.hbox(8)
		head.add_child(UI.label(str(p.pname), 26))
		head.add_child(UI.spacer())
		var low: bool = int(p.stock) <= int(Logistics.demand_est(p) * 3.0)
		head.add_child(UI.label("%d un." % p.stock, 26, Palette.BAD if low else Palette.GOOD))
		pv.add_child(head)
		var dem := Logistics.demand_est(p)
		pv.add_child(UI.kv("Vendas/dia", Fmt.dec(dem, 1) + ("  (perdendo %s)" % Fmt.dec(p.lost_ema, 1) if p.lost_ema >= 0.5 else ""), Palette.BAD if p.lost_ema >= 0.5 else Palette.TEXT, 22))
		var pipe := Logistics.pipeline(p)
		if pipe > 0:
			var soon := 9999
			for o in p.orders:
				soon = mini(soon, int(o.ready) - c.day)
			pv.add_child(UI.kv("Em produção", "%d un. (chega em %d d)" % [pipe, maxi(soon, 0)], Palette.INFO, 22))
		var q := Logistics.quote(c, p, 100)
		pv.add_child(UI.kv("Lote de 100", "%s · %d dias" % [Fmt.money(float(q.cost)), int(q.wait)], Palette.MUTED, 22))
		var hb := UI.hbox(8)
		pv.add_child(hb)
		for n in [50, 200, 1000]:
			var qty: int = n
			var b := UI.button("+%d" % qty, func(): act(Logistics.order(c, pid, qty)), "primary", 60, 0)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.disabled = c.money < float(Logistics.quote(c, p, qty).cost)
			hb.add_child(b)
		var ab := UI.hbox(8)
		pv.add_child(ab)
		ab.add_child(UI.button("Automático: " + ("sim" if p.auto_stock else "não"), func():
			p.auto_stock = not p.auto_stock
			_last_sig = "\u0001"
			refresh(), "good" if p.auto_stock else "normal", 60, 0))
		for dd in [15, 30, 60]:
			var days: int = dd
			ab.add_child(UI.button("%d d" % days, func():
				p.cover_days = days
				_last_sig = "\u0001"
				refresh(), "primary" if p.cover_days == days else "normal", 60, 0))
