class_name Founding
extends RefCounted
## Fundação da empresa: país de origem, dificuldade, especialização e fundador.
## Tudo tem efeito mecânico real (capital, salários, pesquisa, custo de produção, reputação, vendas).

const STAGES := [
	{"id": "garage", "name": "Garagem"},
	{"id": "startup", "name": "Startup"},
	{"id": "company", "name": "Empresa"},
	{"id": "corp", "name": "Corporação"},
	{"id": "multi", "name": "Multinacional"},
]

static func origins() -> Array:
	return (GameData._load("origins") as Dictionary).origins

static func difficulties() -> Array:
	return (GameData._load("origins") as Dictionary).difficulties

static func origin(id: String) -> Dictionary:
	for o in origins():
		if o.id == id:
			return o
	return {}

static func difficulty(id: String) -> Dictionary:
	for d in difficulties():
		if d.id == id:
			return d
	return {}

static func focus_sales() -> float:
	return float((GameData._load("origins") as Dictionary).focus_sales)

## Multiplicador permanente de origem (wage/research/cost). Saves antigos (sem origem) = 1.
static func origin_mult(c: Company, key: String) -> float:
	var o := origin(c.origin)
	return float(o.get(key, 1.0)) if not o.is_empty() else 1.0

static func sales_mult(c: Company, cat_id: String) -> float:
	var m := 1.0
	var d := difficulty(c.difficulty)
	if not d.is_empty():
		m *= float(d.sales)
	if c.focus != "" and c.focus == cat_id:
		m *= focus_sales()
	return m

## Valida e aplica a ficha de fundação numa empresa recém-criada.
static func apply(c: Company, spec: Dictionary) -> void:
	var o := origin(str(spec.get("origin", "br")))
	var d := difficulty(str(spec.get("difficulty", "normal")))
	if o.is_empty():
		o = origin("br")
	if d.is_empty():
		d = difficulty("normal")
	c.origin = str(o.id)
	c.difficulty = str(d.id)
	c.founder = str(spec.get("founder", "")).strip_edges().left(24)
	var f := str(spec.get("focus", ""))
	c.focus = f if not GameData.category(f).is_empty() else ""
	c.money = Rules.START_MONEY * float(o.cash) * float(d.cash)
	c.cash_start = c.money
	c.reputation = clampf(Rules.START_REPUTATION + float(o.rep), 0.0, 100.0)

## Estágio derivado do estado (nada é salvo): reconhece a trajetória da empresa.
static func stage(c: Company) -> Dictionary:
	var lvl := 0
	var staff := c.staff.size()
	var inc := c.last_income
	if staff >= 5 or inc >= 50000.0:
		lvl = 1
	if staff >= 12 and inc >= 250000.0:
		lvl = 2
	if staff >= 25 and inc >= 1500000.0:
		lvl = 3
	var countries := {}
	for s in c.stores:
		countries[str(s.country)] = true
	if lvl >= 3 and countries.size() >= 3 and inc >= 5000000.0:
		lvl = 4
	var st: Dictionary = (STAGES[lvl] as Dictionary).duplicate()
	st["level"] = lvl
	return st
