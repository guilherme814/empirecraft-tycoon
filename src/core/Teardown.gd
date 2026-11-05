class_name Teardown
extends RefCounted
## Desmontagem (teardown): mostra as camadas internas do aparelho e a nota de reparabilidade.
## Aparelhos difíceis de abrir (finos, colados, materiais frágeis) custam mais nos recalls.

static func repair_score(cat_id: String, design: Dictionary) -> int:
	var s := 70.0
	s += {"slim": -15.0, "fold": -20.0, "edge": -8.0}.get(str(design.get("shape", "")), 0.0)
	s += {"glass": -10.0, "ceramic": -8.0, "titanium": -4.0, "plastic": 8.0}.get(str(design.get("finish", "")), 0.0)
	var cat: Dictionary = GameData.category(cat_id)
	for a in cat.axes:
		var pt := Components.chosen(design, str(a))
		s -= 4.0 * float(maxi(0, int(pt.get("tier", 0)) - 1))
	s -= 1.5 * float((design.get("features", []) as Array).size())
	return int(clampf(s, 5.0, 95.0))

## Multiplicador do custo de recall: de 0,7 (fácil de consertar) a 1,4 (muito difícil).
static func recall_mult(score: int) -> float:
	return clampf(1.0 + float(50 - score) / 150.0, 0.7, 1.4)

## Camadas de cima para baixo: [{label, name, tier}].
static func layers(c: Company, p: Product) -> Array:
	var out: Array = []
	var cat: Dictionary = GameData.category(p.category)
	for a in ["display", "camera", "sensors", "graphics", "audio", "thermal", "storage", "performance", "design", "battery"]:
		if cat.axes.has(a):
			var pt := Components.chosen(p.design, a)
			out.append({"label": Components.label(a), "name": str(pt.get("name", "?")), "tier": int(pt.get("tier", 0))})
	var cid := int(p.design.get("chip", 0))
	var ch := Chips.get_chip(c, cid) if cid != 0 else {}
	var chip_row := {"label": "Processador", "name": "SoC genérico" if ch.is_empty() else str(ch.name), "tier": 0 if ch.is_empty() else 3}
	out.insert(mini(2, out.size()), chip_row)
	return out
