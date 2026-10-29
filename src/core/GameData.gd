class_name GameData
extends RefCounted
## Carrega as definições data-driven (res://data/*.json) com cache.

const AXIS_LABELS := {
	"performance": "Desempenho", "battery": "Bateria", "display": "Tela", "camera": "Câmera",
	"thermal": "Térmica", "storage": "Armazenamento", "sensors": "Sensores", "design": "Design",
	"graphics": "Gráficos", "audio": "Áudio",
}
const ATTR_LABELS := {"craft": "Técnica", "pace": "Ritmo", "insight": "Visão"}

static var _cache: Dictionary = {}

static func _load(file: String) -> Variant:
	if _cache.has(file):
		return _cache[file]
	var path := "res://data/%s.json" % file
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("GameData: arquivo não encontrado: " + path)
		return []
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("GameData: JSON inválido: " + path)
		return []
	_cache[file] = parsed
	return parsed

static func professions() -> Array:
	return _load("professions")

static func agencies() -> Array:
	return _load("agencies")

static func categories() -> Array:
	return _load("categories")

static func research() -> Array:
	return _load("research")

static func events() -> Array:
	return _load("events")

static func names() -> Dictionary:
	return _load("names")

static func profession(id: String) -> Dictionary:
	for p in professions():
		if p.id == id:
			return p
	return {}

static func category(id: String) -> Dictionary:
	for c in categories():
		if c.id == id:
			return c
	return {}

static func research_item(id: String) -> Dictionary:
	for r in research():
		if r.id == id:
			return r
	return {}

static func rivals() -> Array:
	return _load("rivals").list

static func designs() -> Dictionary:
	return _load("designs")

static func os_data() -> Dictionary:
	return _load("os")

static func manufacturers() -> Dictionary:
	return _load("manufacturers")

static func features(cat_id: String) -> Array:
	return _load("features").get(cat_id, [])

static func deals() -> Array:
	return _load("deals")

static func reviews() -> Dictionary:
	return _load("reviews")

static func marketing() -> Dictionary:
	return _load("marketing")

static func lab() -> Dictionary:
	return _load("lab")

static func chips() -> Dictionary:
	return _load("chips")

static func feedback() -> Dictionary:
	return _load("feedback")
