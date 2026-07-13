extends Resource
class_name OperatingSystem

@export var os_name: String = "MyOS"
@export var version: String = "1.0"
@export var kernel_type: String = "Monolithic"
@export var market_share: float = 0.0
@export var stability: float = 80.0
@export var security: float = 70.0
@export var user_friendliness: float = 60.0
@export var performance: float = 75.0
@export var is_open_source: bool = false
@export var compatible_apps: Array = []
@export var installed_base: int = 0

func update_market_share(total_users: int):
    if total_users > 0:
        market_share = float(installed_base) / float(total_users) * 100.0

func add_app(app):
    if app not in compatible_apps:
        compatible_apps.append(app)

func remove_app(app):
    compatible_apps.erase(app)

func get_rating() -> float:
    return (stability + security + user_friendliness + performance) / 4.0
