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

func build() -> void:
	var sc := UI.scroll()
	add_child(sc)
	_body = UI.vbox(14)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_body)

func signature() -> String:
	var c := company
	return "%d|%d|%d" % [int(c.loan), c.history.size(), int(c.stocks.value / 50000.0)]

func _stat(row: Control, title: String, value: String, color: Color) -> void:
	var card := UI.card(Palette.PANEL, 16)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(card)
	var v := UI.vbox(2)
	card.add_child(v)
	v.add_child(UI.label(title, 22, Palette.MUTED))
	v.add_child(UI.label(value, 32, color))

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
	cols.add_child(_ledger_card("Mês passado", c.ledger_last))
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
		UI.clear(_cur_box)
		_cur_box.add_child(_ledger_card("Mês atual (até agora)", c.ledger))
