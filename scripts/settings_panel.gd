extends Control

signal closed

@onready var panel: Control = $Panel
@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var shake_slider: HSlider = %ShakeSlider
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var vsync_check: CheckButton = %VsyncCheck
@onready var back_button: Button = %BackButton
@onready var keyboard_steer_check: CheckButton = %KeyboardSteerCheck
@onready var mouse_steer_check: CheckButton = %MouseSteerCheck


var tween: Tween

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sync_from_settings()
	master_slider.value_changed.connect(_set_setting.bind("master_volume"))
	music_slider.value_changed.connect(_set_setting.bind("music_volume"))
	sfx_slider.value_changed.connect(_set_setting.bind("sfx_volume"))
	shake_slider.value_changed.connect(_set_setting.bind("screen_shake"))
	fullscreen_check.toggled.connect(_set_setting.bind("fullscreen"))
	vsync_check.toggled.connect(_set_setting.bind("vsync"))
	keyboard_steer_check.toggled.connect(_on_steer_toggled.bind("keyboard_steering"))
	mouse_steer_check.toggled.connect(_on_steer_toggled.bind("mouse_steering"))
	back_button.pressed.connect(close)

func open() -> void:
	_sync_from_settings()
	visible = true
	panel.pivot_offset = panel.size * 0.5
	if tween and tween.is_valid():
		tween.kill()
	modulate.a = 0.0
	panel.scale = Vector2.ONE * 0.9
	tween = create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 1.0, 0.18)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	back_button.grab_focus()

func close() -> void:
	Settings.save_settings()
	if tween and tween.is_valid():
		tween.kill()
	tween = create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_property(panel, "scale", Vector2.ONE * 0.95, 0.15)
	tween.chain().tween_callback(func(): visible = false)
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _sync_from_settings() -> void:
	master_slider.set_value_no_signal(Settings.master_volume)
	music_slider.set_value_no_signal(Settings.music_volume)
	sfx_slider.set_value_no_signal(Settings.sfx_volume)
	shake_slider.set_value_no_signal(Settings.screen_shake)
	fullscreen_check.set_pressed_no_signal(Settings.fullscreen)
	vsync_check.set_pressed_no_signal(Settings.vsync)
	keyboard_steer_check.set_pressed_no_signal(Settings.keyboard_steering)
	mouse_steer_check.set_pressed_no_signal(Settings.mouse_steering)

func _set_setting(value: Variant, key: String) -> void:
	Settings.set(key, value)
	Settings.apply()

func _on_steer_toggled(pressed: bool, key: String) -> void:
	Settings.set(key, pressed)
	if not Settings.keyboard_steering and not Settings.mouse_steering:
		var other := "mouse_steering" if key == "keyboard_steering" else "keyboard_steering"
		Settings.set(other, true)
		_sync_from_settings()
