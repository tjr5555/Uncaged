extends CharacterBody2D

signal boost_changed(current: float, maximum: float)
signal portal_reached


@export var medallion_scene: PackedScene
var medallion: Node2D
const MEDALLION_NECK = Vector2(-3.0, 0)


var SPEED = 400.0
var JUMP_VELOCITY = -500.0
var JUMP_CUT = 0.45
var JUMP_BUFFER = 0.12
var COYOTE_TIME = 0.3
var HOP_VELOCITY = -220.0
var HOP_INTERVAL = 0.12
const BASE_GRAVITY = 1200.0
const DIVE_GRAVITY = 2400.0
const GLIDING_GRAVITY = 200.0
const INCREASED_GRAVITY = 1800.0
const AIR_FRICTION = 1500.0
const FRICTION = 3000.0
const LEDGE_CHECK_STEP = 28.0 #spacing between ground samples ahead
const LEDGE_CHECK_DROP = 24.0 #how far below the feet counts as ground
const LEDGE_STEP_UP = 8.0 #ray starts this far above the floor (ignores tiny bumps)
const LEDGE_MARGIN = 48.0 #extra look-ahead distance beyond the hop's reach
var DASH_POWER = 1000.0
var HOLD_DURATION = 0.3
var WALL_SLIDE_SPEED = 120.0
var WALL_JUMP_PUSH = 550.0
var WALL_JUMP_HEIGHT = -520.0
var WALL_JUMP_LOCK = 0.18

const SHAKE_MAX_OFFSET = 28.0
const SHAKE_DECAY = 1.8
const WALL_SHAKE = 0.9
const WALL_SHAKE_MIN_SPEED = 300.0

var camera_look := Vector2.ZERO
var shake_trauma := 0.0

const LAND_MIN_IMPACT = 250.0
const LAND_MAX_IMPACT = 1600.0
const LAND_SQUASH = 0.28
const LAND_CAMERA_DIP = 18.0
const HOP_LAND_SQUASH = 0.05
const HOP_LAND_MAX_IMPACT = 420.0
const HOP_LAND_VOLUME_DB = -26.0

var land_tween: Tween
var hop_airborne := false
var jump_cut_available := false 

const FALL_ANIM_SPEED = 350.0 
const SPRITE_FACES_LEFT = true 

const HAZARD_DATA_NAMES = ["hazards", "hazard"] 
const DEBUG_HAZARDS = false
const NO_SPEED_ZOOM_SCENES = ["tutorial"] 
var FLY_CCW_ACTION = "ui_left"
var FLY_CW_ACTION = "ui_right"
var FLY_UP_ACTION = "ui_up" 
var FLY_DOWN_ACTION = "ui_down" 
var FLY_BOOST_ACTION = "Dash"
var FLY_BRAKE_ACTION = "brake" 



const BASE_FLY_TURN_ACCEL = 45.0
const DEFAULT_TURN_RATE = 4.2
const FLY_ENTER_SPEED = 800.0
var FLY_CRUISE_SPEED = 800.0
const FLY_BOOST_SPEED = 1300.0
const FLY_MAX_SPEED = 1700.0
const FLY_MIN_SPEED = 450.0
const FLY_ACCEL = 700.0
const FLY_BOOST_ACCEL = 1400.0
const FLY_DRAG = 450.0
var FLY_BRAKE_DECEL = 900.0
var FLY_TURN_RATE = 4.2
var FLY_TURN_ACCEL = 45.0
var FLY_BRAKE_TURN_MULT = 1.6
const FLY_FAST_TURN_MULT = 0.85
const FLY_AUTO_LEVEL = 0.1 #0 = never levels itself out. Set to 0.9 to bring it back
const FLY_LEVEL_FADE_START = 0.3
const FLY_LEVEL_FADE_END = 0.6 
const FLY_VELOCITY_SMOOTH = 24.0
const FLY_DASH_BOOST = 700.0
const FLY_STALL_TURN = 1.2
const CONTROL_MAX_BONUS = 0.5
const FLY_FLIP_SPEED = 14.0
const FLY_BOOST_BONUS = 500.0
const FLY_DIVE_GAIN = 900.0
const FLY_CLIMB_COST = 800.0
const FLY_LEVEL_DELAY = 0.4
const FLY_STALL_SLOPE = 0.5
const MOUSE_DEADZONE = 40.0
const MOUSE_TURN_GAIN = 6.0
const MOUSE_SWITCH_THRESHOLD = 3.0

enum SteerSource { KEYBOARD, MOUSE }

var steer_source := SteerSource.KEYBOARD
var level_delay := 0.0

const FLY_BOUNCE_LOSS = 0.2
const FLY_BOUNCE_MIN_SPEED = 120.0
const FLY_BOUNCE_RECOVERY = 350.0
const FLY_BOUNCE_ACCEL_MULT = 0.35

var speed_floor: float = FLY_MIN_SPEED 

const CAMERA_ZOOM_START_SPEED = 300
const CAMERA_ZOOM_END_SPEED = 1500
const CAMERA_MIN_ZOOM = 0.2
const CAMERA_ZOOM_SMOOTH = 1.5
const FLY_CAMERA_LOOK = 0.4
const FLY_CAMERA_MAX_OFFSET = 300.0

const WIND_START_SPEED = 900.0
const WIND_FULL_SPEED = 2000.0
const WIND_COLOR = Color(1.0, 1.0, 1.0, 0.5)
const WIND_FADE_SPEED = 3.0

const WIND_BODY_HALF = Vector2(26.0, 30.0)
const WIND_BODY_CENTER = Vector2.ZERO
const WIND_INSET = 0.55
var WIND_LANE_FRACTIONS: PackedFloat32Array = PackedFloat32Array([-0.8, -0.4, 0.0, 0.4, 0.8])
var WIND_LANE_LENGTHS: PackedInt32Array = PackedInt32Array([8, 12, 18, 12, 8])
var WIND_LANE_WIDTHS: PackedFloat32Array = PackedFloat32Array([6.0, 9.0, 12.0, 9.0, 6.0])

var wind_lines: Array[Line2D] = []
var wind_amount: float = 0.0

const BOOST_MAX = 100.0
const BOOST_DRAIN = 35.0
const BOOST_REGEN = 20.0
const BOOST_REGEN_DELAY = 0.8
const BOOST_RESTART_AMOUNT = 20.0
const BOOST_GROUND_REGEN_MULT = 3.0

var boost: float = BOOST_MAX
var boost_regen_timer: float = 0.0
var boost_exhausted: bool = false
var is_boosting: bool = false
var last_emitted_boost: float = -1.0

@onready var bird: AnimatedSprite2D = $AnimatedSprite2D
@onready var base_scale: Vector2 = bird.scale
@onready var camera: Camera2D = get_node_or_null("Camera")
@onready var base_zoom: Vector2 = camera.zoom if camera else Vector2.ONE

const MAGNET_PULL_SPEED = 900.0
const BASE_FLY_BRAKE_DECEL = 900.0

var magnet_area: Area2D
var magnet_shape: CircleShape2D

var flaps = 1
var current_dir = 1

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var hop_timer: float = 0.0
var wall_lock_timer: float = 0.0
var hold_timer: float = 0.0
var is_gliding: bool = false
var autopilot := false
var absorbing := false
var autopilot_target := Vector2.ZERO
var emerge_timer := 0.0

var heading: float = 0.0
var speed: float = 0.0
var turn_speed: float = 0.0
var flip_amount: float = 1.0

var last_grounded_pos: Vector2

const PORTAL_MIN_PULL = 700.0
const PORTAL_MAX_PULL = 1600.0
const PORTAL_TURN = 10.0
const ABSORB_SCALE = 0.15
const ABSORB_SPIN = 9.0
const EMERGE_TIME = 0.5

func _ready() -> void:
	last_grounded_pos = global_position
	if camera == null:
		push_error("Player: no child node named 'camera' found")

	var width_curve := Curve.new()
	width_curve.add_point(Vector2(0.0, 0.35))
	width_curve.add_point(Vector2(0.18, 1.0))
	width_curve.add_point(Vector2(1.0, 0.0))

	var gradient := Gradient.new()
	gradient.set_color(0, Color(WIND_COLOR, 0.0))
	gradient.set_color(1, Color(WIND_COLOR, 0.0))
	gradient.add_point(0.15, WIND_COLOR)
	gradient.add_point(0.45, Color(WIND_COLOR, WIND_COLOR.a * 0.5))

	for i in WIND_LANE_FRACTIONS.size():
		var line := Line2D.new()
		line.width = WIND_LANE_WIDTHS[i]
		line.width_curve = width_curve
		line.gradient = gradient
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.round_precision = 12
		line.antialiased = true
		line.show_behind_parent = true
		add_child(line)
		wind_lines.append(line)

	_build_magnet()

	SignalBus.finishquest1.connect(_give_medallion)
	if Global.has_medallion:
		_give_medallion()

func _physics_process(delta: float) -> void:
	#set shop variables constantly (Player specific ones)
	FLY_CRUISE_SPEED = Global.base_flight_speed
	FLY_TURN_RATE = Global.base_turn_speed
	FLY_BRAKE_DECEL = BASE_FLY_BRAKE_DECEL * Global.brake_decel_scale
	FLY_BRAKE_TURN_MULT = Global.brake_turn_bonus
	FLY_TURN_ACCEL = BASE_FLY_TURN_ACCEL * Global.turn_accel_scale
	_update_magnet(delta)

	if autopilot:
		_autopilot_physics(delta)
		_update_wind(delta)
		return
	if emerge_timer > 0.0:
		_emerge_physics(delta)
		_update_wind(delta)
		return

	if Input.is_action_just_pressed("toggle_fly") and not Global.INPUT_LOCKED:
		_set_mode(Global.Mode.GROUND if Global.mode == Global.Mode.FLY else Global.Mode.FLY)

	is_boosting = false

	match Global.mode:
		Global.Mode.GROUND:
			_ground_physics(delta)
		Global.Mode.FLY:
			_fly_physics(delta)

	_update_boost(delta)
	_update_wind(delta)
	if Input.is_action_just_pressed("reset") and not Global.INPUT_LOCKED:
		reset()

func _input(event: InputEvent) -> void:
	if not Settings.mouse_steering:
		return
	var motion := event as InputEventMouseMotion
	if motion != null and motion.relative.length() > MOUSE_SWITCH_THRESHOLD:
		steer_source = SteerSource.MOUSE

func _set_mode(new_mode: Global.Mode) -> void:
	Global.mode = new_mode
	if Global.mode == Global.Mode.FLY:
		motion_mode = MOTION_MODE_FLOATING
		if velocity.length() > 80.0:
			heading = velocity.angle()
		else:
			heading = 0.0 if current_dir >= 0 else PI
		speed = maxf(velocity.length(), FLY_ENTER_SPEED)
		turn_speed = 0.0
		flip_amount = 1.0 if cos(heading) >= 0.0 else -1.0
		is_gliding = false
		hold_timer = 0.0
		bird.flip_h = SPRITE_FACES_LEFT #fly mode rotates the sprite toward its heading, so it must face right at rest
		bird.flip_v = false
		bird.play("idle") #placeholder until there's a fly animation
	else:
		motion_mode = MOTION_MODE_GROUNDED
		velocity = Vector2.from_angle(heading) * speed
		current_dir = 1 if cos(heading) >= 0.0 else -1
		flaps = 1
		coyote_timer = 0.0
		bird.rotation = 0.0
		bird.scale = base_scale
		bird.flip_v = false
		_face(current_dir)

func _update_camera(delta: float, look: Vector2 = Vector2.ZERO, zoom_multiplier: float = 1.0) -> void:
	if camera == null:
		return
	var move_weight := 1.0 - exp(-3.0 * delta)
	var zoom_weight := 1.0 - exp(-CAMERA_ZOOM_SMOOTH * delta)
	var speed_t := 0.0
	if _speed_zoom_allowed():
		speed_t = smoothstep(CAMERA_ZOOM_START_SPEED, CAMERA_ZOOM_END_SPEED, velocity.length())
	var target_zoom := base_zoom * lerpf(1.0, CAMERA_MIN_ZOOM, speed_t) * zoom_multiplier
	
	camera_look = camera_look.lerp(look, move_weight)
	shake_trauma = maxf(shake_trauma - delta * SHAKE_DECAY, 0.0)
	var shake := shake_trauma * shake_trauma * SHAKE_MAX_OFFSET * Settings.screen_shake
	camera.offset = camera_look + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
	camera.zoom = camera.zoom.lerp(target_zoom, zoom_weight)

func add_shake(amount: float) -> void:
	shake_trauma = minf(shake_trauma + amount, 1.0)

func _speed_zoom_allowed() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return true
	var scene_name := scene.scene_file_path.get_file().get_basename().to_lower()
	return not NO_SPEED_ZOOM_SCENES.has(scene_name)

func _ground_physics(delta: float) -> void:
	var dir := 0.0 if Global.INPUT_LOCKED else Input.get_axis("ui_left", "ui_right")
	var ydir := 0.0 if Global.INPUT_LOCKED else Input.get_axis("ui_up", "ui_down")
	var on_floor := is_on_floor()
	var on_wall := is_on_wall_only()
	
	_update_camera(delta, Vector2.ZERO, 1.0)
	
	if dir != 0.0:
		current_dir = 1 if dir > 0.0 else -1
		_face(dir)
	
	if on_floor:
		coyote_timer = 0.0
		flaps = 1
		Global.dashes = Global.max_dashes
	else:
		coyote_timer += delta
	
	hop_timer = maxf(hop_timer - delta, 0.0)
	wall_lock_timer = maxf(wall_lock_timer - delta, 0.0)
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)
	
	if Input.is_action_just_pressed("ui_accept") and not Global.INPUT_LOCKED:
		jump_buffer_timer = JUMP_BUFFER
	
	var jumped := false
	if jump_buffer_timer > 0.0:
		if on_wall and not on_floor:
			var wall_normal := get_wall_normal()
			velocity.x = wall_normal.x * WALL_JUMP_PUSH
			velocity.y = WALL_JUMP_HEIGHT
			jump_cut_available = false
			wall_lock_timer = WALL_JUMP_LOCK
			current_dir = 1 if wall_normal.x > 0.0 else -1
			_face(current_dir)
			flaps = 1
			Global.dashes = Global.max_dashes
			coyote_timer = 0.0
			jump_buffer_timer = 0.0
			jumped = true
			hop_airborne = false
		elif coyote_timer <= COYOTE_TIME and flaps > 0:
			flaps -= 1
			coyote_timer = COYOTE_TIME
			velocity.y = JUMP_VELOCITY
			jump_cut_available = true
			jump_buffer_timer = 0.0
			jumped = true
			hop_airborne = false
	
	if velocity.y >= 0.0:
		jump_cut_available = false
	if Input.is_action_just_released("ui_accept") and jump_cut_available and velocity.y < 0.0 and not Global.INPUT_LOCKED:
		velocity.y *= JUMP_CUT
		jump_cut_available = false
	if Input.is_action_pressed("ui_accept") and not on_floor and not Global.INPUT_LOCKED:
		hold_timer += delta
		if hold_timer >= HOLD_DURATION and velocity.y > 0.0:
			is_gliding = true
	else:
		hold_timer = 0.0
		is_gliding = false
	
	if not on_floor:
		var gravity := BASE_GRAVITY
		if ydir > 0.0:
			gravity = DIVE_GRAVITY
		elif is_gliding:
			gravity = GLIDING_GRAVITY
		elif velocity.y > 0.0:
			gravity = INCREASED_GRAVITY
		velocity.y += gravity * delta
		
		if on_wall and dir != 0.0 and velocity.y > WALL_SLIDE_SPEED:
			if signf(dir) == -signf(get_wall_normal().x):
				velocity.y = WALL_SLIDE_SPEED
				is_gliding = false
	
	if on_floor and not jumped and dir != 0.0 and hop_timer <= 0.0 and not _ledge_near(dir):
		velocity.y = HOP_VELOCITY
		hop_timer = HOP_INTERVAL
		hop_airborne = true
		bird.play("hop")
		bird.set_frame_and_progress(0, 0.0)
	
	if wall_lock_timer <= 0.0:
		var accel := FRICTION if on_floor else AIR_FRICTION
		velocity.x = move_toward(velocity.x, dir * SPEED, accel * delta)
	
	if Input.is_action_just_pressed("Dash") and Global.dashes > 0 and not Global.INPUT_LOCKED:
		var dash_dir := Vector2(dir, ydir)
		if dash_dir == Vector2.ZERO:
			dash_dir = Vector2(current_dir, 0)
		else:
			dash_dir = dash_dir.normalized()
		Global.dashes -= 1
		wall_lock_timer = 0.0
		hop_airborne = false
		jump_cut_available = false
		velocity = dash_dir * (DASH_POWER if on_floor else DASH_POWER * 1.4)
	
	var incoming_speed_y := velocity.y
	
	move_and_slide()
	
	#touching a hazard tile sends you back to the last safe ground
	if _touching_hazard():
		respawn()
		return
	
	#remember the last safe ground (a hazard touch returned above, so this is never a hazard)
	if is_on_floor():
		last_grounded_pos = global_position
	
	if not on_floor and is_on_floor():
		if hop_airborne and incoming_speed_y < HOP_LAND_MAX_IMPACT:
			_on_hop_landed()
		elif incoming_speed_y > LAND_MIN_IMPACT:
			_on_landed(incoming_speed_y)
		hop_airborne = false
	
	if is_on_floor() and incoming_speed_y > 50.0 and Input.is_action_pressed("ui_down") and Input.is_action_pressed("augment") and not Global.INPUT_LOCKED:
		velocity.y = incoming_speed_y * 1.1 * -1.0
		jump_cut_available = false
		velocity.x = 0.0
		Global.dashes = Global.max_dashes
	
	if is_on_floor() and Input.is_action_pressed("augment") and velocity.y > 50.0 and not Global.INPUT_LOCKED:
		velocity.x += velocity.y
	
	_update_ground_animation()

func _update_ground_animation() -> void:
	if is_gliding and not is_on_floor():
		if bird.animation != "glide":
			bird.play("glide")
		return

	var standing := is_on_floor() and absf(velocity.x) <= 20.0
	var falling := not is_on_floor() and velocity.y > 0.0 and (not hop_airborne or velocity.y > FALL_ANIM_SPEED)
	
	#let the hop windup finish before anything else takes over,
	#unless we've come to rest or started falling
	if bird.animation == "hop" and bird.is_playing() and not standing and not falling:
		return
	
	var anim := ""
	if is_on_floor():
		#still moving along the ground. the next hop starts within a few frames,
		#so hold the last hop frame instead of flickering to idle between hops
		if not standing:
			return
		anim = "idle"
	elif falling and velocity.y > 500:
		anim = "fall"
	elif bird.animation == "idle" and coyote_timer > 0.08:
		anim = "hop" #left the ground from standing still (a jump or a real drop, not a one-frame floor flicker)
	else:
		return #rising or a short drop: hold the current frame
	
	if bird.animation != anim:
		bird.play(anim)

func _face(direction: float) -> void:
	#negative = facing left, positive = facing right, regardless of which way the art is drawn
	bird.flip_h = (direction < 0.0) != SPRITE_FACES_LEFT

func _ledge_near(direction: float) -> bool:
	if direction == 0.0:
		return false
	
	var space := get_world_2d().direct_space_state
	
	# Find the floor directly under the player
	var down_query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(0.0, 128.0),
		collision_mask,
		[get_rid()]
	)
	var floor_hit := space.intersect_ray(down_query)
	if floor_hit.is_empty():
		return false
	var ground_y: float = floor_hit.position.y
	
	# How far a hop would carry you horizontally (up time + down time)
	var air_time := absf(HOP_VELOCITY) / BASE_GRAVITY + absf(HOP_VELOCITY) / INCREASED_GRAVITY
	var reach := maxf(absf(velocity.x) * air_time, LEDGE_CHECK_STEP * 2.0) + LEDGE_MARGIN
	
	# Sample single points ahead; no floor within the drop distance means a ledge
	var dist := LEDGE_CHECK_STEP
	while dist <= reach:
		var x := global_position.x + signf(direction) * dist
		var query := PhysicsRayQueryParameters2D.create(
			Vector2(x, ground_y - LEDGE_STEP_UP),
			Vector2(x, ground_y + LEDGE_CHECK_DROP),
			collision_mask,
			[get_rid()]
		)
		query.hit_from_inside = true # a wall ahead counts as ground, not a gap
		if space.intersect_ray(query).is_empty():
			return true
		dist += LEDGE_CHECK_STEP
	return false

func _fly_physics(delta: float) -> void:
	var braking := Input.is_action_pressed(FLY_BRAKE_ACTION) 
	
	if boost <= 0.0:
		boost_exhausted = true
	elif boost >= BOOST_RESTART_AMOUNT:
		boost_exhausted = false
	
	var boosting := Input.is_action_pressed(FLY_BOOST_ACTION) and not boost_exhausted 
	is_boosting = boosting
	
	speed_floor = move_toward(speed_floor, FLY_MIN_SPEED, FLY_BOUNCE_RECOVERY * delta)
	
	var control: float = FLY_TURN_RATE / DEFAULT_TURN_RATE
	var control_t := clampf((control - 1.0) / CONTROL_MAX_BONUS, 0.0, 1.0)
	
	var speed_t := clampf((speed - FLY_CRUISE_SPEED) / maxf(FLY_MAX_SPEED - FLY_CRUISE_SPEED, 1.0), 0.0, 1.0)
	var fast_mult := lerpf(FLY_FAST_TURN_MULT, 1.0, control_t)
	var turn_rate = FLY_TURN_RATE * control * lerpf(1.0, fast_mult, speed_t)
	if braking:
		turn_rate *= FLY_BRAKE_TURN_MULT
	
	var target_turn := _steer_turn_target(turn_rate)
	turn_speed = move_toward(turn_speed, target_turn, FLY_TURN_ACCEL * control * delta)
	heading = wrapf(heading + turn_speed * delta, -PI, PI)
	
	if steer_source == SteerSource.KEYBOARD and is_zero_approx(target_turn):
		level_delay = maxf(level_delay - delta, 0.0)
		if level_delay <= 0.0:
			var level_target := 0.0 if cos(heading) >= 0.0 else PI
			var level_step := FLY_AUTO_LEVEL * delta
			heading = wrapf(heading + clampf(angle_difference(heading, level_target), -level_step, level_step), -PI, PI)
	else:
		level_delay = FLY_LEVEL_DELAY
	
	var heading_vec := Vector2.from_angle(heading)
	
	var target_speed: float = FLY_CRUISE_SPEED
	var accel := FLY_ACCEL
	if braking:
		target_speed = FLY_MIN_SPEED
		accel = FLY_BRAKE_DECEL
	elif boosting:
		target_speed = FLY_CRUISE_SPEED + FLY_BOOST_BONUS
		accel = FLY_BOOST_ACCEL
	
	if speed > target_speed and not braking:
		accel = FLY_DRAG
	
	if speed_floor < FLY_MIN_SPEED:
		accel *= FLY_BOUNCE_ACCEL_MULT
	
	if heading_vec.y > 0.0:
		var headroom := 1.0 - smoothstep(FLY_MAX_SPEED * 0.75, FLY_MAX_SPEED, speed)
		speed += heading_vec.y * FLY_DIVE_GAIN * headroom * delta
	else:
		speed += heading_vec.y * FLY_CLIMB_COST * delta
	
	speed = move_toward(speed, target_speed, accel * delta)
	speed = clampf(speed, speed_floor, FLY_MAX_SPEED)
	
	if speed <= speed_floor + 10.0 and heading_vec.y < -FLY_STALL_SLOPE:
		var drop := clampf(angle_difference(heading, PI / 2.0), -FLY_STALL_TURN * delta, FLY_STALL_TURN * delta)
		heading = wrapf(heading + drop, -PI, PI)
		heading_vec = Vector2.from_angle(heading)
	
	var vel_smooth := FLY_VELOCITY_SMOOTH * lerpf(1.0, 1.5, control_t)
	velocity = velocity.lerp(heading_vec * speed, 1.0 - exp(-vel_smooth * delta))
	
	move_and_slide()
	
	if _touching_hazard():
		respawn()
		return
	
	if get_slide_collision_count() > 0:
		var normal := get_last_slide_collision().get_normal()
		var impact := -heading_vec.dot(normal)
		if impact > 0.0:
			var impact_speed := speed
			heading_vec = heading_vec.bounce(normal)
			heading = heading_vec.angle()
			speed = maxf(speed * lerpf(1.0, FLY_BOUNCE_LOSS, impact), FLY_BOUNCE_MIN_SPEED)
			speed_floor = FLY_BOUNCE_MIN_SPEED
			velocity = heading_vec * speed
			if impact_speed > WALL_SHAKE_MIN_SPEED:
				add_shake(WALL_SHAKE * impact * clampf(impact_speed / FLY_MAX_SPEED, 0.0, 1.0))
	
	var facing := 1.0 if cos(heading) >= 0.0 else -1.0
	flip_amount = move_toward(flip_amount, facing, FLY_FLIP_SPEED * delta)
	bird.rotation = heading
	bird.flip_h = SPRITE_FACES_LEFT
	bird.flip_v = false
	bird.scale = Vector2(base_scale.x, base_scale.y * flip_amount)
	
	_update_camera(delta, (velocity * FLY_CAMERA_LOOK).limit_length(FLY_CAMERA_MAX_OFFSET))

func _touching_hazard() -> bool:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var layer := col.get_collider() as TileMapLayer
		if layer == null or layer.tile_set == null:
			continue
		
		#find which of the accepted names exists on this tileset (reading a missing layer throws an error)
		var data_name := ""
		for n in HAZARD_DATA_NAMES:
			if layer.tile_set.get_custom_data_layer_by_name(n) != -1:
				data_name = n
				break
		if data_name == "":
			continue
		
		#nudge into the tile we hit so we get that tile and not its neighbor
		for depth in [2.0, 6.0]:
			var hit_pos: Vector2 = col.get_position() - col.get_normal() * depth
			var coords: Vector2i = layer.local_to_map(layer.to_local(hit_pos))
			var data: TileData = layer.get_cell_tile_data(coords)
			if DEBUG_HAZARDS:
				print("hazard check: ", layer.name, " tile ", coords, " ", data_name, " = ", data.get_custom_data(data_name) if data else "no tile")
			if data and data.get_custom_data(data_name):
				return true
	return false

func respawn() -> void:
	if Global.mode == Global.Mode.FLY:
		_set_mode(Global.Mode.GROUND)
	global_position = last_grounded_pos
	velocity = Vector2.ZERO
	speed = FLY_ENTER_SPEED
	speed_floor = FLY_MIN_SPEED
	turn_speed = 0.0
	
	#clear anything that could carry over from before the hit
	hop_airborne = false
	jump_cut_available = false
	is_gliding = false
	hold_timer = 0.0
	hop_timer = 0.0
	wall_lock_timer = 0.0
	jump_buffer_timer = 0.0
	if land_tween and land_tween.is_valid():
		land_tween.kill()
	bird.scale = base_scale
	bird.rotation = 0.0
	bird.play("idle")
	
	camera_look = Vector2.ZERO
	shake_trauma = 0.0
	if camera:
		camera.offset = Vector2.ZERO
		camera.reset_smoothing()


func _update_wind(delta: float) -> void:
	var target := 0.0
	if Global.mode == Global.Mode.FLY:
		target = smoothstep(WIND_START_SPEED, WIND_FULL_SPEED, speed)
	wind_amount = move_toward(wind_amount, target, WIND_FADE_SPEED * delta)

	var emitting := wind_amount > 0.02
	var forward := Vector2.from_angle(heading)
	var side := forward.orthogonal()
	var time := Time.get_ticks_msec() * 0.008
	var body := WIND_BODY_HALF * base_scale.abs()
	var flip := 1.0 if flip_amount >= 0.0 else -1.0
	var center := global_position + Vector2(WIND_BODY_CENTER.x, WIND_BODY_CENTER.y * flip).rotated(heading)

	for i in wind_lines.size():
		var line: Line2D = wind_lines[i]
		line.global_transform = Transform2D.IDENTITY
		line.modulate.a = wind_amount

		if not emitting:
			line.clear_points()
			continue

		var fraction: float = WIND_LANE_FRACTIONS[i]
		var lane_length: int = WIND_LANE_LENGTHS[i]
		var spread: float = lerpf(0.55, 1.0, wind_amount)
		var wobble: float = sin(time + i * 1.7) * 2.5 * wind_amount
		var back := body.x * sqrt(maxf(1.0 - fraction * fraction, 0.0)) * WIND_INSET
		var lateral := fraction * body.y * spread + wobble
		var head: Vector2 = center - forward * back + side * lateral
		line.add_point(head, 0)

		var allowed: int = int(lane_length * lerpf(0.4, 1.0, wind_amount))
		while line.get_point_count() > allowed:
			line.remove_point(line.get_point_count() - 1)

func _update_boost(delta: float) -> void:
	if is_boosting:
		boost = maxf(boost - BOOST_DRAIN * delta, 0.0)
		boost_regen_timer = BOOST_REGEN_DELAY
	else:
		boost_regen_timer = maxf(boost_regen_timer - delta, 0.0)
		if boost_regen_timer <= 0.0:
			var rate := BOOST_REGEN * (BOOST_GROUND_REGEN_MULT if Global.mode == Global.Mode.GROUND else 1.0)
			boost = minf(boost + rate * delta, BOOST_MAX)
	
	if boost != last_emitted_boost:
		last_emitted_boost = boost
		boost_changed.emit(boost, BOOST_MAX)

func reset():
	global_position = Vector2(633, -278)
	velocity = Vector2.ZERO
	speed = FLY_ENTER_SPEED
	speed_floor = FLY_MIN_SPEED
	heading = 0.0
	turn_speed = 0.0
	boost = BOOST_MAX
	if camera:
		camera.reset_smoothing()

func begin_portal_entry(target: Vector2) -> void:
	if Global.mode != Global.Mode.FLY:
		_set_mode(Global.Mode.FLY)
	autopilot = true
	absorbing = false
	autopilot_target = target
	emerge_timer = 0.0
	is_boosting = false
	speed = clampf(maxf(velocity.length(), PORTAL_MIN_PULL), PORTAL_MIN_PULL, PORTAL_MAX_PULL)

func hold_at(pos: Vector2) -> void:
	global_position = pos
	autopilot_target = pos
	velocity = Vector2.ZERO
	wind_amount = 0.0
	for line in wind_lines:
		line.clear_points()
	camera_look = Vector2.ZERO
	shake_trauma = 0.0
	if camera:
		camera.offset = Vector2.ZERO
		camera.reset_smoothing()

func emerge(pos: Vector2, direction: Vector2, arrival_speed: float) -> void:
	autopilot = false
	absorbing = false
	global_position = pos
	var dir := direction.normalized() if direction.length() > 0.01 else Vector2.RIGHT
	heading = dir.angle()
	speed = clampf(arrival_speed, FLY_ENTER_SPEED, FLY_MAX_SPEED)
	speed_floor = FLY_MIN_SPEED
	turn_speed = 0.0
	velocity = dir * speed
	flip_amount = 1.0 if dir.x >= 0.0 else -1.0
	emerge_timer = EMERGE_TIME

func _autopilot_physics(delta: float) -> void:
	if absorbing:
		velocity = Vector2.ZERO
		global_position = autopilot_target
		var flip := 1.0 if flip_amount >= 0.0 else -1.0
		var target_scale := Vector2(base_scale.x, base_scale.y * flip) * ABSORB_SCALE
		bird.scale = bird.scale.lerp(target_scale, 1.0 - exp(-8.0 * delta))
		bird.rotation += ABSORB_SPIN * delta
		return
	
	var to_target := autopilot_target - global_position
	var dist := to_target.length()
	if dist <= maxf(speed * delta, 8.0):
		global_position = autopilot_target
		absorbing = true
		portal_reached.emit()
		return
	
	var dir := to_target / dist
	heading = lerp_angle(heading, dir.angle(), 1.0 - exp(-PORTAL_TURN * delta))
	velocity = dir * speed
	global_position += velocity * delta
	
	var facing := 1.0 if cos(heading) >= 0.0 else -1.0
	flip_amount = move_toward(flip_amount, facing, FLY_FLIP_SPEED * delta)
	bird.rotation = heading
	bird.scale = Vector2(base_scale.x, base_scale.y * flip_amount)
	_update_camera(delta, Vector2.ZERO)

func _emerge_physics(delta: float) -> void:
	emerge_timer = maxf(emerge_timer - delta, 0.0)
	var t := 1.0 - emerge_timer / EMERGE_TIME
	var grow := lerpf(ABSORB_SCALE, 1.0, 1.0 - pow(1.0 - t, 3.0))
	
	velocity = Vector2.from_angle(heading) * speed
	global_position += velocity * delta
	bird.rotation = heading
	bird.scale = Vector2(base_scale.x, base_scale.y * flip_amount) * grow
	_update_camera(delta, (velocity * FLY_CAMERA_LOOK).limit_length(FLY_CAMERA_MAX_OFFSET))

func _on_landed(impact: float) -> void:
	var t := clampf(inverse_lerp(LAND_MIN_IMPACT, LAND_MAX_IMPACT, impact), 0.0, 1.0)
	var squash := lerpf(0.08, LAND_SQUASH, t)

	if land_tween and land_tween.is_valid():
		land_tween.kill()
	bird.scale = Vector2(base_scale.x * (1.0 + squash), base_scale.y * (1.0 - squash))
	land_tween = create_tween()
	land_tween.tween_property(bird, "scale", base_scale, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	camera_look.y += LAND_CAMERA_DIP * t * Settings.screen_shake
	add_shake(0.25 * t)

	_spawn_dust(_floor_contact_point(), t)

	var sound := get_node_or_null("LandSound") as AudioStreamPlayer2D
	if sound:
		sound.pitch_scale = lerpf(1.15, 0.85, t)
		sound.volume_db = lerpf(-12.0, 0.0, t)
		sound.play()

func _floor_contact_point() -> Vector2:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision.get_normal().y < -0.7:
			return collision.get_position()
	return global_position

func _spawn_dust(pos: Vector2, strength: float) -> void:
	var dust := CPUParticles2D.new()
	dust.one_shot = true
	dust.explosiveness = 0.95
	dust.amount = int(lerpf(8.0, 22.0, strength))
	dust.lifetime = 0.55
	dust.local_coords = true
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(14.0, 2.0)
	dust.direction = Vector2.UP
	dust.spread = 75.0
	dust.gravity = Vector2(0.0, 220.0)
	dust.initial_velocity_min = lerpf(40.0, 90.0, strength)
	dust.initial_velocity_max = lerpf(90.0, 220.0, strength)
	dust.damping_min = 120.0
	dust.damping_max = 220.0
	dust.scale_amount_min = 3.0
	dust.scale_amount_max = lerpf(5.0, 8.0, strength)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.92, 0.88, 0.8, 0.85))
	ramp.set_color(1, Color(0.92, 0.88, 0.8, 0.0))
	dust.color_ramp = ramp
	get_tree().current_scene.add_child(dust)
	dust.global_position = pos
	dust.emitting = true
	get_tree().create_timer(1.2).timeout.connect(dust.queue_free)

func _on_hop_landed() -> void:
	if land_tween and land_tween.is_valid():
		land_tween.kill()
	bird.scale = Vector2(base_scale.x * (1.0 + HOP_LAND_SQUASH), base_scale.y * (1.0 - HOP_LAND_SQUASH))
	land_tween = create_tween()
	land_tween.tween_property(bird, "scale", base_scale, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	var sound := get_node_or_null("LandSound") as AudioStreamPlayer2D
	if sound:
		sound.pitch_scale = randf_range(1.2, 1.35)
		sound.volume_db = HOP_LAND_VOLUME_DB
		sound.play()

func _give_medallion() -> void:
	if medallion != null:
		return
	Global.has_medallion = true
	if medallion_scene == null:
		push_error("Player: medallion_scene not set in inspector")
		return
	medallion = medallion_scene.instantiate()
	bird.add_child(medallion)
	_place_medallion()


func _place_medallion() -> void:
	if medallion == null:
		return
	var x := -MEDALLION_NECK.x if bird.flip_h else MEDALLION_NECK.x
	medallion.position = Vector2(x, MEDALLION_NECK.y)

func _process(_delta: float) -> void:
	if Global.mode == Global.Mode.FLY:
		bird.play("fly")
	
	
	_place_medallion()

func _steer_turn_target(turn_rate: float) -> float:
	if not Settings.mouse_steering:
		steer_source = SteerSource.KEYBOARD
	
	var keys_allowed := Settings.keyboard_steering or not Settings.mouse_steering
	var key_input := Input.get_axis(FLY_CCW_ACTION, FLY_CW_ACTION) if keys_allowed else 0.0
	if key_input != 0.0:
		steer_source = SteerSource.KEYBOARD
		return key_input * turn_rate
	
	if steer_source != SteerSource.MOUSE:
		return 0.0
	
	var screen_pos := get_viewport().get_canvas_transform() * global_position
	var to_mouse := get_viewport().get_mouse_position() - screen_pos
	if to_mouse.length() < MOUSE_DEADZONE:
		return 0.0
	var diff := angle_difference(heading, to_mouse.angle())
	return clamp(diff * MOUSE_TURN_GAIN, -turn_rate, turn_rate)

func _build_magnet() -> void:
	magnet_area = Area2D.new()
	magnet_area.collision_layer = 0
	magnet_area.collision_mask = 0xFFFFFFFF
	magnet_area.monitorable = false
	magnet_area.monitoring = false
	magnet_shape = CircleShape2D.new()
	magnet_shape.radius = 1.0
	var shape := CollisionShape2D.new()
	shape.shape = magnet_shape
	magnet_area.add_child(shape)
	add_child(magnet_area)

func _update_magnet(delta: float) -> void:
	var radius: float = Global.magnet_radius
	var enabled := radius > 0.0
	if magnet_area.monitoring != enabled:
		magnet_area.set_deferred("monitoring", enabled)
	if not enabled:
		return
	if not is_equal_approx(magnet_shape.radius, radius):
		magnet_shape.radius = radius
	for area in magnet_area.get_overlapping_areas():
		if area.has_method("magnet_pull"):
			area.magnet_pull(global_position, radius, MAGNET_PULL_SPEED, delta)
