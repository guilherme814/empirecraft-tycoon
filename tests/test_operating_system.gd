
extends SceneTree

func _initialize() -> void:
    print("Executando testes do OperatingSystem...")

    var os_script = preload("res://src/scripts/gameplay/os/OperatingSystem.gd")
    var os = os_script.new()

    if os == null:
        push_error("OperatingSystem não foi criado")
        quit(1)
        return

    if os.performance < 0.0 or os.security < 0.0 or os.stability < 0.0:
        push_error("Uma ou mais métricas estão abaixo de zero")
        quit(1)
        return

    print("Todos os testes passaram!")
    quit(0)
