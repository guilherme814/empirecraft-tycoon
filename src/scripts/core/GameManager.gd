extends Node

signal money_changed(amount: float)
signal day_passed(day: int)

var money: float = 50000.0
var reputation: float = 50.0
var current_day: int = 1
var player_os: OperatingSystem = null

func _ready():
    # Inicializar tema
    var theme_manager = load("res://src/scripts/ui/theme/ThemeManager.gd").new()
    theme_manager.name = "ThemeManager"
    add_child(theme_manager)
    
    # Cria o SO inicial do jogador
    player_os = OperatingSystem.new()
    player_os.os_name = "NebulaOS"
    player_os.version = "0.1 Alpha"
    print("Sistema operacional inicializado: ", player_os.os_name)
    
    # Conectar ao sistema de diagnóstico (se existir)
    var diag = get_node_or_null("/root/DiagnosticAI")
    if diag:
        pass

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
