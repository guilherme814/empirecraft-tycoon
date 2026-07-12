extends Node

const SAVE_DIR = "user://saves/"

func _ready():
    if not DirAccess.dir_exists_absolute(SAVE_DIR):
        DirAccess.make_dir_absolute(SAVE_DIR)

func save_game(slot: int, data: Dictionary):
    var file = FileAccess.open(SAVE_DIR + "save_" + str(slot) + ".json", FileAccess.WRITE)
    file.store_string(JSON.stringify(data))
    file.close()

func load_game(slot: int) -> Dictionary:
    var file = FileAccess.open(SAVE_DIR + "save_" + str(slot) + ".json", FileAccess.READ)
    if file:
        var data = JSON.parse_string(file.get_as_text())
        file.close()
        return data if data else {}
    return {}
