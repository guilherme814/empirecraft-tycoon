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
var design: Dictionary = {}      # {shape, finish, color}
var os_id: String = "droidix"    # sistema operacional ("own" = sistema próprio)
var mfr: String = "fabrix"      # fabricante ("own" = fábrica própria)

# Novos blocos de produto
var hardware: Dictionary = {
	"cpu": "mid",
	"ram": 8,
	"storage": 128,
	"battery": 4000,
	"display": 6.1,
	"camera": 48,
	"chassis": "aluminum",
	"thermal": "balanced"
}
var software: Dictionary = {
	"os": "light",
	"ui": "minimal",
	"ai": "assistant",
	"security": "basic",
	"sync": "cloud"
}
var customization: Dictionary = {
	"shell": "classic",
	"accent": "graphite",
	"packaging": "standard",
	"accessories": []
}
var feedback: Array = []          # {day, source, sentiment, issue, priority}
var tests: Array = []             # {day, type, objective, score, status}
var market_fit: float = 0.5
var test_score: float = 0.0

func progress() -> float:
	return clampf(work_done / maxf(work_required, 1.0), 0.0, 1.0)

func profit_total() -> float:
	return revenue_total - cost_total - dev_cost

func hardware_score() -> float:
	var score := 0.0
	score += float(hardware.get("ram", 8)) / 32.0
	score += float(hardware.get("storage", 128)) / 512.0
	score += float(hardware.get("battery", 4000)) / 8000.0
	score += float(hardware.get("display", 6.1)) / 8.0
	score += float(hardware.get("camera", 48)) / 100.0
	return clampf(score / 5.0, 0.0, 1.0)

func software_score() -> float:
	var score := 0.0
	score += 0.22 if str(software.get("os", "light")) == "light" else 0.18
	score += 0.18 if str(software.get("ui", "minimal")) == "minimal" else 0.12
	score += 0.20 if str(software.get("ai", "assistant")) == "assistant" else 0.10
	score += 0.18 if str(software.get("security", "basic")) == "basic" else 0.14
	score += 0.22 if str(software.get("sync", "cloud")) == "cloud" else 0.12
	return clampf(score, 0.0, 1.0)

func personalization_score() -> float:
	var score := 0.0
	if str(customization.get("shell", "classic")) != "":
		score += 0.25
	if str(customization.get("accent", "graphite")) != "":
		score += 0.25
	if str(customization.get("packaging", "standard")) != "":
		score += 0.2
	score += clampf(float(customization.get("accessories", []).size()) / 4.0, 0.0, 0.3)
	return clampf(score, 0.0, 1.0)

func apply_hardware_variant(data: Dictionary) -> Dictionary:
	for key in data:
		hardware[key] = data[key]
	return hardware

func apply_software_variant(data: Dictionary) -> Dictionary:
	for key in data:
		software[key] = data[key]
	return software

func apply_customization(profile: Dictionary) -> Dictionary:
	for key in profile:
		customization[key] = profile[key]
	market_fit = clampf((hardware_score() + software_score() + personalization_score()) / 3.0, 0.0, 1.0)
	return customization

func add_feedback(entry: Dictionary) -> void:
	feedback.append(entry)
	if feedback.size() > Rules.MAX_FEEDBACK_MEMORY:
		feedback.pop_front()
	var avg_s := 0.0
	for f in feedback:
		avg_s += float(f.get("sentiment", 0.0))
	if not feedback.is_empty():
		market_fit = clampf((avg_s / float(feedback.size())) * 0.5 + market_fit * 0.5, 0.0, 1.0)

func run_test(test_type: String = "field") -> Dictionary:
	var base := (hardware_score() + software_score() + personalization_score()) / 3.0
	var volatility := 0.12 if str(test_type) == "beta" else 0.09 if str(test_type) == "usability" else 0.08
	var score := clampf(base + rngf_range(-volatility, volatility), 0.0, 1.0)
	var result := {
		"day": 0,
		"type": test_type,
		"objective": "qualidade e experiência",
		"score": score,
		"status": "complete"
	}
	tests.append(result)
	if tests.size() > Rules.MAX_TEST_HISTORY:
		tests.pop_front()
	test_score = score
	return result

func rngf_range(minv: float, maxv: float) -> float:
	return randf_range(minv, maxv)

func to_dict() -> Dictionary:
	return {"id": id, "name": pname, "cat": category, "specs": specs, "price": price, "unit_cost": unit_cost,
		"work_req": work_required, "work_done": work_done, "state": state, "quality": quality,
		"release": release_day, "units": units_total, "revenue": revenue_total, "cost": cost_total,
		"dev_cost": dev_cost, "carry": units_carry, "ema": ema_units,
		"design": design, "os": os_id, "mfr": mfr,
		"hardware": hardware, "software": software, "customization": customization,
		"feedback": feedback, "tests": tests, "market_fit": market_fit, "test_score": test_score}

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
	p.hardware = d.get("hardware", p.hardware).duplicate()
	p.software = d.get("software", p.software).duplicate()
	p.customization = d.get("customization", p.customization).duplicate()
	p.feedback = d.get("feedback", []).duplicate(true)
	p.tests = d.get("tests", []).duplicate(true)
	p.market_fit = float(d.get("market_fit", 0.5))
	p.test_score = float(d.get("test_score", 0.0))
	return p

