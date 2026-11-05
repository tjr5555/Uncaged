extends Node2D

@onready var back_rect: TextureRect = $backRect

const GAME_SCENE = "res://scenes/main.tscn"

var colors: Array[Color] = [
	Color("3498db"),
	Color("e67e22"),
	Color("9b59b6"),
	Color("1abc9c")
]

var current_color_index = 0

func _ready() -> void:
	print("Menu loaded from: ", scene_file_path)
	if back_rect:
		back_rect.modulate = colors[0]
		_fade_to_next_color()
	SceneFader.preload_scene(GAME_SCENE)

func _fade_to_next_color() -> void:
	var next_index = (current_color_index + 1 ) % colors.size()
	var tween = create_tween()
	tween.tween_property(back_rect, "modulate", colors[next_index], 4.0)
	tween.finished.connect(func():
		current_color_index = next_index
		_fade_to_next_color()
		)
func _on_enter_button_pressed() -> void:
	SceneFader.change_scene(GAME_SCENE)

func _on_settings_button_pressed() -> void:
	$Overlay/SettingsPanel.open()

func _on_quit_button_pressed() -> void:
	get_tree().quit()
