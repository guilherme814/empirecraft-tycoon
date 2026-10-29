class_name Feedback
extends RefCounted
## Central de feedback: (1) o que os clientes elogiam/reclamam, agregado das avaliações; (2) pedidos da equipe,
## que o jogador responde (custa dinheiro ou moral) e que afetam produtividade e demissões.

const MAX_REQUESTS := 6
const REQUEST_TTL := 60

# ───────── clientes ─────────

static func tag_label(tag: String) -> String:
	var t := tag.substr(1)
	if t.begins_with("flaw:"):
		return str(Lab.flaw_def(t.substr(5)).get("name", "Defeito"))
	match t:
		"price": return "Preço"
		"os": return "Sistema operacional"
		"design": return "Design"
		"fashion": return "Cor da moda"
		"defect": return "Defeitos de fábrica"
		"outdated": return "Aparelho defasado"
	return str(GameData.AXIS_LABELS.get(t, t.capitalize()))

## {pos: {tag: n}, neg: {tag: n}, n: total} somando os últimos `limit` comentários de clientes.
static func summarize(p: Product, limit: int = 24) -> Dictionary:
	var pos := {}
	var neg := {}
	var n := 0
	for i in range(p.reviews.size() - 1, -1, -1):
		var r: Dictionary = p.reviews[i]
		if r.kind != "cliente":
			continue
		n += 1
		for t in r.get("tags", []):
			var tt := str(t)
			var d: Dictionary = pos if tt.begins_with("+") else neg
			d[tt.substr(1)] = int(d.get(tt.substr(1), 0)) + 1
		if n >= limit:
			break
	return {"pos": pos, "neg": neg, "n": n}

static func top(d: Dictionary, k: int = 3) -> Array:
	var items: Array = []
	for key in d:
		items.append([key, int(d[key])])
	items.sort_custom(func(a, b): return a[1] > b[1])
	return items.slice(0, k)

## Sugestões práticas a partir das reclamações mais comuns.
static func suggestions(c: Company, p: Product) -> Array:
	var out: Array = []
	var s := summarize(p)
	for it in top(s.neg, 3):
		var k := str(it[0])
		if k == "price":
			out.append("Clientes acham caro: baixe o preço ou melhore a qualidade (preço justo: %s)." % Fmt.money(c.fair_price(p.category, c.effective_quality(p))))
		elif k == "os":
			out.append("O sistema incomoda: troque de SO ou evolua o seu próprio.")
		elif k == "outdated":
			out.append("Produto defasado: faça uma Nova versão com mais especificações.")
		elif k == "defect":
			out.append("Defeitos de fábrica: troque de fabricante ou rode ensaios no Laboratório.")
		elif k.begins_with("flaw:"):
			out.append("Corrija '%s' no Laboratório de testes (patch)." % tag_label("-" + k))
		elif GameData.AXIS_LABELS.has(k):
			out.append("Reforce %s na próxima versão." % str(GameData.AXIS_LABELS[k]).to_lower())
	if out.is_empty() and int(s.n) >= 4:
		out.append("Clientes satisfeitos. Mantenha o preço e invista em marketing.")
	return out

# ───────── equipe ─────────

static func _emp(c: Company, id: int) -> Employee:
	for e in c.staff:
		if e.id == id:
			return e
	return null

static func _has_open(c: Company, emp_id: int) -> bool:
	for r in c.requests:
		if int(r.emp) == emp_id:
			return true
	return false

static func monthly(c: Company) -> void:
	# moral reage ao resultado do mês
	var profit := c.last_income - c.last_expense
	for e in c.staff:
		e.morale = clampf(e.morale + (2.0 if profit > 0.0 else -2.0), 0.0, 100.0)
	# pedidos que ninguém respondeu expiram (e doem)
	for r in c.requests.duplicate():
		if c.day - int(r.day) >= REQUEST_TTL:
			c.requests.erase(r)
			var e := _emp(c, int(r.emp))
			if e != null and str(r.kind) != "praise":
				e.morale = maxf(0.0, e.morale - 12.0)
	if c.requests.size() >= MAX_REQUESTS or c.staff.is_empty():
		return
	var data: Dictionary = GameData.feedback().requests
	for e in c.staff:
		if c.requests.size() >= MAX_REQUESTS:
			break
		if _has_open(c, e.id):
			continue
		var kind := ""
		var roll := c.rng.randf()
		if e.morale < 40.0 and roll < 0.5:
			kind = "burnout"
		elif e.morale < 62.0 and roll < 0.35:
			kind = "raise"
		elif roll < 0.07:
			kind = ["training", "idea", "raise"][c.rng.randi() % 3]
		elif e.morale > 85.0 and roll < 0.12:
			kind = "praise"
		if kind == "":
			continue
		if kind == "idea" and e.profession != "researcher" and e.profession != "engineer" and e.profession != "programmer":
			kind = "training"
		var texts: Array = data[kind].text
		c.requests.append({"id": c._new_id(), "emp": e.id, "kind": kind, "day": c.day,
			"text": str(texts[c.rng.randi() % texts.size()]) % e.emp_name})
	# desligamentos por moral muito baixa
	for e in c.staff.duplicate():
		if e.morale < 12.0 and c.rng.randf() < 0.35:
			c.staff.erase(e)
			c.add_log("%s pediu demissão (moral muito baixa)" % e.emp_name, "bad", "event_bad")
			for r in c.requests.duplicate():
				if int(r.emp) == e.id:
					c.requests.erase(r)

static func option_cost(c: Company, req: Dictionary, idx: int) -> float:
	var e := _emp(c, int(req.emp))
	if e == null:
		return 0.0
	match str(req.kind):
		"raise":
			return e.salary() * 0.1 * 6.0 if idx == 0 else (e.salary() if idx == 1 else 0.0)
		"training":
			return float(c.train_cost(e).money) if idx == 0 else 0.0
		"burnout":
			return e.salary() * 0.25 if idx == 0 else (e.salary() * 0.6 if idx == 1 else 0.0)
		"idea":
			return 4000.0 if idx == 0 else 0.0
	return 0.0

static func answer(c: Company, req_id: int, idx: int) -> Dictionary:
	var req := {}
	for r in c.requests:
		if int(r.id) == req_id:
			req = r
	if req.is_empty():
		return c._fail("Pedido não encontrado")
	var e := _emp(c, int(req.emp))
	if e == null:
		c.requests.erase(req)
		return c._ok()
	var cost := option_cost(c, req, idx)
	if c.money < cost:
		return c._fail("Caixa insuficiente (%s)" % Fmt.money(cost))
	var msg := ""
	match str(req.kind):
		"raise":
			if idx == 0:
				c._expense(cost, "hiring")
				e.craft = mini(100, e.craft + 1)
				e.morale = minf(100.0, e.morale + 22.0)
				msg = "%s ficou satisfeito com o reajuste" % e.emp_name
			elif idx == 1:
				c._expense(cost, "hiring")
				e.morale = minf(100.0, e.morale + 12.0)
				msg = "Bônus pago a %s" % e.emp_name
			else:
				e.morale = maxf(0.0, e.morale - 14.0)
				msg = "%s não gostou da recusa" % e.emp_name
		"training":
			if idx == 0:
				var r := c.train(e.id, 0.0)
				if not r.ok:
					return r
				e.morale = minf(100.0, e.morale + 10.0)
				msg = "%s foi treinado" % e.emp_name
			else:
				e.morale = maxf(0.0, e.morale - 3.0)
		"burnout":
			if idx == 0:
				c._expense(cost, "hiring")
				e.morale = minf(100.0, e.morale + 28.0)
				msg = "%s voltou renovado" % e.emp_name
			elif idx == 1:
				c._expense(cost, "hiring")
				e.morale = minf(100.0, e.morale + 15.0)
			else:
				e.morale = maxf(0.0, e.morale - 15.0)
				msg = "%s está desmotivado" % e.emp_name
		"idea":
			if idx == 0:
				c._expense(cost, "research")
				var bonus := 25.0 + float(e.insight) * 0.6
				c.research_points += bonus
				e.morale = minf(100.0, e.morale + 8.0)
				msg = "A ideia de %s rendeu %d PP" % [e.emp_name, int(bonus)]
			else:
				e.morale = maxf(0.0, e.morale - 4.0)
		"praise":
			e.morale = minf(100.0, e.morale + 5.0)
			c.reputation = minf(100.0, c.reputation + 0.2)
	c.requests.erase(req)
	return c._ok(msg)
