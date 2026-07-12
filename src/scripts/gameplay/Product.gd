extends Resource
class_name Product

@export var name: String = "Novo Produto"
@export var category: String = "hardware"
@export var quality: float = 50.0
@export var price: float = 100.0
@export var production_cost: float = 60.0
@export var sales: int = 0
@export var innovation_level: int = 1
@export var market_share: float = 0.0
@export var is_released: bool = false
@export var development_progress: float = 0.0

func calculate_profit() -> float:
    return (price - production_cost) * sales

func improve_quality(amount: float):
    quality = min(quality + amount, 100.0)

func set_price(new_price: float):
    price = new_price
