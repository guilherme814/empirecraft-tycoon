class_name PresentationWizard
extends VBoxContainer
## Planejar e assistir a uma apresentação ao vivo: assunto, país, formato e palco animado.

signal closed

var company: Company
var _kind: String = ""
var _id: int = 0
var _country: String = ""
var _format: String = "stage"
var _body: VBoxContainer
var _sc: ScrollContainer

func setup(c: Company) -> PresentationWizard:
	company = c
	add_theme_constant_override("separation", 10)
	var subs := Presentations.subjects(c)
	if not subs.is_empty():
		_kind = str(subs[0].kind)
		_id = int(subs[0].id)
	_sc = UI.scroll()
	_sc.custom_minimum_size = Vector2(0, 640)
	add_child(_sc)
	_body = UI.vbox(10)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sc.add_child(_body)
	_plan()
	return self

func _sec(t: String) -> void:
	_body.add_child(UI.label(t, 26, Palette.ACCENT))

func _plan() -> void:
	UI.clear(_body)
	var c := company
	var subs := Presentations.subjects(c)
	_sec("O que apresentar")
	if subs.is_empty():
		_body.add_child(UI.wrap("Você ainda não tem nada para apresentar. Termine um produto, desenvolva um sistema próprio ou projete um chip.", 22, Palette.MUTED))
		_body.add_child(UI.button("Fechar", func(): closed.emit(), "normal", 72))
		return
	var kinds := {"product": "Produto", "os": "Software", "chip": "Hardware (chip)"}
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(g)
	for s in subs:
		var k: String = s.kind
		var sid: int = int(s.id)
		var sel := _kind == k and _id == sid
		var b := UI.button("%s · %s" % [kinds[k], str(s.name)], func():
			_kind = k
			_id = sid
			_plan(), "primary" if sel else "normal", 64)
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(b)
	var hl := Presentations.highlights(c, _kind, _id)
	_body.add_child(UI.wrap("Destaques no palco: " + ", ".join(hl), 21, Palette.MUTED))

	_sec("País da apresentação")
	var cg := GridContainer.new()
	cg.columns = 3
	cg.add_theme_constant_override("h_separation", 8)
	cg.add_theme_constant_override("v_separation", 8)
	cg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(cg)
	for ct in GameData.countries():
		var cid: String = ct.id
		var locked: bool = c.reputation < float(ct.rep)
		var b2 := UI.button(str(ct.name), func():
			_country = cid
			_plan(), "primary" if cid == _country else "normal", 58, 0, "lock" if locked else "")
		b2.disabled = locked
		b2.clip_text = true
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cg.add_child(b2)
	if _country != "":
		var t := Presentations.taste(_country)
		var ct2 := GameData.country(_country)
		_body.add_child(UI.wrap("%s Mercado ×%.2f · imprensa ×%.1f · gosto: %s ×%.2f." % [str(t.note), float(ct2.w), float(t.press),
			{"product": "produtos", "os": "software", "chip": "chips"}[_kind], float(t.get(_kind, 1.0))], 21, Palette.TEXT))
		var buzz := float(c.buzz.get(_country, 0.0))
		if buzz > 0.02:
			_body.add_child(UI.wrap("Buzz atual no país: %d%%" % int(buzz * 100.0), 21, Palette.GOOD))

	_sec("Formato")
	var fr := UI.vbox(6)
	_body.add_child(fr)
	for f in Presentations.formats():
		var fid: String = f.id
		var price := Presentations.cost(c, _country if _country != "" else "br", fid)
		var b3 := UI.button("%s · %s" % [str(f.name), Fmt.money(price)], func():
			_format = fid
			_plan(), "primary" if fid == _format else "normal", 60)
		fr.add_child(b3)
	_body.add_child(UI.wrap(str(Presentations.format_def(_format).desc), 21, Palette.MUTED))
	var why := Presentations.blocker(c, _kind, _id, _country, _format)
	var go := UI.button("Apresentar", _go, "good", 84)
	go.disabled = why != ""
	_body.add_child(go)
	if why != "":
		_body.add_child(UI.label(why, 22, Palette.WARN))
	_body.add_child(UI.button("Fechar", func(): closed.emit(), "normal", 64))
	if not c.presentations.is_empty():
		_sec("Últimas apresentações")
		var shown := c.presentations.duplicate()
		shown.reverse()
		for e in shown.slice(0, 5):
			var oc: String = {"wow": "sucesso", "ok": "boa", "flop": "fracasso"}[str(e.outcome)]
			_body.add_child(UI.wrap("%s · %s em %s · %s" % [Fmt.date(int(e.day)), str(e.name), str(GameData.country(str(e.country)).get("name", e.country)), oc], 20,
				Palette.GOOD if str(e.outcome) != "flop" else Palette.BAD))

func _go() -> void:
	var res := Presentations.run(company, _kind, _id, _country, _format)
	if not bool(res.ok):
		Game.notice.emit(str(res.msg), "bad")
		_plan()
		return
	Game.changed.emit()
	_stage(res)

## Palco: os destaques entram um a um, a plateia reage e sai o veredito.
func _stage(res: Dictionary) -> void:
	UI.clear(_body)
	var ct := GameData.country(str(res.country))
	_body.add_child(UI.label("%s — %s" % [str(res.name), str(ct.name)], 30, Palette.ACCENT))
	var stage := UI.card(Color("0b1020"), 22)
	stage.custom_minimum_size = Vector2(0, 300)
	_body.add_child(stage)
	var sv := UI.vbox(10)
	stage.add_child(sv)
	var lines: Array = []
	for h in res.highlights:
		var l := UI.label("▸ " + str(h), 30, Palette.TEXT)
		l.modulate.a = 0.0
		sv.add_child(l)
		lines.append(l)
	var aud := UI.bar(0.0, Palette.INFO, 18)
	sv.add_child(aud)
	var verdict_l := UI.label("", 40, Palette.ACCENT)
	verdict_l.modulate.a = 0.0
	_body.add_child(verdict_l)
	var fx_box := UI.vbox(4)
	fx_box.modulate.a = 0.0
	for e in res.effects:
		fx_box.add_child(UI.wrap(str(e), 22, Palette.TEXT))
	_body.add_child(fx_box)
	var close_b := UI.button("Fechar", func(): closed.emit(), "primary", 80)
	close_b.disabled = true
	_body.add_child(close_b)
	var outcome := str(res.outcome)
	var col: Color = Palette.GOOD if outcome == "wow" else (Palette.ACCENT if outcome == "ok" else Palette.BAD)
	verdict_l.text = {"wow": "A plateia se levantou!", "ok": "Boa recepção.", "flop": "Silêncio na plateia..."}[outcome]
	verdict_l.add_theme_color_override("font_color", col)
	var tw := create_tween()
	for l in lines:
		tw.tween_property(l, "modulate:a", 1.0, 0.35)
		tw.tween_callback(func(): UIFx.sparkle(self, l.get_global_rect().get_center() - global_position))
		tw.tween_property(aud, "value", minf(1.0, aud.value + 0.8 / float(maxi(lines.size(), 1))) , 0.25)
		tw.tween_interval(0.25)
	tw.tween_property(aud, "value", clampf(float(res.score) / 1.4, 0.05, 1.0), 0.5)
	tw.tween_property(verdict_l, "modulate:a", 1.0, 0.4)
	tw.tween_callback(func():
		if outcome == "wow":
			UIFx.confetti(self, Vector2(size.x * 0.5, 200.0))
		fx_box.modulate.a = 1.0
		close_b.disabled = false
		await get_tree().process_frame
		_sc.scroll_vertical = 100000)
