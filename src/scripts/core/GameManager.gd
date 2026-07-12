extends Node

signal game_started
signal game_paused
signal day_passed(day: int)
signal money_changed(amount: float)

var company_name: String = "Sua Empresa"
var money: float = 50000.0
var reputation: float = 50.0
var current_day: int = 1
var research_points: float = 0.0
var employees: Array = []
var products: Array = []
var active_events: Array = []

func _ready():
    print("EmpireCraft Tycoon iniciado!")
    load_initial_data()

func load_initial_data():
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
    calculate_daily_income()
    process_events()
    emit_signal("day_passed", current_day)

func calculate_daily_income():
    var income: float = 0.0
    for product in products:
        income += product.sales * product.price
    add_money(income)

func process_events():
    pass
