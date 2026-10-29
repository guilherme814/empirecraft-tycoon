class_name Lab
extends RefCounted
## Laboratório de testes: falhas ocultas nascem no desenvolvimento; ensaios as revelam e o jogador paga
## para corrigi-las antes (ou depois) do lançamento. Falhas não corrigidas pesam em avaliações e recalls.

const MAX_JOBS := 3

static func test_def(id: String) -> Dictionary:
	for t in GameData.lab().tests:
		if t.id == id:
			return t
	return {}

static func flaw_def(id: String) -> Dictionary:
	for f in GameData.lab().flaws:
		if f.id == id:
			return f
	return {}

## Chamado quando o desenvolvimento termina: sorteia falhas ocultas.
static func roll_flaws(c: Company, p: Product) -> void:
	p.flaws = []
	var craft := 0.0
	var n := 0
	for prof in ["engineer", "programmer"]:
		for e in c.staff_of(prof):
			craft += float(e.craft)
			n += 1
	var skill := craft / maxf(float(n), 1.0)   # 0..100
	var mfr_risk: float = float(c.mfr_stats(p.mfr).risk)
	for f in GameData.lab().flaws:
		if not (f.cats as Array).has(p.category):
			continue
		var prob := float(f.p) * (1.35 - skill / 100.0) + mfr_risk * 1.5
		var ax := str(f.axis)
		if ax != "" and p.specs.has(ax):
			prob *= 1.4 - float(p.specs[ax]) / 100.0 * 0.8   # specs altas = projeto mais cuidadoso
		if str(f.id) == "overheat" and p.chip_id != 0:
			var ch := Chips.get_chip(c, p.chip_id)
			if not ch.is_empty() and Chips.throttle(c, ch, p.category, p.specs) < 0.9:
				prob += 0.25
		if c.rng.randf() < prob:
			p.flaws.append({"id": str(f.id), "found": false, "fixed": false})
	while p.flaws.size() > 4:
		p.flaws.pop_back()
	if p.chip_id != 0:
		var chip := Chips.get_chip(c, p.chip_id)
		if not chip.is_empty() and c.rng.randf() < float(chip.get("bug", 0.0)):
			p.flaws.append({"id": "bug_crash", "found": false, "fixed": false})

static func open_flaws(p: Product) -> Array:
	return p.flaws.filter(func(f): return not bool(f.fixed))

static func severity_sum(p: Product) -> int:
	var t := 0
	for f in open_flaws(p):
		t += int(flaw_def(str(f.id)).get("sev", 1))
	return t

static func test_blocker(c: Company, p: Product, id: String) -> String:
	var t := test_def(id)
	if t.is_empty():
		return "Teste inválido"
	if c.research_level("res_lab") < int(t.get("res", 0)):
		return "Pesquise Laboratório de Testes nv.%d" % int(t.res)
	if id == "camera" and not p.specs.has("camera"):
		return "Sem câmera"
	if p.state != Product.STATE_READY and p.state != Product.STATE_RELEASED:
		return "Produto ainda em desenvolvimento"
	for j in c.lab_jobs:
		if int(j.pid) == p.id and str(j.test) == id:
			return "Em andamento"
	if c.lab_jobs.size() >= MAX_JOBS:
		return "Laboratório ocupado (%d ensaios)" % MAX_JOBS
	if c.money < test_cost(c, id):
		return "Caixa insuficiente"
	return ""

static func test_cost(c: Company, id: String) -> float:
	return float(test_def(id).get("cost", 0)) * (1.0 + 0.0 * c.day)

static func test_days(c: Company, id: String) -> int:
	return maxi(2, int(round(float(test_def(id).days) * (1.0 - 0.12 * float(c.research_level("res_lab"))))))

static func run_test(c: Company, pid: int, id: String) -> Dictionary:
	var p: Product = c.get_product(pid)
	if p == null:
		return c._fail("Produto não encontrado")
	var why := test_blocker(c, p, id)
	if why != "":
		return c._fail(why)
	c._expense(test_cost(c, id), "tests")
	c.lab_jobs.append({"pid": pid, "test": id, "left": test_days(c, id), "days": test_days(c, id)})
	return c._ok("Ensaio iniciado: %s" % test_def(id).name)

## Medições "reais" do ensaio (determinísticas por produto), exibidas como indicadores.
static func measure(c: Company, p: Product, id: String) -> Dictionary:
	var sp := p.specs
	var jitter := float((p.id * 7919 + id.hash()) % 100) / 100.0 - 0.5   # -0.5..0.5
	var out := {}
	match id:
		"drop":
			var d := 1.0 + 0.012 * float(sp.get("display", 40)) + 0.5 * jitter
			if Lab.has_flaw(p, "screen_crack") or Lab.has_flaw(p, "hinge_loose") or Lab.has_flaw(p, "stick_drift") or Lab.has_flaw(p, "strap_break"):
				d *= 0.45
			out = {"label": "Altura que sobrevive", "value": "%.1f m" % d, "score": clampf(d / 2.4, 0.0, 1.0)}
		"battery":
			var h := 8.0 + 0.32 * float(sp.get("battery", 40)) + 2.0 * jitter
			if p.category == "laptop":
				h *= 0.8
			if p.category == "watch":
				h = 18.0 + 1.4 * float(sp.get("battery", 40)) + 8.0 * jitter
			if has_flaw(p, "short_battery"):
				h *= 0.6
			var unit := "h" if p.category != "watch" else "h"
			out = {"label": "Autonomia", "value": "%.0f %s" % [h, unit], "score": clampf(h / (28.0 if p.category != "watch" else 90.0), 0.0, 1.0)}
		"thermal":
			var t := 82.0 - 0.28 * float(sp.get("thermal", 40)) + 5.0 * jitter
			if p.chip_id != 0:
				var ch := Chips.get_chip(c, p.chip_id)
				if not ch.is_empty():
					t += 20.0 * (1.0 - Chips.throttle(c, ch, p.category, sp))
			if has_flaw(p, "overheat"):
				t += 14.0
			out = {"label": "Pico de temperatura", "value": "%d °C" % int(t), "score": clampf((100.0 - t) / 45.0, 0.0, 1.0)}
		"water":
			var ip := 52 + int(round(float(sp.get("display", 40)) / 25.0)) + (0 if not has_flaw(p, "water_leak") else -3)
			out = {"label": "Proteção", "value": "IP%d" % ip, "score": clampf(float(ip - 44) / 24.0, 0.0, 1.0)}
		"signal":
			var dbm := -92.0 + 0.1 * float(sp.get("performance", 40)) + 4.0 * jitter
			if has_flaw(p, "weak_signal"):
				dbm -= 9.0
			out = {"label": "Sensibilidade", "value": "%d dBm" % int(dbm), "score": clampf((dbm + 105.0) / 30.0, 0.0, 1.0)}
		"software":
			var bugs := int(round(24.0 - 0.18 * float(sp.get("performance", 40)) + 4.0 * jitter)) + 14 * open_count(p, "software")
			out = {"label": "Bugs encontrados", "value": "%d" % maxi(bugs, 0), "score": clampf(1.0 - float(bugs) / 48.0, 0.0, 1.0)}
		"camera":
			var sc := 55.0 + 0.4 * float(sp.get("camera", 40)) + 4.0 * jitter
			if has_flaw(p, "camera_focus"):
				sc -= 14.0
			out = {"label": "Nota de imagem", "value": "%d/100" % int(sc), "score": clampf(sc / 100.0, 0.0, 1.0)}
	return out

static func has_flaw(p: Product, id: String) -> bool:
	for f in p.flaws:
		if str(f.id) == id and not bool(f.fixed):
			return true
	return false

static func open_count(p: Product, test_id: String) -> int:
	var n := 0
	for f in open_flaws(p):
		if str(flaw_def(str(f.id)).get("test", "")) == test_id:
			n += 1
	return n

static func tick(c: Company) -> void:
	for j in c.lab_jobs.duplicate():
		j.left = int(j.left) - 1
		if int(j.left) > 0:
			continue
		c.lab_jobs.erase(j)
		var p: Product = c.get_product(int(j.pid))
		if p == null:
			continue
		var found: Array = []
		var detect := 0.85 + 0.04 * float(c.research_level("res_lab"))
		for f in p.flaws:
			if bool(f.fixed) or bool(f.found):
				continue
			if str(flaw_def(str(f.id)).get("test", "")) == str(j.test) and c.rng.randf() < detect:
				f.found = true
				found.append(flaw_def(str(f.id)).name)
		p.tests[str(j.test)] = {"day": c.day, "m": measure(c, p, str(j.test)), "found": found.size()}
		if found.is_empty():
			c.add_log("Ensaio '%s' de %s: nenhum problema encontrado" % [test_def(str(j.test)).name, p.pname], "good", "success")
		else:
			c.add_log("Ensaio '%s' de %s achou: %s" % [test_def(str(j.test)).name, p.pname, ", ".join(found)], "bad", "event_bad")

static func fix_cost(c: Company, p: Product, flaw_id: String) -> float:
	var sev: int = int(flaw_def(flaw_id).get("sev", 1))
	var m := 1.0 if p.state != Product.STATE_RELEASED else 1.6
	return roundf(maxf(3000.0, p.dev_cost * float(GameData.lab().fix_frac) * float(sev)) * m)

static func fix(c: Company, pid: int, flaw_id: String) -> Dictionary:
	var p: Product = c.get_product(pid)
	if p == null:
		return c._fail("Produto não encontrado")
	for f in p.flaws:
		if str(f.id) == flaw_id and bool(f.found) and not bool(f.fixed):
			var cost := fix_cost(c, p, flaw_id)
			if c.money < cost:
				return c._fail("Correção custa %s" % Fmt.money(cost))
			c._expense(cost, "tests")
			f.fixed = true
			return c._ok("Corrigido: %s" % flaw_def(flaw_id).name)
	return c._fail("Falha não identificada")

## Teste beta com clientes reais: simula avaliações sem registrá-las no produto.
static func start_beta(c: Company, pid: int) -> Dictionary:
	var p: Product = c.get_product(pid)
	if p == null or (p.state != Product.STATE_READY and p.state != Product.STATE_RELEASED):
		return c._fail("Produto indisponível")
	if not p.beta_job.is_empty():
		return c._fail("Beta em andamento")
	var cost := float(GameData.lab().beta_cost)
	if c.money < cost:
		return c._fail("Beta custa %s" % Fmt.money(cost))
	c._expense(cost, "tests")
	p.beta_job = {"left": int(GameData.lab().beta_days)}
	return c._ok("Beta fechado iniciado")

static func beta_tick(c: Company) -> void:
	for p in c.products:
		if p.beta_job.is_empty():
			continue
		p.beta_job.left = int(p.beta_job.left) - 1
		if int(p.beta_job.left) > 0:
			continue
		p.beta_job = {}
		var revs: Array = []
		var sum := 0.0
		for i in 6:
			var r := Reviews.customer(c, p)
			revs.append(r)
			sum += float(r.stars)
		var info := Reviews.rate(c, p)
		p.beta = {"day": c.day, "stars": sum / 6.0, "critic": clampi(int(round(25.0 + 70.0 * float(info.overall))), 5, 100),
			"fair": float(info.ratio), "reviews": revs, "open": severity_sum(p)}
		c.add_log("Beta de %s concluído: clientes %.1f/5" % [p.pname, float(p.beta.stars)], "good", "success")
