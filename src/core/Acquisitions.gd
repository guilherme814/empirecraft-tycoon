class_name Acquisitions
extends RefCounted
## Compra de empresas: rivais do mercado (viram subsidiárias que repassam lucro) e startups
## que aparecem por um tempo (dão vantagens permanentes). Preço vem do valor da empresa.

const COOLDOWN_DAYS := 45
const MAX_RIVALS := 3
const OFFER_LIFE := 180
const MAX_OFFERS := 4
const SHARE_OF_REV := 0.15      # parte da receita da subsidiária que vira lucro do grupo
const FAR := 36500

static func _data() -> Dictionary:
	return GameData._load("acquisitions")

static func type_def(id: String) -> Dictionary:
	for t in _data().types:
		if t.id == id:
			return t
	return {}

static func owned_rivals(c: Company) -> Array:
	return c.acquired.filter(func(a): return str(a.kind) == "rival")

static func owns(c: Company, name: String) -> bool:
	for a in c.acquired:
		if str(a.name) == name:
			return true
	return false

static func has_unlock(c: Company, key: String) -> bool:
	for a in c.acquired:
		if str(a.get("unlock", "")) == key:
			return true
	return false

## Preço de um rival: valor + prêmio de controle; rivalidade e guerra de preços encarecem.
static func rival_price(c: Company, r: Dictionary) -> float:
	var prem := 1.3 + float(r.get("rivalry", 0.0)) / 250.0
	if int(r.get("war_until", 0)) > c.day:
		prem += 0.1
	return roundf(float(r.value) * prem)

## Alvos à venda: rivais livres e ofertas de startups.
static func targets(c: Company) -> Array:
	var out: Array = []
	for r in c.market.rivals:
		if bool(r.get("owned", false)):
			continue
		out.append({"kind": "rival", "id": str(r.name), "name": str(r.name), "price": rival_price(c, r),
			"desc": str(r.get("desc", "")), "value": float(r.value), "tech": float(r.tech)})
	for o in c.acq_offers:
		var t := type_def(str(o.type))
		out.append({"kind": "startup", "id": str(o.id), "name": str(o.name), "price": float(o.price),
			"desc": str(t.get("desc", "")), "type": str(o.type), "expires": int(o.expires), "icon": str(t.get("icon", "nav_ops"))})
	return out

static func find(c: Company, kind: String, id: String) -> Dictionary:
	for t in targets(c):
		if str(t.kind) == kind and str(t.id) == id:
			return t
	return {}

static func blocker(c: Company, kind: String, id: String) -> String:
	var t := find(c, kind, id)
	if t.is_empty():
		return "Empresa indisponível"
	if c.day - c.last_acq < COOLDOWN_DAYS and c.last_acq >= 0:
		return "Aguarde %d dias para a próxima compra" % (COOLDOWN_DAYS - (c.day - c.last_acq))
	if kind == "rival" and owned_rivals(c).size() >= MAX_RIVALS:
		return "O regulador barra mais de %d compras de concorrentes" % MAX_RIVALS
	if c.money < float(t.price):
		return "Dinheiro insuficiente"
	return ""

static func buy(c: Company, kind: String, id: String) -> Dictionary:
	var why := blocker(c, kind, id)
	if why != "":
		return c._fail(why)
	var t := find(c, kind, id)
	var price: float = float(t.price)
	c._cash_out(price, "acquisitions")
	c._expense(roundf(price * 0.04), "integration")   # advogados, demissões e migração de sistemas
	c.last_acq = c.day
	var rec := {"kind": kind, "name": str(t.name), "day": c.day, "price": price, "unlock": ""}
	var msg := ""
	if kind == "rival":
		msg = _absorb_rival(c, str(t.name), rec)
	else:
		msg = _absorb_startup(c, str(t.id), rec)
	c.acquired.append(rec)
	c.stocks.update_value(c)
	c.add_log(msg, "good", "acquisition")
	return c._ok(msg)

static func _absorb_rival(c: Company, name: String, rec: Dictionary) -> String:
	var i := c.market.rival_index(name)
	var r: Dictionary = c.market.rivals[i]
	r["owned"] = true
	r["owned_day"] = c.day
	r["shock"] = 0.0
	# ações que o jogador tinha viram dinheiro ao preço de mercado
	var n := c.stocks.holding(name)
	if n > 0:
		c._cash_in(float(n) * float(r.price), "stocks")
		c.stocks.holdings.erase(name)
	var rp: float = roundf(60.0 * float(r.tech))
	c.research_points += rp
	c.reputation = minf(100.0, c.reputation + 3.0)
	_add_perk(c, "cost", 0.99, name)
	_add_perk(c, "sales", 1.01, name)
	rec["rp_month"] = roundf(3.0 * float(r.tech))
	return "Você comprou a %s! Ela segue como subsidiária e repassa parte do lucro (+%d pontos de pesquisa)." % [name, int(rp)]

static func _absorb_startup(c: Company, id: String, rec: Dictionary) -> String:
	var offer: Dictionary = {}
	for o in c.acq_offers:
		if str(o.id) == id:
			offer = o
	var t := type_def(str(offer.type))
	var perk: Dictionary = t.perk
	if perk.has("rp_once"):
		c.research_points += float(perk.rp_once)
	if perk.has("rep"):
		c.reputation = minf(100.0, c.reputation + float(perk.rep))
	if perk.has("sales"):
		_add_perk(c, "sales", float(perk.sales), str(offer.name))
	if perk.has("cost"):
		_add_perk(c, "cost", float(perk.cost), str(offer.name))
	rec["unlock"] = str(perk.get("unlock", ""))
	rec["type"] = str(offer.type)
	rec["rp_month"] = float(perk.get("rp_month", 0.0))
	c.acq_offers.erase(offer)
	return "Você comprou a %s (%s). %s" % [offer.name, str(t.name).to_lower(), str(t.desc)]

static func _add_perk(c: Company, key: String, mult: float, src: String) -> void:
	c.mods.append({"key": key, "mult": mult, "until": c.day + FAR, "src": "acq:" + src})

## Valor das empresas do grupo (entra no valor da sua empresa na bolsa).
static func group_value(c: Company) -> float:
	var v := 0.0
	for a in c.acquired:
		if str(a.kind) == "rival":
			var i := c.market.rival_index(str(a.name))
			v += 0.6 * (float(c.market.rivals[i].value) if i >= 0 else float(a.price))
		else:
			v += 0.7 * float(a.price)
	return v

## Fim do mês (antes do fechamento do ledger): lucro das subsidiárias e pesquisa das compradas.
static func monthly(c: Company) -> void:
	var share := 0.0
	for a in c.acquired:
		c.research_points += float(a.get("rp_month", 0.0))
		if str(a.kind) == "rival":
			var i := c.market.rival_index(str(a.name))
			if i >= 0:
				share += float(c.market.rivals[i].get("rev_last", 0.0)) * SHARE_OF_REV
	if share > 0.0:
		c._income(share, "subsidiaries")
	# ofertas vencidas saem; novas surgem
	c.acq_offers = c.acq_offers.filter(func(o): return int(o.expires) > c.day)
	if c.acq_offers.size() < MAX_OFFERS and c.rng.randf() < 0.55:
		_new_offer(c)

static func _new_offer(c: Company) -> void:
	var d := _data()
	var types: Array = d.types
	var t: Dictionary = types[c.rng.randi() % types.size()]
	for o in c.acq_offers:
		if str(o.type) == str(t.id):
			return
	if str(t.id) == "materials" and has_unlock(c, "acq:materials"):
		return
	var nm := "%s %s" % [d.prefix[c.rng.randi() % d.prefix.size()], d.suffix[c.rng.randi() % d.suffix.size()]]
	if owns(c, nm):
		return
	c.acq_offers.append({"id": "s%d_%d" % [c.day, c.rng.randi() % 1000], "type": str(t.id), "name": nm,
		"price": roundf(float(t.base) * Decisions.scale(c) * c.rng.randf_range(0.85, 1.2)), "expires": c.day + OFFER_LIFE})
