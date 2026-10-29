extends Page
## Visão geral: números-chave, projetos em andamento e próximos passos.

var _body: VBoxContainer

func build() -> void:
	var sc := UI.scroll()
	add_child(sc)
	_body = UI.vbox(18)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_body)

# Esta página não tem botões, então pode ser refeita a cada dia sem perder toques.
func signature() -> String:
	return str(company.day) + "|" + str(company.products.size()) + "|" + str(company.staff.size())

func rebuild() -> void:
	UI.clear(_body)
	var c := company
	# números-chave
	var row := UI.hbox(16)
	_body.add_child(row)
	var profit_now: float = c.income_month - c.expense_month
	_stat(row, "coin", "Caixa", Fmt.money(c.money), Palette.GOOD if c.money >= 0.0 else Palette.BAD)
	_stat(row, "trend_up", "Resultado no mês", Fmt.money(profit_now), Palette.GOOD if profit_now >= 0.0 else Palette.BAD)
	_stat(row, "nav_team", "Custos fixos/mês", Fmt.money(c.monthly_payroll() + c.monthly_rent()), Palette.TEXT)
	_stat(row, "star", "Reputação", "%d / 100" % int(c.reputation), Palette.INFO)
	_stat(row, "heart", "Lealdade", "%d%%  ·  %s" % [int(c.loyalty), Loyalty.tier(c.loyalty)], Palette.INFO)

	# projetos
	var proj := UI.card()
	_body.add_child(proj)
	var pv := UI.vbox(10)
	proj.add_child(pv)
	pv.add_child(UI.heading("Projetos"))
	var any := false
	for p in c.products:
		if p.state == Product.STATE_DEV:
			any = true
			var line := UI.hbox(14)
			line.add_child(UI.icon_label(p.category, "%s  ·  %s" % [p.pname, GameData.category(p.category).name], 26))
			line.add_child(UI.spacer())
			line.add_child(UI.label("%d%%" % int(p.progress() * 100.0), 26, Palette.ACCENT))
			pv.add_child(line)
			pv.add_child(UI.bar(p.progress()))
		elif p.state == Product.STATE_READY:
			any = true
			pv.add_child(UI.label("%s está pronto: vá em Produtos para lançar!" % p.pname, 26, Palette.GOOD))
		elif p.state == Product.STATE_RELEASED:
			any = true
			var line := UI.hbox(14)
			line.add_child(UI.icon_label(p.category, "%s  ·  vende ~%.1f/dia" % [p.pname, p.ema_units], 26))
			line.add_child(UI.spacer())
			line.add_child(UI.label("lucro " + Fmt.money(p.profit_total()), 26,
				Palette.GOOD if p.profit_total() >= 0.0 else Palette.BAD))
			pv.add_child(line)
	if not any:
		pv.add_child(UI.wrap("Nenhum projeto ainda."))

	# próximos passos
	var tips := _tips()
	if not tips.is_empty():
		var tc := UI.card(Palette.PANEL_ALT)
		_body.add_child(tc)
		var tv := UI.vbox(8)
		tc.add_child(tv)
		tv.add_child(UI.label("Próximos passos", 30, Palette.ACCENT))
		for t in tips:
			tv.add_child(UI.wrap("• " + t, 26, Palette.TEXT))

	# notícias
	var news := UI.card()
	_body.add_child(news)
	var nv := UI.vbox(8)
	news.add_child(nv)
	nv.add_child(UI.heading("Notícias"))
	var entries: Array = c.log_entries.duplicate()
	entries.reverse()
	for i in mini(10, entries.size()):
		var e: Dictionary = entries[i]
		nv.add_child(UI.wrap("[%s] %s" % [Fmt.date(int(e.day)), e.text], 24, UI.kind_color(str(e.kind))))

func _stat(row: HBoxContainer, icon_name: String, title: String, value: String, color: Color) -> void:
	var card := UI.card(Palette.PANEL, 18)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(card)
	var v := UI.vbox(4)
	card.add_child(v)
	v.add_child(UI.icon_label(icon_name, title, 22, Palette.MUTED, Palette.MUTED))
	v.add_child(UI.label(value, 34, color))

func _tips() -> Array:
	var c := company
	var tips: Array = []
	for prof in ["engineer", "programmer"]:
		if c.staff_of(prof).is_empty():
			tips.append("Contrate %s na aba Equipe (use \"Preencher\" para automatizar)." % GameData.profession(prof).name.to_lower())
	if c.staff_of("researcher").is_empty():
		tips.append("Um pesquisador gera pontos para desbloquear melhorias e novas categorias.")
	if tips.is_empty() and c.products.is_empty():
		tips.append("Abra a aba Produtos e inicie o desenvolvimento do seu primeiro smartphone.")
	if c.money < 30000.0 and c.released_products().is_empty():
		tips.append("Cuidado com o caixa: folha e aluguel são cobrados todo mês.")
	return tips
