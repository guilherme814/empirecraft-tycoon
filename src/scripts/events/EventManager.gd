extends Node

class_name EventManager

signal event_triggered(event: Dictionary)

var event_pool: Array = [
    {
        "name": "Tendência de Mercado",
        "description": "Nova tecnologia está em alta!",
        "type": "opportunity",
        "effect": {"reputation": 10, "sales_boost": 20}
    },
    {
        "name": "Crise Econômica",
        "description": "O mercado está em recessão.",
        "type": "crisis",
        "effect": {"money": -5000, "sales_penalty": 30}
    },
    {
        "name": "Concorrente Lança Produto",
        "description": "Um rival lançou algo similar.",
        "type": "threat",
        "effect": {"market_share": -5}
    },
    {
        "name": "Feira de Tecnologia",
        "description": "Convite para expor seus produtos!",
        "type": "opportunity",
        "effect": {"reputation": 20, "research_points": 50}
    },
    {
        "name": "Vazamento de Dados",
        "description": "Informações confidenciais vazaram.",
        "type": "crisis",
        "effect": {"reputation": -15, "money": -2000}
    }
]

func trigger_random_event() -> Dictionary:
    var event = event_pool[randi() % event_pool.size()]
    emit_signal("event_triggered", event)
    return event

func get_events_by_type(type: String) -> Array:
    var filtered = []
    for event in event_pool:
        if event.type == type:
            filtered.append(event)
    return filtered
