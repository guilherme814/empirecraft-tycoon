extends Control

@onready var log_label = $ScrollContainer/LogLabel
@onready var ai_response_label = $AIResponseLabel
@onready var diag_ai = $DiagnosticAI

func _ready():
    add_to_group("theme_sensitive")
    update_theme()
    refresh_log()

func refresh_log():
    log_label.text = diag_ai.get_diagnostic()

func _on_analyze_button_pressed():
    var last_error = "Nenhum erro específico."
    if not diag_ai.error_log.is_empty():
        last_error = diag_ai.error_log[-1].error
    ai_response_label.text = "Analisando..."
    diag_ai.ask_ai_for_fix(last_error)

func show_ai_reply(reply: String):
    ai_response_label.text = "Sugestão da IA:\n" + reply

func update_theme():
    var tm = get_node("/root/ThemeManager")
    $Panel.color = tm.get_color("panel")
    log_label.add_theme_color_override("font_color", tm.get_color("text"))
    ai_response_label.add_theme_color_override("font_color", tm.get_color("text"))
