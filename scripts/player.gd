extends CharacterBody2D

signal boost_changed(current: float, maximum: float)

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

var FLY_CCW_ACTION = "ui_left"
var FLY_CW_ACTION = "ui_right"
var FLY_BOOST_ACTION = "Dash"
var FLY_BRAKE_ACTION = "ui_down"

const FLY_ENTER_SPEED = 800.0
var FLY_CRUISE_SPEED = 800.0
const FLY_BOOST_SPEED = 1300.0
const FLY_MAX_SPEED = 2200.0
const FLY_MIN_SPEED = 450.0
const FLY_ACCEL = 700.0
const FLY_BOOST_ACCEL = 1400.0
const FLY_DRAG = 350.0
const FLY_BRAKE_DECEL = 900.0
const FLY_GRAVITY = 1100.0
const FLY_TURN_RATE = 4.2
const FLY_TURN_ACCEL = 18.0
const FLY_BRAKE_TURN_MULT = 1.6
const FLY_FAST_TURN_MULT = 0.7
const FLY_AUTO_LEVEL = 0.9
const FLY_VELOCITY_SMOOTH = 14.0
const FLY_DASH_BOOST = 700.0
const FLY_STALL_TURN = 2.5
const FLY_FLIP_SPEED = 14.0

const FLY_BOUNCE_LOSS = 0.2
const FLY_BOUNCE_MIN_SPEED = 120.0
const FLY_BOUNCE_RECOVERY = 350.0
const FLY_BOUNCE_ACCEL_MULT = 0.35

var speed_floor: float = FLY_MIN_SPEED 

const CAMERA_ZOOM_START_SPEED = 300
const CAMERA_ZOOM_END_SPEED = 1500
const CAMERA_MIN_ZOOM = 0.2
const CAMERA_ZOOM_SMOOTH = 1.5
const FLY_CAMERA_LOOK = 0.2
const FLY_CAMERA_MAX_OFFSET = 300.0

const WIND_START_SPEED = 900.0
const WIND_FULL_SPEED = 2000.0
const WIND_OFFSET = 18.0
const WIND_COLOR = Color(1.0, 1.0, 1.0, 0.5)
const WIND_FADE_SPEED = 3.0

var WIND_LANE_OFFSETS: PackedFloat32Array = PackedFloat32Array([-34.0, -17.0, 0.0, 17.0, 34.0])
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

@onready var bird = $Sprite
@onready var base_scale: Vector2 = bird.scale
@onready var camera: Camera2D = get_node_or_null("Camera")
@onready var base_zoom: Vector2 = camera.zoom if camera else Vector2.ONE

var flaps = 1
var current_dir = 1

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var hop_timer: float = 0.0
var wall_lock_timer: float = 0.0
var hold_timer: float = 0.0
var is_gliding: bool = false

var heading: float = 0.0
var speed: float = 0.0
var turn_speed: float = 0.0
var flip_amount: float = 1.0

func _ready() -> void:
	var width_curve := Curve.new()
	width_curve.add_point(Vector2(0.0, 1.0))
	width_curve.add_point(Vector2(0.35, 0.8))
	width_curve.add_point(Vector2(1.0, 0.0))
	
	var gradient := Gradient.new()
	gradient.set_color(0, WIND_COLOR)
	gradient.set_color(1, Color(WIND_COLOR, 0.0))
	gradient.add_point(0.4, Color(WIND_COLOR, WIND_COLOR.a * 0.5))
	
	for i in WIND_LANE_OFFSETS.size():
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


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_fly"):
		_set_mode(Global.Mode.GROUND if Global.mode == Global.Mode.FLY else Global.Mode.FLY)
	
	is_boosting = false
	
	match Global.mode:
		Global.Mode.GROUND:
			_ground_physics(delta)
		Global.Mode.FLY:
			_fly_physics(delta)
	
	_update_boost(delta)
	_update_wind(delta)
	FLY_CRUISE_SPEED = Global.base_flight_speed
	if Input.is_action_just_pressed("reset"):
		reset()



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
		bird.flip_h = false
		bird.flip_v = false
	else:
		motion_mode = MOTION_MODE_GROUNDED
		velocity = Vector2.from_angle(heading) * speed
		current_dir = 1 if cos(heading) >= 0.0 else -1
		flaps = 1
		coyote_timer = 0.0
		bird.rotation = 0.0
		bird.scale = base_scale
		bird.flip_v = false
		bird.flip_h = current_dir < 0



func _update_camera(delta: float, look: Vector2 = Vector2.ZERO, zoom_multiplier: float = 1.0) -> void:
	if camera == null:
		return
	var move_weight := 1.0 - exp(-3.0 * delta)
	var zoom_weight := 1.0 - exp(-CAMERA_ZOOM_SMOOTH * delta)
	var speed_t := smoothstep(CAMERA_ZOOM_START_SPEED, CAMERA_ZOOM_END_SPEED, velocity.length())
	var target_zoom := base_zoom * lerpf(1.0, CAMERA_MIN_ZOOM, speed_t) * zoom_multiplier
	camera.offset = camera.offset.lerp(look, move_weight)
	camera.zoom = camera.zoom.lerp(target_zoom, zoom_weight)

func _ground_physics(delta: float) -> void:
	var dir := Input.get_axis("ui_left", "ui_right")
	var ydir := Input.get_axis("ui_up", "ui_down")
	var on_floor := is_on_floor()
	var on_wall := is_on_wall_only()
	
	_update_camera(delta, Vector2.ZERO, 1.0)
	
	if dir != 0.0:
		current_dir = 1 if dir > 0.0 else -1
		bird.flip_h = dir < 0.0
	
	if on_floor:
		coyote_timer = 0.0
		flaps = 1
		Global.dashes = Global.max_dashes
	else:
		coyote_timer += delta
	
	hop_timer = maxf(hop_timer - delta, 0.0)
	wall_lock_timer = maxf(wall_lock_timer - delta, 0.0)
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)
	
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER
	
	var jumped := false
	if jump_buffer_timer > 0.0:
		if on_wall and not on_floor:
			var wall_normal := get_wall_normal()
			velocity.x = wall_normal.x * WALL_JUMP_PUSH
			velocity.y = WALL_JUMP_HEIGHT
			wall_lock_timer = WALL_JUMP_LOCK
			current_dir = 1 if wall_normal.x > 0.0 else -1
			bird.flip_h = current_dir < 0
			flaps = 1
			Global.dashes = Global.max_dashes
			coyote_timer = 0.0
			jump_buffer_timer = 0.0
			jumped = true
		elif coyote_timer <= COYOTE_TIME and flaps > 0:
			flaps -= 1
			coyote_timer = COYOTE_TIME
			velocity.y = JUMP_VELOCITY
			jump_buffer_timer = 0.0
			jumped = true
	
	if Input.is_action_just_released("ui_accept") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT
	if Input.is_action_pressed("ui_accept") and not on_floor:
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
	
	if wall_lock_timer <= 0.0:
		var accel := FRICTION if on_floor else AIR_FRICTION
		velocity.x = move_toward(velocity.x, dir * SPEED, accel * delta)
	
	if Input.is_action_just_pressed("Dash") and Global.dashes > 0:
		var dash_dir := Vector2(dir, ydir)
		if dash_dir == Vector2.ZERO:
			dash_dir = Vector2(current_dir, 0)
		else:
			dash_dir = dash_dir.normalized()
		Global.dashes -= 1
		wall_lock_timer = 0.0
		velocity = dash_dir * (DASH_POWER if on_floor else DASH_POWER * 1.4)
	
	var incoming_speed_y := velocity.y
	
	move_and_slide()
	
	if is_on_floor() and incoming_speed_y > 50.0 and Input.is_action_pressed("ui_down") and Input.is_action_pressed("augment"):
		velocity.y = incoming_speed_y * 1.1 * -1.0
		velocity.x = 0.0
		Global.dashes = Global.max_dashes
	
	if is_on_floor() and Input.is_action_pressed("augment") and velocity.y > 50.0:
		velocity.x += velocity.y

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
	var turn_input := Input.get_axis(FLY_CCW_ACTION, FLY_CW_ACTION)
	var braking := Input.is_action_pressed(FLY_BRAKE_ACTION)
	
	if boost <= 0.0:
		boost_exhausted = true
	elif boost >= BOOST_RESTART_AMOUNT:
		boost_exhausted = false
	
	var boosting := Input.is_action_pressed(FLY_BOOST_ACTION) and not boost_exhausted
	is_boosting = boosting
	
	speed_floor = move_toward(speed_floor, FLY_MIN_SPEED, FLY_BOUNCE_RECOVERY * delta)
	
	var speed_t := clampf((speed - FLY_CRUISE_SPEED) / (FLY_MAX_SPEED - FLY_CRUISE_SPEED), 0.0, 1.0)
	var turn_rate := FLY_TURN_RATE * lerpf(1.0, FLY_FAST_TURN_MULT, speed_t)
	if braking:
		turn_rate *= FLY_BRAKE_TURN_MULT
	
	turn_speed = move_toward(turn_speed, turn_input * turn_rate, FLY_TURN_ACCEL * delta)
	heading = wrapf(heading + turn_speed * delta, -PI, PI)
	
	if turn_input == 0.0:
		var level_target := 0.0 if cos(heading) >= 0.0 else PI
		var level_step := FLY_AUTO_LEVEL * delta
		heading = wrapf(heading + clampf(angle_difference(heading, level_target), -level_step, level_step), -PI, PI)
	
	var heading_vec := Vector2.from_angle(heading)
	
	var target_speed = FLY_CRUISE_SPEED
	var accel := FLY_ACCEL
	if braking:
		target_speed = FLY_MIN_SPEED
		accel = FLY_BRAKE_DECEL
	elif boosting:
		target_speed = FLY_CRUISE_SPEED + 500.0
		accel = FLY_BOOST_ACCEL
	
	if speed > target_speed and not braking:
		accel = FLY_DRAG
	
	if speed_floor < FLY_MIN_SPEED:
		accel *= FLY_BOUNCE_ACCEL_MULT
	
	speed += heading_vec.y * FLY_GRAVITY * delta
	speed = move_toward(speed, target_speed, accel * delta)
	
	speed = clampf(speed, speed_floor, FLY_MAX_SPEED)
	
	if speed <= speed_floor + 10.0 and heading_vec.y < -0.2:
		var drop := clampf(angle_difference(heading, PI / 2.0), -FLY_STALL_TURN * delta, FLY_STALL_TURN * delta)
		heading = wrapf(heading + drop, -PI, PI)
		heading_vec = Vector2.from_angle(heading)
	
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
	
	var facing := 1.0 if cos(heading) >= 0.0 else -1.0
	flip_amount = move_toward(flip_amount, facing, FLY_FLIP_SPEED * delta)
	bird.rotation = heading
	bird.flip_h = false
	bird.flip_v = false
	bird.scale = Vector2(base_scale.x, base_scale.y * flip_amount)
	
	_update_camera(delta, (velocity * FLY_CAMERA_LOOK).limit_length(FLY_CAMERA_MAX_OFFSET))







func _update_wind(delta: float) -> void:
	var target := 0.0
	if Global.mode == Global.Mode.FLY:
		target = smoothstep(WIND_START_SPEED, WIND_FULL_SPEED, speed)
	wind_amount = move_toward(wind_amount, target, WIND_FADE_SPEED * delta)
	
	var emitting := wind_amount > 0.02
	var forward := Vector2.from_angle(heading)
	var side := forward.orthogonal()
	var time := Time.get_ticks_msec() * 0.008
	
	for i in wind_lines.size():
		var line: Line2D = wind_lines[i]
		line.global_transform = Transform2D.IDENTITY
		line.modulate.a = wind_amount
		
		if not emitting:
			line.clear_points()
			continue
		
		var lane_offset: float = WIND_LANE_OFFSETS[i]
		var lane_length: int = WIND_LANE_LENGTHS[i]
		var spread: float = lerpf(0.55, 1.0, wind_amount)
		var wobble: float = sin(time + i * 1.7) * 2.5 * wind_amount
		var head: Vector2 = global_position - forward * WIND_OFFSET + side * (lane_offset * spread + wobble)
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
