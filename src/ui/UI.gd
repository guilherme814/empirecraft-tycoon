class_name UI
extends RefCounted
## Construtores de widgets (a interface é montada por código, sem editor).

const MIN_FONT := 23   # piso de legibilidade em telas de celular

static func label(text: String, size: int = 28, color: Color = Palette.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", maxi(size, MIN_FONT))
	l.add_theme_color_override("font_color", color)
	return l

static func wrap(text: String, size: int = 26, color: Color = Palette.MUTED) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

static func heading(text: String) -> Label:
	return label(text, 32, Palette.ACCENT)

static func button(text: String, cb: Callable, kind: String = "normal", min_h: int = 84, min_w: int = 0,
		icon_name: String = "", sound: String = "click") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(min_w, min_h)
	Palette.style_button(b, kind)
	if icon_name != "":
		b.icon = Icons.tex(icon_name)   # tamanho limitado por icon_max_width (Palette.style_button)
	if sound != "":
		b.pressed.connect(func(): Sfx.play(sound))
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

## Ícone solto (TextureRect), tingido por `color`.
static func icon(icon_name: String, size: int = 36, color: Color = Palette.TEXT) -> TextureRect:
	var r := TextureRect.new()
	r.texture = Icons.tex(icon_name)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.modulate = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r

## Ícone + texto lado a lado.
static func icon_label(icon_name: String, text: String, size: int = 28, color: Color = Palette.TEXT,
		icon_color: Color = Palette.TEXT) -> HBoxContainer:
	var h := hbox(10)
	h.add_child(icon(icon_name, int(size * 1.15), icon_color))
	h.add_child(label(text, size, color))
	return h

## Fundo "planta técnica" (shader leve, sem texturas).
static func background() -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/blueprint_bg.gdshader") as Shader
	r.material = m
	r.resized.connect(func(): m.set_shader_parameter("rect_size", r.size))
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func card(color: Color = Palette.PANEL, pad: int = 20) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Palette.card_box(color, 18, pad))
	return p

static func vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func grow(c: Control, horizontal: bool = true, vertical: bool = false) -> Control:
	if horizontal:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vertical:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c

static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

## Rolagem vertical por toque. O deadzone evita que um arrasto vire clique de botão.
static func scroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.scroll_deadzone = 24
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s

static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

static func bar(value01: float, color: Color = Palette.ACCENT, h: int = 14) -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0.0
	b.max_value = 1.0
	b.value = clampf(value01, 0.0, 1.0)
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("fill", Palette.box(color, 7))
	return b

## Linha "chave ........ valor".
static func kv(key: String, value: String, value_color: Color = Palette.TEXT, size: int = 26) -> HBoxContainer:
	var h := hbox(8)
	h.add_child(label(key, size, Palette.MUTED))
	h.add_child(spacer())
	h.add_child(label(value, size, value_color))
	return h

static func kind_color(kind: String) -> Color:
	match kind:
		"good": return Palette.GOOD
		"bad": return Palette.BAD
		_: return Palette.TEXT

## Linha de ajuste "nome  [−]  valor  [+]" (estilo do estúdio de design).
static func stepper(name: String, value_text: String, on_minus: Callable, on_plus: Callable,
		can_minus: bool = true, can_plus: bool = true, name_w: int = 250) -> HBoxContainer:
	var row := hbox(8)
	var l := label(name, 26)
	l.custom_minimum_size = Vector2(name_w, 0)
	row.add_child(l)
	var m := button("−", on_minus, "normal", 66, 76)
	m.disabled = not can_minus
	row.add_child(m)
	var v := label(value_text, 28, Palette.ACCENT)
	v.custom_minimum_size = Vector2(150, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(v)
	var pl := button("+", on_plus, "normal", 66, 76)
	pl.disabled = not can_plus
	row.add_child(pl)
	return row

## Painel azul de planta técnica (referência visual do estúdio).
static func blueprint(pad: int = 18) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := Palette.box(Color("17315c"), 20, pad)
	sb.border_color = Color("3b6fc4")
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	return p

static func hex(c: Color) -> String:
	return c.to_html(false)
