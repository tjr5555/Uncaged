extends Control

signal closed

const BLUR_SHADER = preload("res://shaders/ui_blur.gdshader")

const SLIDERS = {
	"MasterSlider": "master_volume",
	"MusicSlider": "music_volume",
	"SfxSlider": "sfx_volume",
	"ShakeSlider": "screen_shake",
}
const TOGGLES = {
	"FullscreenCheck": "fullscreen",
	"VsyncCheck": "vsync",
}
const STEER_TOGGLES = {
	"KeyboardSteerCheck": "keyboard_steering",
	"MouseSteerCheck": "mouse_steering",
}

@export var panel_min_size := Vector2(960, 680)
@export var slider_width := 420.0

@onready var panel: Control = %Panel
@onready var back_button: Button = %BackButton
@onready var reset_button: Button = get_node_or_null("%ResetButton")
@onready var backdrop: ColorRect = get_node_or_null("%Backdrop")

var tween: Tween


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if theme == null:
		theme = UiTheme.build()
	_setup_layout()
	_connect_controls()
	_sync_from_settings()


func open() -> void:
	_sync_from_settings()
	visible = true
	panel.pivot_offset = panel.size * 0.5
	modulate.a = 0.0
	panel.scale = Vector2.ONE * 0.94
	_restart_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.18)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_backdrop, 0.0, 1.0, 0.25)
	back_button.grab_focus()


func close() -> void:
	Settings.save_settings()
	_restart_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_property(panel, "scale", Vector2.ONE * 0.96, 0.15)
	tween.tween_method(_set_backdrop, 1.0, 0.0, 0.15)
	tween.chain().tween_callback(func(): visible = false)
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _setup_layout() -> void:
	panel.custom_minimum_size = panel_min_size
	panel.resized.connect(func(): panel.pivot_offset = panel.size * 0.5)

	if backdrop:
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		if backdrop.material == null:
			var mat := ShaderMaterial.new()
			mat.shader = BLUR_SHADER
			backdrop.material = mat

	for node in find_children("*", "Label", true, false):
		(node as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var title := get_node_or_null("%Title") as Label
	if title:
		title.theme_type_variation = &"HeaderLarge"

	for node_name in SLIDERS:
		var slider := get_node_or_null("%" + node_name) as HSlider
		if slider == null:
			continue
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.custom_minimum_size.x = slider_width
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var value_label := get_node_or_null("%" + node_name.replace("Slider", "Value")) as Label
		if value_label:
			value_label.theme_type_variation = &"DimLabel"
			value_label.custom_minimum_size.x = 80.0
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	for node in find_children("*", "CheckButton", true, false):
		var check := node as CheckButton
		check.text = ""
		check.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		check.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var footer := get_node_or_null("%Footer") as BoxContainer
	if footer:
		footer.alignment = BoxContainer.ALIGNMENT_END

	for node in find_children("*", "TabContainer", true, false):
		(node as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL


func _connect_controls() -> void:
	for node_name in SLIDERS:
		var slider := get_node_or_null("%" + node_name) as Range
		if slider:
			slider.value_changed.connect(_on_slider_changed.bind(node_name))
	for node_name in TOGGLES:
		var toggle := get_node_or_null("%" + node_name) as BaseButton
		if toggle:
			toggle.toggled.connect(_on_toggle_changed.bind(TOGGLES[node_name]))
	for node_name in STEER_TOGGLES:
		var toggle := get_node_or_null("%" + node_name) as BaseButton
		if toggle:
			toggle.toggled.connect(_on_steer_toggled.bind(STEER_TOGGLES[node_name]))

	back_button.pressed.connect(close)
	if reset_button:
		reset_button.pressed.connect(_on_reset)


func _sync_from_settings() -> void:
	for node_name in SLIDERS:
		var slider := get_node_or_null("%" + node_name) as Range
		if slider:
			var value: float = Settings.get(SLIDERS[node_name])
			slider.set_value_no_signal(value)
			_update_value_label(node_name, value)
	for node_name in TOGGLES:
		var toggle := get_node_or_null("%" + node_name) as BaseButton
		if toggle:
			toggle.set_pressed_no_signal(Settings.get(TOGGLES[node_name]))
	for node_name in STEER_TOGGLES:
		var toggle := get_node_or_null("%" + node_name) as BaseButton
		if toggle:
			toggle.set_pressed_no_signal(Settings.get(STEER_TOGGLES[node_name]))


func _on_slider_changed(value: float, node_name: String) -> void:
	Settings.set(SLIDERS[node_name], value)
	Settings.apply()
	_update_value_label(node_name, value)


func _on_toggle_changed(pressed: bool, key: String) -> void:
	Settings.set(key, pressed)
	Settings.apply()


func _on_steer_toggled(pressed: bool, key: String) -> void:
	Settings.set(key, pressed)
	if not Settings.keyboard_steering and not Settings.mouse_steering:
		var other := "mouse_steering" if key == "keyboard_steering" else "keyboard_steering"
		Settings.set(other, true)
		_sync_from_settings()


func _on_reset() -> void:
	Settings.reset_to_defaults()
	_sync_from_settings()


func _update_value_label(node_name: String, value: float) -> void:
	var label := get_node_or_null("%" + node_name.replace("Slider", "Value")) as Label
	if label:
		label.text = "%d%%" % roundi(value * 100.0)


func _set_backdrop(value: float) -> void:
	if backdrop == null:
		return
	var mat := backdrop.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("amount", value)


func _restart_tween() -> void:
	if tween and tween.is_valid():
		tween.kill()
	tween = create_tween().set_parallel()
