extends Node

const PATH = "user://settings.cfg"

var master_volume := 1.0
var music_volume := 0.8
var sfx_volume := 0.9
var screen_shake := 1.0
var fullscreen := false
var vsync := true
var keyboard_steering := true
var mouse_steering := true

func _ready() -> void:
	load_settings()
	apply()

func apply() -> void:
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)
	
	var current := DisplayServer.window_get_mode()
	var is_full := current == DisplayServer.WINDOW_MODE_FULLSCREEN or current == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen and not is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen and is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("video", "vsync", vsync)
	config.set_value("gameplay", "screen_shake", screen_shake)
	config.set_value("controls", "keyboard_steering", keyboard_steering)
	config.set_value("controls", "mouse_steering", mouse_steering)
	config.save(PATH)

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	master_volume = config.get_value("audio", "master", master_volume)
	music_volume = config.get_value("audio", "music", music_volume)
	sfx_volume = config.get_value("audio", "sfx", sfx_volume)
	fullscreen = config.get_value("video", "fullscreen", fullscreen)
	vsync = config.get_value("video", "vsync", vsync)
	screen_shake = config.get_value("gameplay", "screen_shake", screen_shake)
	keyboard_steering = config.get_value("controls", "keyboard_steering", keyboard_steering)
	mouse_steering = config.get_value("controls", "mouse_steering", mouse_steering)

func _set_bus_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(index, linear <= 0.001)
