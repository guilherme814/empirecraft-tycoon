class_name Identity
extends RefCounted
## Identidade visual da empresa (logotipo) e catálogo de decoração do escritório.
## Tudo vem de data/identity.json; combinações controladas, sem editor livre.

static func default_logo() -> Dictionary:
	return {"symbol": "shield", "c1": "ff9a2e", "c2": "1b2036", "style": "caps"}

static func default_decor() -> Dictionary:
	return {"desk": "white", "chair": "common", "pc": "single", "light": "warm", "deco": "plants"}

static func _ids(arr: Array) -> Array:
	var out: Array = []
	for x in arr:
		out.append(str(x.id))
	return out

static func clean_logo(d: Dictionary) -> Dictionary:
	var out := default_logo()
	var cat := GameData.identity()
	if _ids(cat.symbols).has(str(d.get("symbol", ""))):
		out.symbol = str(d.symbol)
	for k in ["c1", "c2"]:
		if (cat.colors as Array).has(str(d.get(k, ""))):
			out[k] = str(d[k])
	if _ids(cat.styles).has(str(d.get("style", ""))):
		out.style = str(d.style)
	return out

static func clean_decor(d: Dictionary) -> Dictionary:
	var out := default_decor()
	for g in GameData.identity().decor:
		var opts := _ids(g.options)
		if opts.has(str(d.get(g.group, ""))):
			out[str(g.group)] = str(d[g.group])
	return out

static func option_cost(group: String, id: String) -> float:
	for g in GameData.identity().decor:
		if g.group == group:
			for o in g.options:
				if o.id == id:
					return float(o.cost)
	return 0.0

static func change_cost(old_logo: Dictionary, new_logo: Dictionary, old_decor: Dictionary, new_decor: Dictionary) -> float:
	var t := 0.0
	if old_logo != new_logo:
		t += float(GameData.identity().logo_fee)
	for g in GameData.identity().decor:
		var k: String = g.group
		if str(old_decor.get(k, "")) != str(new_decor.get(k, "")):
			t += option_cost(k, str(new_decor.get(k, "")))
	return t

static func color(hex: String) -> Color:
	return Color(hex)

## Contorno do símbolo em coordenadas -1..1 (y para baixo).
static func points(symbol: String) -> PackedVector2Array:
	match symbol:
		"shield":
			return PackedVector2Array([Vector2(-0.8, -0.85), Vector2(0.8, -0.85), Vector2(0.8, 0.05), Vector2(0, 0.95), Vector2(-0.8, 0.05)])
		"hexagon":
			return _ngon(6, 0.95, -PI / 2.0)
		"diamond":
			return PackedVector2Array([Vector2(0, -1), Vector2(0.8, 0), Vector2(0, 1), Vector2(-0.8, 0)])
		"circle":
			return _ngon(20, 0.95, 0.0)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var r := 0.98 if i % 2 == 0 else 0.42
				var a := -PI / 2.0 + TAU * float(i) / 10.0
				pts.append(Vector2(cos(a) * r, sin(a) * r))
			return pts
		"bolt":
			return PackedVector2Array([Vector2(0.2, -1), Vector2(-0.6, 0.15), Vector2(-0.05, 0.15), Vector2(-0.25, 1), Vector2(0.6, -0.2), Vector2(0.05, -0.2)])
		"triangle":
			return PackedVector2Array([Vector2(0, -0.95), Vector2(0.95, 0.8), Vector2(-0.95, 0.8)])
		"crown":
			return PackedVector2Array([Vector2(-0.9, 0.7), Vector2(-0.9, -0.5), Vector2(-0.45, 0.0), Vector2(0, -0.8), Vector2(0.45, 0.0), Vector2(0.9, -0.5), Vector2(0.9, 0.7)])
	return _ngon(6, 0.95, -PI / 2.0)

static func _ngon(n: int, r: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := rot + TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	return pts

## Nome conforme o estilo tipográfico.
static func format_name(name: String, style: String) -> String:
	match style:
		"caps": return name.to_upper()
		"lower": return name.to_lower()
		"wide":
			var out := ""
			for ch in name.to_upper():
				out += str(ch) + "\u2009"
			return out.strip_edges()
		_: return name
