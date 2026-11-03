extends Control
## Fundação da empresa: nome, fundador, país de origem, dificuldade, especialização e modo.
## Campanha e sandbox usam slots de save independentes; uma campanha só é substituída com confirmação.

var _name: String = "Minha Empresa"
var _founder: String = ""
var _origin: String = "br"
var _diff: String = "normal"
var _focus: String = ""
var _sandbox: bool = false
var _confirm: bool = false
var _body: VBoxContainer
var _side: VBoxContainer

func _ready() -> void:
	theme = Palette.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UI.background())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + k, 36)
	add_child(margin)
	var root := UI.hbox(24)
	margin.add_child(root)
	var sc := UI.scroll()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(sc)
	_body = UI.vbox(16)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_body)
	var side_card := UI.card(Palette.PANEL, 24)
	side_card.custom_minimum_size = Vector2(620, 0)
	root.add_child(side_card)
	_side = UI.vbox(10)
	side_card.add_child(_side)
	_render()

func _origin_def() -> Dictionary:
	return Founding.origin(_origin)

func _pick(cb: Callable) -> void:
	Sfx.play("click")
	cb.call()
	_confirm = false
	_render()

func _field(placeholder: String, text: String, on_change: Callable) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.text = text
	e.custom_minimum_size = Vector2(0, 76)
	e.add_theme_font_size_override("font_size", 30)
	e.add_theme_stylebox_override("normal", Palette.box(Palette.PANEL, 14, 18))
	e.add_theme_stylebox_override("focus", Palette.box(Palette.PANEL_ALT, 14, 18))
	e.max_length = 28
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.text_changed.connect(func(t): on_change.call(t))
	return e

func _render() -> void:
	UI.clear(_body)
	UI.clear(_side)
	_body.add_child(UI.heading("Fundar sua empresa"))
	var names := UI.hbox(12)
	names.add_child(_field("Nome da empresa", _name, func(t): _name = t))
	names.add_child(_field("Seu nome (fundador)", _founder, func(t): _founder = t))
	_body.add_child(names)

	_section("País de origem", "Define capital, salários, velocidade de pesquisa, custo de produção e reputação inicial.")
	var og := GridContainer.new()
	og.columns = 3
	og.add_theme_constant_override("h_separation", 10)
	og.add_theme_constant_override("v_separation", 10)
	og.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(og)
	for o in Founding.origins():
		var id := str(o.id)
		var b := UI.button(str(o.name), func(): _pick(func(): _origin = id), "primary" if id == _origin else "normal", 70)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		og.add_child(b)
	var od := _origin_def()
	_body.add_child(UI.wrap("%s — %s" % [od.tag, od.desc], 24, Palette.TEXT))

	_section("Dificuldade", "")
	var dr := UI.hbox(10)
	_body.add_child(dr)
	for d in Founding.difficulties():
		var id := str(d.id)
		var b := UI.button(str(d.name), func(): _pick(func(): _diff = id), "primary" if id == _diff else "normal", 70)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dr.add_child(b)
	_body.add_child(UI.wrap(str(Founding.difficulty(_diff).desc), 24, Palette.TEXT))

	_section("Especialização", "A categoria escolhida vende %d%% mais." % int(round((Founding.focus_sales() - 1.0) * 100.0)))
	var fr := UI.hbox(10)
	_body.add_child(fr)
	var none := UI.button("Sem foco", func(): _pick(func(): _focus = ""), "primary" if _focus == "" else "normal", 70)
	none.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fr.add_child(none)
	for cat in GameData.categories():
		var id := str(cat.id)
		var b := UI.button(str(cat.name), func(): _pick(func(): _focus = id), "primary" if id == _focus else "normal", 70)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fr.add_child(b)

	_section("Modo de jogo", "Campanha e sandbox têm saves separados: um nunca apaga o outro.")
	var mr := UI.hbox(10)
	_body.add_child(mr)
	var camp := UI.button("Campanha", func(): _pick(func(): _sandbox = false), "primary" if not _sandbox else "normal", 70)
	camp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mr.add_child(camp)
	var sb := UI.button("Sandbox (dinheiro e pesquisa infinitos)", func(): _pick(func(): _sandbox = true), "info" if _sandbox else "normal", 70)
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mr.add_child(sb)
	_render_side()

func _section(title: String, hint: String) -> void:
	_body.add_child(UI.label(title, 30, Palette.ACCENT))
	if hint != "":
		_body.add_child(UI.wrap(hint, 22, Palette.MUTED))

func _pct(m: float) -> String:
	return "%+d%%" % int(round((m - 1.0) * 100.0))

func _render_side() -> void:
	var o := _origin_def()
	var d := Founding.difficulty(_diff)
	_side.add_child(UI.heading(_name.strip_edges() if _name.strip_edges() != "" else "Minha Empresa"))
	if _founder.strip_edges() != "":
		_side.add_child(UI.label("Fundador: " + _founder.strip_edges(), 24, Palette.MUTED))
	_side.add_child(UI.label("Estágio inicial: Garagem", 24, Palette.INFO))
	var cap := Rules.START_MONEY * float(o.cash) * float(d.cash)
	_side.add_child(UI.kv("Capital inicial", Fmt.money(cap), Palette.ACCENT, 26))
	_side.add_child(UI.kv("Reputação inicial", "%d" % int(Rules.START_REPUTATION + float(o.rep)), Palette.TEXT, 24))
	_side.add_child(UI.kv("Salários", _pct(float(o.wage)), Palette.GOOD if float(o.wage) < 1.0 else (Palette.BAD if float(o.wage) > 1.0 else Palette.TEXT), 24))
	_side.add_child(UI.kv("Velocidade de pesquisa", _pct(float(o.research)), Palette.GOOD if float(o.research) > 1.0 else Palette.TEXT, 24))
	_side.add_child(UI.kv("Custo de produção", _pct(float(o.cost)), Palette.GOOD if float(o.cost) < 1.0 else (Palette.BAD if float(o.cost) > 1.0 else Palette.TEXT), 24))
	_side.add_child(UI.kv("Vendas (dificuldade)", _pct(float(d.sales)), Palette.GOOD if float(d.sales) > 1.0 else (Palette.BAD if float(d.sales) < 1.0 else Palette.TEXT), 24))
	if _focus != "":
		_side.add_child(UI.kv("Foco: " + str(GameData.category(_focus).name), "+%d%% vendas" % int(round((Founding.focus_sales() - 1.0) * 100.0)), Palette.GOOD, 24))
	_side.add_child(UI.spacer())
	var existing := Saves.peek(_sandbox)
	var warn := not existing.is_empty()
	if warn:
		_side.add_child(UI.wrap("Já existe %s (%s, dia %d). %s" % [
			"um sandbox salvo" if _sandbox else "uma campanha salva", existing.name, int(existing.day),
			"Fundar de novo substitui esse slot; uma cópia da anterior é guardada." if not _sandbox else "Fundar de novo substitui esse sandbox."], 22, Palette.BAD))
	var go_text := "Fundar empresa"
	if warn and _confirm:
		go_text = "Confirmar: substituir e fundar"
	elif warn:
		go_text = "Fundar empresa (substitui o save)"
	_side.add_child(UI.button(go_text, _on_go, "danger" if (warn and _confirm) else "primary", 96))
	_side.add_child(UI.button("Voltar", func(): get_tree().change_scene_to_file("res://src/scenes/MainMenu.tscn"), "normal", 76))

func _on_go() -> void:
	if Saves.has_save(_sandbox) and not _confirm:
		_confirm = true
		_render()
		return
	if not _sandbox:
		Saves.archive_campaign()
	Saves.delete_save(_sandbox)
	Game.new_game(_name, _sandbox, {"origin": _origin, "difficulty": _diff, "founder": _founder, "focus": _focus})
	Game.save()
	get_tree().change_scene_to_file("res://src/scenes/GameScreen.tscn")
