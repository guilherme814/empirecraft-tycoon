class_name Decisions
extends RefCounted
## Eventos com decisão: o jogador escolhe entre opções com custo, risco e consequência persistente.
## Efeitos suportados: money, reputation, rp, morale (todos), lose_staff (n), mod {key,mult,days}.
## Chaves de mod: cost (custo unitário), sales (demanda), wage (folha).

const MIN_GAP_DAYS := 40
const DAILY_CHANCE := 0.06

static func defs() -> Array:
	return GameData._load("decisions")

static func def(id: String) -> Dictionary:
	for d in defs():
		if d.id == id:
			return d
	return {}

## Escala os valores em dinheiro com o porte da empresa.
static func scale(c: Company) -> float:
	return clampf(c.last_income / 60000.0, 1.0, 12.0)

static func eligible(c: Company, d: Dictionary) -> bool:
	if c.day < int(d.get("min_day", 0)):
		return false
	if c.released_products().size() < int(d.get("need_products", 0)):
		return false
	if c.staff.size() < int(d.get("need_staff", 0)):
		return false
	return true

## Chamado todo dia: abre uma decisão ocasionalmente (no máximo uma pendente).
static func maybe_trigger(c: Company) -> void:
	if not c.pending_decision.is_empty() or c.tutorial.get("on", false) or c.day < 45:
		return
	if c.day - c.last_decision_day < MIN_GAP_DAYS:
		return
	if c.rng.randf() >= DAILY_CHANCE:
		return
	var pool: Array = defs().filter(func(d): return eligible(c, d))
	# não repete a mesma decisão duas vezes seguidas
	var last := "" if c.decision_log.is_empty() else str((c.decision_log[-1] as Dictionary).id)
	var pool2: Array = pool.filter(func(d): return str(d.id) != last)
	if not pool2.is_empty():
		pool = pool2
	if pool.is_empty():
		return
	var total := 0.0
	for d in pool:
		total += float(d.weight)
	var roll := c.rng.randf() * total
	var picked: Dictionary = pool[0]
	for d in pool:
		roll -= float(d.weight)
		if roll <= 0.0:
			picked = d
			break
	open(c, str(picked.id))

static func open(c: Company, id: String) -> void:
	c.pending_decision = {"id": id, "day": c.day}
	c.last_decision_day = c.day
	c.add_log("Decisão necessária: %s" % str(def(id).get("title", id)), "info", "event_bad")

## Texto automático do que a opção faz (evita descrição divergente do efeito real).
static func describe(c: Company, opt: Dictionary) -> String:
	var parts: Array = []
	var eff: Dictionary = opt.get("effect", {})
	var k := scale(c)
	if eff.has("money"):
		var m := float(eff.money) * k
		parts.append(("Custa %s" % Fmt.money(-m)) if m < 0.0 else ("Recebe %s" % Fmt.money(m)))
	if eff.has("reputation"):
		parts.append("%+d reputação" % int(eff.reputation))
	if eff.has("rp"):
		parts.append("%+d PP" % int(eff.rp))
	if eff.has("morale"):
		parts.append("moral da equipe %+d" % int(eff.morale))
	if eff.has("lose_staff"):
		parts.append("perde %d funcionário" % int(eff.lose_staff))
	if eff.has("mod"):
		var m: Dictionary = eff.mod
		var nm: String = {"cost": "custo de produção", "sales": "vendas", "wage": "folha"}.get(str(m.key), str(m.key))
		parts.append("%s %+d%% por %d dias" % [nm, int(round((float(m.mult) - 1.0) * 100.0)), int(m.days)])
	if parts.is_empty():
		parts.append("Sem custo e sem efeito")
	var s := " · ".join(parts)
	if opt.has("risk"):
		s += "\nRisco de %d%%: %s" % [int(float(opt.risk.chance) * 100.0), str(opt.risk.text)]
	return s

static func affordable(c: Company, opt: Dictionary) -> bool:
	var eff: Dictionary = opt.get("effect", {})
	if eff.has("money") and float(eff.money) < 0.0 and not c.sandbox:
		return c.money >= -float(eff.money) * scale(c)
	return true

static func _apply(c: Company, eff: Dictionary) -> void:
	var k := scale(c)
	if eff.has("money"):
		var m := float(eff.money) * k
		if m >= 0.0:
			c._income(m, "events")
		else:
			c._expense(-m, "events")
	if eff.has("reputation"):
		c.reputation = clampf(c.reputation + float(eff.reputation), 0.0, 100.0)
	if eff.has("rp"):
		c.research_points += float(eff.rp)
	if eff.has("morale"):
		for e in c.staff:
			e.morale = clampf(e.morale + float(eff.morale), 0.0, 100.0)
	if eff.has("lose_staff"):
		for i in int(eff.lose_staff):
			if c.staff.size() > 1:
				var best: Employee = c.staff[0]
				for e in c.staff:
					if e.total() > best.total():
						best = e
				c.add_log("%s deixou a empresa." % best.emp_name, "bad")
				c.staff.erase(best)
	if eff.has("mod"):
		var m: Dictionary = eff.mod
		c.mods.append({"key": str(m.key), "mult": float(m.mult), "until": c.day + int(m.days), "src": str(c.pending_decision.get("id", ""))})

## Resolve a decisão pendente com a opção idx. Devolve {ok,msg,risk_hit}.
static func resolve(c: Company, idx: int) -> Dictionary:
	if c.pending_decision.is_empty():
		return {"ok": false, "msg": "Nenhuma decisão pendente"}
	var d := def(str(c.pending_decision.id))
	var opts: Array = d.get("options", [])
	if idx < 0 or idx >= opts.size():
		return {"ok": false, "msg": "Opção inválida"}
	var opt: Dictionary = opts[idx]
	if not affordable(c, opt):
		return {"ok": false, "msg": "Caixa insuficiente"}
	_apply(c, opt.get("effect", {}))
	var hit := false
	var msg := "Você escolheu: %s." % str(opt.label)
	if opt.has("risk") and c.rng.randf() < float(opt.risk.chance):
		hit = true
		_apply(c, opt.risk.effect)
		msg += " " + str(opt.risk.text)
	c.decision_log.append({"id": str(d.id), "title": str(d.title), "day": c.day, "choice": str(opt.label), "risk": hit})
	if c.decision_log.size() > 40:
		c.decision_log.pop_front()
	c.pending_decision = {}
	c.add_log("%s — %s" % [str(d.title), msg], "bad" if hit else "info")
	return {"ok": true, "msg": msg, "risk_hit": hit}
