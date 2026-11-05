class_name Updates
extends RefCounted
## Atualizações de software (OTA) de produtos já lançados: corrigem defeitos, sobem a qualidade
## de forma permanente (com teto) e rejuvenescem a curva de demanda. O sistema próprio sai mais
## barato e rende mais; a otimização para o chip recupera o desempenho perdido por estrangulamento.

const COOLDOWN_DAYS := 45
const MAX_BONUS := 0.18
const OWN_OS_COST := 0.7
const OWN_OS_GAIN := 1.3

const TIERS := [
	{"id": "fix", "name": "Correção de falhas", "mult": 0.6, "gain": 0.0, "refresh": 5, "desc": "Corrige todos os defeitos já encontrados e melhora a nota dos clientes."},
	{"id": "perf", "name": "Melhoria de desempenho", "mult": 1.0, "gain": 0.03, "refresh": 20, "desc": "+3% de qualidade permanente."},
	{"id": "major", "name": "Grande versão", "mult": 2.5, "gain": 0.06, "refresh": 60, "desc": "+6% de qualidade e demanda rejuvenescida. Exige Software Avançado."},
	{"id": "chip", "name": "Otimização para o chip", "mult": 1.4, "gain": 0.0, "refresh": 15, "desc": "Recupera o desempenho perdido por estrangulamento do chip próprio (uma vez)."},
]

static func tier(id: String) -> Dictionary:
	for t in TIERS:
		if t.id == id:
			return t
	return {}

static func base_cost(c: Company, p: Product) -> float:
	var own := p.os_id == "own"
	return 4000.0 * Decisions.scale(c) * (OWN_OS_COST if own else 1.0)

static func cost(c: Company, p: Product, id: String) -> float:
	return roundf(base_cost(c, p) * float(tier(id).mult))

static func chip_gain(c: Company, p: Product) -> float:
	var cid := int(p.design.get("chip", 0))
	if cid == 0:
		return 0.0
	var ch := Chips.get_chip(c, cid)
	if ch.is_empty():
		return 0.0
	return clampf(0.5 * (1.0 - Chips.throttle(c, ch, p.category, p.specs)) * 0.2, 0.0, 0.1)

static func gain(c: Company, p: Product, id: String) -> float:
	var g := chip_gain(c, p) if id == "chip" else float(tier(id).gain)
	return g * (OWN_OS_GAIN if p.os_id == "own" else 1.0)

## Motivo pelo qual a atualização não pode sair agora ("" = pode).
static func blocker(c: Company, p: Product, id: String) -> String:
	if p.state != Product.STATE_RELEASED:
		return "Produto não está à venda"
	if tier(id).is_empty():
		return "Atualização inválida"
	if c.day - p.last_update < COOLDOWN_DAYS and p.last_update > 0:
		return "Aguarde %d dias" % (COOLDOWN_DAYS - (c.day - p.last_update))
	if c.money < cost(c, p, id) and not c.sandbox:
		return "Caixa insuficiente"
	match id:
		"fix":
			if Lab.open_flaws(p).filter(func(f): return bool(f.found)).is_empty():
				return "Nenhum defeito conhecido"
		"perf":
			if p.update_q >= MAX_BONUS - 0.0001:
				return "Qualidade já no limite"
		"major":
			if c.research_level("res_software") < 1:
				return "Pesquise Software Avançado"
			if p.update_q >= MAX_BONUS - 0.0001:
				return "Qualidade já no limite"
		"chip":
			if p.update_log.has("chip"):
				return "Já otimizado"
			if chip_gain(c, p) <= 0.001:
				return "Sem estrangulamento a recuperar"
	return ""

static func apply(c: Company, pid: int, id: String) -> Dictionary:
	var p: Variant = c._find_in(c.products, pid)
	if p == null:
		return c._fail("Produto não encontrado")
	var why := blocker(c, p, id)
	if why != "":
		return c._fail(why)
	var t := tier(id)
	c._expense(cost(c, p, id), "dev")
	if id == "fix":
		for f in p.flaws:
			if bool(f.found):
				f["fixed"] = true
		p.rating = minf(5.0, p.rating + 0.15)
	else:
		p.update_q = minf(MAX_BONUS, p.update_q + gain(c, p, id))
	p.refresh_days = mini(240, p.refresh_days + int(t.refresh))
	p.last_update = c.day
	p.updates += 1
	if id == "chip":
		p.update_log.append("chip")
	c.reputation = clampf(c.reputation + 0.4, 0.0, 100.0)
	c.add_log("%s: %s para %s" % [str(t.name), "publicada", p.pname], "good", "success")
	return c._ok("%s publicada" % str(t.name))
