class_name Presentations
extends RefCounted
## Apresentações ao vivo: o jogador escolhe o que apresentar (produto, sistema próprio ou chip),
## o país e o formato. O resultado depende da qualidade do que é apresentado, do gosto do país
## e do formato, e gera buzz local (vendas nas lojas do país), vendas globais e reputação.

const COOLDOWN_DAYS := 30
const REPEAT_DAYS := 120
const MAX_LOG := 30

static func _data() -> Dictionary:
	return GameData._load("presentations")

static func formats() -> Array:
	return _data().formats

static func format_def(id: String) -> Dictionary:
	for f in formats():
		if f.id == id:
			return f
	return {}

static func taste(country: String) -> Dictionary:
	return (_data().countries as Dictionary).get(country, {"product": 1.0, "os": 1.0, "chip": 1.0, "press": 1.0, "cost": 1.0, "note": ""})

static func cost(c: Company, country: String, format_id: String) -> float:
	return roundf(float(format_def(format_id).cost) * float(taste(country).cost) * Decisions.scale(c))

## Assuntos disponíveis: [{kind, id, name}].
static func subjects(c: Company) -> Array:
	var out: Array = []
	for p in c.products:
		if p.state == Product.STATE_RELEASED or p.state == Product.STATE_READY:
			out.append({"kind": "product", "id": p.id, "name": p.pname})
	if int(c.own_os.get("version", 0)) >= 1:
		out.append({"kind": "os", "id": 0, "name": "%s v%d" % [str(c.os_info("own").name), int(c.own_os.version)]})
	for ch in c.chips:
		out.append({"kind": "chip", "id": int(ch.id), "name": str(ch.name)})
	return out

static func _subject_name(c: Company, kind: String, id: int) -> String:
	for s in subjects(c):
		if s.kind == kind and int(s.id) == id:
			return str(s.name)
	return ""

## Pontos fortes mostrados no palco (até 5).
static func highlights(c: Company, kind: String, id: int) -> Array:
	var out: Array = []
	if kind == "product":
		var p: Product = c.get_product(id)
		if p == null:
			return out
		var cat: Dictionary = GameData.category(p.category)
		var picks: Array = []
		for a in cat.axes:
			var pt := Components.chosen(p.design, str(a))
			if int(pt.get("tier", 0)) >= 1:
				picks.append(pt)
		picks.sort_custom(func(x, y): return int(x.tier) > int(y.tier))
		for pt in picks:
			out.append(str(pt.name))
		var cid := int(p.design.get("chip", 0))
		if cid != 0:
			var ch := Chips.get_chip(c, cid)
			if not ch.is_empty():
				out.insert(0, "Processador próprio %s" % str(ch.name))
		if p.os_id == "own":
			out.append("Roda %s" % str(c.os_info("own").name))
		for f in p.design.get("features", []):
			var ft := c.feature_item(p.category, str(f))
			if not ft.is_empty():
				out.append(str(ft.name))
	elif kind == "os":
		for fid in c.own_os.get("features", []):
			var ft2 := c.os_feature(str(fid))
			if not ft2.is_empty():
				out.append(str(ft2.name))
		out.append("Versão %d do sistema" % int(c.own_os.get("version", 1)))
	elif kind == "chip":
		var ch2 := Chips.get_chip(c, id)
		if not ch2.is_empty():
			out.append("%s · %d núcleos a %.1f GHz" % [str(Chips.node(str(ch2.node)).name), int(ch2.cores), float(ch2.clock)])
			if int(ch2.get("gpu", 0)) > 0:
				out.append("GPU com %d unidades" % int(ch2.gpu))
			if int(ch2.npu) > 0:
				out.append("NPU para IA")
			if bool(ch2.get("isp", false)):
				out.append("ISP de câmera")
			out.append("%s" % str(Chips.ARCHS.get(str(ch2.get("arch", "bal")), Chips.ARCHS.bal).name))
	if out.is_empty():
		out.append("Design renovado")
	return out.slice(0, 5)

## Qualidade do assunto em relação ao esperado (1,0 = na média do mercado).
static func base_score(c: Company, kind: String, id: int) -> float:
	match kind:
		"product":
			var p: Product = c.get_product(id)
			return 0.0 if p == null else c.effective_quality(p) / maxf(c.market.expectation(c.day), 1.0)
		"os":
			return float(c.os_info("own").q) / 1.05
		"chip":
			var ch := Chips.get_chip(c, id)
			return 0.0 if ch.is_empty() else minf(1.8, float(Chips.stats(ch).index))
	return 0.0

static func blocker(c: Company, kind: String, id: int, country: String, format_id: String) -> String:
	var ct := GameData.country(country)
	if ct.is_empty():
		return "Escolha um país"
	if format_def(format_id).is_empty():
		return "Escolha o formato"
	if _subject_name(c, kind, id) == "":
		return "Escolha o que apresentar"
	if c.reputation < float(ct.rep):
		return "%s exige reputação %d" % [str(ct.name), int(ct.rep)]
	if c.last_presentation > 0 and c.day - c.last_presentation < COOLDOWN_DAYS:
		return "Aguarde %d dias para outro evento" % (COOLDOWN_DAYS - (c.day - c.last_presentation))
	for e in c.presentations:
		if str(e.kind) == kind and int(e.id) == id and str(e.country) == country and c.day - int(e.day) < REPEAT_DAYS:
			return "Já apresentado aí há pouco tempo"
	if c.money < cost(c, country, format_id) and not c.sandbox:
		return "Caixa insuficiente"
	return ""

static func verdict(score: float) -> String:
	return "wow" if score >= 1.12 else ("ok" if score >= 0.92 else "flop")

## Executa a apresentação. Devolve {ok, msg, outcome, score, highlights, effects[], country}.
static func run(c: Company, kind: String, id: int, country: String, format_id: String) -> Dictionary:
	var why := blocker(c, kind, id, country, format_id)
	if why != "":
		return c._fail(why)
	var f := format_def(format_id)
	var ct := GameData.country(country)
	var tt := taste(country)
	var reach := float(f.reach)
	var hl := highlights(c, kind, id)
	var score := base_score(c, kind, id) * float(tt.get(kind, 1.0)) * c.rng.randf_range(0.93, 1.07) * (1.0 + 0.03 * float(mini(hl.size(), 5)))
	var outcome := verdict(score)
	var paid := cost(c, country, format_id)
	c._expense(paid, "fees")
	var press := float(tt.press)
	var fx := 1.0 if outcome == "wow" else (0.5 if outcome == "ok" else -0.4 * (2.0 if format_id == "mega" else 1.0))
	var rep_fx := 1.0 if outcome == "wow" else (0.3 if outcome == "ok" else -0.8 * (2.0 if format_id == "mega" else 1.0))
	var effects: Array = ["Custo %s" % Fmt.money(paid)]
	var dr := 6.0 * reach * press * rep_fx
	c.reputation = clampf(c.reputation + dr, 0.0, 100.0)
	effects.append("Reputação %+.1f" % dr)
	var hype := 0.05 * reach * press * (0.6 + float(ct.w))
	var mult := maxf(0.9, 1.0 + hype * fx)
	var days := 30 + int(30.0 * reach)
	c.mods.append({"key": "sales", "mult": mult, "until": c.day + days, "src": "presentation"})
	effects.append("Vendas globais %+d%% por %d dias" % [int(round((mult - 1.0) * 100.0)), days])
	if fx > 0.0:
		var gain := minf(1.0, 0.35 * reach * fx)
		c.buzz[country] = minf(1.0, float(c.buzz.get(country, 0.0)) + gain)
		effects.append("Buzz em %s: lojas vendem mais" % str(ct.name))
	if kind == "product":
		var p: Product = c.get_product(id)
		if p != null and fx > 0.0:
			p.awareness = clampf(p.awareness + 0.15 * reach * fx, 0.0, 1.0)
			effects.append("Consciência de marca do produto sobe")
	elif kind == "os" and fx > 0.0:
		c.own_os["buzz"] = minf(4.0, float(c.own_os.get("buzz", 0.0)) + reach * fx)
		effects.append("Ecossistema do sistema próprio cresce")
	elif kind == "chip" and outcome == "wow":
		var rp := roundf(20.0 * reach)
		c.research_points += rp
		effects.append("+%d pontos de pesquisa (parcerias)" % int(rp))
	c.last_presentation = c.day
	c.presentations.append({"day": c.day, "kind": kind, "id": id, "country": country, "format": format_id, "outcome": outcome, "name": _subject_name(c, kind, id)})
	while c.presentations.size() > MAX_LOG:
		c.presentations.pop_front()
	var label: String = {"wow": "sucesso absoluto", "ok": "boa recepção", "flop": "fracasso"}[outcome]
	c.add_log("Apresentação de %s em %s: %s." % [_subject_name(c, kind, id), str(ct.name), label], "good" if outcome != "flop" else "bad", "release" if outcome == "wow" else "")
	return {"ok": true, "msg": label, "outcome": outcome, "score": score, "highlights": hl, "effects": effects, "country": country, "name": _subject_name(c, kind, id)}
