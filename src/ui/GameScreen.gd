extends Control
## Tela principal: barra superior (caixa, data, velocidade), navegação lateral e páginas.

const PAGE_DEFS := [
	{"id": "dash", "title": "Painel", "icon": "nav_dash", "script": "res://src/ui/pages/DashboardPage.gd"},
	{"id": "team", "title": "Equipe", "icon": "nav_team", "script": "res://src/ui/pages/TeamPage.gd"},
	{"id": "products", "title": "Produtos", "icon": "nav_products", "script": "res://src/ui/pages/ProductsPage.gd"},
	{"id": "research", "title": "Pesquisa", "icon": "nav_research", "script": "res://src/ui/pages/ResearchPage.gd"},
	{"id": "market", "title": "Mercado", "icon": "nav_market", "script": "res://src/ui/pages/MarketPage.gd"},
]
const SPEED_ICONS := ["pause", "speed1", "speed2", "speed3", "speed4"]

var _pages: Dictionary = {}
var _nav: Dictionary = {}
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

	var body := UI.hbox(0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	body.add_child(_build_nav())
	_content = Control.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.clip_contents = true
	body.add_child(_content)

	_build_toast()
	Clock.active = true
	Clock.set_speed(0)
	Game.ticked.connect(_on_ticked)
	Game.changed.connect(_refresh_all)
	Game.notice.connect(_on_notice)
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
	for sig in [[Game.ticked, _on_ticked], [Game.changed, _refresh_all], [Game.notice, _on_notice], [Clock.speed_changed, _on_speed]]:
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

func _build_nav() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(260, 0)
	panel.add_theme_stylebox_override("panel", Palette.box(Palette.PANEL_DEEP, 0, 14))
	var v := UI.vbox(12)
	panel.add_child(v)
	for d in PAGE_DEFS:
		var b := UI.button(str(d.title), func(): _show_page(d.id), "normal", 96, 0, str(d.icon), "nav")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_nav[d.id] = b
		v.add_child(b)
	return panel

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
	if _pages.has(id):
		_pages[id].refresh()

func _refresh_all() -> void:
	var c: Company = Game.company
	if c == null:
		return
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
	_toast.position = Vector2(size.x - _toast.size.x - 24.0, size.y - _toast.size.y - 24.0)   # canto inferior direito
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

func _close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null

func _to_menu() -> void:
	Game.save()
	_to_menu_nosave()

func _to_menu_nosave() -> void:
	get_tree().change_scene_to_file("res://src/scenes/MainMenu.tscn")
