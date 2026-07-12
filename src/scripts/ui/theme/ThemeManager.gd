extends Node

enum Theme { LIGHT, DARK }
var current_theme = Theme.DARK

var colors = {
    Theme.LIGHT: {
        "background": Color.WHITE,
        "panel": Color(0.95, 0.95, 0.95),
        "text": Color.BLACK,
        "accent": Color.DODGER_BLUE
    },
    Theme.DARK: {
        "background": Color(0.1, 0.1, 0.12),
        "panel": Color(0.18, 0.18, 0.2),
        "text": Color.WHITE,
        "accent": Color.ORANGE
    }
}

func get_color(key: String) -> Color:
    return colors[current_theme][key]

func set_theme(theme: int):
    current_theme = theme
    # Emite sinal para atualizar toda a UI
    get_tree().call_group("theme_sensitive", "update_theme")
