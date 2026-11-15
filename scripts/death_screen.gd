extends CanvasLayer

const BLUR_SHADER = preload("res://shaders/ui_blur.gdshader")

@export_range(0.0, 1.0) var coin_loss := 0.5
@export var slowmo_time := 0.6
@export var death_sound: AudioStream

var root: Control
var backdrop: ColorRect
var backdrop_material: ShaderMaterial
var panel: PanelContainer
var lost_label: Label
var respawn_button: Button
var tween: Tween
var showing := false
var audio := AudioStreamPlayer.new()


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("death_screen")
	add_child(audio)
	audio.bus = "SFX"
	_build()
	visible = false
	_connect_health.call_deferred()


func _connect_health() -> void:
	var health = get_tree().get_first_node_in_group("player_health")
	if health == null:
		push_warning("DeathScreen: no Health node found on the player.")
		return
	health.died.connect(_on_died)


func _on_died() -> void:
	if showing:
		return
	showing = true
	Global.in_transition = true
	if death_sound:
		audio.stream = death_sound
		audio.play()
	else:
		Sfx.play("faint")

	Engine.time_scale = 0.3
	await get_tree().create_timer(slowmo_time, true, false, true).timeout
	Engine.time_scale = 1.0
	get_tree().paused = true

	var lost := int(floor(float(Global.total_coins) * coin_loss))
	Global.total_coins -= lost
	SaveManager.save_game()
	lost_label.text = ("You dropped %s coins" % _format(lost)) if lost > 0 else "You had no coins to drop"
	_open()


func _open() -> void:
	visible = true
	respawn_button.disabled = false
	panel.pivot_offset = panel.size * 0.5
	panel.modulate.a = 0.0
	panel.scale = Vector2.ONE * 0.9
	if tween and tween.is_valid():
		tween.kill()
	tween = create_tween().set_parallel()
	tween.tween_method(_set_blur, 0.0, 1.0, 0.5)
	tween.tween_property(panel, "modulate:a", 1.0, 0.35).set_delay(0.2)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.45).set_delay(0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	respawn_button.grab_focus()


func _on_respawn_pressed() -> void:
	if not showing:
		return
	respawn_button.disabled = true
	get_tree().paused = false
	if tween and tween.is_valid():
		tween.kill()
	tween = create_tween().set_parallel()
	tween.tween_property(panel, "modulate:a", 0.0, 0.2)
	tween.tween_method(_set_blur, 1.0, 0.0, 0.4)
	tween.chain().tween_callback(func(): visible = false)

	var manager = get_tree().get_first_node_in_group("world_manager")
	if manager and manager.has_method("respawn_player"):
		manager.respawn_player()
	else:
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("respawn_at"):
			player.respawn_at(player.last_grounded_pos)
		Global.in_transition = false
	showing = false


func _build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.build()
	add_child(root)

	backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop_material = ShaderMaterial.new()
	backdrop_material.shader = BLUR_SHADER
	backdrop_material.set_shader_parameter("amount", 0.0)
	backdrop.material = backdrop_material
	root.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)

	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 48)
	padding.add_theme_constant_override("margin_right", 48)
	padding.add_theme_constant_override("margin_top", 36)
	padding.add_theme_constant_override("margin_bottom", 40)
	panel.add_child(padding)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	padding.add_child(box)

	var title := Label.new()
	title.text = "You fainted"
	title.theme_type_variation = &"HeaderLarge"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	lost_label = Label.new()
	lost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lost_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	box.add_child(lost_label)

	var hint := Label.new()
	hint.text = "You'll wake up back at the hub."
	hint.theme_type_variation = &"DimLabel"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 12)
	box.add_child(gap)

	respawn_button = Button.new()
	respawn_button.text = "Respawn"
	respawn_button.custom_minimum_size = Vector2(280, 64)
	respawn_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	respawn_button.pressed.connect(_on_respawn_pressed)
	box.add_child(respawn_button)

func _set_blur(value: float) -> void:
	backdrop_material.set_shader_parameter("amount", value)


func _format(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return digits + out
