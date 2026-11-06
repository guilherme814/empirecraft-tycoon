extends Page
## Aquisições: compre concorrentes (viram subsidiárias) ou startups com vantagens permanentes.

var _body: VBoxContainer
var _confirm: String = ""

func build() -> void:
	var sc := UI.scroll()
	add_child(sc)
	_body = UI.vbox(14)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_body)

func signature() -> String:
	var c := company
	var ids: Array = []
	for t in Acquisitions.targets(c):
		ids.append("%s:%d" % [t.id, int(float(t.price) / 10000.0)])
	return "%s|%d|%d|%s|%d" % [str(ids), c.acquired.size(), int(c.money / 20000.0), _confirm, c.last_acq + c.day / 5]

func _buy(t: Dictionary) -> void:
	var key := "%s/%s" % [t.kind, t.id]
	if _confirm != key:
		_confirm = key
		_last_sig = "\u0001"
		refresh()
		return
	_confirm = ""
	act(Acquisitions.buy(company, str(t.kind), str(t.id)))
	_last_sig = "\u0001"
	refresh()

func rebuild() -> void:
	UI.clear(_body)
	var c := company
	var top := UI.hbox(14)
	_body.add_child(top)
	var wait := maxi(0, Acquisitions.COOLDOWN_DAYS - (c.day - c.last_acq)) if c.last_acq >= 0 else 0
	var info := [["Caixa", Fmt.money(c.money), Palette.ACCENT],
		["Empresas no grupo", "%d" % c.acquired.size(), Palette.INFO],
		["Próxima compra", "agora" if wait <= 0 else "em %d dias" % wait, Palette.GOOD if wait <= 0 else Palette.MUTED]]
	for it in info:
		var card := UI.card(Palette.PANEL, 16)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(card)
		var v := UI.vbox(2)
		card.add_child(v)
		v.add_child(UI.label(str(it[0]), 22, Palette.MUTED))
		v.add_child(UI.label(str(it[1]), 32, it[2]))
	_body.add_child(UI.wrap("Compre concorrentes (até %d) ou startups. Cada compra paga 4%% extra de integração e só pode ser feita a cada %d dias." % [Acquisitions.MAX_RIVALS, Acquisitions.COOLDOWN_DAYS], 22, Palette.MUTED))

	if not c.acquired.is_empty():
		_body.add_child(UI.heading("Seu grupo"))
		for a in c.acquired:
			var card := UI.card(Palette.PANEL, 16)
			_body.add_child(card)
			var v := UI.vbox(4)
			card.add_child(v)
			var kind := "Subsidiária" if str(a.kind) == "rival" else str(Acquisitions.type_def(str(a.get("type", ""))).get("name", "Startup"))
			v.add_child(UI.kv(str(a.name), "%s · pago %s" % [kind, Fmt.money(float(a.price))], Palette.TEXT, 24))
			if str(a.kind) == "rival":
				var i := c.market.rival_index(str(a.name))
				if i >= 0:
					var rv: float = float(c.market.rivals[i].get("rev_last", 0.0)) * Acquisitions.SHARE_OF_REV
					v.add_child(UI.label("Repasse do último mês: %s" % Fmt.money(rv), 22, Palette.GOOD))

	_body.add_child(UI.heading("À venda"))
	var list: Array = Acquisitions.targets(c)
	list.sort_custom(func(a, b): return float(a.price) < float(b.price))
	for t in list:
		_body.add_child(_target_card(t))

func _target_card(t: Dictionary) -> Control:
	var c := company
	var card := UI.card(Palette.PANEL, 16)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(6)
	card.add_child(v)
	var head := UI.hbox(8)
	v.add_child(head)
	var tag := "Concorrente" if str(t.kind) == "rival" else str(Acquisitions.type_def(str(t.type)).name)
	head.add_child(UI.label(str(t.name), 28, Palette.TEXT))
	head.add_child(UI.spacer())
	head.add_child(UI.label(tag, 22, Palette.INFO))
	v.add_child(UI.wrap(str(t.desc), 22, Palette.MUTED))
	if str(t.kind) == "rival":
		v.add_child(UI.kv("Valor de mercado", Fmt.money(float(t.value)), Palette.TEXT, 22))
		v.add_child(UI.kv("Tecnologia", "×%.2f" % float(t.tech), Palette.TEXT, 22))
	else:
		v.add_child(UI.kv("Oferta válida por", "%d dias" % maxi(0, int(t.expires) - c.day), Palette.TEXT, 22))
	var why := Acquisitions.blocker(c, str(t.kind), str(t.id))
	var key := "%s/%s" % [t.kind, t.id]
	var label := "Confirmar compra: %s" % Fmt.money(float(t.price)) if _confirm == key else "Comprar por %s" % Fmt.money(float(t.price))
	var b := UI.button(label, func(): _buy(t), "danger" if _confirm == key else "primary", 66)
	b.disabled = why != ""
	v.add_child(b)
	if why != "":
		v.add_child(UI.label(why, 21, Palette.BAD))
	return card
