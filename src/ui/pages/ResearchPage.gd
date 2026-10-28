extends Page
## Pesquisa: melhorias permanentes e desbloqueio de categorias.

var _body: VBoxContainer

func build() -> void:
	var sc := UI.scroll()
	add_child(sc)
	_body = UI.vbox(14)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_body)

func signature() -> String:
	var c := company
	var parts: Array = []
	for r in GameData.research():
		var cost := c.research_cost(r)
		parts.append("%s:%d:%d" % [r.id, c.research_level(r.id),
			1 if (c.research_blocker(r) == "" and c.research_points >= float(cost.rp) and c.money >= float(cost.money)) else 0])
	parts.append(int(c.research_points / 25.0))   # atualiza o saldo de vez em quando
	return str(parts)

func rebuild() -> void:
	UI.clear(_body)
	var c := company
	var top := UI.card()
	_body.add_child(top)
	var th := UI.hbox(14)
	top.add_child(th)
	th.add_child(UI.icon("flask", 40, Palette.ACCENT))
	th.add_child(UI.label("Pontos de pesquisa: %d" % int(c.research_points), 32, Palette.ACCENT))
	th.add_child(UI.label("+%.1f/dia" % c.research_per_day(), 26, Palette.MUTED))
	th.add_child(UI.spacer())
	th.add_child(UI.button("Pesquisar tudo (auto)", func(): act(c.research_all()), "primary", 76))
	if c.staff_of("researcher").is_empty():
		_body.add_child(UI.wrap("Contrate pesquisadores na aba Equipe para gerar pontos de pesquisa.", 26, Palette.BAD))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(grid)
	for r in GameData.research():
		var card := UI.card(Palette.PANEL, 18)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var v := UI.vbox(8)
		card.add_child(v)
		var head := UI.hbox(8)
		head.add_child(UI.label(str(r.name), 28))
		head.add_child(UI.spacer())
		head.add_child(UI.label("nv. %d/%d" % [c.research_level(r.id), int(r.max)], 26, Palette.ACCENT))
		v.add_child(head)
		v.add_child(UI.wrap(str(r.desc), 23))
		v.add_child(UI.bar(float(c.research_level(r.id)) / float(r.max), Palette.GOOD, 12))
		var blocker := c.research_blocker(r)
		if blocker != "":
			v.add_child(UI.label(blocker, 24, Palette.MUTED))
		else:
			var cost := c.research_cost(r)
			var b := UI.button("Pesquisar  %d PP + %s" % [int(cost.rp), Fmt.money(float(cost.money))],
				func(): act(c.do_research(r.id)), "primary", 72)
			b.disabled = c.research_points < float(cost.rp) or c.money < float(cost.money)
			v.add_child(b)
