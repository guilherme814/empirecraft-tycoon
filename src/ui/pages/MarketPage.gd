extends Page
## Mercado: tamanho por categoria, tendências, concorrência e notícias.

var _body: VBoxContainer
var _sel: String = ""      # rival aberto na ficha
var _cat: String = ""      # categoria da comparação de participação

func build() -> void:
	var sc := UI.scroll()
	add_child(sc)
	_body = UI.vbox(14)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_body)

func signature() -> String:
	return "%d|%s|%s" % [company.day / 7, _sel, _cat]

func rebuild() -> void:
	UI.clear(_body)
	var c := company
	var m := c.market
	var top := UI.card()
	_body.add_child(top)
	var tv := UI.vbox(6)
	top.add_child(tv)
	tv.add_child(UI.heading("Expectativa do mercado"))
	tv.add_child(UI.kv("Qualidade esperada hoje", "%d" % int(m.expectation(c.day)), Palette.ACCENT, 28))
	tv.add_child(UI.wrap("Produtos abaixo dessa qualidade vendem pouco. A expectativa sobe com o tempo: pesquise e evolua."))

	_rivals_card()
	_share_card()

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(grid)
	for cat in GameData.categories():
		var card := UI.card(Palette.PANEL, 18)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var v := UI.vbox(6)
		card.add_child(v)
		var unlocked := c.category_unlocked(cat.id)
		v.add_child(UI.icon_label(str(cat.id) if unlocked else "lock", str(cat.name) + ("" if unlocked else "  (bloqueada)"), 30,
			Palette.TEXT if unlocked else Palette.MUTED, Palette.ACCENT if unlocked else Palette.MUTED))
		v.add_child(UI.kv("Mercado", "%d un./dia" % int(m.market_size(cat.id, c.day))))
		var tr := m.trend_mult(cat.id, c.day)
		var tcolor := Palette.GOOD if tr > 1.01 else (Palette.BAD if tr < 0.99 else Palette.TEXT)
		v.add_child(UI.kv("Tendência", "%+d%%" % int(round((tr - 1.0) * 100.0)), tcolor))
		v.add_child(UI.kv("Produtos rivais", str(m.competitor_count(cat.id))))
		var mine := 0
		for p in c.released_products():
			if p.category == cat.id:
				mine += 1
		v.add_child(UI.kv("Seus produtos à venda", str(mine), Palette.ACCENT))

	var news := UI.card()
	_body.add_child(news)
	var nv := UI.vbox(8)
	news.add_child(nv)
	nv.add_child(UI.heading("Histórico"))
	var entries: Array = c.log_entries.duplicate()
	entries.reverse()
	for i in mini(25, entries.size()):
		var e: Dictionary = entries[i]
		nv.add_child(UI.wrap("[%s] %s" % [Fmt.date(int(e.day)), e.text], 24, UI.kind_color(str(e.kind))))

const STRAT := {"premium": "Premium", "volume": "Volume", "value": "Custo-benefício", "innovator": "Inovador"}

func _seg_names(r: Dictionary) -> String:
	var segs: Array = []
	var fo: Variant = r.focus
	for cid in (fo if fo is Array else [fo]):
		segs.append(str(GameData.category(str(cid)).get("name", cid)))
	return ", ".join(segs)

func _rivals_card() -> void:
	var c := company
	var m := c.market
	var rc := UI.card(Palette.PANEL, 18)
	_body.add_child(rc)
	var rv := UI.vbox(8)
	rc.add_child(rv)
	rv.add_child(UI.heading("Concorrentes"))
	var tot := c.last_income * 12.0
	for r in m.rivals:
		tot += float(r.rev_year)
	var my_share := c.last_income * 12.0 / maxf(tot, 1.0)
	rv.add_child(UI.kv("Você", "%s%% do faturamento simulado" % Fmt.dec(my_share * 100.0, 1), Palette.ACCENT, 24))
	rv.add_child(UI.wrap("Toque em uma empresa para ver a ficha: estratégia, histórico, produto-estrela e rivalidade com você.", 22, Palette.MUTED))
	var order: Array = m.rivals.duplicate()
	order.sort_custom(func(a, b): return float(a.rev_year) > float(b.rev_year))
	for r in order:
		var open := str(r.name) == _sel
		var row := UI.hbox(10)
		var nm := UI.button(("▾ " if open else "▸ ") + str(r.name), func():
			_sel = "" if open else str(r.name)
			rebuild(), "primary" if open else "normal", 64, 250)
		row.add_child(nm)
		var war := int(r.get("war_until", 0)) > c.day
		if war:
			row.add_child(UI.label("guerra de preços", 22, Palette.BAD))
		row.add_child(UI.bar(float(r.rev_year) / maxf(tot, 1.0) * 3.0, Palette.INFO, 12))
		var pc := UI.label("%s%%" % Fmt.dec(float(r.rev_year) / maxf(tot, 1.0) * 100.0, 1), 24, Palette.INFO)
		pc.custom_minimum_size = Vector2(90, 0)
		pc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(pc)
		rv.add_child(row)
		if open:
			_rival_sheet(rv, r)

func _rival_sheet(into: VBoxContainer, r: Dictionary) -> void:
	var c := company
	var box := UI.card(Palette.PANEL_ALT, 16)
	into.add_child(box)
	var v := UI.vbox(6)
	box.add_child(v)
	v.add_child(UI.wrap(str(r.get("desc", STRAT.get(str(r.strategy), ""))), 22, Palette.TEXT))
	v.add_child(UI.kv("Segmentos", _seg_names(r), Palette.TEXT, 22))
	v.add_child(UI.kv("Valor de mercado", Fmt.money(float(r.value)), Palette.INFO, 22))
	v.add_child(UI.kv("Caixa", Fmt.money(float(r.cash)), Palette.TEXT, 22))
	v.add_child(UI.kv("Tecnologia", "x%s" % Fmt.dec(float(r.tech), 2), Palette.TEXT, 22))
	var riv := float(r.get("rivalry", 0.0))
	var rcol := Palette.BAD if riv >= 50.0 else (Palette.ACCENT if riv >= 20.0 else Palette.MUTED)
	v.add_child(UI.kv("Rivalidade com você", "%d/100" % int(riv), rcol, 22))
	v.add_child(UI.bar(riv / 100.0, rcol, 10))
	var star: Dictionary = r.get("star", {})
	if not star.is_empty():
		var cn := str(GameData.category(str(star.cat)).get("name", star.cat))
		v.add_child(UI.kv("Produto-estrela", "%s · qualidade %d · %s" % [cn, int(star.quality), Fmt.money(float(star.price))], Palette.ACCENT, 22))
		# comparação com o seu melhor aparelho da mesma categoria
		var mine: Variant = null
		for p in c.released_products():
			if p.category == str(star.cat) and (mine == null or c.effective_quality(p) > c.effective_quality(mine)):
				mine = p
		if mine != null:
			var mq := c.effective_quality(mine)
			var d := mq - float(star.quality)
			v.add_child(UI.kv("Seu melhor (%s)" % mine.pname, "qualidade %d · %s" % [int(mq), Fmt.money(mine.price)], Palette.TEXT, 22))
			v.add_child(UI.wrap("Você está %s na qualidade e %s no preço." % [
				("%d pontos à frente" % int(d)) if d >= 0.0 else ("%d pontos atrás" % int(-d)),
				"mais barato" if mine.price < float(star.price) else "mais caro"], 22, Palette.GOOD if d >= 0.0 else Palette.BAD))
	var hist: Array = r.get("launches", [])
	if hist.is_empty():
		v.add_child(UI.wrap("Nenhum lançamento registrado ainda.", 22, Palette.MUTED))
	else:
		v.add_child(UI.label("Últimos lançamentos", 22, Palette.MUTED))
		for i in range(hist.size() - 1, maxi(-1, hist.size() - 5), -1):
			var h: Dictionary = hist[i]
			v.add_child(UI.wrap("%s · %s · qualidade %d · %s" % [Fmt.date(int(h.day)), str(GameData.category(str(h.cat)).get("name", h.cat)),
				int(h.quality), Fmt.money(float(h.price))], 22, Palette.TEXT))

func _share_card() -> void:
	var c := company
	var cats: Array = GameData.categories()
	if _cat == "":
		_cat = str(cats[0].id)
	var card := UI.card(Palette.PANEL, 18)
	_body.add_child(card)
	var v := UI.vbox(8)
	card.add_child(v)
	v.add_child(UI.heading("Participação por categoria"))
	var tabs := UI.hbox(8)
	v.add_child(tabs)
	for cat in cats:
		var id := str(cat.id)
		tabs.add_child(UI.button(str(cat.name), func():
			_cat = id
			rebuild(), "primary" if id == _cat else "normal", 60))
	var shares := c.category_shares(_cat)
	if shares.is_empty():
		v.add_child(UI.wrap("Sem produtos nesta categoria ainda.", 22, Palette.MUTED))
	for i in mini(6, shares.size()):
		var e: Dictionary = shares[i]
		var row := UI.hbox(10)
		var nm := UI.label(("%d. %s" % [i + 1, e.name]), 24, Palette.ACCENT if e.mine else Palette.TEXT)
		nm.custom_minimum_size = Vector2(230, 0)
		row.add_child(nm)
		row.add_child(UI.bar(float(e.share) * 2.0, Palette.ACCENT if e.mine else Palette.INFO, 12))
		var pc := UI.label("%s%%" % Fmt.dec(float(e.share) * 100.0, 1), 24, Palette.TEXT)
		pc.custom_minimum_size = Vector2(90, 0)
		pc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(pc)
		v.add_child(row)
