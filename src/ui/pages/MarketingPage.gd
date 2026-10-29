extends Page
## Marketing: escolha um produto, o canal de mídia, as regiões, o orçamento diário e a duração.
## A campanha aumenta a consciência de marca, que multiplica as vendas e decai com o tempo.

const BUDGETS := [250.0, 500.0, 1000.0, 2000.0, 3500.0, 5000.0, 8000.0, 12000.0, 20000.0]
const DAYS := [5, 10, 15, 30, 45, 60, 90]

var _pid: int = 0
var _channel: String = "billboard"
var _regions: Array = ["latam"]
var _bi: int = 2
var _di: int = 3
var _form: VBoxContainer
var _right: VBoxContainer
var _bars: Dictionary = {}   # id de campanha -> {bar, label}

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
	_form = UI.vbox(12)
	panel.add_child(_form)
	_right = UI.vbox(12)
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(_right)

func _touch() -> void:
	_last_sig = "\u0001"
	refresh()

func signature() -> String:
	var c := company
	var ids: Array = []
	for k in c.campaigns:
		ids.append(k.id)
	var st: Array = []
	for p in c.products:
		st.append(p.id * 10 + (1 if p.state == Product.STATE_RELEASED else (2 if p.state == Product.STATE_READY else 0)))
	return "%s|%s|%d|%d|%s|%s|%d|%d|%d" % [str(ids), str(st), _pid, c.research_level("res_marketing"), _channel, str(_regions), _bi, _di, int(c.money / 5000.0) + int(c.reputation / 5.0) * 100000]

func _eligible() -> Array:
	return company.products.filter(func(p): return p.state == Product.STATE_RELEASED or p.state == Product.STATE_READY)

func rebuild() -> void:
	var c := company
	UI.clear(_form)
	UI.clear(_right)
	_bars.clear()
	var elig := _eligible()
	_form.add_child(UI.label("Nova campanha", 36, Color("bfe0ff")))
	if elig.is_empty():
		_form.add_child(UI.wrap("Você ainda não tem produto pronto ou lançado. Termine um projeto em Produtos.", 24, Color("9fc0e8")))
		_right_side()
		return
	if c.get_product(_pid) == null or not elig.has(c.get_product(_pid)):
		_pid = int(elig[0].id)
	_form.add_child(UI.label("1  Produto", 24, Palette.MUTED))
	var row := GridContainer.new()
	row.columns = 3
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	for p in elig:
		var b := UI.button(str(p.pname), func(): _pid = int(p.id); _touch(), "primary" if int(p.id) == _pid else "normal", 64, 0, str(p.category))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		row.add_child(b)
	_form.add_child(row)
	_form.add_child(UI.label("2  Canal de mídia", 24, Palette.MUTED))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	for ch in GameData.marketing().channels:
		var why := Marketing.channel_blocker(c, str(ch.id))
		var txt := "%s · %s/d" % [str(ch.name), Fmt.money(float(ch.cost))] if why == "" else "%s  (%s)" % [str(ch.name), why]
		var b2 := UI.button(txt, func(): _channel = str(ch.id); _touch(), "primary" if str(ch.id) == _channel and why == "" else "normal", 64, 0, "lock" if why != "" else "")
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b2.disabled = why != ""
		b2.clip_text = true
		b2.add_theme_font_size_override("font_size", 21)
		g.add_child(b2)
	_form.add_child(g)
	var chd := Marketing.channel(_channel)
	if not chd.is_empty():
		_form.add_child(UI.wrap(str(chd.desc), 21, Color("9fc0e8")))
	_form.add_child(UI.label("3  Regiões", 24, Palette.MUTED))
	var rg := GridContainer.new()
	rg.columns = 3
	rg.add_theme_constant_override("h_separation", 8)
	rg.add_theme_constant_override("v_separation", 8)
	for r in GameData.marketing().regions:
		var on := _regions.has(str(r.id))
		var rb := UI.button("%s %d%%" % [str(r.name), int(float(r.w) * 100.0)], func():
			if _regions.has(str(r.id)):
				if _regions.size() > 1:
					_regions.erase(str(r.id))
			else:
				_regions.append(str(r.id))
			_touch(), "primary" if on else "normal", 58)
		rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rb.clip_text = true
		rg.add_child(rb)
	_form.add_child(rg)
	_form.add_child(UI.label("4  Orçamento e duração", 24, Palette.MUTED))
	_form.add_child(UI.stepper("Orçamento/dia", Fmt.money(BUDGETS[_bi]), func(): _bi = maxi(0, _bi - 1); _touch(), func(): _bi = mini(BUDGETS.size() - 1, _bi + 1); _touch(), _bi > 0, _bi < BUDGETS.size() - 1, 250))
	_form.add_child(UI.stepper("Duração", "%d dias" % int(DAYS[_di]), func(): _di = maxi(0, _di - 1); _touch(), func(): _di = mini(DAYS.size() - 1, _di + 1); _touch(), _di > 0, _di < DAYS.size() - 1, 250))
	var p: Product = c.get_product(_pid)
	var pv := Marketing.preview(c, p, _channel, _regions, BUDGETS[_bi], int(DAYS[_di]))
	var box := UI.card(Color("0b1830"), 14)
	var bv := UI.vbox(4)
	box.add_child(bv)
	bv.add_child(UI.kv("Custo total", Fmt.money(float(pv.cost)), Palette.TEXT, 26))
	bv.add_child(UI.kv("Consciência de marca", "%d%% → %d%%" % [int(Marketing.awareness_of(c, p) * 100.0), int(maxf(float(pv.awareness), Marketing.organic(c)) * 100.0)], Palette.ACCENT, 26))
	bv.add_child(UI.kv("Impulso nas vendas (estimado)", "+%d%%" % int(maxf(0.0, float(pv.boost)) * 100.0), Palette.GOOD, 26))
	_form.add_child(box)
	var start := UI.button("Iniciar campanha", func(): act(Marketing.start(c, _pid, _channel, _regions, BUDGETS[_bi], int(DAYS[_di]))), "good", 84)
	start.disabled = c.campaigns.size() >= Marketing.MAX_CAMPAIGNS
	_form.add_child(start)
	if c.campaigns.size() >= Marketing.MAX_CAMPAIGNS:
		_form.add_child(UI.label("Limite de %d campanhas simultâneas" % Marketing.MAX_CAMPAIGNS, 22, Palette.BAD))
	_right_side()

func _right_side() -> void:
	var c := company
	var card := UI.card(Palette.PANEL, 18)
	_right.add_child(card)
	var v := UI.vbox(10)
	card.add_child(v)
	v.add_child(UI.heading("Campanhas ativas  (%d/%d)" % [c.campaigns.size(), Marketing.MAX_CAMPAIGNS]))
	if c.campaigns.is_empty():
		v.add_child(UI.wrap("Nenhuma campanha. A consciência de marca cai ~1,5% ao dia sem investimento."))
	for k in c.campaigns:
		var p: Product = c.get_product(int(k.pid))
		if p == null:
			continue
		var box := UI.card(Palette.PANEL_ALT, 14)
		v.add_child(box)
		var bv := UI.vbox(6)
		box.add_child(bv)
		var h := UI.hbox(8)
		h.add_child(UI.label("%s · %s" % [p.pname, str(Marketing.channel(str(k.channel)).name)], 25, Palette.TEXT))
		h.add_child(UI.spacer())
		h.add_child(UI.button("Encerrar", func(): act(Marketing.stop(c, int(k.id))), "danger", 54, 140))
		bv.add_child(h)
		var bar := UI.bar(0.0, Palette.INFO, 16)
		bv.add_child(bar)
		var lab := UI.label("", 22, Palette.MUTED)
		bv.add_child(lab)
		_bars[int(k.id)] = {"bar": bar, "label": lab, "k": k}
	var aw := UI.card(Palette.PANEL, 18)
	_right.add_child(aw)
	var av := UI.vbox(8)
	aw.add_child(av)
	av.add_child(UI.heading("Consciência de marca"))
	for p in _eligible():
		av.add_child(UI.kv(str(p.pname), "%d%%  ·  vendas ×%.2f" % [int(Marketing.awareness_of(c, p) * 100.0), Marketing.factor(Marketing.awareness_of(c, p))], Palette.TEXT, 24))
		av.add_child(UI.bar(Marketing.awareness_of(c, p), Palette.ACCENT, 12))
	av.add_child(UI.wrap("Reputação alta dá consciência orgânica mínima. Canais mais caros exigem pesquisa de Marketing Avançado e reputação.", 21))

func live() -> void:
	for id in _bars:
		var w: Dictionary = _bars[id]
		var k: Dictionary = w.k
		(w.bar as ProgressBar).value = 1.0 - float(k.left) / float(k.days)
		(w.label as Label).text = "restam %d dias · gasto %s · %s/dia" % [int(k.left), Fmt.money(float(k.spent)), Fmt.money(float(k.budget))]
