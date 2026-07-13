extends Node

signal money_changed(amount: float)
signal day_passed(day: int)

var money: float = 50000.0
var reputation: float = 50.0
var current_day: int = 1

func _ready():
    print("GameManager inicializado com sucesso!")

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
