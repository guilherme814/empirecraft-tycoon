class_name Tutorial
extends RefCounted
## Tutorial guiado e dicas de primeira visita. Estado em Company.tutorial / Company.tips_seen.
## Cada passo avança sozinho quando a condição é cumprida; o jogador pode pular tudo.

static func steps() -> Array:
	return GameData.tutorial().steps

static func start(c: Company) -> void:
	c.tutorial = {"on": true, "step": 0, "visited": []}

static func active(c: Company) -> bool:
	return bool(c.tutorial.get("on", false))

static func current(c: Company) -> Dictionary:
	if not active(c):
		return {}
	var i := int(c.tutorial.get("step", 0))
	var st := steps()
	return st[i] if i < st.size() else {}

static func skip(c: Company) -> void:
	c.tutorial["on"] = false

static func mark_visit(c: Company, page: String) -> void:
	var v: Array = c.tutorial.get("visited", [])
	if not v.has(page):
		v.append(page)
	c.tutorial["visited"] = v

static func _done(c: Company, id: String) -> bool:
	match id:
		"team":
			return not c.staff_of("engineer").is_empty() and not c.staff_of("programmer").is_empty()
		"product":
			return not c.products.is_empty()
		"ready":
			for p in c.products:
				if p.state == Product.STATE_READY or p.state == Product.STATE_RELEASED:
					return true
			return false
		"release":
			return not c.released_products().is_empty()
		"stock":
			return (c.tutorial.get("visited", []) as Array).has("ops")
		"research":
			var n := 0
			for k in c.research_levels:
				n += int(c.research_levels[k])
			return n > 0
		"market":
			return (c.tutorial.get("visited", []) as Array).has("market")
	return false

## Avança enquanto a condição do passo atual estiver cumprida. Devolve true se mudou algo.
static func update(c: Company) -> bool:
	if not active(c):
		return false
	var changed := false
	var st := steps()
	while int(c.tutorial.step) < st.size() and _done(c, str(st[int(c.tutorial.step)].id)):
		c.tutorial["step"] = int(c.tutorial.step) + 1
		changed = true
	if int(c.tutorial.step) >= st.size():
		c.tutorial["on"] = false
		c.add_log("Tutorial concluído! Agora é com você: expanda a empresa.", "good", "success")
		changed = true
	return changed

## Dica da primeira visita a uma aba ("" se já vista, se o tutorial está ativo ou se não há dica).
static func tip_for(c: Company, page: String) -> String:
	if active(c) or c.tips_seen.has(page):
		return ""
	return str(GameData.tutorial().tips.get(page, ""))

static func tip_seen(c: Company, page: String) -> void:
	if not c.tips_seen.has(page):
		c.tips_seen.append(page)
