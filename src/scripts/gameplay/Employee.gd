extends Resource
class_name Employee

@export var name: String = "Funcionário"
@export var role: String = "developer"
@export var skill: float = 50.0
@export var salary: float = 2000.0
@export var happiness: float = 70.0
@export var productivity: float = 1.0
@export var experience: int = 0

func work_on_project(hours: float) -> float:
    var output = skill * productivity * hours / 100.0
    experience += int(hours)
    return output

func give_raise(amount: float):
    salary += amount
    happiness += 10.0
