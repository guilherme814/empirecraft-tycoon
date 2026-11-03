class_name Look
extends RefCounted
## Aparência de um funcionário, derivada de forma determinística de id + nome + profissão
## (nenhum campo novo no save). Usada pelo retrato 2D e pelo boneco 3D, para serem a mesma pessoa.

const SKIN := [Color("f6d5b8"), Color("eebf94"), Color("d9a574"), Color("b27c52"), Color("8d5a3a"), Color("5f3d29")]
const HAIR := [Color("2b2118"), Color("5a3b22"), Color("c79a54"), Color("1c1c24"), Color("8a3b2a"), Color("8e8e96"), Color("e0c27a")]
const EYES := [Color("3a2a1c"), Color("2f4f7a"), Color("2f6b4a"), Color("5a3b22")]
const STYLES := 7        # 0 curto, 1 raspado, 2 longo, 3 coque, 4 cacheado, 5 topete, 6 careca
const STYLE_NAMES := ["curto", "raspado", "longo", "coque", "cacheado", "topete", "careca"]

static func _h(id: int, nm: String) -> int:
	return absi(hash("%d|%s" % [id, nm]))

## Devolve {skin_i, hair_i, style, beard, glasses, eye_i, dye, freckles}.
static func of(id: int, nm: String, prof: String) -> Dictionary:
	var h := _h(id, nm)
	var style := (h / 7) % STYLES
	var beard := 0
	var b_roll := (h / 53) % 10
	if style != 2 and style != 3 and b_roll < 3:
		beard = 1 + (h / 531) % 3            # 1 barba rala · 2 cheia · 3 bigode
	var glasses := false
	match prof:
		"programmer", "researcher":
			glasses = true
		_:
			glasses = (h / 17) % 4 == 0
	var hair_i := (h / 11) % HAIR.size()
	if style == 6:
		beard = maxi(beard, 2)
	return {
		"skin_i": h % SKIN.size(),
		"hair_i": hair_i,
		"style": style,
		"beard": beard,
		"glasses": glasses,
		"eye_i": (h / 89) % EYES.size(),
		"dye": prof == "designer" and (h / 5) % 2 == 0,      # designer: cabelo tingido
		"freckles": (h / 97) % 6 == 0,
	}

## Chave curta para cache de malhas.
static func key(lk: Dictionary) -> String:
	return "%d.%d.%d.%d.%d.%d" % [int(lk.skin_i), int(lk.hair_i), int(lk.style), int(lk.beard),
		1 if bool(lk.glasses) else 0, 1 if bool(lk.dye) else 0]

## Faixa de experiência pela soma de atributos (0..3): borda do retrato.
static func tier(total: int) -> int:
	if total >= 270:
		return 3
	if total >= 190:
		return 2
	if total >= 120:
		return 1
	return 0

const TIER_NAMES := ["Júnior", "Pleno", "Sênior", "Mestre"]
