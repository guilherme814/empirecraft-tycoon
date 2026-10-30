extends Control
## Tela principal: barra superior (caixa, data, velocidade), navegação lateral e páginas.

const PAGE_DEFS := [
	{"id": "dash", "title": "Painel", "icon": "nav_dash", "script": "res://src/ui/pages/DashboardPage.gd"},
	{"id": "team", "title": "Equipe", "icon": "nav_team", "script": "res://src/ui/pages/TeamPage.gd"},
	{"id": "office", "title": "Escritório", "icon": "nav_office", "script": "res://src/ui/pages/OfficePage.gd"},
	{"id": "stores", "title": "Lojas", "icon": "nav_store", "script": "res://src/ui/pages/StoresPage.gd"},
	{"id": "products", "title": "Produtos", "icon": "nav_products", "script": "res://src/ui/pages/ProductsPage.gd"},
	{"id": "lab", "title": "Testes", "icon": "nav_test", "script": "res://src/ui/pages/LabPage.gd"},
	{"id": "marketing", "title": "Marketing", "icon": "nav_marketing", "script": "res://src/ui/pages/MarketingPage.gd"},
	{"id": "research", "title": "Pesquisa", "icon": "nav_research", "script": "res://src/ui/pages/ResearchPage.gd"},
	{"id": "chips", "title": "Hardware", "icon": "nav_chip", "script": "res://src/ui/pages/ChipsPage.gd"},
	{"id": "ops", "title": "Operações", "icon": "nav_ops", "script": "res://src/ui/pages/OperationsPage.gd"},
	{"id": "finance", "title": "Finanças", "icon": "nav_finance", "script": "res://src/ui/pages/FinancePage.gd"},
	{"id": "stocks", "title": "Bolsa", "icon": "nav_stocks", "script": "res://src/ui/pages/StocksPage.gd"},
	{"id": "market", "title": "Mercado", "icon": "nav_market", "script": "res://src/ui/pages/MarketPage.gd"},
	{"id": "feedback", "title": "Feedback", "icon": "nav_feedback", "script": "res://src/ui/pages/FeedbackPage.gd"},
]
const SPEED_ICONS := ["pause", "speed1", "speed2", "speed3", "speed4"]

var _pages: Dictionary = {}
var _nav: Dictionary = {}
var _badges: Dictionary = {}
var _current: String = ""
var _content: Control
var _name_l: Label
var _money_l: Label
var _date_l: Label
var _rep_l: Label
var _rp_l: Label
var _speed_btns: Array = []
var _toast: PanelContainer
var _toast_l: Label
var _toast_gen: int = 0
var _overlay: Control = null

func _ready() -> void:
	theme = Palette.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UI.background())

	var root := UI.vbox(0)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(_build_top_bar())

	_content = Control.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.clip_contents = true
	root.add_child(_content)
	root.add_child(_build_nav())

	_build_toast()
	Clock.active = true
	Clock.set_speed(0)
	Game.ticked.connect(_on_ticked)
	Game.changed.connect(_refresh_all)
	Game.notice.connect(_on_notice)
	Game.ui_request.connect(_on_ui_request)
	Clock.speed_changed.connect(_on_speed)
	_show_page("dash")
	_refresh_all()
	_on_speed(0)

func _notification(what: int) -> void:
	# Botão "voltar" do Android: fecha o painel aberto ou abre o menu, em vez de sair do jogo.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _overlay != null and not Game.company.game_over:
			_close_overlay()
		elif _overlay == null:
			_open_menu()

func _exit_tree() -> void:
	Clock.active = false
	Clock.pause()
	for sig in [[Game.ticked, _on_ticked], [Game.changed, _refresh_all], [Game.notice, _on_notice], [Game.ui_request, _on_ui_request], [Clock.speed_changed, _on_speed]]:
		if sig[0].is_connected(sig[1]):
			sig[0].disconnect(sig[1])

# ───────────── construção ─────────────

func _build_top_bar() -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", Palette.box(Palette.PANEL, 0, 14))
	var h := UI.hbox(26)
	bar.add_child(h)
	_name_l = UI.label(Game.company.company_name, 30, Palette.ACCENT)
	h.add_child(_name_l)
	_money_l = UI.label("", 32, Palette.GOOD)
	h.add_child(_chip("coin", Palette.GOOD, _money_l))
	_date_l = UI.label("", 28)
	h.add_child(_chip("calendar", Palette.MUTED, _date_l))
	_rep_l = UI.label("", 26, Palette.INFO)
	h.add_child(_chip("star", Palette.INFO, _rep_l))
	_rp_l = UI.label("", 26, Palette.MUTED)
	h.add_child(_chip("flask", Palette.MUTED, _rp_l))
	h.add_child(UI.spacer())
	for i in SPEED_ICONS.size():
		var b := UI.button("", func(): Clock.set_speed(i), "normal", 68, 84, SPEED_ICONS[i], "nav")
		_speed_btns.append(b)
		h.add_child(b)
	h.add_child(UI.button("", _open_menu, "normal", 68, 84, "menu", "nav"))
	return bar

func _chip(icon_name: String, color: Color, value: Label) -> Control:
	var c := UI.hbox(8)
	c.add_child(UI.icon(icon_name, 32, color))
	c.add_child(value)
	return c

## Dock inferior (como no hub do jogo de referência): ícone + rótulo + selo de pendências.
func _build_nav() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 118)
	panel.add_theme_stylebox_override("panel", Palette.box(Palette.PANEL_DEEP, 0, 8))
	var h := UI.hbox(6)
	panel.add_child(h)
	for d in PAGE_DEFS:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 100)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Palette.style_button(b, "normal")
		b.pressed.connect(func(): Sfx.play("nav"); _show_page(d.id))
		var v := UI.vbox(2)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var ic := UI.icon(str(d.icon), 40, Palette.TEXT)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var l := UI.label(str(d.title), 19, Palette.TEXT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
		b.add_child(v)
		var badge := Label.new()
		badge.add_theme_font_size_override("font_size", 18)
		badge.add_theme_color_override("font_color", Color.WHITE)
		var bs := Palette.box(Palette.BAD, 14, 2)
		bs.content_margin_left = 9
		bs.content_margin_right = 9
		badge.add_theme_stylebox_override("normal", bs)
		badge.position = Vector2(8, 4)
		badge.visible = false
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(badge)
		_nav[d.id] = b
		_badges[d.id] = badge
		h.add_child(b)
	return panel

func _badge_count(id: String) -> int:
	var c: Company = Game.company
	var n := 0
	match id:
		"products":
			for p in c.products:
				if p.state == Product.STATE_READY:
					n += 1
		"feedback":
			n = c.requests.size()
		"lab":
			for p in c.products:
				for f in p.flaws:
					if bool(f.found) and not bool(f.fixed):
						n += 1
		"chips":
			n = 1 if c.chip_dev == null and not c.chips.is_empty() and false else 0
	return n

func _update_badges() -> void:
	for id in _badges:
		var n := _badge_count(id)
		var l: Label = _badges[id]
		l.visible = n > 0
		l.text = str(n)

func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", Palette.box(Palette.PANEL_ALT, 16, 18))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_toast_l = UI.wrap("", 26, Palette.TEXT)
	_toast_l.custom_minimum_size = Vector2(620, 0)
	_toast.add_child(_toast_l)
	add_child(_toast)

# ───────────── páginas ─────────────

func _show_page(id: String) -> void:
	_current = id
	for d in PAGE_DEFS:
		if d.id == id and not _pages.has(id):
			var page: Control = (load(d.script) as GDScript).new()
			_content.add_child(page)
			_pages[id] = page
	for pid in _pages:
		_pages[pid].visible = (pid == id)
	for pid in _nav:
		Palette.style_button(_nav[pid], "primary" if pid == id else "normal")
		var lab := _nav[pid].get_child(0).get_child(1) as Label
		lab.add_theme_color_override("font_color", Palette.ON_COLOR if pid == id else Palette.TEXT)
		(_nav[pid].get_child(0).get_child(0) as TextureRect).modulate = Palette.ON_COLOR if pid == id else Palette.TEXT
	if _pages.has(id):
		var pg: Control = _pages[id]
		pg.modulate.a = 0.0
		create_tween().tween_property(pg, "modulate:a", 1.0, 0.18)
	if _pages.has(id):
		_pages[id].refresh()

func _refresh_all() -> void:
	var c: Company = Game.company
	if c == null:
		return
	_update_badges()
	_money_l.text = Fmt.money(c.money)
	_money_l.add_theme_color_override("font_color", Palette.GOOD if c.money >= 0.0 else Palette.BAD)
	_date_l.text = Fmt.date(c.day)
	_rep_l.text = "Rep. %d" % int(c.reputation)
	_rp_l.text = "PP %d" % int(c.research_points)
	if _pages.has(_current):
		_pages[_current].refresh()
	if c.game_over and _overlay == null:
		_show_game_over()

func _on_ticked(_day: int) -> void:
	_refresh_all()

func _on_speed(i: int) -> void:
	for k in _speed_btns.size():
		Palette.style_button(_speed_btns[k], "primary" if k == i else "normal")

# ───────────── avisos e menus ─────────────

func _on_notice(text: String, kind: String) -> void:
	_toast_l.text = text
	_toast_l.add_theme_color_override("font_color", UI.kind_color(kind))
	_toast.visible = true
	_toast.reset_size()
	_toast.position = Vector2(size.x - _toast.size.x - 24.0, size.y - _toast.size.y - 140.0)   # canto inferior direito
	_toast_gen += 1
	var gen := _toast_gen
	await get_tree().create_timer(3.0).timeout
	if gen == _toast_gen and is_instance_valid(_toast):
		_toast.visible = false

func _open_menu() -> void:
	if _overlay != null:
		return
	Clock.pause()
	_overlay = _modal("Menu")
	var v: VBoxContainer = _overlay.get_meta("box")
	v.add_child(UI.button("Continuar jogando", _close_overlay, "primary", 90))
	v.add_child(UI.button("Salvar", func(): Game.save(); Game.notice.emit("Jogo salvo.", "good"); _close_overlay(), "normal", 90))
	v.add_child(UI.button("Salvar e voltar ao menu", _to_menu, "normal", 90))

func _show_game_over() -> void:
	Clock.pause()
	_overlay = _modal("Falência")
	var v: VBoxContainer = _overlay.get_meta("box")
	v.add_child(UI.wrap("Sua empresa não aguentou as dívidas. Dia %d (%s)." % [Game.company.day, Fmt.date(Game.company.day)], 28, Palette.TEXT))
	v.add_child(UI.button("Voltar ao menu", func(): Saves.delete_save(); _to_menu_nosave(), "primary", 90))

func _modal(title: String) -> Control:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var card := UI.card(Palette.PANEL, 28)
	card.custom_minimum_size = Vector2(760, 0)
	center.add_child(card)
	var v := UI.vbox(16)
	card.add_child(v)
	v.add_child(UI.heading(title))
	shade.set_meta("box", v)
	return shade

func _on_ui_request(kind: String, pid: int) -> void:
	if kind == "goto_team":
		_show_page("team")
		return
	var c: Company = Game.company
	var p: Product = c.get_product(pid)
	if p == null:
		return
	if kind == "reviews":
		_show_reviews(p, true)
	elif kind == "reviews_list":
		_show_reviews(p, false)
	elif kind == "launch":
		_show_launch(p)

func _stars(n: float) -> String:
	var full := clampi(int(round(n)), 0, 5)
	return "★".repeat(full) + "☆".repeat(5 - full)

func _score_color(score: float) -> Color:
	return Palette.GOOD if score >= 70.0 else (Palette.WARN if score >= 45.0 else Palette.BAD)

func _show_reviews(p: Product, fresh: bool) -> void:
	if _overlay != null:
		_close_overlay()
	Clock.pause()
	_overlay = _modal(("Avaliações de lançamento: %s" if fresh else "Avaliações: %s") % p.pname)
	var v: VBoxContainer = _overlay.get_meta("box")
	var top := UI.hbox(24)
	var cs := UI.vbox(2)
	cs.add_child(UI.label("Crítica", 24, Palette.MUTED))
	cs.add_child(UI.label("%d/100" % int(p.critic), 52, _score_color(p.critic)))
	top.add_child(cs)
	var cu := UI.vbox(2)
	cu.add_child(UI.label("Clientes", 24, Palette.MUTED))
	cu.add_child(UI.label("%.1f/5" % p.rating, 52, _score_color(p.rating * 20.0)))
	cu.add_child(UI.label(_stars(p.rating), 28, Palette.WARN))
	top.add_child(cu)
	v.add_child(top)
	if p.promise > 0.0:
		var ok_p := p.promise_gap <= 0.0
		v.add_child(UI.wrap("Promessa de +%d%% sobre a concorrência: %s" % [int(p.promise * 100.0), "cumprida!" if ok_p else "NÃO cumprida (reputação cai)."], 24, Palette.GOOD if ok_p else Palette.BAD))
	var sc := UI.scroll()
	sc.custom_minimum_size = Vector2(0, 520)
	v.add_child(sc)
	var list := UI.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	var shown := 0
	for i in range(p.reviews.size() - 1, -1, -1):
		var r: Dictionary = p.reviews[i]
		var crit: bool = r.kind == "critica"
		var card := UI.card(Palette.PANEL_ALT, 14)
		var cv := UI.vbox(4)
		card.add_child(cv)
		var hd := UI.hbox(10)
		hd.add_child(UI.label(str(r.who), 24, Palette.ACCENT if crit else Palette.TEXT))
		hd.add_child(UI.spacer())
		if crit:
			hd.add_child(UI.label("%d/100" % int(r.stars), 26, _score_color(float(r.stars))))
		else:
			hd.add_child(UI.label(_stars(float(r.stars)), 26, Palette.WARN))
		cv.add_child(hd)
		cv.add_child(UI.wrap(str(r.text), 22, Palette.MUTED))
		list.add_child(card)
		shown += 1
		if shown >= 12:
			break
	v.add_child(UI.button("Fechar", _close_overlay, "primary", 84))

func _show_launch(p: Product) -> void:
	if _overlay != null:
		return
	var c: Company = Game.company
	Clock.pause()
	_overlay = _modal("Lançar %s" % p.pname)
	var v: VBoxContainer = _overlay.get_meta("box")
	var best := c.market.best_quality(p.category)
	var mine := c.effective_quality(p)
	var adv := mine / maxf(best, 1.0) - 1.0
	var line := "Sua qualidade: %d" % int(round(mine))
	if best > 0.0:
		line += "  ·  melhor rival: %d  (%s%d%%)" % [int(round(best)), "+" if adv >= 0.0 else "", int(round(adv * 100.0))]
	v.add_child(UI.wrap(line, 26, Palette.TEXT))
	var known := p.flaws.filter(func(f): return bool(f.found) and not bool(f.fixed)).size()
	var tested := p.tests.size()
	if known > 0:
		v.add_child(UI.wrap("%d falha(s) conhecida(s) sem correção: o lançamento será criticado." % known, 23, Palette.BAD))
	elif tested == 0:
		v.add_child(UI.wrap("Este produto não passou por nenhum ensaio. Defeitos escondidos podem aparecer só depois do lançamento.", 23, Palette.WARN))
	else:
		v.add_child(UI.wrap("%d ensaio(s) concluído(s)." % tested, 23, Palette.GOOD))
	v.add_child(UI.button("Ir ao Laboratório de testes", func(): _close_overlay(); _show_page("lab"), "info", 66))
	var fan_n := Loyalty.preorders(c, p.category)
	v.add_child(UI.wrap("Fãs (lealdade %d%%): %d pré-vendas no primeiro dia." % [int(c.loyalty), fan_n], 24, Palette.INFO))
	v.add_child(UI.wrap("Prometa uma vantagem na campanha: mais atenção no lançamento, mas se o produto não entregar, a reputação cai.", 22, Palette.MUTED))
	for pr in [0.0, 0.1, 0.25, 0.4]:
		var fee: float = float(Company.PROMISE_COSTS[pr])
		var ok_adv: bool = adv >= float(pr)
		var txt: String = "Lançar sem promessa" if pr == 0.0 else "Prometer +%d%%  ·  campanha %s  ·  %s" % [int(pr * 100.0), Fmt.money(fee), "você entrega" if ok_adv else "risco!"]
		var kind: String = "primary" if pr == 0.0 else ("good" if ok_adv else "danger")
		var b := UI.button(txt, func():
			_close_overlay()
			var res: Dictionary = c.release(p.id, -1.0, pr)
			if not res.get("ok", true):
				Game.notice.emit(str(res.get("msg", "Não foi possível lançar")), "bad")
			Game.changed.emit(), kind, 84)
		b.disabled = c.money < fee
		v.add_child(b)
	v.add_child(UI.button("Cancelar", _close_overlay, "normal", 72))

func _close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null

func _to_menu() -> void:
	Game.save()
	_to_menu_nosave()

func _to_menu_nosave() -> void:
	get_tree().change_scene_to_file("res://src/scenes/MainMenu.tscn")
