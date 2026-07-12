extends Node

var competitor_products: Array = []
var market_trends: Dictionary = {
    "hardware": 0.5,
    "software": 0.6,
    "ai": 0.8,
    "mobile": 0.7
}

func analyze_market() -> Dictionary:
    return market_trends

func competitor_launch_product(category: String):
    var product = {
        "name": "Produto Concorrente",
        "category": category,
        "quality": randf_range(40.0, 90.0),
        "price": randf_range(80.0, 200.0)
    }
    competitor_products.append(product)
    print("Concorrente lançou: ", product.name)
