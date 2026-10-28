class_name Page
extends MarginContainer
## Base das páginas do jogo. Reconstrói a interface só quando a "assinatura" muda
## (evita destruir botões no meio de um toque enquanto o tempo passa) e atualiza
## o resto no lugar com live().

var company: Company:
	get: return Game.company

var _last_sig: String = "\u0001"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, 20)
	build()
	refresh()

## Cria a estrutura fixa (containers, scroll).
func build() -> void:
	pass

## Texto que muda quando a estrutura da página precisa ser reconstruída.
func signature() -> String:
	return ""

func rebuild() -> void:
	pass

## Atualização barata, no lugar (barras, números).
func live() -> void:
	pass

func refresh() -> void:
	if company == null:
		return
	var s := signature()
	if s != _last_sig:
		_last_sig = s
		rebuild()
	live()

## Resultado de uma ação do jogador: avisa erros e atualiza a tela.
func act(res: Dictionary) -> void:
	if not res.ok:
		Sfx.play("error")
		Game.notice.emit(str(res.msg), "bad")
	elif str(res.msg) != "":
		Game.notice.emit(str(res.msg), "good")
	_last_sig = "\u0001"
	Game.changed.emit()
