class_name Reviews
extends RefCounted
## Avaliações: crítica especializada e clientes. Dependem da qualidade real, do preço, do SO,
## do design, da moda e de defeitos. A nota média realimenta as vendas.

static func _pick(rng: RandomNumberGenerator, arr: Array) -> String:
	return str(arr[rng.randi() % arr.size()]) if not arr.is_empty() else ""

## Pontuação geral 0..1 e seus componentes.
static func rate(c: Company, p: Product) -> Dictionary:
	var exp_q := c.market.expectation(c.day)
	var q := c.effective_quality(p)
	var qs := clampf((q / exp_q - 0.4) / 1.2, 0.0, 1.0)
	var fair := c.fair_price(p.category, q)
	var ratio := p.price / maxf(fair, 1.0)
	var ps := clampf((1.4 - ratio) / 0.8, 0.0, 1.0)
	var overall := 0.68 * qs + 0.32 * ps
	if c.is_fashion_color(str(p.design.get("color", ""))):
		overall += 0.03
	overall += float(c.mfr_stats(p.mfr).q - 1.0) * 0.3
	overall -= minf(0.4, 0.05 * float(Lab.severity_sum(p)))
	if p.promise_gap > 0.0 and c.day - p.release_day < 90:
		overall -= minf(0.45, p.promise_gap * 1.2)
	return {"overall": clampf(overall, 0.0, 1.0), "qs": qs, "ps": ps, "ratio": ratio}

static func _axis_extremes(p: Product) -> Dictionary:
	var best := ""
	var worst := ""
	var hi := -1
	var lo := 1000
	for a in p.specs:
		var v := int(p.specs[a])
		if v > hi:
			hi = v
			best = a
		if v < lo:
			lo = v
			worst = a
	return {"best": best, "worst": worst}

static func _customer_text(c: Company, p: Product, stars: int, info: Dictionary) -> Dictionary:
	var rng := c.rng
	var data: Dictionary = GameData.reviews()
	var ex := _axis_extremes(p)
	var bits: Array = []
	var tags: Array = []
	var pos: Dictionary = data.axis_pos
	var neg: Dictionary = data.axis_neg
	if stars >= 4:
		if pos.has(ex.best):
			bits.append(_pick(rng, pos[ex.best]))
			tags.append("+" + str(ex.best))
		if float(info.ratio) < 1.0:
			bits.append(_pick(rng, data.price_pos))
			tags.append("+price")
		elif c.is_fashion_color(str(p.design.get("color", ""))):
			bits.append(_pick(rng, data.fashion))
			tags.append("+fashion")
		elif c.os_mult(p.os_id, p.category) >= 1.02:
			bits.append(_pick(rng, data.os_pos))
			tags.append("+os")
		else:
			bits.append(_pick(rng, data.design_pos))
			tags.append("+design")
	elif stars == 3:
		if pos.has(ex.best):
			bits.append(_pick(rng, pos[ex.best]))
			tags.append("+" + str(ex.best))
		if neg.has(ex.worst):
			bits.append(_pick(rng, neg[ex.worst]))
			tags.append("-" + str(ex.worst))
	else:
		if float(info.ratio) > 1.15:
			bits.append(_pick(rng, data.price_neg))
			tags.append("-price")
		if neg.has(ex.worst):
			bits.append(_pick(rng, neg[ex.worst]))
			tags.append("-" + str(ex.worst))
		if float(info.qs) < 0.35:
			bits.append(_pick(rng, data.outdated))
			tags.append("-outdated")
		elif c.os_mult(p.os_id, p.category) < 0.95:
			bits.append(_pick(rng, data.os_neg))
			tags.append("-os")
	# falhas não corrigidas aparecem nas avaliações de quem dá nota baixa/média
	if stars <= 3:
		var open := Lab.open_flaws(p)
		if not open.is_empty():
			var f: Dictionary = Lab.flaw_def(str(open[rng.randi() % open.size()].id))
			bits.append("Além disso, " + str(f.review) + ".")
			tags.append("-flaw:" + str(f.id))
	bits.append(_pick(rng, data.closers[str(stars)]))
	return {"text": " ".join(bits), "tags": tags}

static func customer(c: Company, p: Product, defect: bool = false) -> Dictionary:
	var rng := c.rng
	var info := rate(c, p)
	var base: float = 1.0 + 4.0 * float(info.overall)
	var stars := clampi(int(round(base + rng.randf_range(-0.9, 0.9))), 1, 5)
	var ct := _customer_text(c, p, stars, info)
	var text: String = ct.text
	var tags: Array = ct.tags
	if defect:
		stars = mini(stars, 2)
		text = _pick(rng, GameData.reviews().defect) + " " + _pick(rng, GameData.reviews().closers["2"])
		tags = ["-defect"]
	var n: Dictionary = GameData.names()
	var who := "%s %s." % [_pick(rng, n.first), str(_pick(rng, n.last)).substr(0, 1)]
	return {"day": c.day, "who": who, "stars": stars, "text": text, "kind": "cliente", "tags": tags}

static func critic(c: Company, p: Product, outlet: String) -> Dictionary:
	var rng := c.rng
	var info := rate(c, p)
	var score := clampi(int(round(25.0 + 70.0 * float(info.overall) + rng.randf_range(-6.0, 6.0))), 5, 100)
	var heads: Dictionary = GameData.reviews().critic_heads
	var band := "0"
	for k in ["90", "75", "60", "40"]:
		if score >= int(k):
			band = k
			break
	var text := "%s. %s" % [_pick(rng, heads[band]), str(_customer_text(c, p, clampi(int(round(1.0 + 4.0 * float(score) / 100.0)), 1, 5), info).text)]
	return {"day": c.day, "who": outlet, "stars": score, "text": text, "kind": "critica"}

static func _add(p: Product, r: Dictionary) -> void:
	p.reviews.append(r)
	while p.reviews.size() > 30:
		p.reviews.pop_front()
	if r.kind == "cliente":
		p.rating_n += 1
		var w := maxf(1.0 / float(p.rating_n), 0.04)
		p.rating = float(r.stars) if p.rating_n == 1 else lerpf(p.rating, float(r.stars), w)

## Chamado no lançamento: 3 críticos e 5 clientes.
static func launch(c: Company, p: Product) -> void:
	var outlets: Array = GameData.reviews().outlets.duplicate()
	var sum := 0.0
	for i in 3:
		var o := _pick(c.rng, outlets)
		outlets.erase(o)
		var r := critic(c, p, o)
		sum += float(r.stars)
		p.reviews.append(r)
	p.critic = sum / 3.0
	for i in 5:
		_add(p, customer(c, p))
	var avg := p.rating
	if p.promise > 0.0:
		if p.promise_gap > 0.0:
			c.reputation = maxf(0.0, c.reputation - minf(8.0, p.promise_gap * 20.0))
			c.add_log("%s não cumpriu a promessa de +%d%% sobre a concorrência" % [p.pname, int(p.promise * 100.0)], "bad", "event_bad")
		else:
			c.reputation = minf(100.0, c.reputation + p.promise * 5.0)
			c.add_log("%s cumpriu a promessa de +%d%%!" % [p.pname, int(p.promise * 100.0)], "good", "event_good")
	if p.critic >= 80.0 and avg >= 4.0:
		c.reputation = minf(100.0, c.reputation + 2.0)
	elif p.critic < 45.0 or avg < 2.5:
		c.reputation = maxf(0.0, c.reputation - 2.5)
	elif p.critic >= 65.0:
		c.reputation = minf(100.0, c.reputation + 0.8)
	Loyalty.on_launch(c, p)
	c.add_log("Avaliações de %s: crítica %d, clientes %.1f/5" % [p.pname, int(p.critic), p.rating],
		"good" if p.critic >= 60.0 else "bad", "event_good" if p.critic >= 60.0 else "event_bad")
	c.review_ready.emit(p.id)

## Mensal: novas avaliações de clientes conforme as vendas.
static func monthly(c: Company) -> void:
	for p in c.released_products():
		if p.ema_units < 0.5:
			continue
		var n := clampi(int(p.ema_units / 3.0), 1, 4)
		for i in n:
			_add(p, customer(c, p))
