class_name GlassPanel
extends PanelContainer
## Cartão com acabamento "vidro": brilho suave no topo, sombra embaixo e filete de luz na borda.
## O brilho é uma textura 9-slice gerada uma vez (cantos arredondados nítidos em qualquer tamanho).

static var _tex: ImageTexture = null
static var _sb: StyleBoxTexture = null

static func _overlay() -> StyleBoxTexture:
	if _sb != null:
		return _sb
	var n := 64
	var rad := 18.0
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var dx := maxf(rad - float(x), float(x) - (float(n) - 1.0 - rad))
			var dy := maxf(rad - float(y), float(y) - (float(n) - 1.0 - rad))
			var dist := Vector2(maxf(dx, 0.0), maxf(dy, 0.0)).length()
			var inside := clampf(rad - dist + 0.5, 0.0, 1.0)
			var col := Color(1, 1, 1, 0)
			if y < 26:
				col.a = 0.075 * (1.0 - float(y) / 26.0)
			elif y > 40:
				col = Color(0, 0, 0, 0.16 * (float(y) - 40.0) / 24.0)
			# filete de luz na borda (mais forte no alto)
			var edge := clampf(1.0 - absf(dist - rad + 1.0) / 1.4, 0.0, 1.0) if dist > rad - 2.5 else 0.0
			if edge > 0.0:
				var k := 0.22 * (1.0 - float(y) / float(n - 1)) + 0.04
				col = Color(1, 1, 1, maxf(col.a, edge * k))
			col.a *= inside
			img.set_pixel(x, y, col)
	_tex = ImageTexture.create_from_image(img)
	_sb = StyleBoxTexture.new()
	_sb.texture = _tex
	_sb.set_texture_margin_all(24.0)
	return _sb

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

func _draw() -> void:
	if Saves.gfx == "eco":
		return
	draw_style_box(_overlay(), Rect2(Vector2.ZERO, size))
