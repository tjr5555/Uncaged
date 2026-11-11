extends CharacterBody2D
## A bird NPC that travels between islands, hopping when they're close and flying when they're not.
## It is NOT talkable: it has no interaction area and never joins any dialogue/interact group.
##
## Scene setup:
##   CharacterBody2D (this script) > Sprite2D (the Godot icon for now) + CollisionShape2D
##   Don't add an interaction Area2D to it.
##
## Islands: put a Marker2D (or any Node2D) on the surface of each island where the bird should
## stand, and add it to the group "islands" (Node tab > Groups). The bird picks one at random,
## goes there, rests a moment, then picks the next. With no islands in the group it just flies
## to random spots around where it spawned.

enum Mode { GROUND, FLY }

@export_group("Islands")
@export var island_group := "islands"
@export var walk_max_distance := 700.0       # islands farther than this (horizontally) are always flown to
@export var walk_max_height_diff := 120.0    # ...and so are islands higher/lower than this
@export_range(0.0, 1.0) var walk_chance := 0.6   # when both are possible, how often it walks instead of flies
@export var rest_time_range := Vector2(1.0, 3.0) # pause on each island before the next trip
@export var fallback_radius := 1400.0        # only used when there are no islands

@export_group("Sprite")
@export var sprite_faces_left := false       # the Godot icon has no facing; set true for left-facing bird art

# --- ground tuning (matches the player) ---
const SPEED = 260.0                 # a bit slower than the player so it feels like an NPC
const HOP_VELOCITY = -220.0
const HOP_INTERVAL = 0.12
const BASE_GRAVITY = 1200.0
const INCREASED_GRAVITY = 1800.0
const FRICTION = 3000.0
const AIR_FRICTION = 1500.0
const TAKEOFF_VELOCITY = -450.0

# --- fly tuning (matches the player) ---
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

# --- trip tuning ---
const HOVER_HEIGHT = 100.0       # fly toward a point this far above the island, then drop onto it
const LAND_DISTANCE = 250.0      # start landing when this close (turning radius means it can't be tighter)
const ARRIVE_X = 30.0            # "I'm there" tolerance when walking
const ARRIVE_Y = 150.0
const WALK_TIMEOUT = 8.0         # give up walking and fly instead
const FLY_TIMEOUT = 12.0         # give up on an island that can't be reached and pick another
const FALL_TIME = 1.0            # fell off an island for this long -> take off
const MIN_ISLAND_SEPARATION = 150.0   # don't pick the island it's already standing on

@onready var bird: Sprite2D = $Sprite2D
@onready var base_scale: Vector2 = bird.scale

var mode := Mode.GROUND
var home: Vector2

# trip state
var dest := Vector2.ZERO
var traveling := false
var travel_timer := 0.0
var rest_timer := 0.0
var air_time := 0.0

# ground state
var move_dir := 0.0
var hop_timer := 0.0

# fly state
var heading := 0.0
var speed := 0.0
var speed_floor := FLY_MIN_SPEED
var turn_speed := 0.0
var flip_amount := 1.0


func _ready() -> void:
	home = global_position
	randomize()
	rest_timer = randf_range(0.2, 1.0)   # short pause, then off to the first island
	_enter_ground()


func _physics_process(delta: float) -> void:
	match mode:
		Mode.GROUND:
			_ground_physics(delta)
		Mode.FLY:
			_fly_physics(delta)


# ------------------------------------------------------------------ trips ----

func _pick_destination() -> Vector2:
	var options: Array[Node2D] = []
	for n in get_tree().get_nodes_in_group(island_group):
		var island := n as Node2D
		if island != null and island.global_position.distance_to(global_position) > MIN_ISLAND_SEPARATION:
			options.append(island)
	if options.is_empty():
		return home + Vector2.from_angle(randf() * TAU) * randf_range(300.0, fallback_radius)
	return options.pick_random().global_position


func _begin_trip() -> void:
	dest = _pick_destination()
	traveling = true
	travel_timer = 0.0
	var to := dest - global_position
	var can_walk := absf(to.x) <= walk_max_distance and absf(to.y) <= walk_max_height_diff
	if not (can_walk and randf() < walk_chance):
		_take_off()


func _finish_trip() -> void:
	traveling = false
	move_dir = 0.0
	rest_timer = randf_range(rest_time_range.x, rest_time_range.y)


# ---------------------------------------------------------------- ground ----

func _enter_ground() -> void:
	mode = Mode.GROUND
	motion_mode = MOTION_MODE_GROUNDED
	bird.rotation = 0.0
	bird.scale = base_scale
	bird.flip_v = false
	air_time = 0.0
	travel_timer = 0.0


func _ground_physics(delta: float) -> void:
	var on_floor := is_on_floor()
	hop_timer = maxf(hop_timer - delta, 0.0)

	if on_floor:
		air_time = 0.0
	else:
		air_time += delta

	if traveling:
		travel_timer += delta
		var to := dest - global_position
		if absf(to.x) < ARRIVE_X:
			if on_floor and absf(to.y) <= ARRIVE_Y:
				_finish_trip()
			elif on_floor:
				_take_off()   # right under/over the island but can't walk there: fly instead
				return
		move_dir = signf(to.x) if absf(to.x) >= ARRIVE_X else 0.0

		# blocked by a wall, walked off a ledge, or taking too long -> fly instead
		var blocked := is_on_wall() and move_dir != 0.0 and signf(get_wall_normal().x) == -signf(move_dir)
		if blocked or air_time > FALL_TIME or travel_timer > WALK_TIMEOUT:
			_take_off()
			return
	else:
		move_dir = 0.0
		rest_timer -= delta
		if rest_timer <= 0.0 and on_floor:
			_begin_trip()
			if mode != Mode.GROUND:
				return

	if move_dir != 0.0:
		_face(move_dir)

	# gravity
	if not on_floor:
		velocity.y += (INCREASED_GRAVITY if velocity.y > 0.0 else BASE_GRAVITY) * delta

	# little hops while walking
	if on_floor and move_dir != 0.0 and hop_timer <= 0.0:
		velocity.y = HOP_VELOCITY
		hop_timer = HOP_INTERVAL

	var accel := FRICTION if on_floor else AIR_FRICTION
	velocity.x = move_toward(velocity.x, move_dir * SPEED, accel * delta)

	move_and_slide()


func _face(direction: float) -> void:
	bird.flip_h = (direction < 0.0) != sprite_faces_left


# ------------------------------------------------------------------- fly ----

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
	travel_timer = 0.0
	traveling = true
	bird.flip_h = sprite_faces_left   # fly mode rotates the sprite toward its heading
	bird.flip_v = false


func _fly_physics(delta: float) -> void:
	travel_timer += delta
	var aim := dest + Vector2(0.0, -HOVER_HEIGHT)

	# can't reach this one (blocked, orbiting, etc): try another island
	if travel_timer > FLY_TIMEOUT:
		dest = _pick_destination()
		aim = dest + Vector2(0.0, -HOVER_HEIGHT)
		travel_timer = 0.0

	speed_floor = move_toward(speed_floor, FLY_MIN_SPEED, FLY_BOUNCE_RECOVERY * delta)

	# steer toward the island the way mouse steering does for the player
	var to_aim := aim - global_position
	var diff := angle_difference(heading, to_aim.angle())
	var target_turn := clampf(diff * 5.0, -FLY_TURN_RATE, FLY_TURN_RATE)
	turn_speed = move_toward(turn_speed, target_turn, FLY_TURN_ACCEL * delta)
	heading = wrapf(heading + turn_speed * delta, -PI, PI)

	var heading_vec := Vector2.from_angle(heading)

	var accel := FLY_ACCEL
	if speed > FLY_CRUISE_SPEED:
		accel = FLY_DRAG
	if speed_floor < FLY_MIN_SPEED:
		accel *= FLY_BOUNCE_ACCEL_MULT

	# dive gains speed, climbing costs it
	if heading_vec.y > 0.0:
		var headroom := 1.0 - smoothstep(FLY_MAX_SPEED * 0.75, FLY_MAX_SPEED, speed)
		speed += heading_vec.y * FLY_DIVE_GAIN * headroom * delta
	else:
		speed += heading_vec.y * FLY_CLIMB_COST * delta
	speed = move_toward(speed, FLY_CRUISE_SPEED, accel * delta)
	speed = clampf(speed, speed_floor, FLY_MAX_SPEED)

	velocity = velocity.lerp(heading_vec * speed, 1.0 - exp(-FLY_VELOCITY_SMOOTH * delta))
	move_and_slide()

	# bounce off walls
	if get_slide_collision_count() > 0:
		var normal := get_last_slide_collision().get_normal()
		var impact := -heading_vec.dot(normal)
		if impact > 0.0:
			heading_vec = heading_vec.bounce(normal)
			heading = heading_vec.angle()
			speed = maxf(speed * lerpf(1.0, FLY_BOUNCE_LOSS, impact), FLY_BOUNCE_MIN_SPEED)
			speed_floor = FLY_BOUNCE_MIN_SPEED
			velocity = heading_vec * speed

	# sprite follows heading and flips smoothly when turning around
	var facing := 1.0 if cos(heading) >= 0.0 else -1.0
	flip_amount = move_toward(flip_amount, facing, FLY_FLIP_SPEED * delta)
	bird.rotation = heading
	bird.flip_h = sprite_faces_left
	bird.flip_v = false
	bird.scale = Vector2(base_scale.x, base_scale.y * flip_amount)

	# close to the island and there's ground below: land, then walk the last bit
	if global_position.distance_to(aim) < LAND_DISTANCE and _floor_below():
		_land()


func _floor_below() -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(
		global_position, global_position + Vector2(0.0, 600.0), collision_mask, [get_rid()])
	return not space.intersect_ray(q).is_empty()


func _land() -> void:
	velocity = Vector2(velocity.x * 0.3, maxf(velocity.y, 0.0))
	_enter_ground()
