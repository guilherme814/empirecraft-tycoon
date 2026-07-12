extends Node

enum NebulaTheme { LIGHT, DARK }
var current_theme = NebulaTheme.DARK

var colors = {
    NebulaTheme.LIGHT: {
        "background": Color.WHITE,
        "panel": Color(0.95, 0.95, 0.95),
        "text": Color.BLACK,
        "accent": Color.DODGER_BLUE
    },
    NebulaTheme.DARK: {
        "background": Color(0.08, 0.08, 0.1),
        "panel": Color(0.15, 0.15, 0.18),
        "text": Color.WHITE,
        "accent": Color.ORANGE
    }
}

func get_color(key: String) -> Color:
    return colors[current_theme][key]

func toggle_theme():
    current_theme = NebulaTheme.LIGHT if current_theme == NebulaTheme.DARK else NebulaTheme.DARK
    get_tree().call_group("theme_sensitive", "update_theme")
