extends Node
## Relógio do jogo: converte tempo real em dias de jogo, com velocidades.

signal speed_changed(index: int)

const SPEEDS := [0.0, 1.0, 2.0, 4.0, 8.0]   # dias de jogo por segundo
const MAX_STEPS_PER_FRAME := 8

var speed_index: int = 0
var active: bool = false      # só roda dentro da tela de jogo
var _acc: float = 0.0

func set_speed(i: int) -> void:
	speed_index = clampi(i, 0, SPEEDS.size() - 1)
	speed_changed.emit(speed_index)

func pause() -> void:
	set_speed(0)

func _process(delta: float) -> void:
	if not active or speed_index == 0 or Game.company == null:
		return
	_acc += delta * float(SPEEDS[speed_index])
	var steps := 0
	while _acc >= 1.0 and steps < MAX_STEPS_PER_FRAME:
		_acc -= 1.0
		steps += 1
		Game.advance_day()
		if Game.company.game_over:
			set_speed(0)
			break
	if steps >= MAX_STEPS_PER_FRAME:
		_acc = 0.0

func _notification(what: int) -> void:
	# Economiza bateria e protege o progresso ao sair do app.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if active:
			pause()
			Game.save()
