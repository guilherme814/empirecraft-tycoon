class_name Marketing
extends RefCounted
## Campanhas de marketing: canal + regiões + orçamento diário + duração geram "consciência de marca"
## do produto (0..1), que decai sozinha e multiplica a atratividade nas vendas.

const MAX_CAMPAIGNS := 3
const REF_BUDGET := 1000.0

static func channel(id: String) -> Dictionary:
	for ch in GameData.marketing().channels:
		if ch.id == id:
			return ch
	return {}

static func region(id: String) -> Dictionary:
	for r in GameData.marketing().regions:
		if r.id == id:
			return r
	return {}

static func channel_blocker(c: Company, id: String) -> String:
	var ch := channel(id)
	if ch.is_empty():
		return "Canal inválido"
	if c.research_level("res_marketing") < int(ch.res):
		return "Pesquise Marketing Avançado nv.%d" % int(ch.res)
	if c.reputation < float(ch.rep):
		return "Reputação %d" % int(ch.rep)
	return ""

static func reach(regions: Array) -> float:
	var t := 0.0
	for r in regions:
		t += float(region(str(r)).get("w", 0.0))
	return t

## Ganho diário de consciência (antes do fator (1 - a)).
static func daily_gain(c: Company, p: Product, channel_id: String, regions: Array, budget_day: float) -> float:
	var ch := channel(channel_id)
	if ch.is_empty():
		return 0.0
	var aff: float = float(GameData.marketing().affinity.get(p.category, {}).get(channel_id, 1.0))
	var eff := float(ch.eff) * aff * (1.0 + c.effect("hype") * 0.5)
	# retorno decrescente no orçamento; mais regiões = mais alcance mas o orçamento se dilui
	return 0.075 * eff * pow(maxf(budget_day, 1.0) / REF_BUDGET, 0.6) * (0.35 + 0.65 * reach(regions))

## Custo total e consciência esperada ao fim da campanha.
static func preview(c: Company, p: Product, channel_id: String, regions: Array, budget_day: float, days: int) -> Dictionary:
	var g := daily_gain(c, p, channel_id, regions, budget_day)
	var a := p.awareness
	for i in days:
		a = a * 0.985 + g * (1.0 - a)
	var extra := (factor(a) / factor(p.awareness) - 1.0)
	return {"cost": budget_day * float(days), "awareness": a, "boost": extra, "gain": g}

static func organic(c: Company) -> float:
	return 0.10 + c.reputation / 400.0

static func awareness_of(c: Company, p: Product) -> float:
	return maxf(p.awareness, organic(c))

static func factor(a: float) -> float:
	return 0.9 + 0.5 * a

static func start(c: Company, pid: int, channel_id: String, regions: Array, budget_day: float, days: int) -> Dictionary:
	var p: Product = c.get_product(pid)
	if p == null or p.state != Product.STATE_RELEASED and p.state != Product.STATE_READY:
		return c._fail("Escolha um produto pronto ou lançado")
	if c.campaigns.size() >= MAX_CAMPAIGNS:
		return c._fail("Limite de %d campanhas simultâneas" % MAX_CAMPAIGNS)
	var why := channel_blocker(c, channel_id)
	if why != "":
		return c._fail(why)
	if regions.is_empty():
		return c._fail("Escolha ao menos uma região")
	days = clampi(days, 3, 90)
	budget_day = clampf(budget_day, 100.0, 50000.0)
	var upfront := budget_day * minf(5.0, float(days))
	if c.money < upfront:
		return c._fail("Caixa insuficiente: ao menos %s para começar" % Fmt.money(upfront))
	for k in c.campaigns:
		if int(k.pid) == pid and str(k.channel) == channel_id:
			return c._fail("Já existe uma campanha desse canal para este produto")
	c.campaigns.append({"id": c._new_id(), "pid": pid, "channel": channel_id, "regions": regions.duplicate(),
		"budget": budget_day, "left": days, "days": days, "spent": 0.0, "a0": p.awareness, "day0": c.day})
	return c._ok("Campanha iniciada: %s" % channel(channel_id).name)

static func stop(c: Company, cid: int) -> Dictionary:
	for k in c.campaigns:
		if int(k.id) == cid:
			c.campaigns.erase(k)
			return c._ok("Campanha encerrada")
	return c._fail("Campanha não encontrada")

## Chamado todo dia.
static func tick(c: Company) -> void:
	for p in c.products:
		if p.state == Product.STATE_RELEASED or p.state == Product.STATE_READY:
			p.awareness = maxf(0.0, p.awareness * 0.985)
	for k in c.campaigns.duplicate():
		var p: Product = c.get_product(int(k.pid))
		if p == null or p.state == Product.STATE_RETIRED:
			c.campaigns.erase(k)
			continue
		var b := float(k.budget)
		if c.money < b:
			c.add_log("Campanha de %s pausada: sem caixa" % p.pname, "bad")
			c.campaigns.erase(k)
			continue
		c._expense(b, "marketing")
		k.spent = float(k.spent) + b
		var g := daily_gain(c, p, str(k.channel), k.regions, b)
		p.awareness = clampf(p.awareness + g * (1.0 - p.awareness), 0.0, 1.0)
		k.left = int(k.left) - 1
		if int(k.left) <= 0:
			c.campaigns.erase(k)
			c.add_log("Campanha de %s (%s) terminou: gastou %s, consciência %d%% → %d%%" % [p.pname,
				channel(str(k.channel)).name, Fmt.money(float(k.spent)), int(float(k.a0) * 100.0), int(p.awareness * 100.0)], "good", "success")
