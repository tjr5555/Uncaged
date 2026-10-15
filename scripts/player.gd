extends CharacterBody2D

enum Mode { GROUND, FLY }



var SPEED = 600.0
var JUMP_VELOCITY = -500.0
var JUMP_CUT = 0.45
var JUMP_BUFFER = 0.12
var COYOTE_TIME = 0.4
var HOP_VELOCITY = -220.0
var HOP_INTERVAL = 0.12
const BASE_GRAVITY = 1200.0
const DIVE_GRAVITY = 2400.0
const GLIDING_GRAVITY = 200.0
const INCREASED_GRAVITY = 1800.0
const AIR_FRICTION = 1500.0
const FRICTION = 3000.0
var DASH_POWER = 1000.0
var HOLD_DURATION = 0.3
var WALL_SLIDE_SPEED = 120.0
var WALL_JUMP_PUSH = 550.0
var WALL_JUMP_HEIGHT = -520.0
var WALL_JUMP_LOCK = 0.18

var FLY_CCW_ACTION = "ui_left"
var FLY_CW_ACTION = "ui_right"
var FLY_BOOST_ACTION = "ui_up"
var FLY_BRAKE_ACTION = "ui_down"

const FLY_ENTER_SPEED = 800.0
const FLY_MIN_SPEED = 450.0
const FLY_CRUISE_SPEED = 800.0
const FLY_BOOST_SPEED = 1300.0
const FLY_MAX_SPEED = 2200.0
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
const FLY_BOUNCE_LOSS = 0.7
const FLY_FLIP_SPEED = 14.0
const FLY_CAMERA_LOOK = 0.2
const FLY_CAMERA_MAX_OFFSET = 300.0
const FLY_CAMERA_MIN_ZOOM = 0.75

@onready var bird = $Sprite
@onready var base_scale: Vector2 = bird.scale
@onready var camera: Camera2D = get_node_or_null("Camera2D")
@onready var base_zoom: Vector2 = camera.zoom if camera else Vector2.ONE

var mode: Mode = Mode.GROUND

var flaps = 1
var dashes = 2
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


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_fly"):
		_set_mode(Mode.GROUND if mode == Mode.FLY else Mode.FLY)

	match mode:
		Mode.GROUND:
			_ground_physics(delta)
		Mode.FLY:
			_fly_physics(delta)


func _set_mode(new_mode: Mode) -> void:
	mode = new_mode
	if mode == Mode.FLY:
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


func _update_camera(delta: float, look: Vector2, zoom_factor: float) -> void:
	if camera == null:
		return
	var weight := 1.0 - exp(-3.0 * delta)
	camera.offset = camera.offset.lerp(look, weight)
	camera.zoom = camera.zoom.lerp(base_zoom * zoom_factor, weight)


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
		dashes = 2
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
			dashes = 2
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

	if on_floor and not jumped and dir != 0.0 and hop_timer <= 0.0:
		velocity.y = HOP_VELOCITY
		hop_timer = HOP_INTERVAL

	if wall_lock_timer <= 0.0:
		var accel := FRICTION if on_floor else AIR_FRICTION
		velocity.x = move_toward(velocity.x, dir * SPEED, accel * delta)

	if Input.is_action_just_pressed("Dash") and dashes > 0:
		var dash_dir := Vector2(dir, ydir)
		if dash_dir == Vector2.ZERO:
			dash_dir = Vector2(current_dir, 0)
		else:
			dash_dir = dash_dir.normalized()
		dashes -= 1
		wall_lock_timer = 0.0
		velocity = dash_dir * (DASH_POWER if on_floor else DASH_POWER * 1.4)

	var incoming_speed_y := velocity.y

	move_and_slide()

	if is_on_floor() and incoming_speed_y > 50.0 and Input.is_action_pressed("ui_down") and Input.is_action_pressed("augment"):
		velocity.y = incoming_speed_y * 1.1 * -1.0
		velocity.x = 0.0
		dashes = 2

	if is_on_floor() and Input.is_action_pressed("augment") and velocity.y > 50.0:
		velocity.x += velocity.y


func _fly_physics(delta: float) -> void:
	var turn_input := Input.get_axis(FLY_CCW_ACTION, FLY_CW_ACTION)
	var boosting := Input.is_action_pressed(FLY_BOOST_ACTION) or Input.is_action_pressed("ui_accept")
	var braking := Input.is_action_pressed(FLY_BRAKE_ACTION)

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

	var target_speed := FLY_CRUISE_SPEED
	var accel := FLY_ACCEL
	if braking:
		target_speed = FLY_MIN_SPEED
		accel = FLY_BRAKE_DECEL
	elif boosting:
		target_speed = FLY_BOOST_SPEED
		accel = FLY_BOOST_ACCEL

	if speed > target_speed and not braking:
		accel = FLY_DRAG

	speed += heading_vec.y * FLY_GRAVITY * delta
	speed = move_toward(speed, target_speed, accel * delta)

	if Input.is_action_just_pressed("Dash"):
		speed += FLY_DASH_BOOST

	speed = clampf(speed, FLY_MIN_SPEED, FLY_MAX_SPEED)

	if speed <= FLY_MIN_SPEED + 10.0 and heading_vec.y < -0.2:
		var drop := clampf(angle_difference(heading, PI / 2.0), -FLY_STALL_TURN * delta, FLY_STALL_TURN * delta)
		heading = wrapf(heading + drop, -PI, PI)
		heading_vec = Vector2.from_angle(heading)

	velocity = velocity.lerp(heading_vec * speed, 1.0 - exp(-FLY_VELOCITY_SMOOTH * delta))

	move_and_slide()

	if get_slide_collision_count() > 0:
		var normal := get_last_slide_collision().get_normal()
		if heading_vec.dot(normal) < 0.0:
			heading_vec = heading_vec.bounce(normal)
			heading = heading_vec.angle()
			speed = maxf(speed * FLY_BOUNCE_LOSS, FLY_MIN_SPEED)
			velocity = heading_vec * speed

	var facing := 1.0 if cos(heading) >= 0.0 else -1.0
	flip_amount = move_toward(flip_amount, facing, FLY_FLIP_SPEED * delta)
	bird.rotation = heading
	bird.flip_h = false
	bird.flip_v = false
	bird.scale = Vector2(base_scale.x, base_scale.y * flip_amount)

	var zoom_t := clampf((speed - FLY_CRUISE_SPEED) / (FLY_MAX_SPEED - FLY_CRUISE_SPEED), 0.0, 1.0)
	_update_camera(delta, (velocity * FLY_CAMERA_LOOK).limit_length(FLY_CAMERA_MAX_OFFSET), lerpf(1.0, FLY_CAMERA_MIN_ZOOM, zoom_t))
