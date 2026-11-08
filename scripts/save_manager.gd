extends Node

signal saved

const PATH = "user://save.cfg"
const SAVE_VERSION = 1
const AUTOSAVE_INTERVAL = 120.0
const SAVED_GLOBALS = [
	"total_coins",
	"base_flight_speed",
	"base_turn_speed",
	"brake_turn_bonus",
	"brake_decel_scale",
	"gravity_scale",
	"turn_accel_scale",
	"max_dashes",
	"base_coin_mult",
	"magnet_radius",
	"has_medallion",
	"upgrade_levels",
]

var active := false
var defaults: Dictionary = {}
var autosave_timer: Timer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in SAVED_GLOBALS:
		defaults[key] = _copy(Global.get(key))
	
	autosave_timer = Timer.new()
	autosave_timer.wait_time = AUTOSAVE_INTERVAL
	autosave_timer.autostart = true
	autosave_timer.timeout.connect(_on_autosave)
	add_child(autosave_timer)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()

func has_save() -> bool:
	return FileAccess.file_exists(PATH)

func new_game() -> void:
	for key in SAVED_GLOBALS:
		Global.set(key, _copy(defaults[key]))
	Global.dashes = Global.max_dashes
	active = true
	save_game()

func load_game() -> bool:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return false
	for key in SAVED_GLOBALS:
		if config.has_section_key("global", key):
			Global.set(key, config.get_value("global", key))
	Global.dashes = Global.max_dashes
	active = true
	return true

func save_game() -> void:
	if not active:
		return
	var config := ConfigFile.new()
	config.set_value("meta", "version", SAVE_VERSION)
	config.set_value("meta", "saved_at", Time.get_datetime_string_from_system())
	for key in SAVED_GLOBALS:
		config.set_value("global", key, Global.get(key))
	var err := config.save(PATH)
	if err != OK:
		push_error("SaveManager: saving to %s failed (error %d)." % [PATH, err])
	saved.emit()

func _on_autosave() -> void:
	if active and not Global.in_transition:
		save_game()

func _copy(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value
