extends Node
## Áudio: efeitos (pool de players) e música em loop, com volumes salvos.
## Efeitos em assets/audio/sfx/<nome>.wav; música em assets/audio/music/ambient_loop.ogg.

const SFX_NAMES := ["click", "nav", "error", "success", "hire", "fire", "cash", "train", "research", "ready",
	"release", "month", "event_good", "event_bad", "bankrupt"]
const POOL_SIZE := 8
const MIN_GAP_MS := 35

var _streams: Dictionary = {}
var _players: Array = []
var _next: int = 0
var _last_play: Dictionary = {}
var _music: AudioStreamPlayer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("SFX")
	_ensure_bus("Music")
	for n in SFX_NAMES:
		var path: String = "res://assets/audio/sfx/%s.wav" % n
		if ResourceLoader.exists(path):
			_streams[n] = load(path)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	var mpath := "res://assets/audio/music/ambient_loop.ogg"
	if ResourceLoader.exists(mpath):
		var stream: AudioStream = load(mpath)
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		_music = AudioStreamPlayer.new()
		_music.stream = stream
		_music.bus = "Music"
		add_child(_music)
	apply_volumes()
	if _music != null and Saves.music_volume > 0:
		_music.play()

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)

func _vol_db(v: int) -> float:
	return -80.0 if v <= 0 else linear_to_db(pow(float(v) / 10.0, 1.6))

func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), _vol_db(Saves.sfx_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), _vol_db(Saves.music_volume) - 6.0)
	if _music != null:
		if Saves.music_volume > 0 and not _music.playing:
			_music.play()
		elif Saves.music_volume == 0 and _music.playing:
			_music.stop()

func set_sfx_volume(v: int) -> void:
	Saves.sfx_volume = clampi(v, 0, 10)
	Saves.save_settings()
	apply_volumes()

func set_music_volume(v: int) -> void:
	Saves.music_volume = clampi(v, 0, 10)
	Saves.save_settings()
	apply_volumes()

func play(sound: String, pitch_jitter: float = 0.0) -> void:
	if Saves.sfx_volume <= 0 or not _streams.has(sound):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(sound, -1000)) < MIN_GAP_MS:
		return
	_last_play[sound] = now
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = _streams[sound]
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()

func _notification(what: int) -> void:
	if _music == null:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_music.stream_paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_music.stream_paused = false
