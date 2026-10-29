class_name Chips
extends RefCounted
## Projeto de processadores: nó de fabricação, núcleos, clock, cache e NPU definem área do die,
## rendimento do wafer (modelo de Murphy), custo por chip bom, desempenho e consumo (TDP).
## O chip escolhido altera qualidade, custo, calor e risco de bugs do produto.

const CLOCK_MIN := 0.8
const CLOCK_MAX := 3.6
const MAX_CORES := 16
const MAX_CACHE := 32
const MAX_NPU := 3

static func node(id: String) -> Dictionary:
	for n in GameData.chips().nodes:
		if n.id == id:
			return n
	return {}

static func foundry(id: String) -> Dictionary:
	for f in GameData.chips().foundries:
		if f.id == id:
			return f
	return {}

static func node_unlocked(c: Company, n: Dictionary) -> bool:
	return c.research_level("res_chips") >= int(n.lvl)

static func get_chip(c: Company, id: int) -> Dictionary:
	for ch in c.chips:
		if int(ch.id) == id:
			return ch
	return {}

static func default_design(c: Company) -> Dictionary:
	var best := "n90"
	for n in GameData.chips().nodes:
		if node_unlocked(c, n):
			best = str(n.id)
	return {"node": best, "cores": 4, "clock": 2.0, "cache": 4, "npu": 0, "foundry": "fab_a", "name": ""}

## Cálculo completo de um projeto (usa só dados do projeto; sem efeitos colaterais).
static func stats(d: Dictionary) -> Dictionary:
	var g := GameData.chips()
	var n := node(str(d.node))
	var f := foundry(str(d.get("foundry", "fab_a")))
	var cores := int(d.cores)
	var clock := float(d.clock)
	var cache := int(d.cache)
	var npu := int(d.npu)
	var tr := float(cores) * float(g.core_tr) + float(cache) * float(g.cache_tr) + float(npu) * float(g.npu_tr)   # milhões
	var area := tr / float(n.density)                       # mm²
	var area_cm := area / 100.0
	var d0 := float(n.d0) * float(f.d0)
	var ad := maxf(area_cm * d0, 0.0001)
	var y := pow((1.0 - exp(-ad)) / ad, 2.0)               # Murphy
	var rad := float(g.wafer_mm) * 0.5
	var dpw := maxf(1.0, PI * rad * rad / area - PI * float(g.wafer_mm) / sqrt(2.0 * area))
	var wafer_cost := float(n.wafer) * float(f.wafer)
	var good := maxf(dpw * y, 0.5)
	var die_cost := wafer_cost / good
	var unit := die_cost + float(g.pack_cost) + float(g.core_cost) * float(cores)
	var perf := pow(float(cores), 0.72) * clock * float(n.perf) * (1.0 + 0.04 * log(float(cache)) / log(2.0)) * (1.0 + 0.12 * float(npu))
	var tdp := float(cores) * clock * clock * float(n.power) * 0.55 + float(npu) * 0.9 * float(n.power) + 0.4
	var bug := 0.03 + 0.05 * maxf(0.0, clock - 2.6) + 0.002 * maxf(0.0, area - 120.0) + 0.01 * float(npu)
	return {"area": area, "dpw": dpw, "yield": y, "good": good, "wafer_cost": wafer_cost, "die_cost": die_cost,
		"unit_cost": unit, "perf": perf, "index": perf / 5.4, "tdp": tdp, "bug": minf(bug, 0.6), "transistors": tr / 1000.0}

static func chip_stats(chip: Dictionary) -> Dictionary:
	return stats(chip)

## Capacidade térmica do aparelho (W) segundo categoria e especificação de Térmica.
static func thermal_cap(cat_id: String, specs: Dictionary) -> float:
	var base: float = float(GameData.chips().thermal_cap.get(cat_id, 8.0))
	return base * (1.0 + 0.012 * float(specs.get("thermal", 25)))

## Fração do desempenho mantida sob carga contínua (1.0 = sem estrangulamento).
static func throttle(_c: Company, chip: Dictionary, cat_id: String, specs: Dictionary) -> float:
	var st := stats(chip)
	return minf(1.0, pow(thermal_cap(cat_id, specs) / maxf(float(st.tdp), 0.1), 0.6))

## Multiplicador de qualidade do produto devido ao chip (1.0 = SoC genérico).
static func quality_mult(c: Company, chip: Dictionary, cat_id: String, specs: Dictionary) -> float:
	if chip.is_empty():
		return 1.0
	var st := stats(chip)
	var idx := minf(2.6, float(st.index) * (0.55 + 0.45 * throttle(c, chip, cat_id, specs)))
	var m := 0.88 + 0.12 * idx
	var w: float = float(GameData.chips().cat_perf_weight.get(cat_id, 0.1))
	return 1.0 + (m - 1.0) * (0.5 + 2.0 * w)

## Custo do chip no produto, no lugar do SoC genérico (22% do custo base da categoria).
static func cost_delta(chip: Dictionary, cat_id: String) -> float:
	if chip.is_empty():
		return 0.0
	return float(stats(chip).unit_cost) - 0.22 * float(GameData.category(cat_id).unit_cost)

# ── desenvolvimento ──

static func dev_cost(d: Dictionary) -> float:
	var n := node(str(d.node))
	var f := foundry(str(d.get("foundry", "fab_a")))
	return roundf(float(GameData.chips().dev_money_base) * float(n.work) * (1.0 + float(d.cores) / 8.0 + 0.4 * float(d.npu)) + float(f.fee))

static func dev_work(d: Dictionary) -> float:
	var n := node(str(d.node))
	return roundf(float(GameData.chips().dev_work_base) * float(n.work) * (1.0 + float(d.cores) / 6.0 + 0.3 * float(d.npu) + 0.1 * float(d.cache) / 8.0))

static func blocker(c: Company, d: Dictionary) -> String:
	if c.research_level("res_chips") < 1:
		return "Pesquise Projeto de Chips"
	if c.chip_dev != null:
		return "Outro chip em desenvolvimento"
	if c.staff_of("engineer").is_empty():
		return "Contrate engenheiros"
	var n := node(str(d.node))
	if n.is_empty() or not node_unlocked(c, n):
		return "Nó indisponível (pesquise mais Projeto de Chips)"
	var f := foundry(str(d.get("foundry", "fab_a")))
	if c.reputation < float(f.rep):
		return "Fundição exige reputação %d" % int(f.rep)
	if str(d.get("name", "")).strip_edges() == "":
		return "Dê um nome ao chip"
	if c.money < dev_cost(d):
		return "Caixa insuficiente"
	return ""

static func start(c: Company, d: Dictionary) -> Dictionary:
	var why := blocker(c, d)
	if why != "":
		return c._fail(why)
	c._expense(dev_cost(d), "dev")
	c.chip_dev = {"design": d.duplicate(), "work": 0.0, "req": dev_work(d)}
	c.add_log("Iniciou o projeto do chip %s" % str(d.name), "info", "success")
	return c._ok()

static func tick(c: Company) -> void:
	if c.chip_dev == null:
		return
	var work := 0.0
	for e in c.staff_of("engineer"):
		work += (0.5 + float(e.pace) / 100.0) * (0.7 + 0.3 * e.morale / 100.0)
	c.chip_dev.work = float(c.chip_dev.work) + work * 0.8 * (1.0 + c.effect("dev_speed"))
	if float(c.chip_dev.work) >= float(c.chip_dev.req):
		var d: Dictionary = c.chip_dev.design
		var st := stats(d)
		var chip := d.duplicate()
		chip["id"] = c._new_id()
		chip["day"] = c.day
		chip["bug"] = float(st.bug)
		c.chips.append(chip)
		c.chip_dev = null
		c.add_log("Chip %s pronto: %d núcleos, %.1f GHz, rendimento %d%%" % [d.name, int(d.cores), float(d.clock), int(float(st.yield) * 100.0)], "good", "release")

static func delete_chip(c: Company, id: int) -> Dictionary:
	for p in c.products:
		if int(p.design.get("chip", 0)) == id and p.state != Product.STATE_RETIRED:
			return c._fail("Chip em uso por %s" % p.pname)
	var ch := get_chip(c, id)
	if ch.is_empty():
		return c._fail("Chip não encontrado")
	c.chips.erase(ch)
	return c._ok()
