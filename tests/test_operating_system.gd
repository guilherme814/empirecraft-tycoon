extends Node

func _ready():
    print("Executando testes do OperatingSystem...")
    var os = OperatingSystem.new()
    assert(os != null, "OperatingSystem não foi criado")
    assert(os.performance >= 0, "Performance fora do intervalo")
    assert(os.security >= 0, "Security fora do intervalo")
    assert(os.stability >= 0, "Stability fora do intervalo")
    print("Todos os testes passaram!")
    get_tree().quit(0)
