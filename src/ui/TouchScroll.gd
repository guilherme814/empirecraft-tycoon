class_name TouchScroll
extends ScrollContainer
## Rolagem por arrasto do dedo, sem barra visível. Painéis e botões dentro dela deixam o toque
## "passar" (MOUSE_FILTER_PASS) para que arrastar sobre eles role a lista em vez de ser engolido.

const KEEP_STOP := ["LineEdit", "TextEdit", "Slider", "ScrollBar", "OptionButton"]

func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll_deadzone = 18
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func _enter_tree() -> void:
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)

func _exit_tree() -> void:
	if get_tree() != null and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)

func _on_node_added(n: Node) -> void:
	if n is Control and is_ancestor_of(n):
		_pass(n as Control)

static func _pass(c: Control) -> void:
	if c.mouse_filter != Control.MOUSE_FILTER_STOP:
		return
	for k in KEEP_STOP:
		if c.is_class(k):
			return
	c.mouse_filter = Control.MOUSE_FILTER_PASS
