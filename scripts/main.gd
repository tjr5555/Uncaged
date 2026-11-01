extends Node2D

const FOG_SHADER = preload("res://shaders/fog.gdshader")

@export var fog_in_time := 0.9
@export var fog_out_time := 1.8
@export var min_fog_hold := 0.4
@export var max_fog_hold := 4.0
@export var ready_radius := 6000.0
@export var arrival_cooldown := 1.5
@export var min_arrival_speed := 900.0

@onready var world_root: Node2D = $World
@onready var player = $player
@onready var ui = $UI

var hub: Node2D
var current_world: Node2D
var fog: ColorRect
var fog_material: ShaderMaterial
var fog_tween: Tween
var transitioning := false
var cooldown_until := 0.0


func _ready() -> void:
	add_to_group("world_manager")
	player.boost_changed.connect(ui.set_boost)

	if world_root.get_child_count() > 0:
		hub = world_root.get_child(0) as Node2D
	current_world = hub
	_create_fog()


func can_enter_portal() -> bool:
	return not transitioning and _now() >= cooldown_until


func enter_portal(portal: Portal) -> void:
	if not can_enter_portal():
		return
	transitioning = true
	Global.in_transition = true

	var player_velocity: Vector2 = player.velocity
	var arrival_speed := maxf(player_velocity.length(), min_arrival_speed)

	_set_fog_tint(portal.fog_tint)
	portal.play_enter_effect()
	player.begin_portal_entry(portal.get_entry_point(player.global_position))

	var fog_in := _fog_to(1.0, fog_in_time)
	await player.portal_reached
	if fog_in.is_running():
		await fog_in.finished

	var arrival := _swap_world(portal)
	var arrival_pos := Vector2.ZERO
	var exit_dir := player_velocity.normalized() if player_velocity.length() > 10.0 else Vector2.RIGHT
	if arrival != null:
		arrival_pos = arrival.global_position
		exit_dir = arrival.get_front()
	player.hold_at(arrival_pos)

	_set_burst(true)
	await _wait_until_ready()
	_set_burst(false)

	if arrival != null:
		arrival.play_exit_effect()
	player.emerge(arrival_pos, exit_dir, arrival_speed)
	cooldown_until = _now() + arrival_cooldown

	await _fog_to(0.0, fog_out_time).finished
	Global.in_transition = false
	transitioning = false


func _swap_world(portal: Portal) -> Portal:
	if current_world == hub:
		world_root.remove_child(hub)
	elif current_world != null:
		current_world.queue_free()

	if portal.leads_to_hub:
		if hub.get_parent() == null:
			world_root.add_child(hub)
		current_world = hub
		return _find_portal(hub, Global.return_portal_id, false)

	Global.return_portal_id = portal.portal_id
	var world := portal.destination_scene.instantiate() as Node2D
	var generator = _find_generator(world)
	if generator != null:
		generator.set("world_seed", portal.destination_seed if portal.destination_seed != 0 else randi())
	world_root.add_child(world)
	current_world = world
	return _find_portal(world, "", true)


func _find_portal(root: Node, id: String, to_hub: bool) -> Portal:
	for node in root.find_children("*", "Node2D", true, false):
		var p := node as Portal
		if p == null:
			continue
		if to_hub and p.leads_to_hub:
			return p
		if not to_hub and p.portal_id == id:
			return p
	return null


func _find_generator(root: Node) -> Node:
	if root == null:
		return null
	if root.has_method("pending_near"):
		return root
	for node in root.find_children("*", "", true, false):
		if node.has_method("pending_near"):
			return node
	return null


func _set_burst(enabled: bool) -> void:
	var generator = _find_generator(current_world)
	if generator != null:
		generator.set("burst", enabled)


func _wait_until_ready() -> void:
	var waited := 0.0
	while waited < max_fog_hold:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if waited < min_fog_hold:
			continue
		var generator = _find_generator(current_world)
		if generator == null or generator.pending_near(player.global_position, ready_radius) == 0:
			return


func _create_fog() -> void:
	fog = ColorRect.new()
	fog.name = "Fog"
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog_material = ShaderMaterial.new()
	fog_material.shader = FOG_SHADER
	fog_material.set_shader_parameter("coverage", 0.0)
	fog.material = fog_material
	fog.visible = false
	ui.add_child(fog)

	var speed_lines = ui.get_node_or_null("SpeedLines")
	ui.move_child(fog, speed_lines.get_index() + 1 if speed_lines != null else 0)


func _set_fog_tint(tint: Color) -> void:
	fog_material.set_shader_parameter("fog_color", tint)
	fog_material.set_shader_parameter("shade_color", tint.darkened(0.2))

func _fog_to(target: float, time: float) -> Tween:
	fog.visible = true
	if fog_tween and fog_tween.is_valid():
		fog_tween.kill()
	var current := float(fog_material.get_shader_parameter("coverage"))
	fog_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fog_tween.tween_method(_set_fog_coverage, current, target, time)
	if target <= 0.0:
		fog_tween.tween_callback(func(): fog.visible = false)
	return fog_tween

func _set_fog_coverage(value: float) -> void:
	fog_material.set_shader_parameter("coverage", value)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
