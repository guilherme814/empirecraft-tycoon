extends Control

@onready var money_label = $TopBar/MoneyLabel
@onready var day_label = $TopBar/DayLabel
@onready var rep_label = $TopBar/RepLabel

func _ready():
    add_to_group("theme_sensitive")
    update_theme()
    GameManager.money_changed.connect(_on_money_changed)
    GameManager.day_passed.connect(_on_day_passed)

func update_theme():
    var tm = get_node("/root/ThemeManager")
    $TopBar.color = tm.get_color("panel")
    money_label.add_theme_color_override("font_color", tm.get_color("text"))
    # ... outros labels

func _on_money_changed(amount):
    money_label.text = "$ " + str(amount)

func _on_day_passed(day):
    day_label.text = "Dia " + str(day)
