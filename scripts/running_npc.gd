extends CharacterBody2D

enum Mode { GROUND, FLY }

@export_group("Islands")
@export var island_group := "islands"
@export var island_reach := 400.0
@export var min_trip_distance := 1500.0
@export var recent_memory := 4
@export var walk_max_distance := 700.0
@export var walk_max_height_diff := 120.0
@export_range(0.0, 1.0) var walk_chance := 0.85
@export var fallback_radius := 1400.0
@export var void_depth := 2500.0

@export_group("Roaming")
@export var roam_legs_range := Vector2i(2, 4)
@export var roam_leg_time_range := Vector2(1.0, 2.5)
@export var roam_pause_range := Vector2(0.4, 1.4)
@export var ledge_probe_ahead := 70.0
@export var ledge_probe_depth := 220.0

@export_group("Sprite")
@export var sprite_faces_left := false

const SPEED = 260.0
const HOP_VELOCITY = -220.0
const HOP_INTERVAL = 0.12
const BASE_GRAVITY = 1200.0
const INCREASED_GRAVITY = 1800.0
const FRICTION = 3000.0
const AIR_FRICTION = 1500.0
const TAKEOFF_VELOCITY = -450.0

const FLY_CRUISE_SPEED = 650.0
const FLY_MAX_SPEED = 1400.0
const FLY_MIN_SPEED = 400.0
const FLY_ACCEL = 700.0
const FLY_DRAG = 450.0
const FLY_TURN_RATE = 3.2
const FLY_TURN_ACCEL = 30.0
const FLY_DIVE_GAIN = 900.0
const FLY_CLIMB_COST = 800.0
const FLY_VELOCITY_SMOOTH = 24.0
const FLY_FLIP_SPEED = 14.0
const FLY_BOUNCE_LOSS = 0.2
const FLY_BOUNCE_MIN_SPEED = 120.0
const FLY_BOUNCE_RECOVERY = 350.0
const FLY_BOUNCE_ACCEL_MULT = 0.35

const HOVER_HEIGHT = 150.0
const SLOW_DISTANCE = 900.0
const GLIDE_DISTANCE = 350.0
const GLIDE_SPEED = 450.0
const GLIDE_ARRIVE = 40.0
const STALL_TIME = 3.0
const ARRIVE_X = 30.0
const ARRIVE_Y = 300.0
const WALK_TIMEOUT = 8.0
const WALK_STALL_TIME = 2.0
const TRIP_TIMEOUT = 20.0
const FALL_TIME = 0.45
const MIN_ISLAND_SEPARATION = 150.0

@onready var bird: Sprite2D = $Sprite2D
@onready var base_scale: Vector2 = bird.scale

var mode := Mode.GROUND
var home: Vector2
var last_safe: Vector2
var limit_y := 0.0

var dest := Vector2.ZERO
var recent: Array[Vector2] = []
var traveling := false
var arrived := false
var trip_timer := 0.0
var travel_timer := 0.0
var rest_timer := 0.0
var air_time := 0.0

var move_dir := 0.0
var hop_timer := 0.0
var walk_best := INF
var walk_stall := 0.0
var roam_legs := 0
var roam_dir := 0.0
var roam_timer := 0.0

var heading := 0.0
var speed := 0.0
var speed_floor := FLY_MIN_SPEED
var turn_speed := 0.0
var flip_amount := 1.0
var best_dist := INF
var stall_timer := 0.0
var landing := false
var glide_timer := 0.0
var glide_limit := 0.0


func _ready() -> void:
	home = global_position
	last_safe = global_position
	limit_y = _void_limit()
	randomize()
	roam_legs = randi_range(roam_legs_range.x, roam_legs_range.y)
	rest_timer = randf_range(0.2, 1.0)
	_enter_ground()


func _physics_process(delta: float) -> void:
	if global_position.y > limit_y:
		_recover()
		return

	if traveling:
		trip_timer += delta
		if trip_timer > TRIP_TIMEOUT:
			_reroll()

	match mode:
		Mode.GROUND:
			_ground_physics(delta)
		Mode.FLY:
			_fly_physics(delta)


func _void_limit() -> float:
	var lowest := home.y
	for n in get_tree().get_nodes_in_group(island_group):
		var island := n as Node2D
		if island != null:
			lowest = maxf(lowest, island.global_position.y)
	return lowest + void_depth


func _on_island() -> bool:
	var any := false
	var nearest := INF
	for n in get_tree().get_nodes_in_group(island_group):
		var island := n as Node2D
		if island == null:
			continue
		any = true
		nearest = minf(nearest, global_position.distance_to(island.global_position))
	return not any or nearest <= island_reach


func _recover() -> void:
	global_position = last_safe
	velocity = Vector2.ZERO
	_enter_ground()
	traveling = false
	arrived = false
	move_dir = 0.0
	roam_dir = 0.0
	roam_timer = 0.0
	roam_legs = randi_range(roam_legs_range.x, roam_legs_range.y)
	rest_timer = 1.0


func _pick_destination() -> Vector2:
	var all: Array[Node2D] = []
	for n in get_tree().get_nodes_in_group(island_group):
		var island := n as Node2D
		if island != null and island.global_position.distance_to(global_position) > MIN_ISLAND_SEPARATION:
			all.append(island)
	if all.is_empty():
		return home + Vector2.from_angle(randf() * TAU) * randf_range(300.0, fallback_radius)

	var fresh: Array[Node2D] = []
	for island in all:
		if not recent.has(island.global_position):
			fresh.append(island)
	if fresh.is_empty():
		recent.clear()
		fresh = all

	var far: Array[Node2D] = []
	for island in fresh:
		if island.global_position.distance_to(global_position) >= min_trip_distance:
			far.append(island)

	var chosen: Node2D
	if not far.is_empty():
		chosen = far.pick_random()
	else:
		fresh.sort_custom(func(a: Node2D, b: Node2D) -> bool:
			return a.global_position.distance_to(global_position) > b.global_position.distance_to(global_position))
		chosen = fresh[randi() % maxi(1, int(fresh.size() * 0.5))]

	recent.append(chosen.global_position)
	while recent.size() > recent_memory:
		recent.pop_front()
	return chosen.global_position


func _begin_trip() -> void:
	traveling = true
	_reroll()


func _reroll(force_fly := false) -> void:
	dest = _pick_destination()
	trip_timer = 0.0
	travel_timer = 0.0
	arrived = false
	landing = false
	best_dist = INF
	stall_timer = 0.0
	walk_best = INF
	walk_stall = 0.0
	if mode == Mode.GROUND:
		var to := dest - global_position
		var can_walk := absf(to.x) <= walk_max_distance and absf(to.y) <= walk_max_height_diff
		if force_fly or not (can_walk and randf() < walk_chance):
			_take_off()


func _finish_trip() -> void:
	traveling = false
	arrived = false
	move_dir = 0.0
	roam_dir = 0.0
	roam_timer = 0.0
	roam_legs = randi_range(roam_legs_range.x, roam_legs_range.y)
	rest_timer = randf_range(roam_pause_range.x, roam_pause_range.y)


func _ledge_ahead(direction: float) -> bool:
	if direction == 0.0:
		return false
	var from := global_position + Vector2(direction * ledge_probe_ahead, 0.0)
	var query := PhysicsRayQueryParameters2D.create(
		from, from + Vector2(0.0, ledge_probe_depth), collision_mask, [get_rid()])
	query.hit_from_inside = true
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _enter_ground() -> void:
	mode = Mode.GROUND
	motion_mode = MOTION_MODE_GROUNDED
	bird.rotation = 0.0
	bird.scale = base_scale
	bird.flip_v = false
	landing = false
	air_time = 0.0
	travel_timer = 0.0
	walk_best = INF
	walk_stall = 0.0


func _ground_physics(delta: float) -> void:
	var on_floor := is_on_floor()
	hop_timer = maxf(hop_timer - delta, 0.0)

	if on_floor:
		air_time = 0.0
		last_safe = global_position
	else:
		air_time += delta
		if air_time > FALL_TIME and not traveling:
			traveling = true
			_reroll(true)
			return

	if traveling:
		travel_timer += delta
		var to := dest - global_position

		if absf(to.x) < ARRIVE_X and absf(to.y) <= ARRIVE_Y:
			arrived = true

		if arrived:
			move_dir = 0.0
			if on_floor:
				_finish_trip()
		else:
			if on_floor and absf(to.x) < ARRIVE_X:
				_take_off()
				return
			move_dir = signf(to.x)

			var d := absf(to.x)
			if d < walk_best - 8.0:
				walk_best = d
				walk_stall = 0.0
			else:
				walk_stall += delta

			var blocked := is_on_wall() and move_dir != 0.0 and signf(get_wall_normal().x) == -signf(move_dir)
			if blocked or _ledge_ahead(move_dir) or air_time > FALL_TIME or travel_timer > WALK_TIMEOUT or walk_stall > WALK_STALL_TIME:
				_take_off()
				return
	elif roam_timer > 0.0:
		roam_timer -= delta
		var wall_ahead := is_on_wall() and signf(get_wall_normal().x) == -signf(roam_dir)
		if wall_ahead or _ledge_ahead(roam_dir):
			roam_dir = -roam_dir
			if _ledge_ahead(roam_dir):
				roam_dir = 0.0
		move_dir = roam_dir
		if roam_timer <= 0.0 or roam_dir == 0.0:
			roam_timer = 0.0
			roam_dir = 0.0
			move_dir = 0.0
			rest_timer = randf_range(roam_pause_range.x, roam_pause_range.y)
	else:
		move_dir = 0.0
		rest_timer -= delta
		if rest_timer <= 0.0 and on_floor:
			if roam_legs > 0:
				roam_legs -= 1
				roam_dir = [-1.0, 1.0].pick_random()
				roam_timer = randf_range(roam_leg_time_range.x, roam_leg_time_range.y)
			else:
				_begin_trip()
				if mode != Mode.GROUND:
					return

	if move_dir != 0.0:
		_face(move_dir)

	if not on_floor:
		velocity.y += (INCREASED_GRAVITY if velocity.y > 0.0 else BASE_GRAVITY) * delta

	if on_floor and move_dir != 0.0 and hop_timer <= 0.0:
		velocity.y = HOP_VELOCITY
		hop_timer = HOP_INTERVAL

	var accel := FRICTION if on_floor else AIR_FRICTION
	velocity.x = move_toward(velocity.x, move_dir * SPEED, accel * delta)

	move_and_slide()


func _face(direction: float) -> void:
	bird.flip_h = (direction < 0.0) != sprite_faces_left


func _take_off() -> void:
	var to_dest_x := dest.x - global_position.x
	velocity.y = TAKEOFF_VELOCITY
	mode = Mode.FLY
	motion_mode = MOTION_MODE_FLOATING
	heading = -PI / 4.0 if to_dest_x >= 0.0 else -3.0 * PI / 4.0
	speed = maxf(velocity.length(), FLY_CRUISE_SPEED)
	speed_floor = FLY_MIN_SPEED
	turn_speed = 0.0
	flip_amount = 1.0 if cos(heading) >= 0.0 else -1.0
	traveling = true
	arrived = false
	landing = false
	roam_dir = 0.0
	roam_timer = 0.0
	best_dist = INF
	stall_timer = 0.0
	bird.flip_h = sprite_faces_left
	bird.flip_v = false


func _fly_physics(delta: float) -> void:
	var to_dest := dest - global_position
	var dist := to_dest.length()

	if landing:
		_glide_physics(delta, to_dest, dist)
		return

	if dist < best_dist - 1.0:
		best_dist = dist
		stall_timer = 0.0
	else:
		stall_timer += delta

	if dist < GLIDE_DISTANCE or stall_timer > STALL_TIME:
		landing = true
		glide_timer = 0.0
		glide_limit = 3.0 + dist / GLIDE_SPEED
		return

	speed_floor = move_toward(speed_floor, FLY_MIN_SPEED, FLY_BOUNCE_RECOVERY * delta)

	var aim := dest + Vector2(0.0, -HOVER_HEIGHT)
	var diff := angle_difference(heading, (aim - global_position).angle())
	var target_turn := clampf(diff * 5.0, -FLY_TURN_RATE, FLY_TURN_RATE)
	turn_speed = move_toward(turn_speed, target_turn, FLY_TURN_ACCEL * delta)
	heading = wrapf(heading + turn_speed * delta, -PI, PI)

	var heading_vec := Vector2.from_angle(heading)

	var target_speed := lerpf(FLY_MIN_SPEED, FLY_CRUISE_SPEED, smoothstep(GLIDE_DISTANCE, SLOW_DISTANCE, dist))
	var accel := FLY_DRAG if speed > target_speed else FLY_ACCEL
	if speed_floor < FLY_MIN_SPEED:
		accel *= FLY_BOUNCE_ACCEL_MULT

	if heading_vec.y > 0.0:
		var headroom := 1.0 - smoothstep(FLY_MAX_SPEED * 0.75, FLY_MAX_SPEED, speed)
		speed += heading_vec.y * FLY_DIVE_GAIN * headroom * delta
	else:
		speed += heading_vec.y * FLY_CLIMB_COST * delta
	speed = move_toward(speed, target_speed, accel * delta)
	speed = clampf(speed, speed_floor, FLY_MAX_SPEED)

	velocity = velocity.lerp(heading_vec * speed, 1.0 - exp(-FLY_VELOCITY_SMOOTH * delta))
	move_and_slide()

	if get_slide_collision_count() > 0:
		var normal := get_last_slide_collision().get_normal()
		var impact := -heading_vec.dot(normal)
		if impact > 0.0:
			heading_vec = heading_vec.bounce(normal)
			heading = heading_vec.angle()
			speed = maxf(speed * lerpf(1.0, FLY_BOUNCE_LOSS, impact), FLY_BOUNCE_MIN_SPEED)
			speed_floor = FLY_BOUNCE_MIN_SPEED
			velocity = heading_vec * speed

	_update_fly_sprite(delta)


func _glide_physics(delta: float, to_dest: Vector2, dist: float) -> void:
	glide_timer += delta
	if glide_timer > glide_limit:
		_reroll()
		return

	var dir := to_dest / dist if dist > 0.001 else Vector2.DOWN
	speed = move_toward(speed, GLIDE_SPEED, FLY_DRAG * delta)
	velocity = velocity.lerp(dir * speed, 1.0 - exp(-8.0 * delta))
	heading = lerp_angle(heading, dir.angle(), 1.0 - exp(-8.0 * delta))
	move_and_slide()
	_update_fly_sprite(delta)

	for i in get_slide_collision_count():
		if get_slide_collision(i).get_normal().y < -0.6:
			_try_land()
			return
	if dist < GLIDE_ARRIVE:
		_try_land()


func _try_land() -> void:
	if not _on_island():
		_reroll()
		return
	velocity = Vector2(velocity.x * 0.3, maxf(velocity.y, 0.0))
	_enter_ground()
	arrived = true


func _update_fly_sprite(delta: float) -> void:
	var facing := 1.0 if cos(heading) >= 0.0 else -1.0
	flip_amount = move_toward(flip_amount, facing, FLY_FLIP_SPEED * delta)
	bird.rotation = heading
	bird.flip_h = sprite_faces_left
	bird.flip_v = false
	bird.scale = Vector2(base_scale.x, base_scale.y * flip_amount)
