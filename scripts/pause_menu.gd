extends CanvasLayer

const BLUR_SHADER = preload("res://shaders/ui_blur.gdshader")

@export_file("*.tscn") var menu_scene := "res://scenes/main_menu.scn"
@export var panel_min_size := Vector2(480, 0)
@export var button_height := 64.0

@onready var backdrop: ColorRect = $Backdrop
@onready var root: Control = $Root
@onready var pause_panel: Control = %PausePanel
@onready var title: Label = %Title
@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var menu_button: Button = %MenuButton
@onready var quit_button: Button = %QuitButton
@onready var settings_panel: Control = %SettingsCompact

var tween: Tween
var is_open := false

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_setup_layout()
	_set_blur(0.0)
	
	resume_button.pressed.connect(close)
	settings_button.pressed.connect(_open_settings)
	menu_button.pressed.connect(_return_to_menu)
	quit_button.pressed.connect(_quit)
	settings_panel.closed.connect(_on_settings_closed)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if settings_panel.visible:
		return
	get_viewport().set_input_as_handled()
	if is_open:
		close()
	else:
		open()

func open() -> void:
	if is_open or Global.in_transition or SceneFader.busy:
		return
	is_open = true
	get_tree().paused = true
	visible = true
	pause_panel.visible = true
	pause_panel.pivot_offset = pause_panel.size * 0.5
	pause_panel.modulate.a = 0.0
	pause_panel.scale = Vector2.ONE * 0.92
	_restart_tween()
	tween.tween_method(_set_blur, 0.0, 1.0, 0.25)
	tween.tween_property(pause_panel, "modulate:a", 1.0, 0.2)
	tween.tween_property(pause_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	resume_button.grab_focus()

func close() -> void:
	if not is_open:
		return
	is_open = false
	get_tree().paused = false
	if settings_panel.visible:
		settings_panel.close()
	_restart_tween()
	tween.tween_method(_set_blur, _get_blur(), 0.0, 0.2)
	tween.tween_property(pause_panel, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(func(): visible = false)

func _setup_layout() -> void:
	root.theme = UiTheme.build()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	if backdrop.material == null:
		var mat := ShaderMaterial.new()
		mat.shader = BLUR_SHADER
		backdrop.material = mat

	pause_panel.custom_minimum_size = panel_min_size
	pause_panel.resized.connect(func(): pause_panel.pivot_offset = pause_panel.size * 0.5)

	title.theme_type_variation = &"HeaderLarge"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	for button: Button in [resume_button, settings_button, menu_button, quit_button]:
		button.custom_minimum_size.y = button_height

func _open_settings() -> void:
	_restart_tween()
	tween.tween_property(pause_panel, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(func(): pause_panel.visible = false)
	settings_panel.open()

func _on_settings_closed() -> void:
	if not is_open:
		return
	pause_panel.visible = true
	_restart_tween()
	tween.tween_property(pause_panel, "modulate:a", 1.0, 0.15)
	settings_button.grab_focus()

func _return_to_menu() -> void:
	SaveManager.save_game()
	is_open = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	SceneFader.change_scene(menu_scene)

func _restart_tween() -> void:
	if tween and tween.is_valid():
		tween.kill()
	tween = create_tween().set_parallel()

func _set_blur(value: float) -> void:
	var mat := backdrop.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("amount", value)
	backdrop.visible = value > 0.001

func _get_blur() -> float:
	var mat := backdrop.material as ShaderMaterial
	return float(mat.get_shader_parameter("amount")) if mat else 0.0

func _quit() -> void:
	SaveManager.save_game()
	get_tree().quit()
