class_name Components
extends RefCounted
## Catálogo de componentes por eixo de especificação (bateria, tela, câmera, GPU...).
## Cada peça muda a eficácia do eixo (q), o custo e o consumo. Algumas exigem pesquisa, um formato
## compatível ou capacidades do processador (nó, NPU, ISP, GPU): chips próprios abrem as peças top.
## Sem escolha, vale a peça de nível 0 — produtos antigos mantêm exatamente os mesmos números.

static func _data() -> Dictionary:
	return GameData._load("components")

static func parts(axis: String) -> Array:
	return (_data().axes as Dictionary).get(axis, [])

static func label(axis: String) -> String:
	return str((_data().labels as Dictionary).get(axis, GameData.AXIS_LABELS.get(axis, axis)))

static func part(axis: String, id: String) -> Dictionary:
	for p in parts(axis):
		if p.id == id:
			return p
	return {}

static func base_part(axis: String) -> Dictionary:
	var l := parts(axis)
	return l[0] if not l.is_empty() else {}

## Peça escolhida no design para o eixo (ou a básica).
static func chosen(design: Dictionary, axis: String) -> Dictionary:
	var sel: String = str((design.get("parts", {}) as Dictionary).get(axis, ""))
	var p := part(axis, sel) if sel != "" else {}
	if p.is_empty() and sel == "":
		# sem escolha: um formato que exige peça específica (dobrável -> tela dobrável) usa essa peça
		var rule: Dictionary = (_data().shape_rules as Dictionary).get(str(design.get("shape", "")), {})
		if rule.has(axis):
			p = part(axis, str((rule[axis] as Array)[0]))
	return p if not p.is_empty() else base_part(axis)

static func axis_q(design: Dictionary, axis: String) -> float:
	var p := chosen(design, axis)
	return float(p.get("q", 1.0))

static func axis_cost(design: Dictionary, axis: String) -> float:
	var p := chosen(design, axis)
	return float(p.get("cost", 1.0))

## Capacidades do processador do design (SoC genérico se não houver chip próprio).
static func chip_caps(c: Company, design: Dictionary) -> Dictionary:
	var cid := int(design.get("chip", 0))
	if cid == 0:
		return (_data().generic_chip as Dictionary).duplicate()
	var ch := Chips.get_chip(c, cid)
	if ch.is_empty():
		return (_data().generic_chip as Dictionary).duplicate()
	return Chips.caps(ch)

## Motivo pelo qual a peça não pode ser usada agora ("" = livre).
static func part_blocker(c: Company, p: Dictionary, design: Dictionary) -> String:
	if c.research_level("res_specs") < int(p.lvl):
		return "Eng. de Materiais nv.%d" % int(p.lvl)
	var need: Dictionary = p.get("chip", {})
	if not need.is_empty():
		var caps := chip_caps(c, design)
		if need.has("node") and int(caps.node) < int(need.node):
			return "chip em nó mais avançado"
		if need.has("npu") and int(caps.npu) < int(need.npu):
			return "chip com NPU"
		if need.has("isp") and bool(need.isp) and not bool(caps.isp):
			return "chip com ISP"
		if need.has("gpu") and int(caps.gpu) < int(need.gpu):
			return "chip com %d+ unidades de GPU" % int(need.gpu)
		if need.has("rt") and bool(need.rt) and not bool(caps.rt):
			return "chip com ray tracing"
		if need.has("mem") and int(caps.mem) < int(need.mem):
			return "chip com %d+ canais de memória" % int(need.mem)
	var shape := str(design.get("shape", ""))
	if (p.get("forbid_shapes", []) as Array).has(shape):
		return "incompatível com o formato"
	var only: Array = p.get("only_shapes", [])
	if not only.is_empty() and not only.has(shape):
		return "só em formato dobrável"
	return ""

## Problemas do conjunto (peças bloqueadas, formato que exige peça específica).
static func problems(c: Company, cat_id: String, design: Dictionary) -> Array:
	var out: Array = []
	var cat: Dictionary = GameData.category(cat_id)
	for a in cat.axes:
		var p := chosen(design, str(a))
		if p.is_empty():
			continue
		var why := part_blocker(c, p, design)
		if why != "":
			out.append("%s (%s): %s" % [label(str(a)), str(p.name), why])
	var rules: Dictionary = (_data().shape_rules as Dictionary).get(str(design.get("shape", "")), {})
	for a in rules:
		if cat.axes.has(a) and not (rules[a] as Array).has(str(chosen(design, str(a)).get("id", ""))):
			out.append("Formato %s exige %s específica" % [str(design.get("shape", "")), label(str(a)).to_lower()])
	return out

static func _pivot(cat_id: String) -> float:
	var n: int = (GameData.category(cat_id).axes as Dictionary).size()
	return float(floori(float(Rules.SPEC_BUDGET_BASE) / float(n) / float(Rules.SPEC_STEP)) * Rules.SPEC_STEP)

static func _chip_tdp(c: Company, cat_id: String, design: Dictionary) -> float:
	var cid := int(design.get("chip", 0))
	if cid != 0:
		var ch := Chips.get_chip(c, cid)
		if not ch.is_empty():
			return float(Chips.stats(ch).tdp)
	return float(GameData.chips().thermal_cap.get(cat_id, 8.0)) * 0.35

## Balanço de energia: autonomia relativa (1.0 = configuração básica) e multiplicador de qualidade.
## Só para categorias com bateria. Peças gulosas + bateria pequena = produto que não aguenta o dia.
static func analysis(c: Company, cat_id: String, specs: Dictionary, design: Dictionary) -> Dictionary:
	var cat: Dictionary = GameData.category(cat_id)
	if not (cat.axes as Dictionary).has("battery"):
		return {"has_battery": false, "autonomy": 1.0, "q_mult": 1.0, "draw": 0.0}
	var scale := float((_data().draw_scale as Dictionary).get(cat_id, 1.0))
	var draw := 0.0
	var ref := 0.0
	for a in cat.axes:
		draw += float(chosen(design, str(a)).get("power", 0.0)) * scale
		ref += float(base_part(str(a)).get("power", 0.0)) * scale
	draw += 0.45 * _chip_tdp(c, cat_id, design)
	ref += 0.45 * float(GameData.chips().thermal_cap.get(cat_id, 8.0)) * 0.35
	var bat := chosen(design, "battery")
	var pts := float(specs.get("battery", _pivot(cat_id)))
	var cap := float(bat.get("cap", 1.0)) * clampf(pts / _pivot(cat_id), 0.3, 1.7)
	var autonomy := cap / maxf(draw / maxf(ref, 0.01), 0.05)
	return {"has_battery": true, "autonomy": autonomy, "q_mult": clampf(0.80 + 0.2 * autonomy, 0.80, 1.05), "draw": draw}
