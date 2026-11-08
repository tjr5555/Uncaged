extends Node2D

const GAME_SCENE = "res://scenes/main.tscn"

const SKY_PALETTES = [
	{"top": Color(0.26, 0.5, 0.92), "horizon": Color(0.62, 0.76, 0.92)},
	{"top": Color(0.25, 0.58, 0.86), "horizon": Color(0.74, 0.88, 0.9)},
	{"top": Color(0.32, 0.46, 0.8), "horizon": Color(0.96, 0.78, 0.62)},
	{"top": Color(0.24, 0.3, 0.62), "horizon": Color(0.86, 0.58, 0.64)},
]
const SKY_FADE_TIME = 8.0
const SKY_HOLD_TIME = 6.0
const CONFIRM_TIME = 3.0

@onready var sky_rect: ColorRect = $backRect
@onready var menu_world = get_node_or_null("MenuWorld")
@onready var continue_button: Button = find_child("continueButton", true, false)
@onready var enter_button: Button = find_child("enterButton", true, false)

var sky_material: ShaderMaterial
var palette_index := 0
var confirm_new_game := false

func _ready() -> void:
	sky_rect.position = Vector2.ZERO
	sky_rect.size = get_viewport_rect().size
	sky_material = sky_rect.material as ShaderMaterial
	if sky_material:
		sky_material.set_shader_parameter("screen_size", sky_rect.size)
		_apply_palette(0.0, SKY_PALETTES[0], SKY_PALETTES[0])
		_cycle_sky()
	_setup_save_buttons()
	SceneFader.preload_scene(GAME_SCENE)

func _setup_save_buttons() -> void:
	var has_save: bool = SaveManager.has_save()
	if continue_button:
		continue_button.visible = has_save
		if not continue_button.pressed.is_connected(_on_continue_button_pressed):
			continue_button.pressed.connect(_on_continue_button_pressed)
	else:
		push_error("MainMenu: no node named 'continueButton' found")
	if enter_button:
		enter_button.text = "New Game" if has_save else "Play"
	else:
		push_error("MainMenu: no node named 'enterButton' was found")

func _cycle_sky() -> void:
	var from: Dictionary = SKY_PALETTES[palette_index]
	palette_index = (palette_index + 1) % SKY_PALETTES.size()
	var to: Dictionary = SKY_PALETTES[palette_index]
	
	var tween := create_tween()
	tween.tween_method(_apply_palette.bind(from, to), 0.0, 1.0, SKY_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_cycle_sky)

func _apply_palette(t: float, from: Dictionary, to: Dictionary) -> void:
	var top: Color = (from["top"] as Color).lerp(to["top"], t)
	var horizon: Color = (from["horizon"] as Color).lerp(to["horizon"], t)
	sky_material.set_shader_parameter("top_color", top)
	sky_material.set_shader_parameter("horizon_color", horizon)
	if menu_world:
		menu_world.haze_color = horizon.lerp(Color.WHITE, 0.25)

func _on_continue_button_pressed() -> void:
	if not SaveManager.load_game():
		SaveManager.new_game()
	SceneFader.change_scene(GAME_SCENE)

func _on_enter_button_pressed() -> void:
	if SaveManager.has_save() and not confirm_new_game:
		confirm_new_game = true
		enter_button.text = "Overwrite save?"
		get_tree().create_timer(CONFIRM_TIME).timeout.connect(_reset_new_game_confirm)
		return
	SaveManager.new_game()
	SceneFader.change_scene(GAME_SCENE)

func _reset_new_game_confirm() -> void:
	confirm_new_game = false
	if enter_button:
		enter_button.text = "New Game"

func _on_settings_button_pressed() -> void:
	$Overlay/SettingsPanel.open()

func _on_quit_button_pressed() -> void:
	SaveManager.save_game()
	get_tree().quit()

func _on_tutorial_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/tutorial.scn")
