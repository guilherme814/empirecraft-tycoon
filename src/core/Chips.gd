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
const MAX_GPU := 12
const GPU_TR := 520        # milhões de transistores por unidade de GPU
const MEM_TR := 220.0        # controlador de memória (por canal)
const RT_TR := 400.0         # unidades de ray tracing
const MEM_PIN_COST := 0.8  # pinos/PCB por canal
const SALVAGE := 0.55      # fração dos dies defeituosos aproveitáveis com 1 núcleo desligado
const MAX_ECORES := 16
const MAX_MEM := 8
const ISP_TR := 300
## Arquitetura: eficiência (menos calor), equilibrada ou desempenho (mais rápida e quente).
const ARCHS := {
	"eff": {"name": "Eficiência", "perf": 0.9, "power": 0.72, "bug": 0.0},
	"bal": {"name": "Equilibrada", "perf": 1.0, "power": 1.0, "bug": 0.0},
	"perf": {"name": "Desempenho", "perf": 1.1, "power": 1.3, "bug": 0.02},
}

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
	return {"node": best, "cores": 4, "clock": 2.0, "cache": 4, "npu": 0, "gpu": 0, "isp": false, "rt": false, "ecores": 0, "mem": 2, "valid": 0, "bin": "full", "arch": "bal", "foundry": "fab_a", "name": ""}

## Tensão (V) necessária para um clock (GHz): sobe junto, por isso a potência cresce mais que o clock.
static func voltage(clock: float) -> float:
	return clampf(0.6 + 0.25 * (clock - 0.8), 0.55, 1.4)

## Cálculo completo de um projeto (usa só dados do projeto; sem efeitos colaterais).
## Realismo: núcleos de alto desempenho + eficientes, parede de memória (canais x cache), potência
## dinâmica V²·f e vazamento por área, dies aproveitados (binning), ISP/NPU/GPU/RT e validação.
## Projetos antigos (sem os campos novos) são lidos com valores neutros.
static func stats(d: Dictionary) -> Dictionary:
	var g := GameData.chips()
	var n := node(str(d.node))
	var f := foundry(str(d.get("foundry", "fab_a")))
	var cores := int(d.cores)
	var ecores := int(d.get("ecores", 0))
	var clock := float(d.clock)
	var cache := int(d.cache)
	var npu := int(d.npu)
	var gpu := int(d.get("gpu", 0))
	var isp := bool(d.get("isp", false))
	var rt := bool(d.get("rt", false)) and gpu > 0
	var mem := int(d.get("mem", 4))
	var valid := clampi(int(d.get("valid", 0)), 0, 2)
	var salv := str(d.get("bin", "full")) == "salv" and cores >= 4
	var ar: Dictionary = ARCHS.get(str(d.get("arch", "bal")), ARCHS.bal)
	var tr: float = float(cores) * float(g.core_tr) + float(ecores) * float(g.core_tr) * 0.35 + float(cache) * float(g.cache_tr) \
		+ float(npu) * float(g.npu_tr) + float(gpu) * float(GPU_TR) + (float(ISP_TR) if isp else 0.0) \
		+ float(mem) * MEM_TR + (RT_TR if rt else 0.0)   # milhões
	var area: float = tr / float(n.density)                       # mm²
	var area_cm: float = area / 100.0
	var d0 := float(n.d0) * float(f.d0)
	var ad := maxf(area_cm * d0, 0.0001)
	var y := pow((1.0 - exp(-ad)) / ad, 2.0)               # Murphy
	var rad := float(g.wafer_mm) * 0.5
	var dpw := maxf(1.0, PI * rad * rad / area - PI * float(g.wafer_mm) / sqrt(2.0 * area))
	var wafer_cost := float(n.wafer) * float(f.wafer)
	# binning: dies com um núcleo defeituoso viram a versão com 1 núcleo a menos, em vez de lixo
	var sell_frac: float = (y + (1.0 - y) * SALVAGE) if salv else y
	var good := maxf(dpw * sell_frac, 0.5)
	var die_cost := wafer_cost / good
	var unit := die_cost + float(g.pack_cost) + float(MEM_PIN_COST) * float(mem) + float(g.core_cost) * (float(cores) + 0.4 * float(ecores))
	var eff_cores := cores - 1 if salv else cores
	# desempenho: núcleos grandes + núcleos pequenos (lentos, mas baratos em energia)
	var cache_f := 1.0 + 0.04 * log(float(cache)) / log(2.0)
	var p_perf := pow(float(eff_cores), 0.72) * clock * float(n.perf)
	var e_perf := pow(float(maxi(ecores, 0)), 0.72) * clock * 0.6 * float(n.perf) * 0.45 if ecores > 0 else 0.0
	var perf := (p_perf + e_perf) * cache_f * (1.0 + 0.12 * float(npu)) * float(ar.perf)
	# parede de memória: sem canais/cache suficientes, mais núcleos e clock não viram desempenho
	var bw := float(mem) * float(g.get("mem_bw", 4.2)) * (1.0 + 0.08 * log(float(cache)) / log(2.0))
	var need := (float(eff_cores) + 0.4 * float(ecores)) * clock * 0.9
	var mem_ratio := bw / maxf(need, 0.1)
	var mem_f := 1.0 if mem_ratio >= 1.0 else sqrt(mem_ratio)
	perf *= mem_f
	# potência: dinâmica (V²·f) + vazamento (cresce com a área) + blocos
	var v := voltage(clock)
	var dyn := float(cores) * 0.55 * float(n.power) * v * v * clock * 2.47 * float(ar.power)
	var ve := voltage(clock * 0.6)
	dyn += float(ecores) * 0.55 * float(n.power) * ve * ve * clock * 0.6 * 2.47 * 0.22
	var leak: float = area * float(n.get("leak", 1.0)) * 0.006
	var tdp: float = dyn + leak + float(npu) * 0.9 * float(n.power) + 0.4 + float(mem) * 0.12 \
		+ float(gpu) * 0.32 * float(n.power) * (0.6 + 0.4 * clock / 2.0) + (0.25 * float(n.power) if isp else 0.0) \
		+ (0.6 * float(n.power) if rt else 0.0)
	# GPU: 0 unidades = gráficos integrados básicos (0,3); divide a memória com a CPU
	var gfx := maxf(0.3, pow(float(gpu), 0.8) * clock * float(n.perf) / 9.0)
	var g_need := need + float(gpu) * 0.7 * clock * 0.9
	var g_ratio := bw / maxf(g_need, 0.1)
	if g_ratio < 1.0:
		gfx *= sqrt(g_ratio)
	if rt:
		gfx *= 1.12
	var bug := 0.03 + 0.05 * maxf(0.0, clock - 2.6) + 0.002 * maxf(0.0, area - 120.0) + 0.01 * float(npu) \
		+ 0.004 * float(gpu) + (0.01 if isp else 0.0) + float(ar.bug) + 0.003 * float(ecores) + 0.004 * float(mem) + (0.01 if rt else 0.0)
	bug *= [1.0, 0.6, 0.35][valid]
	return {"gfx": gfx, "gpu": gpu, "area": area, "dpw": dpw, "yield": y, "sell_frac": sell_frac, "good": good,
		"wafer_cost": wafer_cost, "die_cost": die_cost, "unit_cost": unit, "perf": perf, "index": perf / 5.4, "tdp": tdp,
		"leak_w": leak, "mem_ratio": mem_ratio, "mem_factor": mem_f, "eff_cores": eff_cores, "bug": minf(bug, 0.6), "transistors": tr / 1000.0}

## Capacidades do chip, usadas para liberar componentes (ver Components).
static func caps(chip: Dictionary) -> Dictionary:
	return {"node": int(node(str(chip.get("node", "n90"))).get("lvl", 1)), "npu": int(chip.get("npu", 0)),
		"isp": bool(chip.get("isp", false)), "gpu": int(chip.get("gpu", 0)),
		"rt": bool(chip.get("rt", false)) and int(chip.get("gpu", 0)) > 0, "mem": int(chip.get("mem", 4))}

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
	var gw: float = float(GameData.chips().get("cat_gfx_weight", {}).get(cat_id, 0.0))
	var base_idx: float = float(st.index) * (1.0 - gw) + float(st.gfx) * gw
	var idx := minf(2.6, base_idx * (0.55 + 0.45 * throttle(c, chip, cat_id, specs)))
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
	return roundf(float(GameData.chips().dev_money_base) * float(n.work) * (1.0 + float(d.cores) / 8.0 + 0.4 * float(d.npu) + 0.08 * float(d.get("gpu", 0)) + (0.25 if bool(d.get("isp", false)) else 0.0) + 0.03 * float(d.get("ecores", 0)) + (0.15 if bool(d.get("rt", false)) else 0.0)) * (1.0 + 0.25 * float(clampi(int(d.get("valid", 0)), 0, 2))) + float(f.fee))

static func dev_work(d: Dictionary) -> float:
	var n := node(str(d.node))
	return roundf(float(GameData.chips().dev_work_base) * float(n.work) * (1.0 + float(d.cores) / 6.0 + 0.3 * float(d.npu) + 0.1 * float(d.cache) / 8.0 + 0.06 * float(d.get("gpu", 0)) + (0.2 if bool(d.get("isp", false)) else 0.0) + 0.02 * float(d.get("ecores", 0)) + 0.02 * float(d.get("mem", 4)) + (0.15 if bool(d.get("rt", false)) else 0.0)) * (1.0 + 0.3 * float(clampi(int(d.get("valid", 0)), 0, 2))))

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
