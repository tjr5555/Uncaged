class_name Portal
extends Node2D

const PORTAL_SHADER = preload("res://shaders/portal.gdshader")
const PORTAL_FOG_SHADER = preload("res://shaders/portal_fog.gdshader")
const ELLIPSE = Vector2(0.16, 0.46)

@export var portal_id := "portal_1"
@export var label_text := "Portal"
@export var leads_to_hub := false
@export var destination_scene: PackedScene
@export var destination_seed := 0
@export var color := Color(0.55, 0.35, 1.0)
@export var fog_tint := Color(0.93, 0.95, 1.0)

@export_group("Shape")
@export var face_left := false
@export var visual_width := 360.0
@export var visual_height := 420.0
@export var pixel_size := 4.0

@export_group("Entry")
@export var capture_depth := 220.0
@export_range(0.0, 180.0) var max_entry_angle := 70.0
@export var min_entry_speed := 150.0

@export_group("Ambience")
@export_range(0.0, 1.0) var fog_strength := 0.3
@export var fog_scale := Vector2(1.5, 1.35)
@export var mote_amount := 28
@export var sparkle_amount := 18

var portal_material: ShaderMaterial
var pulse_tween: Tween
var fog_material: ShaderMaterial
var motes: CPUParticles2D
var sparkles: CPUParticles2D


func _ready() -> void:
	add_to_group("portals")
	if not leads_to_hub and destination_scene == null:
		push_error("Portal '&s': no Destination Scene is set in the inspector" % name)
	var facing := -1.0 if face_left else 1.0
	
	_build_fog(facing)
	_build_visual(facing)
	motes = _build_motes(facing)
	sparkles = _build_sparkles()
	
	var waypoint := Waypoint.new()
	waypoint.label_text = label_text
	waypoint.color = color.lerp(Color.WHITE, 0.3)
	waypoint.hide_within = capture_depth
	add_child(waypoint)

func get_front() -> Vector2:
	return Vector2.from_angle(global_rotation) * (-1.0 if face_left else 1.0)

func get_entry_point(from: Vector2) -> Vector2:
	var up := get_front().orthogonal()
	var limit := _opening_half_height() * 0.6
	var along := clampf((from - global_position).dot(up), -limit, limit)
	return global_position + up * along


func _opening_half_height() -> float:
	return visual_height * ELLIPSE.y * 0.9


func _physics_process(_delta: float) -> void:
	if Global.in_transition:
		return
	if not leads_to_hub and destination_scene == null:
		return

	var manager = get_tree().get_first_node_in_group("world_manager")
	if manager == null or not manager.can_enter_portal():
		return

	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null:
		return

	var front := get_front()
	var rel := player.global_position - global_position
	var ahead := rel.dot(front)
	var along := rel.dot(front.orthogonal())
	if ahead < 0.0 or ahead > capture_depth:
		return
	if absf(along) > _opening_half_height():
		return

	var vel := player.velocity
	if vel.length() < min_entry_speed:
		return
	if rad_to_deg(absf(vel.angle_to(-front))) > max_entry_angle:
		return

	manager.enter_portal(self)


func play_enter_effect() -> void:
	_pulse(1.0, 0.25, 1.2)


func play_exit_effect() -> void:
	_pulse(0.8, 0.15, 1.0)

func _pulse(peak: float, up_time: float, down_time: float) -> void:
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
	var current := float(portal_material.get_shader_parameter("pulse"))
	pulse_tween = create_tween()
	pulse_tween.tween_method(_set_pulse, current, peak, up_time)
	pulse_tween.tween_method(_set_pulse, peak, 0.0, down_time)

func _set_pulse(value: float) -> void:
	portal_material.set_shader_parameter("pulse", value)
	if fog_material:
		fog_material.set_shader_parameter("strength", fog_strength * (1.0 + value * 1.5))
	if motes:
		motes.speed_scale = 1.0 + value * 2.0
	if sparkles:
		sparkles.speed_scale = 1.0 + value * 2.0

func _build_visual(facing: float) -> void:
	var visual := ColorRect.new()
	visual.size = Vector2(visual_width, visual_height)
	visual.position = -visual.size * 0.5
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portal_material = ShaderMaterial.new()
	portal_material.shader = PORTAL_SHADER
	portal_material.set_shader_parameter("core_color", color)
	portal_material.set_shader_parameter("rim_color", color.lerp(Color.WHITE, 0.7))
	portal_material.set_shader_parameter("facing", facing)
	portal_material.set_shader_parameter("ellipse", ELLIPSE)
	portal_material.set_shader_parameter("pixel_grid", visual.size / pixel_size if pixel_size > 0.0 else Vector2.ZERO)
	portal_material.set_shader_parameter("pulse", 0.0)
	visual.material = portal_material
	add_child(visual)


func _build_fog(facing: float) -> void:
	var rect := ColorRect.new()
	rect.size = Vector2(visual_width * fog_scale.x, visual_height * fog_scale.y)
	rect.position = -rect.size * 0.5
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog_material = ShaderMaterial.new()
	fog_material.shader = PORTAL_FOG_SHADER
	fog_material.set_shader_parameter("tint", color.lerp(fog_tint, 0.4))
	fog_material.set_shader_parameter("strength", fog_strength)
	fog_material.set_shader_parameter("facing", facing)
	fog_material.set_shader_parameter("pixel_grid", rect.size / pixel_size if pixel_size > 0.0 else Vector2.ZERO)
	rect.material = fog_material
	add_child(rect)


func _build_motes(facing: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	var oval_half_width := visual_width * ELLIPSE.x
	p.amount = mote_amount
	p.lifetime = 2.6
	p.preprocess = 2.6
	p.randomness = 0.5
	p.local_coords = false
	p.texture = _soft_dot_texture(16)
	p.material = _additive_material()
	p.position = Vector2(facing * oval_half_width * 0.4, 0.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(oval_half_width * 0.3, _opening_half_height() * 0.85)
	p.direction = Vector2(facing, 0.0)
	p.spread = 28.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 70.0
	p.damping_min = 8.0
	p.damping_max = 20.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.8
	p.scale_amount_curve = _shrink_curve()
	p.color_ramp = _fade_ramp(color.lerp(Color.WHITE, 0.45))
	add_child(p)
	return p


func _build_sparkles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	var half_width := visual_width * ELLIPSE.x
	var half_height := visual_height * ELLIPSE.y
	var rim := PackedVector2Array()
	for i in 32:
		var t := TAU * float(i) / 32.0
		rim.append(Vector2(cos(t) * half_width, sin(t) * half_height))

	p.amount = sparkle_amount
	p.lifetime = 1.4
	p.preprocess = 1.4
	p.randomness = 0.6
	p.local_coords = false
	p.texture = _soft_dot_texture(8)
	p.material = _additive_material()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	p.emission_points = rim
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2(0.0, -12.0)
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 20.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 0.9
	p.scale_amount_curve = _shrink_curve()
	p.color_ramp = _fade_ramp(color.lerp(Color.WHITE, 0.75))
	add_child(p)
	return p


func _soft_dot_texture(size: int) -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = size
	tex.height = size
	return tex


func _fade_ramp(start: Color) -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(start, 0.0))
	ramp.set_color(1, Color(start, 0.0))
	ramp.add_point(0.15, start)
	ramp.add_point(0.6, Color(start, start.a * 0.6))
	return ramp


func _shrink_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.3))
	return curve


func _additive_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat
