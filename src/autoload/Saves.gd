extends Node
## Persistência: save em JSON versionado e configurações.

const SAVE_PATH := "user://save_0.json"
const SETTINGS_PATH := "user://settings.cfg"

var autosave_days: int = 30
var sfx_volume: int = 7       # 0-10
var music_volume: int = 4     # 0-10

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		autosave_days = int(cfg.get_value("game", "autosave_days", 30))
		sfx_volume = int(cfg.get_value("audio", "sfx", 7))
		music_volume = int(cfg.get_value("audio", "music", 4))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "autosave_days", autosave_days)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.save(SETTINGS_PATH)

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_company(c: Company) -> bool:
	# Escreve em arquivo temporário e renomeia: evita save corrompido se o app fechar no meio.
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Saves: não foi possível escrever o save")
		return false
	f.store_string(JSON.stringify(c.to_dict()))
	f.close()
	DirAccess.rename_absolute(tmp, SAVE_PATH)
	return true

func load_company() -> Company:
	if not has_save():
		return null
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return null
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (data is Dictionary):
		return null
	return Company.from_dict(data)   # null se o save for inválido/futuro

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
