extends Page
## Laboratório de testes: ensaios que revelam falhas ocultas do protótipo, correções e teste beta com clientes.

var _pid: int = 0
var _left: VBoxContainer
var _right: VBoxContainer
var _job_bars: Array = []

func build() -> void:
	var sc := UI.scroll()
	add_child(sc)
	var cols := UI.hbox(16)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(cols)
	var panel := UI.blueprint(16)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cols.add_child(panel)
	_left = UI.vbox(12)
	panel.add_child(_left)
	_right = UI.vbox(12)
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(_right)

func _touch() -> void:
	_last_sig = "\u0001"
	refresh()

func _eligible() -> Array:
	return company.products.filter(func(p): return p.state == Product.STATE_READY or p.state == Product.STATE_RELEASED)

func signature() -> String:
	var c := company
	var parts: Array = [_pid, c.research_level("res_lab"), c.lab_jobs.size(), int(c.money / 4000.0)]
	for p in c.products:
		var fl: Array = []
		for f in p.flaws:
			fl.append("%s%d%d" % [f.id, 1 if f.found else 0, 1 if f.fixed else 0])
		parts.append("%d:%s:%s:%d:%d" % [p.id, p.state, ",".join(fl), p.tests.size(), 1 if not p.beta.is_empty() else 0])
	return str(parts)

func rebuild() -> void:
	var c := company
	UI.clear(_left)
	UI.clear(_right)
	_job_bars.clear()
	_left.add_child(UI.label("Laboratório de testes", 36, Color("bfe0ff")))
	var elig := _eligible()
	if elig.is_empty():
		_left.add_child(UI.wrap("Quando um produto ficar pronto você poderá ensaiá-lo aqui antes do lançamento. Falhas escondidas viram avaliações ruins e recalls.", 24, Color("9fc0e8")))
		return
	var cur: Product = c.get_product(_pid)
	if cur == null or not elig.has(cur):
		_pid = int(elig[0].id)
		cur = c.get_product(_pid)
	var row := GridContainer.new()
	row.columns = 3
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	for p in elig:
		var b := UI.button(str(p.pname), func(): _pid = int(p.id); _touch(), "primary" if int(p.id) == _pid else "normal", 64, 0, str(p.category))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		row.add_child(b)
	_left.add_child(row)
	_left.add_child(UI.label("Ensaios (cada um revela um tipo de defeito)", 24, Palette.MUTED))
	for t in GameData.lab().tests:
		_left.add_child(_test_row(cur, t))
	_left.add_child(UI.label("Teste beta com clientes", 24, Palette.MUTED))
	_left.add_child(_beta_box(cur))
	_right_side(cur)

func _test_row(p: Product, t: Dictionary) -> Control:
	var c := company
	var id := str(t.id)
	var why := Lab.test_blocker(c, p, id)
	var box := UI.card(Color("0f2547"), 12)
	var v := UI.vbox(4)
	box.add_child(v)
	var h := UI.hbox(8)
	h.add_child(UI.label(str(t.name), 25, Palette.TEXT))
	h.add_child(UI.spacer())
	var done: Dictionary = p.tests.get(id, {})
	var running := false
	for j in c.lab_jobs:
		if int(j.pid) == p.id and str(j.test) == id:
			running = true
	var btn := UI.button("Rodar  %s · %dd" % [Fmt.money(Lab.test_cost(c, id)), Lab.test_days(c, id)] if not running else "Em andamento", func(): act(Lab.run_test(c, p.id, id)), "primary", 56, 250)
	btn.disabled = why != ""
	h.add_child(btn)
	v.add_child(h)
	if why != "" and not running and not why.begins_with("Caixa"):
		v.add_child(UI.label(why, 20, Palette.BAD))
	if running:
		for j in c.lab_jobs:
			if int(j.pid) == p.id and str(j.test) == id:
				var bar := UI.bar(1.0 - float(j.left) / float(j.days), Palette.INFO, 12)
				v.add_child(bar)
				_job_bars.append({"bar": bar, "j": j})
	elif not done.is_empty():
		var m: Dictionary = done.get("m", {})
		if not m.is_empty():
			var mh := UI.hbox(8)
			mh.add_child(UI.label("%s: %s" % [m.label, m.value], 22, Palette.MUTED))
			mh.add_child(UI.spacer())
			var sc: float = float(m.score)
			mh.add_child(UI.label("achou %d problema(s)" % int(done.found) if int(done.found) > 0 else "sem problemas", 22, Palette.BAD if int(done.found) > 0 else Palette.GOOD))
			v.add_child(mh)
			v.add_child(UI.bar(sc, Palette.GOOD if sc >= 0.55 else (Palette.WARN if sc >= 0.35 else Palette.BAD), 10))
	return box

func _beta_box(p: Product) -> Control:
	var c := company
	var box := UI.card(Color("0f2547"), 12)
	var v := UI.vbox(6)
	box.add_child(v)
	if not p.beta_job.is_empty():
		v.add_child(UI.label("Beta em andamento: %d dias" % int(p.beta_job.left), 24, Palette.INFO))
		return box
	if not p.beta.is_empty():
		var b: Dictionary = p.beta
		v.add_child(UI.kv("Clientes beta", "★ %.1f / 5" % float(b.stars), Palette.WARN, 26))
		v.add_child(UI.kv("Crítica prevista", "%d / 100" % int(b.critic), Palette.INFO, 26))
		var fair := float(b.fair)
		v.add_child(UI.kv("Preço", "justo" if fair > 0.9 and fair < 1.1 else ("caro" if fair >= 1.1 else "barato"), Palette.TEXT, 24))
		for r in (b.reviews as Array).slice(0, 3):
			v.add_child(UI.wrap("“%s” — %s %s" % [str(r.text), str(r.who), "★".repeat(int(r.stars))], 20, Palette.MUTED))
		v.add_child(UI.label("Feito em %s" % Fmt.date(int(b.day)), 20, Palette.MUTED))
	var btn := UI.button("%s  —  %s · %d dias" % ["Repetir beta" if not p.beta.is_empty() else "Rodar beta", Fmt.money(float(GameData.lab().beta_cost)), int(GameData.lab().beta_days)],
		func(): act(Lab.start_beta(c, p.id)), "primary", 64)
	btn.disabled = c.money < float(GameData.lab().beta_cost)
	v.add_child(btn)
	return box

func _right_side(p: Product) -> void:
	var c := company
	var card := UI.card(Palette.PANEL, 18)
	_right.add_child(card)
	var v := UI.vbox(10)
	card.add_child(v)
	v.add_child(UI.heading("Falhas de %s" % p.pname))
	var found: Array = p.flaws.filter(func(f): return bool(f.found) and not bool(f.fixed))
	var hidden: int = p.flaws.filter(func(f): return not bool(f.found) and not bool(f.fixed)).size()
	var fixed: int = p.flaws.filter(func(f): return bool(f.fixed)).size()
	if found.is_empty() and hidden == 0 and p.tests.is_empty():
		v.add_child(UI.wrap("Nada testado ainda. Seu produto pode ter defeitos escondidos: rode os ensaios antes de lançar."))
	for f in found:
		var fd := Lab.flaw_def(str(f.id))
		var box := UI.card(Palette.PANEL_ALT, 14)
		v.add_child(box)
		var bv := UI.vbox(4)
		box.add_child(bv)
		var h := UI.hbox(8)
		h.add_child(UI.label("%s  %s" % ["●".repeat(int(fd.sev)), str(fd.name)], 25, Palette.BAD))
		bv.add_child(h)
		bv.add_child(UI.wrap("“%s”" % str(fd.review), 20, Palette.MUTED))
		var cost := Lab.fix_cost(c, p, str(f.id))
		var b := UI.button("%s  —  %s" % [str(fd.fix), Fmt.money(cost)], func(): act(Lab.fix(c, p.id, str(f.id))), "good", 60)
		b.disabled = c.money < cost
		bv.add_child(b)
	if hidden > 0:
		v.add_child(UI.wrap("Ainda podem existir falhas não identificadas. Rode mais ensaios para encontrá-las.", 22, Palette.WARN))
	if fixed > 0:
		v.add_child(UI.label("%d falha(s) corrigida(s)" % fixed, 24, Palette.GOOD))
	var open_s := Lab.severity_sum(p)
	if open_s > 0:
		v.add_child(UI.wrap("Defeitos abertos reduzem a nota dos clientes e aumentam a chance de recall (gravidade total %d)." % open_s, 21, Palette.MUTED))
	var info := UI.card(Palette.PANEL, 18)
	_right.add_child(info)
	var iv := UI.vbox(6)
	info.add_child(iv)
	iv.add_child(UI.heading("Ensaios em andamento  (%d/%d)" % [c.lab_jobs.size(), Lab.MAX_JOBS]))
	if c.lab_jobs.is_empty():
		iv.add_child(UI.wrap("Laboratório livre."))
	for j in c.lab_jobs:
		var pp: Product = c.get_product(int(j.pid))
		iv.add_child(UI.label("%s · %s  (%d dias)" % [pp.pname if pp != null else "?", str(Lab.test_def(str(j.test)).name), int(j.left)], 22, Palette.TEXT))
	iv.add_child(UI.wrap("Pesquisar Laboratório de Testes libera ensaios de água, sinal e câmera e encurta os prazos.", 20))

func live() -> void:
	for w in _job_bars:
		var j: Dictionary = w.j
		(w.bar as ProgressBar).value = 1.0 - float(j.left) / float(j.days)
