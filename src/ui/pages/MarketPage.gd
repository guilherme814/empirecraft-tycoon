extends Page
## Mercado: tamanho por categoria, tendências, concorrência e notícias.

var _body: VBoxContainer

func build() -> void:
	var sc := UI.scroll()
	add_child(sc)
	_body = UI.vbox(14)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_body)

func signature() -> String:
	return str(company.day)

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
