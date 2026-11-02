extends Page
## Pesquisa: melhorias permanentes e desbloqueio de categorias.

var _body: VBoxContainer
var _rp_label: Label
var _area: String = "tech"

func build() -> void:
	var sc := UI.scroll()
	add_child(sc)
	_body = UI.vbox(14)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_body)

func signature() -> String:
	var c := company
	var parts: Array = [_area]
	for r in GameData.research():
		var cost := c.research_cost(r)
		parts.append("%s:%d:%d" % [r.id, c.research_level(r.id),
			1 if (c.research_blocker(r) == "" and c.research_points >= float(cost.rp) and c.money >= float(cost.money)) else 0])
	return str(parts)

func rebuild() -> void:
	UI.clear(_body)
	var c := company
	var top := UI.card()
	_body.add_child(top)
	var th := UI.hbox(14)
	top.add_child(th)
	th.add_child(UI.icon("flask", 40, Palette.ACCENT))
	_rp_label = UI.label("Pontos de pesquisa: %d" % int(c.research_points), 32, Palette.ACCENT)
	th.add_child(_rp_label)
	th.add_child(UI.label("+%.1f/dia" % c.research_per_day(), 26, Palette.MUTED))
	th.add_child(UI.spacer())
	th.add_child(UI.button("Pesquisar tudo (auto)", func(): act(c.research_all()), "primary", 76))
	if c.staff_of("researcher").is_empty():
		_body.add_child(UI.wrap("Contrate pesquisadores na aba Equipe para gerar pontos de pesquisa.", 26, Palette.BAD))

	var split := UI.hbox(14)
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(split)
	# menu lateral de áreas
	var menu := UI.vbox(8)
	menu.custom_minimum_size = Vector2(300, 0)
	split.add_child(menu)
	for a in Rules.RESEARCH_AREAS:
		var done := 0
		var total := 0
		for r in GameData.research():
			if str(r.area) == str(a.id):
				done += c.research_level(r.id)
				total += int(r.max)
		var aid := str(a.id)
		var b := UI.button("%s   %d/%d" % [a.name, done, total], func():
			_area = aid
			rebuild(), "primary" if aid == _area else "normal", 76, 300, str(a.icon))
		menu.add_child(b)
	# cartões da área escolhida
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(grid)
	for r in GameData.research():
		if str(r.area) != _area:
			continue
		_card(grid, r)

func _card(grid: GridContainer, r: Dictionary) -> void:
	var c := company
	var lvl := c.research_level(r.id)
	var mx := int(r.max)
	var blocker := c.research_blocker(r)
	var maxed := lvl >= mx
	var locked := blocker != "" and not maxed
	var cost := c.research_cost(r)
	var can := not maxed and not locked and c.research_points >= float(cost.rp) and c.money >= float(cost.money)
	var tint := Palette.PANEL if not can else Color("26324a")
	var card := UI.card(tint, 18)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if locked:
		card.modulate = Color(1, 1, 1, 0.6)
	grid.add_child(card)
	var v := UI.vbox(8)
	card.add_child(v)
	var head := UI.hbox(8)
	head.add_child(UI.icon("lock" if locked else ("check" if maxed else "flask"), 30, Palette.MUTED if locked else (Palette.GOOD if maxed else Palette.ACCENT)))
	var nm := UI.label(str(r.name), 26)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	if maxed:
		head.add_child(UI.label("MAX", 24, Palette.GOOD))
	v.add_child(head)
	v.add_child(UI.wrap(str(r.desc), 22))
	# estrelas de nível
	if mx > 1:
		var stars := UI.hbox(4)
		for i in mx:
			var star := UI.icon("star_fill" if i < lvl else "star", 28, Color("ffc247") if i < lvl else Color("3a4156"))
			stars.add_child(star)
		stars.add_child(UI.spacer())
		stars.add_child(UI.label("%d/%d" % [lvl, mx], 24, Palette.ACCENT))
		v.add_child(stars)
	if locked:
		v.add_child(UI.label(blocker, 22, Palette.MUTED))
	elif not maxed:
		var b := UI.button("%s  %d PP + %s" % ["Desbloquear" if mx == 1 else "Evoluir", int(cost.rp), Fmt.money(float(cost.money))],
			func(): act(c.do_research(r.id)), "primary", 68)
		b.disabled = not can
		v.add_child(b)

func live() -> void:
	if _rp_label != null:
		_rp_label.text = "Pontos de pesquisa: %d" % int(company.research_points)
