extends Resource
class_name OperatingSystem

@export var os_name: String = "MyOS"
@export var version: String = "1.0"
@export var market_share: float = 0.0
@export var stability: float = 80.0
@export var security: float = 70.0
@export var performance: float = 75.0

func get_rating() -> float:
    return (stability + security + performance) / 3.0
