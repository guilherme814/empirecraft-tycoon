extends Control

var _autosave_label: Label
var _sfx_label: Label
var _music_label: Label
var _upd_label: Label
var _http: HTTPRequest
var _manifest: Dictionary = {}
var _upd_btn: Button
const PRIVACY_URL := "https://github.com/guilherme814/empirecraft-tycoon/blob/main/docs/PRIVACY.md"

func _ready() -> void:
	theme = Palette.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UI.background())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var root := UI.vbox(14)
	root.custom_minimum_size = Vector2(900, 0)
	center.add_child(root)
	root.add_child(UI.heading("Configurações"))
	var sc := UI.scroll()
	sc.custom_minimum_size = Vector2(900, 800)    # lista rolável; o "Voltar" fica sempre visível embaixo
	root.add_child(sc)
	var v := UI.vbox(20)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)

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

	var gcard := UI.card()
	v.add_child(gcard)
	var gv := UI.vbox(10)
	gcard.add_child(gv)
	gv.add_child(UI.label("Gráficos", 28))
	var grow := UI.hbox(10)
	gv.add_child(grow)
	for opt in [["eco", "Econômico"], ["bal", "Equilibrado"], ["high", "Alto"]]:
		var gid: String = opt[0]
		var gb := UI.button(opt[1], func():
			Saves.gfx = gid
			Saves.save_settings()
			get_tree().reload_current_scene(), "primary" if Saves.gfx == gid else "normal", 72)
		gb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grow.add_child(gb)
	gv.add_child(UI.wrap("Econômico poupa bateria (sem efeitos de partículas e sombras de painel). Alto usa mais suavização e brilho.", 21))

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

	var about := UI.card()
	v.add_child(about)
	var abv := UI.vbox(10)
	about.add_child(abv)
	abv.add_child(UI.label("Sobre e privacidade", 28))
	abv.add_child(UI.wrap("Device Empire funciona offline. Seus saves ficam só neste aparelho; o jogo não coleta nem envia dados pessoais. A única conexão é a verificação opcional de atualização.", 22))
	abv.add_child(UI.wrap("Feito com Godot Engine (licença MIT) e fonte Poppins (SIL Open Font License).", 21))
	abv.add_child(UI.button("Política de privacidade", func(): OS.shell_open(PRIVACY_URL), "normal", 72))

	var danger := UI.button("Apagar campanha salva", func(): _delete(false), "danger", 84)
	danger.disabled = not Saves.has_save(false)
	v.add_child(danger)
	var danger2 := UI.button("Apagar sandbox salvo", func(): _delete(true), "danger", 84)
	danger2.disabled = not Saves.has_save(true)
	v.add_child(danger2)
	root.add_child(UI.button("Voltar", func(): get_tree().change_scene_to_file("res://src/scenes/MainMenu.tscn"), "primary", 90))
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

func _delete(sandbox: bool) -> void:
	Saves.delete_save(sandbox)
	get_tree().change_scene_to_file("res://src/scenes/MainMenu.tscn")
