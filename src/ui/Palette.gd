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
	b.add_theme_stylebox_override("normal", box(base, 14, 12))
	b.add_theme_stylebox_override("hover", box(base.lightened(0.12), 14, 12))
	b.add_theme_stylebox_override("pressed", box(base.darkened(0.2), 14, 12))
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
