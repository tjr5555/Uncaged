extends Node2D

const GAS_SHADER = preload("res://shaders/gas.gdshader")

@export var safe_radius := 7500.0
@export var warning_distance := 1000.0
@export var gas_depth := 3000.0
@export var min_damage_per_second := 2.0
@export var max_damage_per_second := 45.0
@export var damage_curve := 1.8

@export_group("Look")
@export var gas_color := Color(0.55, 0.25, 0.85)
@export var gas_shade := Color(0.25, 0.08, 0.4)
@export var edge_softness := 450.0
@export var noise_scale := 900.0
@export var drift_speed := 60.0
@export var warning_text := "Toxic gas ahead. Turn back."
@export var inside_text := "Get out of the gas!"

var layer: CanvasLayer
var gas_rect: ColorRect
var gas_material: ShaderMaterial
var warning_label: Label
var player: Node2D
var health: Node
var warn_amount := 0.0
var inside_amount := 0.0
var warned := false
var gas_tick_timer := 0.0

func _ready() -> void:
	layer = CanvasLayer.new()
	layer.layer = 1
	add_child(layer)

	gas_rect = ColorRect.new()
	gas_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gas_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gas_material = ShaderMaterial.new()
	gas_material.shader = GAS_SHADER
	gas_rect.material = gas_material
	layer.add_child(gas_rect)

	warning_label = Label.new()
	warning_label.text = warning_text
	warning_label.add_theme_font_size_override("font_size", 32)
	warning_label.add_theme_color_override("font_color", gas_color.lightened(0.45))
	warning_label.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.1, 0.85))
	warning_label.add_theme_constant_override("outline_size", 8)
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warning_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	warning_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	warning_label.offset_top = 140.0
	warning_label.modulate.a = 0.0
	layer.add_child(warning_label)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
		if player == null:
			return
		health = player.get_node_or_null("Health")

	var depth := player.global_position.distance_to(global_position) - safe_radius

	var warn_target := 1.0 if depth >= 0.0 else clampf(1.0 + depth / warning_distance, 0.0, 1.0)
	warn_amount = move_toward(warn_amount, warn_target, delta * 2.0)
	var inside_target := clampf(depth / gas_depth, 0.0, 1.0) if depth > 0.0 else 0.0
	inside_amount = lerpf(inside_amount, inside_target, 1.0 - exp(-3.0 * delta))

	if warn_target > 0.0 and not warned and not Global.in_transition:
		warned = true
		Sfx.play("gas_warning")
	elif warn_target <= 0.0:
		warned = false

	if depth > 0.0 and health != null and not Global.in_transition:
		var t := clampf(depth / gas_depth, 0.0, 1.0)
		var dps := lerpf(min_damage_per_second, max_damage_per_second, pow(t, damage_curve))
		health.damage(dps * delta, "gas", true)
		gas_tick_timer -= delta
		if gas_tick_timer <= 0.0:
			gas_tick_timer = lerpf(0.9, 0.35, t)
			Sfx.play("gas_tick", lerpf(0.9, 1.15, t), lerpf(-8.0, 0.0, t))
	else:
		gas_tick_timer = 0.0

	var time := Time.get_ticks_msec() / 1000.0
	warning_label.text = inside_text if depth > 0.0 else warning_text
	warning_label.modulate.a = warn_amount * (0.6 + 0.4 * (0.5 + 0.5 * sin(time * 5.0)))

	_update_shader()

func _update_shader() -> void:
	var canvas_xf := get_viewport().get_canvas_transform()
	var inv := canvas_xf.affine_inverse()
	var view := get_viewport().get_visible_rect().size
	var per_pixel := 1.0 / maxf(canvas_xf.get_scale().x, 0.0001)

	var view_center: Vector2 = inv * (view * 0.5)
	var half_diag := (view * per_pixel * 0.5).length()
	var reach := view_center.distance_to(global_position) + half_diag
	gas_rect.visible = reach > safe_radius - edge_softness * 2.0 or warn_amount > 0.01
	if not gas_rect.visible:
		return

	gas_material.set_shader_parameter("world_top_left", inv * Vector2.ZERO)
	gas_material.set_shader_parameter("world_per_pixel", per_pixel)
	gas_material.set_shader_parameter("screen_size", view)
	gas_material.set_shader_parameter("center", global_position)
	gas_material.set_shader_parameter("radius", safe_radius)
	gas_material.set_shader_parameter("edge_softness", edge_softness)
	gas_material.set_shader_parameter("gas_depth", gas_depth)
	gas_material.set_shader_parameter("noise_scale", noise_scale)
	gas_material.set_shader_parameter("drift_speed", drift_speed)
	gas_material.set_shader_parameter("gas_color", gas_color)
	gas_material.set_shader_parameter("gas_shade", gas_shade)
	gas_material.set_shader_parameter("inside", inside_amount)
	gas_material.set_shader_parameter("warn", warn_amount)
