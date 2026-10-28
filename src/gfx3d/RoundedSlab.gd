class_name RoundedSlab
extends RefCounted
## Gera uma placa de cantos arredondados no plano XY (espessura em Z, centrada) com chanfro.
## É a peça básica de telefones, notebooks, relógios e consoles.

## Contorno (sentido anti-horário visto de +Z): devolve [pontos, normais 2D].
static func outline(w: float, h: float, r: float, seg: int) -> Array:
	var pts := PackedVector2Array()
	var nrm := PackedVector2Array()
	r = minf(r, minf(w, h) * 0.5 - 0.0001)
	var hw := w * 0.5 - r
	var hh := h * 0.5 - r
	var centers := [Vector2(hw, hh), Vector2(-hw, hh), Vector2(-hw, -hh), Vector2(hw, -hh)]
	for c in 4:
		for i in seg + 1:
			var a := deg_to_rad(90.0 * float(c) + 90.0 * float(i) / float(seg))
			var n := Vector2(cos(a), sin(a))
			pts.append((centers[c] as Vector2) + n * r)
			nrm.append(n)
	return [pts, nrm]

static func build(w: float, h: float, t: float, r: float, chamfer: float = 0.01, seg: int = 6) -> ArrayMesh:
	var o := outline(w, h, r, seg)
	var pts: PackedVector2Array = o[0]
	var nrm: PackedVector2Array = o[1]
	var n := pts.size()
	var hz := t * 0.5
	var c := minf(chamfer, hz * 0.9)
	# 4 anéis ao longo da espessura: [inset, z, componente z da normal da faixa seguinte]
	var rings := [[c, -hz], [0.0, -hz + c], [0.0, hz - c], [c, hz]]
	var band_nz := [-1.0, 0.0, 1.0]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in 3:
		var r0: Array = rings[b]
		var r1: Array = rings[b + 1]
		for k in n:
			var k2 := (k + 1) % n
			var va := Vector3(pts[k].x - nrm[k].x * float(r0[0]), pts[k].y - nrm[k].y * float(r0[0]), float(r0[1]))
			var vb := Vector3(pts[k2].x - nrm[k2].x * float(r0[0]), pts[k2].y - nrm[k2].y * float(r0[0]), float(r0[1]))
			var vc := Vector3(pts[k2].x - nrm[k2].x * float(r1[0]), pts[k2].y - nrm[k2].y * float(r1[0]), float(r1[1]))
			var vd := Vector3(pts[k].x - nrm[k].x * float(r1[0]), pts[k].y - nrm[k].y * float(r1[0]), float(r1[1]))
			var na := Vector3(nrm[k].x, nrm[k].y, float(band_nz[b])).normalized()
			var nb := Vector3(nrm[k2].x, nrm[k2].y, float(band_nz[b])).normalized()
			# Godot: face frontal = sentido horário visto de fora
			_tri(st, va, vc, vb, na, nb, nb)
			_tri(st, va, vd, vc, na, na, nb)
	# tampas (leque a partir do centro)
	for k in n:
		var k2 := (k + 1) % n
		var pa := Vector3(pts[k].x - nrm[k].x * c, pts[k].y - nrm[k].y * c, -hz)
		var pb := Vector3(pts[k2].x - nrm[k2].x * c, pts[k2].y - nrm[k2].y * c, -hz)
		_tri(st, Vector3(0, 0, -hz), pa, pb, Vector3.BACK * -1.0, Vector3.BACK * -1.0, Vector3.BACK * -1.0, w, h)
		var ta := Vector3(pa.x, pa.y, hz)
		var tb := Vector3(pb.x, pb.y, hz)
		_tri(st, Vector3(0, 0, hz), tb, ta, Vector3.BACK, Vector3.BACK, Vector3.BACK, w, h)
	return st.commit()

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3,
		w: float = 1.0, h: float = 1.0) -> void:
	for pair in [[a, na], [b, nb], [c, nc]]:
		var v: Vector3 = pair[0]
		st.set_normal(pair[1])
		st.set_uv(Vector2(v.x / w + 0.5, 0.5 - v.y / h))
		st.add_vertex(v)
