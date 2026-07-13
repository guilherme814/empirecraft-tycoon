extends Node

signal money_changed(amount: float)
signal day_passed(day: int)

var money: float = 50000.0
var reputation: float = 50.0
var current_day: int = 1
var player_os = null  # Será inicializado com ScriptRegistry quando necessário

func _ready():
    # Inicializar tema
    var theme_manager = load("res://src/scripts/ui/theme/ThemeManager.gd").new()
    theme_manager.name = "ThemeManager"
    add_child(theme_manager)
    
    # Exemplo de uso seguro do ScriptRegistry (sem dependência no escopo global)
    if ScriptRegistry:
        player_os = ScriptRegistry.OperatingSystem.new()
        player_os.os_name = "NebulaOS"
        player_os.version = "0.1 Alpha"
        print("SO inicializado via ScriptRegistry: ", player_os.os_name)
    else:
        print("ScriptRegistry não encontrado. SO não será carregado.")

func add_money(amount: float):
    money += amount
    emit_signal("money_changed", money)

func spend_money(amount: float) -> bool:
    if money >= amount:
        money -= amount
        emit_signal("money_changed", money)
        return true
    return false

func next_day():
    current_day += 1
    emit_signal("day_passed", current_day)
