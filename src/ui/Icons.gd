class_name Icons
extends RefCounted
## Ícones SVG em assets/icons (gerados por tools/gen_icons.py). Traço branco: tinja com modulate/cor.

static var _cache: Dictionary = {}

static func tex(icon_name: String) -> Texture2D:
	if _cache.has(icon_name):
		return _cache[icon_name]
	var t: Texture2D = null
	var path := "res://assets/icons/%s.svg" % icon_name
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	_cache[icon_name] = t
	return t
