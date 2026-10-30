extends Page
## Finanças: demonstrativo do mês, empréstimos, patrimônio e histórico.

const LABELS := {
	"sales": "Vendas", "cogs": "Custo de produção", "payroll": "Salários", "rent": "Aluguel e escritório",
	"dev": "Desenvolvimento", "research": "Pesquisa", "hiring": "Contratações", "training": "Treinamento",
	"capex": "Investimentos (obras)", "fees": "Taxas de contratos", "commission": "Comissões e acordos",
	"recall": "Recalls e defeitos", "interest": "Juros", "taxes": "Impostos (15% do lucro)",
	"events": "Eventos", "loan": "Empréstimos", "other": "Outros"}

var _body: VBoxContainer
var _cur_box: VBoxContainer
var _cur_day: int = -1
var _chart: Chart
var _kpi_row_holder: VBoxContainer

func build() -> void:
	var sc := UI.scroll()
	add_child(sc)
	_body = UI.vbox(14)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_body)

func signature() -> String:
	var c := company
	return "%d|%d|%d|%d" % [int(c.loan), c.history.size(), int(c.stocks.value / 50000.0), c.day / 5]

func _stat(row: Control, title: String, value: String, color: Color) -> void:
	var card := UI.card(Palette.PANEL, 16)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(card)
	var v := UI.vbox(2)
	card.add_child(v)
	v.add_child(UI.label(title, 22, Palette.MUTED))
	v.add_child(UI.label(value, 32, color))

func _row(v: VBoxContainer, key: String, val: float, sign_good: bool = true, bold: bool = false, hint: String = "") -> void:
	var col := Palette.TEXT
	if bold:
		col = Palette.GOOD if val >= 0.0 else Palette.BAD
	v.add_child(UI.kv(key + ("  (" + hint + ")" if hint != "" else ""), Fmt.money(val), col, 26 if bold else 23))

## Demonstrativo simplificado (DRE) + fluxo de caixa: lucro não é caixa.
func _dre_card(title: String, d: Dictionary, cash_items: Dictionary) -> Control:
	var card := UI.card(Palette.PANEL, 18)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(4)
	card.add_child(v)
	v.add_child(UI.heading(title))
	_row(v, "Receita bruta", float(d.revenue))
	_row(v, "(−) Custo de produção", -float(d.cogs))
	_row(v, "Lucro bruto", float(d.gross), true, true)
	_row(v, "(−) Marketing", -float(d.marketing))
	_row(v, "(−) Salários", -float(d.payroll))
	_row(v, "(−) Estrutura e logística", -float(d.structure), true, false, "aluguel, fábrica")
	_row(v, "(−) Outras despesas", -float(d.other), true, false, "P&D, testes, taxas")
	_row(v, "Lucro operacional", float(d.operating), true, true)
	_row(v, "(−) Juros", -float(d.interest))
	_row(v, "(−) Impostos", -float(d.taxes))
	_row(v, "Lucro líquido", float(d.net), true, true)
	v.add_child(HSeparator.new())
	v.add_child(UI.label("Fluxo de caixa", 24, Palette.INFO))
	_row(v, "Lucro líquido", float(d.net))
	var names := {"capex": "Obras e fábrica", "loan": "Empréstimos", "stocks": "Bolsa e capital"}
	for k in cash_items:
		_row(v, str(names.get(k, k)), float(cash_items[k]), true, false, "fora do lucro")
	_row(v, "Variação do caixa", float(d.cash_flow), true, true)
	if float(d.net) > 0.0 and float(d.cash_flow) < 0.0:
		v.add_child(UI.wrap("Lucro positivo, mas o caixa caiu: cuidado com a liquidez.", 21, Palette.BAD))
	return card

func _kpi_row() -> Control:
	var c := company
	var row := UI.hbox(14)
	var dl := Economy.daily(c)
	var bal := Economy.balance(c)
	_stat(row, "Receita diária", Fmt.money(float(dl.revenue)), Palette.GOOD)
	_stat(row, "Lucro diário", Fmt.money(float(dl.profit)), Palette.GOOD if float(dl.profit) >= 0.0 else Palette.BAD)
	_stat(row, "Participação de mercado", Fmt.dec(float(bal.share) * 100.0) + "%", Palette.INFO)
	var pc := Economy.price_cost(c)
	_stat(row, "Margem média", Fmt.dec(float(pc.margin) * 100.0) + "%", Palette.ACCENT)
	return row

func _market_card() -> Control:
	var c := company
	var bal := Economy.balance(c)
	var pc := Economy.price_cost(c)
	var card := UI.card(Palette.PANEL, 18)
	var v := UI.vbox(6)
	card.add_child(v)
	v.add_child(UI.heading("Equilíbrio do mercado (hoje)"))
	var dem := maxf(float(bal.demand), 0.001)
	v.add_child(UI.kv("Demanda do mercado", Fmt.dec(float(bal.demand)) + " un./dia", Palette.TEXT, 24))
	v.add_child(UI.kv("Atendida por você", Fmt.dec(float(bal.mine)) + " un.", Palette.GOOD, 24))
	v.add_child(UI.bar(float(bal.mine) / dem, Palette.GOOD, 12))
	v.add_child(UI.kv("Atendida por rivais", Fmt.dec(float(bal.rivals)) + " un.", Palette.INFO, 24))
	v.add_child(UI.bar(float(bal.rivals) / dem, Palette.INFO, 12))
	v.add_child(UI.kv("Demanda não atendida", Fmt.dec(float(bal.unmet)) + " un.", Palette.WARN, 24))
	v.add_child(UI.bar(float(bal.unmet) / dem, Palette.WARN, 12))
	v.add_child(UI.kv("Preço médio", Fmt.money(float(pc.price)), Palette.TEXT, 24))
	v.add_child(UI.kv("Custo médio", Fmt.money(float(pc.cost)), Palette.TEXT, 24))
	if float(bal.unmet) > float(bal.mine) + float(bal.rivals):
		v.add_child(UI.wrap("Muita gente não comprou: preços altos ou qualidade abaixo da expectativa deixam demanda na mesa.", 21))
	return card

func _products_card() -> Control:
	var c := company
	var card := UI.card(Palette.PANEL, 18)
	var v := UI.vbox(6)
	card.add_child(v)
	v.add_child(UI.heading("Desempenho por produto"))
	var list := Economy.products(c)
	if list.is_empty():
		v.add_child(UI.label("Lance um produto para ver o resultado dele aqui.", 24, Palette.MUTED))
	for p in list:
		var h := UI.hbox(8)
		h.add_child(UI.icon_label(str(p.cat), str(p.name) + ("  (fora de linha)" if p.state == Product.STATE_RETIRED else ""), 24))
		h.add_child(UI.spacer())
		h.add_child(UI.label(Fmt.dec(float(p.per_day)) + "/dia", 22, Palette.MUTED))
		h.add_child(UI.label("margem %d%%" % int(float(p.unit_margin) * 100.0), 22, Palette.MUTED))
		var col := Palette.GOOD if float(p.profit) >= 0.0 else Palette.BAD
		h.add_child(UI.label(Fmt.money(float(p.profit)), 26, col))
		v.add_child(h)
	v.add_child(UI.wrap("Lucro acumulado de cada produto já descontando o custo de desenvolvimento.", 20))
	return card

func _ledger_card(title: String, led: Dictionary) -> Control:
	var card := UI.card(Palette.PANEL, 18)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(4)
	card.add_child(v)
	v.add_child(UI.heading(title))
	var total := 0.0
	var keys: Array = led.keys()
	keys.sort_custom(func(a, b): return float(led[a]) > float(led[b]))
	for k in keys:
		var val := float(led[k])
		total += val
		v.add_child(UI.kv(str(LABELS.get(k, k)), Fmt.money(val), Palette.GOOD if val >= 0.0 else Palette.BAD, 24))
	if keys.is_empty():
		v.add_child(UI.label("Sem movimentos", 24, Palette.MUTED))
	v.add_child(UI.kv("Resultado", Fmt.money(total), Palette.GOOD if total >= 0.0 else Palette.BAD, 28))
	return card

func rebuild() -> void:
	UI.clear(_body)
	var c := company
	var row := UI.hbox(14)
	_body.add_child(row)
	_stat(row, "Caixa", Fmt.money(c.money), Palette.GOOD if c.money >= 0.0 else Palette.BAD)
	_stat(row, "Dívida", Fmt.money(c.loan), Palette.BAD if c.loan > 0.0 else Palette.TEXT)
	_stat(row, "Patrimônio líquido", Fmt.money(c.net_worth()), Palette.INFO)
	_stat(row, "Valor da empresa", Fmt.money(c.stocks.value), Palette.ACCENT)

	_kpi_row_holder = UI.vbox(0)
	_body.add_child(_kpi_row_holder)
	_body.add_child(_market_card())
	_body.add_child(_products_card())
	var hist := UI.card(Palette.PANEL, 18)
	_body.add_child(hist)
	var hv := UI.vbox(8)
	hist.add_child(hv)
	hv.add_child(UI.heading("Caixa mês a mês"))
	_chart = Chart.new(190)
	var vals: Array = []
	for h in c.history:
		vals.append(float(h.money))
	_chart.set_series(vals, Palette.GOOD)
	hv.add_child(_chart)
	if vals.size() < 2:
		hv.add_child(UI.label("O gráfico aparece após o segundo fechamento de mês.", 22, Palette.MUTED))

	var cols := UI.hbox(14)
	_body.add_child(cols)
	cols.add_child(_dre_card("Mês passado", Economy.last_month(c), c.cash_items_last))
	_cur_box = UI.vbox(0)
	_cur_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(_cur_box)
	_cur_day = -1

	var loan_card := UI.card(Palette.PANEL, 18)
	_body.add_child(loan_card)
	var lv := UI.vbox(10)
	loan_card.add_child(lv)
	lv.add_child(UI.heading("Empréstimos"))
	lv.add_child(UI.kv("Limite de crédito", Fmt.money(c.loan_limit()), Palette.TEXT, 26))
	lv.add_child(UI.kv("Juros", "%.1f%% ao mês  (%s/mês)" % [Company.LOAN_RATE * 100.0, Fmt.money(c.loan * Company.LOAN_RATE)], Palette.MUTED, 24))
	var btns := UI.hbox(10)
	lv.add_child(btns)
	for amt in [50000.0, 200000.0, 1000000.0]:
		var b := UI.button("Pegar " + Fmt.money(amt), func(): act(c.take_loan(amt)), "primary", 72)
		b.disabled = c.loan + amt > c.loan_limit()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btns.add_child(b)
	var rb := UI.hbox(10)
	lv.add_child(rb)
	for amt in [50000.0, 200000.0]:
		var b := UI.button("Pagar " + Fmt.money(amt), func(): act(c.repay_loan(amt)), "good", 72)
		b.disabled = c.loan <= 0.0 or c.money < minf(amt, c.loan)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rb.add_child(b)
	var all := UI.button("Quitar tudo", func(): act(c.repay_loan(c.loan)), "good", 72)
	all.disabled = c.loan <= 0.0 or c.money < c.loan
	all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rb.add_child(all)

func live() -> void:
	var c := company
	if _cur_box != null and _cur_day != c.day:
		_cur_day = c.day
		UI.clear(_kpi_row_holder)
		_kpi_row_holder.add_child(_kpi_row())
		UI.clear(_cur_box)
		_cur_box.add_child(_dre_card("Mês atual (até agora)", Economy.current(c), c.cash_items))
