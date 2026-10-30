class_name OfficeLayout
extends RefCounted
## Planta automática do escritório. Pura (sem nós): recebe quantos funcionários há em cada profissão
## e devolve baias, assentos, pontos de pausa/conversa e as rotas entre eles. O jogador não edita nada.
## Medidas em metros do cenário. O fundo do escritório fica em x=0 e z=0 (paredes); a frente é aberta.

const COL_W := 2.6      # largura de cada coluna de baias
const ROW_H := 3.4      # profundidade de cada fileira
const OX := 1.4         # margem até a primeira pista vertical
const OZ := 1.1         # margem do fundo até a primeira pista horizontal
const STRIP := 3.9      # faixa de áreas comuns na frente
const SEAT_Z := 1.05    # distância da cadeira ao centro da baia
const MAX_VISIBLE := 48
const MIN_COLS := 3
const MAX_COLS := 6
const WALL_H := 2.1

var order: Array = []
var counts: Dictionary = {}           # visíveis por profissão
var stage: int = 0
var cols: int = 3
var rows: int = 1
var width: float = 0.0
var depth: float = 0.0
var front_lane: float = 0.0
var pods: Array = []                  # {i,row,col,cx,cz,prof}
var seats: Array = []                 # {i,pod,prof,pos,yaw,lane_z,lane_x}
var seats_by_prof: Dictionary = {}    # prof -> [índices em seats]
var spots: Array = []                 # {id,kind,tag,pos,yaw,sit,lane_z,pair}
var slots: Array = []                 # tipo de cada área da faixa da frente
var door: Dictionary = {}

## Fase visual pela equipe e pelo maior nível de escritório (0 início, 3 grande empresa).
static func stage_for(total: int, max_level: int) -> int:
	var s := 0
	if total >= 26:
		s = 3
	elif total >= 14:
		s = 2
	elif total >= 6:
		s = 1
	return maxi(s, clampi(max_level - 2, 0, 3))

## Reduz a equipe visível ao limite, tirando de quem tem mais gente.
static func limit_counts(raw: Dictionary, prof_order: Array, limit: int) -> Dictionary:
	var out := {}
	var total := 0
	for p in prof_order:
		out[p] = maxi(0, int(raw.get(p, 0)))
		total += int(out[p])
	while total > limit:
		var big := ""
		for p in prof_order:
			if big == "" or int(out[p]) > int(out[big]):
				big = p
		out[big] = int(out[big]) - 1
		total -= 1
	return out

static func face(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(-d.x, -d.z)

static func build(raw_counts: Dictionary, prof_order: Array, stage_in: int, limit: int = MAX_VISIBLE) -> OfficeLayout:
	var L := OfficeLayout.new()
	L.order = prof_order.duplicate()
	L.counts = limit_counts(raw_counts, prof_order, limit)
	L.stage = clampi(stage_in, 0, 3)
	var pods_n := 0
	for p in prof_order:
		pods_n += (int(L.counts[p]) + 1) / 2
	pods_n = maxi(pods_n, 2)
	var min_cols := MIN_COLS
	if L.stage >= 3:
		min_cols = 5
	elif L.stage >= 2:
		min_cols = 4
	L.cols = clampi(int(ceil(sqrt(float(pods_n) * 1.4))), min_cols, MAX_COLS)
	L.rows = maxi(1, int(ceil(float(pods_n) / float(L.cols))))
	L.width = 2.0 * OX + float(L.cols) * COL_W
	L.front_lane = OZ + float(L.rows) * ROW_H
	L.depth = L.front_lane + STRIP

	# baias: uma fileira após a outra, agrupadas por profissão
	var kinds: Array = []
	for p in prof_order:
		for k in (int(L.counts[p]) + 1) / 2:
			kinds.append(p)
	while kinds.size() < pods_n:
		kinds.append("")
	for i in pods_n:
		var row := i / L.cols
		var col := i % L.cols
		var cx := OX + (float(col) + 0.5) * COL_W
		var cz := OZ + (float(row) + 0.5) * ROW_H
		L.pods.append({"i": i, "row": row, "col": col, "cx": cx, "cz": cz, "prof": kinds[i]})
		for si in 2:
			var side := 1.0 if si == 0 else -1.0
			var seat := {
				"i": L.seats.size(), "pod": i, "prof": kinds[i],
				"pos": Vector3(cx, 0.0, cz + side * SEAT_Z),
				"yaw": 0.0 if si == 0 else PI,
				"lane_z": OZ + float(row + (1 if si == 0 else 0)) * ROW_H,
				"lane_x": OX + float(col + (1 if si == 0 else 0)) * COL_W,
			}
			if kinds[i] != "":
				if not L.seats_by_prof.has(kinds[i]):
					L.seats_by_prof[kinds[i]] = []
				(L.seats_by_prof[kinds[i]] as Array).append(seat.i)
			L.seats.append(seat)

	# áreas comuns na frente
	var base: Array = ["lounge", "pantry", "chat"]
	if L.stage >= 3:
		base = ["lounge", "pantry", "meeting", "chat", "reception", "chat"]
	elif L.stage >= 2:
		base = ["lounge", "pantry", "meeting", "chat"]
	for k in L.cols:
		L.slots.append(base[k] if k < base.size() else "chat")
	var fl := L.front_lane
	for k in L.cols:
		var cx := OX + (float(k) + 0.5) * COL_W
		match str(L.slots[k]):
			"lounge":
				L._spot("sofa", Vector3(cx - 0.65, 0, fl + 2.5), 0.0, true, fl, -1)
				L._spot("sofa", Vector3(cx + 0.65, 0, fl + 2.5), 0.0, true, fl, -1)
			"pantry":
				L._spot("cooler", Vector3(cx - 0.55, 0, fl + 0.85), PI, false, fl, -1)
				L._spot("coffee", Vector3(cx + 0.55, 0, fl + 0.85), PI, false, fl, -1)
			"chat":
				for zoff in [0.9, 2.0]:
					var a := Vector3(cx - 0.42, 0, fl + zoff)
					var b := Vector3(cx + 0.42, 0, fl + zoff)
					var ia := L._spot("chat", a, face(a, b), false, fl, -1)
					var ib := L._spot("chat", b, face(b, a), false, fl, ia)
					L.spots[ia].pair = ib
	L.door = {"pos": Vector3(OX, 0.0, L.depth + 1.6), "yaw": 0.0, "sit": false, "lane_z": fl, "kind": "door"}
	return L

func _spot(tag: String, pos: Vector3, yaw: float, sit: bool, lane_z: float, pair: int) -> int:
	var id := spots.size()
	spots.append({"id": id, "kind": "chat" if tag == "chat" else "break", "tag": tag, "pos": pos, "yaw": yaw,
		"sit": sit, "lane_z": lane_z, "pair": pair})
	return id

func slot_center_x(k: int) -> float:
	return OX + (float(k) + 0.5) * COL_W

func seat_index(prof: String, n: int) -> int:
	var arr: Array = seats_by_prof.get(prof, [])
	return int(arr[n]) if n >= 0 and n < arr.size() else -1

static func _dedupe(pts: Array) -> Array:
	var out: Array = []
	for p in pts:
		if out.is_empty() or (out[out.size() - 1] as Vector3).distance_to(p) > 0.01:
			out.append(p)
	return out

## Caminho do assento até um ponto (só segmentos retos ao longo das pistas livres).
static func route_seat_to(seat: Dictionary, spot: Dictionary) -> Array:
	var sp: Vector3 = seat.pos
	var side_x: float = sp.x + (0.5 if float(seat.lane_x) > sp.x else -0.5)
	var sl: float = seat.lane_z
	var lx: float = seat.lane_x
	var tl: float = spot.lane_z
	var tp: Vector3 = spot.pos
	return _dedupe([sp, Vector3(side_x, 0, sp.z), Vector3(side_x, 0, sl), Vector3(lx, 0, sl),
		Vector3(lx, 0, tl), Vector3(tp.x, 0, tl), tp])

static func route_spot_to_seat(spot: Dictionary, seat: Dictionary) -> Array:
	var r := route_seat_to(seat, spot)
	r.reverse()
	return r
