class_name Portal
extends Node2D

const PORTAL_SHADER = preload("res://shaders/portal.gdshader")
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

var portal_material: ShaderMaterial
var pulse_tween: Tween


func _ready() -> void:
	add_to_group("portals")

	var visual := ColorRect.new()
	visual.size = Vector2(visual_width, visual_height)
	visual.position = -visual.size * 0.5
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portal_material = ShaderMaterial.new()
	portal_material.shader = PORTAL_SHADER
	portal_material.set_shader_parameter("core_color", color)
	portal_material.set_shader_parameter("rim_color", color.lerp(Color.WHITE, 0.7))
	portal_material.set_shader_parameter("facing", -1.0 if face_left else 1.0)
	portal_material.set_shader_parameter("ellipse", ELLIPSE)
	portal_material.set_shader_parameter("pulse", 0.0)
	var grid := visual.size / pixel_size if pixel_size > 0.0 else Vector2.ZERO
	portal_material.set_shader_parameter("pixel_grid", grid)
	visual.material = portal_material
	add_child(visual)

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
