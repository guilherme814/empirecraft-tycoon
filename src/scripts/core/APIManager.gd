extends Node

var api_keys: Dictionary = {}

func _ready():
    load_keys()

func load_keys():
    var file = FileAccess.open("res://api_config.json", FileAccess.READ)
    if file:
        var data = JSON.parse_string(file.get_as_text())
        if data:
            api_keys = data
        file.close()
    else:
        print("api_config.json não encontrado. Crie o arquivo com suas chaves.")

func get_key(service: String) -> String:
    return api_keys.get(service, "")
