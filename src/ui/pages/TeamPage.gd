extends Page
## Equipe: contratar (agências), treinar e demitir, por profissão.

var _prof_idx: int = 0
var _body: VBoxContainer

func build() -> void:
	_body = UI.vbox(14)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_body)

func _prof() -> String:
	return GameData.professions()[_prof_idx].id

func signature() -> String:
	var c := company
	var prof := _prof()
	var parts: Array = [_prof_idx, c.office_level[prof]]
	for e in c.staff_of(prof):
		parts.append("s%d:%d" % [e.id, e.total()])
		var t := c.train_cost(e)
		parts.append(1 if (c.money >= float(t.money) and c.research_points >= float(t.rp) and not e.is_maxed()) else 0)
	for e in c.candidates_of(prof):
		parts.append("c%d" % e.id)
	for ag in GameData.agencies():
		parts.append(1 if c.money >= float(ag.price) else 0)
	var up := c.office_upgrade_cost(prof)
	parts.append(1 if up >= 0.0 and c.money >= up else 0)
	parts.append(c.free_seats(prof))
	return str(parts)

func rebuild() -> void:
	UI.clear(_body)
	var c := company
	var prof := _prof()

	# abas de profissão
	var tabs := UI.hbox(10)
	_body.add_child(tabs)
	for i in GameData.professions().size():
		var p: Dictionary = GameData.professions()[i]
		var b := UI.button("%s (%d)" % [p.name, c.staff_of(p.id).size()], func(): _select(i),
			"primary" if i == _prof_idx else "normal", 72, 0, str(p.id), "nav")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)

	# escritório + automações
	var info := UI.card(Palette.PANEL, 16)
	_body.add_child(info)
	var ih := UI.hbox(14)
	info.add_child(ih)
	var cap := c.capacity(prof)
	ih.add_child(UI.label("Escritório nv.%d  ·  vagas %d/%d" % [c.office_level[prof], c.staff_of(prof).size(), cap], 28))
	ih.add_child(UI.spacer())
	var up := c.office_upgrade_cost(prof)
	var upb := UI.button("Ampliar  " + Fmt.money(up) if up >= 0.0 else "Nível máximo", func(): act(c.upgrade_office(prof)),
		"info", 72)
	upb.disabled = up < 0.0 or c.money < up
	ih.add_child(upb)
	ih.add_child(UI.button("Treinar todos", func(): _train_all(prof, 1), "good", 72))
	ih.add_child(UI.button("Treinar até o máx.", func(): _train_all(prof, 100), "good", 72))

	# agências
	var ags := UI.hbox(12)
	_body.add_child(ags)
	for i in GameData.agencies().size():
		var ag: Dictionary = GameData.agencies()[i]
		var card := UI.card(Palette.PANEL_ALT, 14)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ags.add_child(card)
		var v := UI.vbox(6)
		card.add_child(v)
		v.add_child(UI.label(str(ag.name), 28, Palette.TEXT))
		v.add_child(UI.label("%s  ·  habilidade %d-%d" % [Fmt.money(float(ag.price)), int(ag.skill_min), int(ag.skill_max)], 22, Palette.MUTED))
		var br := UI.hbox(8)
		v.add_child(br)
		var search := UI.button("Buscar", func(): act(c.search_agency(i, prof)), "primary", 72)
		search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		search.disabled = c.money < float(ag.price)
		br.add_child(search)
		var fill := UI.button("Preencher", func(): act(c.auto_fill(prof, i)), "info", 72)
		fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fill.disabled = c.money < float(ag.price) or c.free_seats(prof) <= 0
		br.add_child(fill)

	# candidatos | equipe
	var cols := UI.hbox(14)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(cols)
	_column(cols, "Candidatos", c.candidates_of(prof), false)
	_column(cols, "Equipe", c.staff_of(prof), true)

func _column(parent: HBoxContainer, title: String, people: Array, is_staff: bool) -> void:
	var col := UI.vbox(10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(col)
	col.add_child(UI.label("%s (%d)" % [title, people.size()], 30, Palette.ACCENT))
	var sc := UI.scroll()
	col.add_child(sc)
	var list := UI.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	if people.is_empty():
		list.add_child(UI.wrap("Ninguém por aqui. " + ("Contrate candidatos." if is_staff else "Use uma agência para buscar.")))
	for e in people:
		list.add_child(_person_card(e, is_staff))

func _person_card(e: Employee, is_staff: bool) -> Control:
	var c := company
	var card := UI.card(Palette.PANEL, 16)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(6)
	card.add_child(v)
	var head := UI.hbox(8)
	head.add_child(UI.label(e.emp_name, 28))
	head.add_child(UI.spacer())
	head.add_child(UI.label(Fmt.money(e.salary()) + "/mês", 22, Palette.MUTED))
	v.add_child(head)
	for a in Employee.ATTRS:
		var r := UI.hbox(10)
		var l := UI.label("%s %d" % [GameData.ATTR_LABELS[a], int(e.get(a))], 22, Palette.MUTED)
		l.custom_minimum_size = Vector2(190, 0)
		r.add_child(l)
		var bar := UI.bar(float(e.get(a)) / 100.0, Palette.INFO if a == "pace" else (Palette.ACCENT if a == "craft" else Palette.GOOD), 16)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(bar)
		v.add_child(r)
	var btns := UI.hbox(8)
	v.add_child(btns)
	if is_staff:
		var t := c.train_cost(e)
		var tb := UI.button("Treinar  %s + %d PP" % [Fmt.money(float(t.money)), int(t.rp)] if not e.is_maxed() else "Máximo",
			func(): _train(e.id), "good", 68)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.disabled = e.is_maxed() or c.money < float(t.money) or c.research_points < float(t.rp)
		btns.add_child(tb)
		btns.add_child(UI.button("Demitir", func(): act(c.fire(e.id)), "danger", 68))
	else:
		var hb := UI.button("Contratar", func(): act(c.hire(e.id)), "primary", 68)
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.disabled = c.free_seats(e.profession) <= 0
		btns.add_child(hb)
	return card

func _train(emp_id: int) -> void:
	var res := company.train(emp_id)
	if res.ok:
		Sfx.play("train", 0.08)
	act(res)

func _train_all(prof: String, rounds: int) -> void:
	var res := company.train_all(prof, rounds)
	if res.ok and int(res.steps) > 0:
		Sfx.play("train")
	act(res)

func _select(i: int) -> void:
	_prof_idx = i
	_last_sig = "\u0001"
	refresh()
