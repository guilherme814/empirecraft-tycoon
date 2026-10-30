extends Control

var _autosave_label: Label
var _sfx_label: Label
var _music_label: Label
var _upd_label: Label
var _http: HTTPRequest
var _manifest: Dictionary = {}
var _upd_btn: Button

func _ready() -> void:
	theme = Palette.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UI.background())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := UI.vbox(20)
	v.custom_minimum_size = Vector2(900, 0)
	center.add_child(v)
	v.add_child(UI.heading("Configurações"))

	var card := UI.card()
	v.add_child(card)
	var cv := UI.vbox(14)
	card.add_child(cv)
	cv.add_child(UI.label("Salvamento automático (dias de jogo)", 28))
	var row := UI.hbox(12)
	cv.add_child(row)
	row.add_child(UI.button("−", func(): _change(-10), "normal", 80, 100))
	_autosave_label = UI.label("", 32, Palette.ACCENT)
	_autosave_label.custom_minimum_size = Vector2(260, 0)
	_autosave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_autosave_label)
	row.add_child(UI.button("+", func(): _change(10), "normal", 80, 100))
	cv.add_child(UI.wrap("0 desliga. O jogo também salva ao sair do app."))

	var audio := UI.card()
	v.add_child(audio)
	var av := UI.vbox(14)
	audio.add_child(av)
	av.add_child(UI.label("Áudio", 28))
	_sfx_label = UI.label("", 30, Palette.ACCENT)
	_music_label = UI.label("", 30, Palette.ACCENT)
	av.add_child(_volume_row("Efeitos", _sfx_label, func(d): Sfx.set_sfx_volume(Saves.sfx_volume + d); Sfx.play("click"); _update()))
	av.add_child(_volume_row("Música", _music_label, func(d): Sfx.set_music_volume(Saves.music_volume + d); _update()))

	var up := UI.card()
	v.add_child(up)
	var uv := UI.vbox(12)
	up.add_child(uv)
	uv.add_child(UI.label("Versão instalada: %s" % Rules.VERSION, 28))
	_upd_label = UI.wrap("Verifique se há uma versão nova. Seus saves são copiados antes de qualquer migração.", 22)
	uv.add_child(_upd_label)
	_upd_btn = UI.button("Verificar atualização", _check_update, "normal", 84)
	uv.add_child(_upd_btn)
	_http = HTTPRequest.new()
	_http.timeout = 12.0
	add_child(_http)
	_http.request_completed.connect(_on_manifest)

	var danger := UI.button("Apagar save", func(): _delete(), "danger", 84)
	danger.disabled = not Saves.has_save()
	v.add_child(danger)
	v.add_child(UI.button("Voltar", func(): get_tree().change_scene_to_file("res://src/scenes/MainMenu.tscn"), "primary", 90))
	_update()

func _check_update() -> void:
	_upd_label.text = "Procurando…"
	_upd_btn.disabled = true
	if _http.request(Updater.MANIFEST_URL) != OK:
		_upd_label.text = "Sem conexão. Você pode continuar jogando offline."
		_upd_btn.disabled = false

func _on_manifest(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	_upd_btn.disabled = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_upd_label.text = "Não foi possível verificar agora (sem conexão ou servidor indisponível)."
		return
	var m := Updater.parse_manifest(body.get_string_from_utf8())
	if m.is_empty():
		_upd_label.text = "A resposta de atualização é inválida e foi ignorada."
		return
	if not Updater.is_newer(str(m.version), Rules.VERSION):
		_upd_label.text = "Você já está na versão mais recente (%s)." % Rules.VERSION
		return
	_manifest = m
	_upd_label.text = "Nova versão %s disponível. %s\nO Android pede sua confirmação para instalar; seus saves continuam no aparelho." % [m.version, m.notes]
	_upd_btn.text = "Baixar versão %s" % m.version
	for c in _upd_btn.pressed.get_connections():
		_upd_btn.pressed.disconnect(c.callable)
	_upd_btn.pressed.connect(func(): OS.shell_open(str(_manifest.apk_url)))

func _change(delta: int) -> void:
	Saves.autosave_days = clampi(Saves.autosave_days + delta, 0, 360)
	Saves.save_settings()
	_update()

func _volume_row(title: String, value_label: Label, change: Callable) -> HBoxContainer:
	var row := UI.hbox(12)
	var l := UI.label(title, 28, Palette.MUTED)
	l.custom_minimum_size = Vector2(200, 0)
	row.add_child(l)
	row.add_child(UI.button("−", func(): change.call(-1), "normal", 72, 100, "", ""))
	value_label.custom_minimum_size = Vector2(110, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value_label)
	row.add_child(UI.button("+", func(): change.call(1), "normal", 72, 100, "", ""))
	return row

func _update() -> void:
	_autosave_label.text = "desligado" if Saves.autosave_days == 0 else "a cada %d dias" % Saves.autosave_days
	_sfx_label.text = "%d / 10" % Saves.sfx_volume
	_music_label.text = "%d / 10" % Saves.music_volume

func _delete() -> void:
	Saves.delete_save()
	get_tree().change_scene_to_file("res://src/scenes/MainMenu.tscn")
