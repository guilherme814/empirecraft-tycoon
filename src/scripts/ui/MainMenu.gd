extends Control

func _ready():
    $VBoxContainer/NewGameButton.pressed.connect(_on_new_game)
    $VBoxContainer/ContinueButton.pressed.connect(_on_continue)
    $VBoxContainer/SettingsButton.pressed.connect(_on_settings)

func _on_new_game():
    get_tree().change_scene_to_file("res://src/scenes/game/GameScreen.tscn")

func _on_continue():
    pass

func _on_settings():
    get_tree().change_scene_to_file("res://src/scenes/settings/SettingsScreen.tscn")
