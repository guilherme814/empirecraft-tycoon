class_name Palette
extends RefCounted
## Identidade visual: escuro, laranja de destaque (mesma assinatura dos seus outros projetos).

const BG := Color("12141a")
const PANEL := Color("1d2029")
const PANEL_ALT := Color("2a2f3d")
const PANEL_DEEP := Color("0e1016")
const TEXT := Color("e9ecf2")
const MUTED := Color("8d94a6")
const ACCENT := Color("ff9a2e")
const GOOD := Color("4cd18a")
const BAD := Color("ff5d6c")
const INFO := Color("5aa9ff")
const WARN := Color("ffc857")
const ON_COLOR := Color("14161c")   # texto sobre botões coloridos

static var _theme: Theme = null

static func box(color: Color, radius: int = 16, pad: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s

## Cartão com borda fina e levemente mais clara (acabamento).
static func card_box(color: Color, radius: int = 18, pad: int = 20) -> StyleBoxFlat:
	var s := box(color, radius, pad)
	s.set_border_width_all(1)
	s.border_color = color.lightened(0.10)
	if Saves.gfx != "eco":
		s.shadow_color = Color(0, 0, 0, 0.28 if Saves.gfx == "high" else 0.18)
		s.shadow_size = 8 if Saves.gfx == "high" else 5
		s.shadow_offset = Vector2(0, 3)
		s.border_blend = true
	return s

## Botão com relevo: filete de luz em cima e base mais escura (parece uma tecla).
static func key_box(color: Color, colored: bool, pressed: bool = false) -> StyleBoxFlat:
	var s := box(color, 14, 12)
	if Saves.gfx == "eco":
		return s
	s.border_width_top = 0 if pressed else 2
	s.border_width_bottom = 2 if pressed else 5
	s.border_color = color.lightened(0.28) if colored else color.lightened(0.10)
	# a borda é única; o escurecimento da base vem da sombra
	s.shadow_color = Color(0, 0, 0, 0.30)
	s.shadow_size = 0 if pressed else 3
	s.shadow_offset = Vector2(0, 2)
	s.content_margin_top = 12.0 + (3.0 if pressed else 0.0)
	return s

static func kind_color(kind: String) -> Color:
	match kind:
		"primary": return ACCENT
		"good": return GOOD
		"danger": return BAD
		"info": return INFO
		_: return PANEL_ALT

static func style_button(b: Button, kind: String) -> void:
	var base := kind_color(kind)
	var colored := kind != "normal"
	var txt := ON_COLOR if colored else TEXT
	b.add_theme_stylebox_override("normal", key_box(base, colored))
	b.add_theme_stylebox_override("hover", key_box(base.lightened(0.12), colored))
	b.add_theme_stylebox_override("pressed", key_box(base.darkened(0.2), colored, true))
	b.add_theme_stylebox_override("disabled", box(PANEL_DEEP, 14, 12))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", txt)
	b.add_theme_color_override("font_hover_color", txt)
	b.add_theme_color_override("font_pressed_color", txt)
	b.add_theme_color_override("font_disabled_color", MUTED.darkened(0.2))
	b.add_theme_color_override("icon_normal_color", txt)
	b.add_theme_color_override("icon_hover_color", txt)
	b.add_theme_color_override("icon_pressed_color", txt)
	b.add_theme_color_override("icon_disabled_color", MUTED.darkened(0.2))
	b.add_theme_constant_override("icon_max_width", 40)
	b.add_theme_constant_override("h_separation", 12)

static func make_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	var font: Font = load("res://assets/fonts/Poppins-Regular.ttf") as Font
	if font != null:
		t.default_font = font
	t.default_font_size = 28
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("background", "ProgressBar", box(PANEL_DEEP, 7))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, 7))
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 18, 20))
	_theme = t
	return t
