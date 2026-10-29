class_name Product
extends RefCounted

const STATE_DEV := "dev"
const STATE_READY := "ready"
const STATE_RELEASED := "released"
const STATE_RETIRED := "retired"

var id: int = 0
var pname: String = "Produto"
var category: String = "phone"
var specs: Dictionary = {}
var price: float = 0.0
var unit_cost: float = 0.0
var work_required: float = 100.0
var work_done: float = 0.0
var state: String = STATE_DEV
var quality: float = 0.0
var release_day: int = 0
var units_total: int = 0
var revenue_total: float = 0.0
var cost_total: float = 0.0     # custo de produção acumulado
var dev_cost: float = 0.0
var units_carry: float = 0.0
var ema_units: float = 0.0      # média móvel de unidades por dia
var design: Dictionary = {}     # {shape, finish, color}
var os_id: String = "droidix"   # sistema operacional ("own" = sistema próprio)
var mfr: String = "fabrix"      # fabricante ("own" = fábrica própria)
var rating: float = 0.0         # nota média dos clientes (1-5)
var rating_n: int = 0
var critic: float = 0.0         # média da crítica (0-100)
var reviews: Array = []         # últimas avaliações
var promise: float = 0.0        # vantagem prometida no lançamento (0, .10, .25, .40)
var promise_gap: float = 0.0    # quanto da promessa não foi cumprida
var awareness: float = 0.0      # consciência de marca do produto (marketing)
var flaws: Array = []           # falhas ocultas: {id, found, fixed}
var tests: Dictionary = {}      # ensaios concluídos: id -> {day, m, found}
var beta: Dictionary = {}       # resultado do teste beta
var beta_job: Dictionary = {}   # beta em andamento
var chip_id: int:
	get: return int(design.get("chip", 0))

func progress() -> float:
	return clampf(work_done / maxf(work_required, 1.0), 0.0, 1.0)

func profit_total() -> float:
	return revenue_total - cost_total - dev_cost

func to_dict() -> Dictionary:
	return {"id": id, "name": pname, "cat": category, "specs": specs, "price": price, "unit_cost": unit_cost,
		"work_req": work_required, "work_done": work_done, "state": state, "quality": quality,
		"release": release_day, "units": units_total, "revenue": revenue_total, "cost": cost_total,
		"dev_cost": dev_cost, "carry": units_carry, "ema": ema_units,
		"design": design, "os": os_id, "mfr": mfr,
		"rating": rating, "rating_n": rating_n, "critic": critic, "reviews": reviews, "promise": promise, "gap": promise_gap,
		"aw": awareness, "flaws": flaws, "tests": tests, "beta": beta, "beta_job": beta_job}

static func from_dict(d: Dictionary) -> Product:
	var p := Product.new()
	p.id = int(d.get("id", 0))
	p.pname = str(d.get("name", "Produto"))
	p.category = str(d.get("cat", "phone"))
	var sp: Dictionary = d.get("specs", {})
	for k in sp:
		p.specs[k] = int(sp[k])
	p.price = float(d.get("price", 0.0))
	p.unit_cost = float(d.get("unit_cost", 0.0))
	p.work_required = float(d.get("work_req", 100.0))
	p.work_done = float(d.get("work_done", 0.0))
	p.state = str(d.get("state", STATE_DEV))
	p.quality = float(d.get("quality", 0.0))
	p.release_day = int(d.get("release", 0))
	p.units_total = int(d.get("units", 0))
	p.revenue_total = float(d.get("revenue", 0.0))
	p.cost_total = float(d.get("cost", 0.0))
	p.dev_cost = float(d.get("dev_cost", 0.0))
	p.units_carry = float(d.get("carry", 0.0))
	p.ema_units = float(d.get("ema", 0.0))
	p.design = d.get("design", {}).duplicate()
	p.os_id = str(d.get("os", "droidix"))
	p.mfr = str(d.get("mfr", "fabrix"))
	p.rating = float(d.get("rating", 0.0))
	p.rating_n = int(d.get("rating_n", 0))
	p.critic = float(d.get("critic", 0.0))
	p.reviews = d.get("reviews", []).duplicate(true)
	p.promise = float(d.get("promise", 0.0))
	p.promise_gap = float(d.get("gap", 0.0))
	p.awareness = float(d.get("aw", 0.0))
	p.flaws = d.get("flaws", []).duplicate(true)
	p.tests = d.get("tests", {}).duplicate(true)
	p.beta = d.get("beta", {}).duplicate(true)
	p.beta_job = d.get("beta_job", {}).duplicate(true)
	return p
