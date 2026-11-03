extends Node
## Persistência: save em JSON versionado e configurações.

const SAVE_PATH := "user://save_0.json"            # campanha
const BACKUP_PATH := "user://save_0.bak.json"
const SANDBOX_PATH := "user://save_sandbox.json"   # sandbox: slot independente, nunca mistura com a campanha
const SANDBOX_BACKUP_PATH := "user://save_sandbox.bak.json"
const REPLACED_PATH := "user://save_0.replaced.json"   # última campanha substituída por um novo jogo (rede de segurança)
const SETTINGS_PATH := "user://settings.cfg"

var autosave_days: int = 30
var sfx_volume: int = 7       # 0-10
var music_volume: int = 4     # 0-10
var nav_collapsed: bool = false   # menu lateral só com ícones
var gfx: String = "bal"           # perfil gráfico: eco | bal | high

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		autosave_days = int(cfg.get_value("game", "autosave_days", 30))
		sfx_volume = int(cfg.get_value("audio", "sfx", 7))
		music_volume = int(cfg.get_value("audio", "music", 4))
		nav_collapsed = bool(cfg.get_value("ui", "nav_collapsed", false))
		gfx = str(cfg.get_value("ui", "gfx", "bal"))
		if not ["eco", "bal", "high"].has(gfx):
			gfx = "bal"
	_migrate_legacy_sandbox()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "autosave_days", autosave_days)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("ui", "nav_collapsed", nav_collapsed)
	cfg.set_value("ui", "gfx", gfx)
	cfg.save(SETTINGS_PATH)

static func path_for(sandbox: bool) -> String:
	return SANDBOX_PATH if sandbox else SAVE_PATH

static func backup_for(sandbox: bool) -> String:
	return SANDBOX_BACKUP_PATH if sandbox else BACKUP_PATH

## Versões anteriores guardavam o sandbox como uma flag dentro da campanha. Move esse save para o
## slot de sandbox (se estiver livre), para que a campanha e o sandbox nunca se sobrescrevam.
func _migrate_legacy_sandbox() -> void:
	if not FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(SANDBOX_PATH):
		return
	var data: Variant = _read(SAVE_PATH)
	if data is Dictionary and bool((data as Dictionary).get("sandbox", false)):
		DirAccess.copy_absolute(SAVE_PATH, SANDBOX_PATH)
		DirAccess.remove_absolute(SAVE_PATH)

func has_save(sandbox: bool = false) -> bool:
	return FileAccess.file_exists(path_for(sandbox))

## Resumo do slot para o menu: {name, day, origin} ou {} se vazio/ilegível.
func peek(sandbox: bool = false) -> Dictionary:
	if not has_save(sandbox):
		return {}
	var d: Variant = _read(path_for(sandbox))
	if not (d is Dictionary):
		return {}
	return {"name": str(d.get("name", "?")), "day": int(d.get("day", 0)), "origin": str(d.get("origin", ""))}

## Antes de começar uma campanha nova por cima de outra, guarda a antiga (uma cópia).
func archive_campaign() -> void:
	if has_save(false):
		DirAccess.copy_absolute(SAVE_PATH, REPLACED_PATH)

func save_company(c: Company) -> bool:
	var path := path_for(c.sandbox)
	# Escreve em arquivo temporário e renomeia: evita save corrompido se o app fechar no meio.
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Saves: não foi possível escrever o save")
		return false
	f.store_string(JSON.stringify(c.to_dict()))
	f.close()
	# guarda a versão anterior antes de substituir (recuperação se algo der errado)
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, backup_for(c.sandbox))
	DirAccess.rename_absolute(tmp, path)
	return true

func _read(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return data

func load_company(sandbox: bool = false) -> Company:
	if not has_save(sandbox):
		return null
	var path := path_for(sandbox)
	var data: Variant = _read(path)
	if not (data is Dictionary):
		# save principal corrompido: tenta o backup automático
		var bp := backup_for(sandbox)
		data = _read(bp) if FileAccess.file_exists(bp) else null
		if not (data is Dictionary):
			return null
	var old_v := int(data.get("version", 1))
	if old_v < Company.SAVE_VERSION:
		# antes de migrar, guarda uma cópia do formato antigo (nunca sobrescreve uma cópia já existente)
		var mig := "user://save_%s.v%d.bak.json" % ["sandbox" if sandbox else "0", old_v]
		if not FileAccess.file_exists(mig):
			DirAccess.copy_absolute(path, mig)
	return Company.from_dict(data)   # null se o save for inválido/futuro

func delete_save(sandbox: bool = false) -> void:
	if has_save(sandbox):
		DirAccess.remove_absolute(path_for(sandbox))
