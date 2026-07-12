extends Button

func _ready():
    add_to_group("theme_sensitive")
    update_theme()

func update_theme():
    var tm = get_node("/root/ThemeManager")
    modulate = tm.get_color("accent")
    add_theme_color_override("font_color", Color.WHITE)
    add_theme_font_override("font", load("res://assets/fonts/DefaultFont.tres"))
