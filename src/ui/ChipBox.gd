class_name ChipBox
extends Control
## Caixa do processador em perspectiva: faixa na cor da arquitetura, nome e especificações.
## Aparece nos chips prontos, como o produto que vai para a prateleira.

var chip: Dictionary = {}

func _init() -> void:
	custom_minimum_size = Vector2(300, 250)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_chip(ch: Dictionary) -> void:
	chip = ch
	queue_redraw()

func _poly(pts: Array, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array(pts), col)

func _draw() -> void:
	if chip.is_empty():
		return
	var rim: Color = ChipView.ARCH_RIM.get(str(chip.get("arch", "bal")), ChipView.ARCH_RIM.bal)
	var f := ThemeDB.fallback_font
	# sombra no chão
	draw_colored_polygon(PackedVector2Array([Vector2(30, 218), Vector2(250, 232), Vector2(290, 214), Vector2(100, 198)]), Color(0, 0, 0, 0.35))
	# faces: frente (esq.), lateral (dir.), topo
	var fl := Vector2(24, 70)      # frente: canto sup. esq.
	var fw := Vector2(170, 24)     # vetor largura (desce um pouco: perspectiva)
	var fh := Vector2(0, 124)      # vetor altura
	var dp := Vector2(70, -34)     # profundidade
	var p0 := fl
	var p1 := fl + fw
	var p2 := fl + fw + fh
	var p3 := fl + fh
	_poly([p1, p1 + dp, p2 + dp, p2], Color("14182a"))                         # lateral
	_poly([p0, p0 + dp, p1 + dp, p1], Color("2a3350"))                         # topo
	_poly([p0, p1, p2, p3], Color("1c2340"))                                  # frente
	# faixa colorida e brilho
	_poly([p0 + fh * 0.0, p1, p1 + fh * 0.16, p0 + fh * 0.16], rim.darkened(0.15))
	_poly([p1, p1 + dp, p1 + dp + fh * 0.16, p1 + fh * 0.16], rim.darkened(0.45))
	_poly([p0, p0 + dp, p1 + dp, p1], Color(1, 1, 1, 0.05))
	# janela com o chip
	var win0 := fl + fw * 0.12 + fh * 0.30
	var win_w := fw * 0.76
	var win_h := fh * 0.42
	_poly([win0, win0 + win_w, win0 + win_w + win_h, win0 + win_h], Color("0b0f1d"))
	var cc := win0 + win_w * 0.5 + win_h * 0.5
	var cw := win_w * 0.34
	var ch2 := win_h * 0.68
	var cp0 := cc - cw * 0.5 - ch2 * 0.5
	_poly([cp0, cp0 + cw, cp0 + cw + ch2, cp0 + ch2], Color("9aa3b8"))
	_poly([cp0 + cw * 0.15 + ch2 * 0.15, cp0 + cw * 0.85 + ch2 * 0.15, cp0 + cw * 0.85 + ch2 * 0.85, cp0 + cw * 0.15 + ch2 * 0.85], rim.darkened(0.2))
	# textos (levemente inclinados pela perspectiva)
	draw_set_transform(fl + Vector2(8, 22), atan2(fw.y, fw.x), Vector2(1, 1))
	draw_string(f, Vector2(0, 0), str(chip.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, 150, 22, Color.WHITE)
	draw_set_transform(fl + fh * 0.80, atan2(fw.y, fw.x), Vector2(1, 1))
	draw_string(f, Vector2(10, 0), "%d núcleos · %.1f GHz" % [int(chip.get("cores", 0)) + int(chip.get("ecores", 0)), float(chip.get("clock", 0.0))], HORIZONTAL_ALIGNMENT_LEFT, 160, 17, Color(1, 1, 1, 0.9))
	draw_string(f, Vector2(10, 22), "%s · %s" % [str(Chips.node(str(chip.get("node", "n90"))).get("name", "")), str(Chips.ARCHS.get(str(chip.get("arch", "bal")), Chips.ARCHS.bal).name)], HORIZONTAL_ALIGNMENT_LEFT, 160, 16, rim.lightened(0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(fl.x, fl.y, 1, 1), Color(0, 0, 0, 0))
