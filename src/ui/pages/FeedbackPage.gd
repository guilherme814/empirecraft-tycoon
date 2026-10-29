extends Page
## Central de feedback: o que os clientes dizem de cada produto e os pedidos da equipe.

var _tab: int = 0
var _pid: int = 0
var _body: VBoxContainer

func build() -> void:
	var sc := UI.scroll()
	add_child(sc)
	_body = UI.vbox(14)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_body)

func _touch() -> void:
	_last_sig = "\u0001"
	refresh()

func signature() -> String:
	var c := company
	var ids: Array = []
	for r in c.requests:
		ids.append(r.id)
	var sums: Array = []
	for p in c.released_products():
		sums.append("%d:%d:%d" % [p.id, p.reviews.size(), int(p.rating * 10.0)])
	return "%d|%d|%s|%s|%d" % [_tab, _pid, str(ids), str(sums), int(c.money / 3000.0)]

func rebuild() -> void:
	UI.clear(_body)
	var tabs := UI.hbox(10)
	for i in 2:
		var names := ["Clientes", "Equipe"]
		var b := UI.button("%s%s" % [names[i], "  (%d)" % company.requests.size() if i == 1 and not company.requests.is_empty() else ""], func(): _tab = i; _touch(), "primary" if _tab == i else "normal", 72, 260)
		tabs.add_child(b)
	_body.add_child(tabs)
	if _tab == 0:
		_customers()
	else:
		_team()

func _customers() -> void:
	var c := company
	var list := c.released_products()
	if list.is_empty():
		_body.add_child(UI.card(Palette.PANEL, 18))
		(_body.get_child(_body.get_child_count() - 1) as PanelContainer).add_child(UI.wrap("Lance um produto para começar a receber opiniões dos clientes."))
		return
	if c.get_product(_pid) == null or c.get_product(_pid).state != Product.STATE_RELEASED:
		_pid = int(list[0].id)
	var p: Product = c.get_product(_pid)
	var row := UI.hbox(8)
	for q in list:
		var b := UI.button(str(q.pname), func(): _pid = int(q.id); _touch(), "primary" if int(q.id) == _pid else "normal", 64, 0, str(q.category))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		row.add_child(b)
	_body.add_child(row)
	var cols := UI.hbox(14)
	_body.add_child(cols)
	var s := Feedback.summarize(p)
	var left := UI.card(Palette.PANEL, 18)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var lv := UI.vbox(8)
	left.add_child(lv)
	lv.add_child(UI.heading("Opinião geral"))
	lv.add_child(UI.kv("Nota dos clientes", "★ %.1f / 5  (%d avaliações)" % [p.rating, p.rating_n], Palette.WARN, 28))
	lv.add_child(UI.kv("Crítica", "%d / 100" % int(p.critic), Palette.INFO, 28))
	lv.add_child(UI.kv("Influência nas vendas", "×%.2f" % c.rating_factor(p), Palette.ACCENT, 26))
	lv.add_child(UI.label("O que elogiam", 26, Palette.GOOD))
	var pos := Feedback.top(s.pos)
	if pos.is_empty():
		lv.add_child(UI.label("—", 24, Palette.MUTED))
	for it in pos:
		lv.add_child(UI.kv(Feedback.tag_label("+" + str(it[0])), "%d×" % int(it[1]), Palette.TEXT, 24))
	lv.add_child(UI.label("Do que reclamam", 26, Palette.BAD))
	var neg := Feedback.top(s.neg)
	if neg.is_empty():
		lv.add_child(UI.label("—", 24, Palette.MUTED))
	for it in neg:
		lv.add_child(UI.kv(Feedback.tag_label("-" + str(it[0])), "%d×" % int(it[1]), Palette.TEXT, 24))
	var right := UI.card(Palette.PANEL_ALT, 18)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var rv := UI.vbox(8)
	right.add_child(rv)
	rv.add_child(UI.label("Sugestões", 30, Palette.ACCENT))
	var sug := Feedback.suggestions(c, p)
	if sug.is_empty():
		rv.add_child(UI.wrap("Ainda não há avaliações suficientes.", 24))
	for t in sug:
		rv.add_child(UI.wrap("• " + str(t), 24, Palette.TEXT))
	var rev := UI.card(Palette.PANEL, 18)
	_body.add_child(rev)
	var vv := UI.vbox(8)
	rev.add_child(vv)
	vv.add_child(UI.heading("Comentários recentes"))
	var shown := 0
	for i in range(p.reviews.size() - 1, -1, -1):
		var r: Dictionary = p.reviews[i]
		var h := UI.hbox(8)
		h.add_child(UI.label(str(r.who), 22, Palette.ACCENT if r.kind == "critica" else Palette.TEXT))
		h.add_child(UI.spacer())
		h.add_child(UI.label("%d/100" % int(r.stars) if r.kind == "critica" else "★".repeat(int(r.stars)), 22, Palette.WARN))
		vv.add_child(h)
		vv.add_child(UI.wrap(str(r.text), 21))
		shown += 1
		if shown >= 8:
			break

func _team() -> void:
	var c := company
	var avg := 0.0
	for e in c.staff:
		avg += e.morale
	avg /= maxf(float(c.staff.size()), 1.0)
	var top := UI.card(Palette.PANEL, 18)
	_body.add_child(top)
	var tv := UI.vbox(6)
	top.add_child(tv)
	tv.add_child(UI.kv("Moral média da equipe", "%d / 100" % int(avg), Palette.GOOD if avg >= 65.0 else (Palette.WARN if avg >= 40.0 else Palette.BAD), 30))
	tv.add_child(UI.bar(avg / 100.0, Palette.GOOD if avg >= 65.0 else (Palette.WARN if avg >= 40.0 else Palette.BAD), 16))
	tv.add_child(UI.wrap("Moral baixa reduz a produtividade e pode levar a pedidos de demissão. Pedidos sem resposta expiram em %d dias." % Feedback.REQUEST_TTL, 21))
	if c.requests.is_empty():
		var e := UI.card(Palette.PANEL, 18)
		_body.add_child(e)
		e.add_child(UI.wrap("Nenhum pedido no momento. Sua equipe está tranquila."))
	for r in c.requests:
		var emp: Employee = null
		for e in c.staff:
			if e.id == int(r.emp):
				emp = e
		if emp == null:
			continue
		var box := UI.card(Palette.PANEL, 18)
		_body.add_child(box)
		var v := UI.vbox(8)
		box.add_child(v)
		var h := UI.hbox(8)
		h.add_child(UI.icon_label(emp.profession, "%s · %s" % [emp.emp_name, GameData.profession(emp.profession).singular], 26, Palette.TEXT, Palette.ACCENT))
		h.add_child(UI.spacer())
		h.add_child(UI.label("moral %d" % int(emp.morale), 24, Palette.GOOD if emp.morale >= 60.0 else Palette.BAD))
		v.add_child(h)
		v.add_child(UI.wrap(str(r.text), 25, Palette.TEXT))
		var opts: Array = GameData.feedback().requests[str(r.kind)].opts
		var oh := UI.hbox(8)
		for i in opts.size():
			var cost := Feedback.option_cost(c, r, i)
			var label := str(opts[i]) + ("  (%s)" % Fmt.money(cost) if cost > 0.0 else "")
			var b := UI.button(label, func(): act(Feedback.answer(c, int(r.id), i)), "good" if i == 0 else "normal", 64)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.clip_text = true
			oh.add_child(b)
		v.add_child(oh)
