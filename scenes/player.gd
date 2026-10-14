extends CharacterBody2D

const SPEED = 600.0
const JUMP_VELOCITY = -500.0
var BASE_GRAVITY = 1200.0
var DIVE_GRAVITY = 2400.0
var GLIDING_GRAVITY = 200.0
var INCREASED_GRAVITY = 1800

var gravity = BASE_GRAVITY
var flaps = 1
var flap_boost = 0
var air_friction = 1500
var friction = 3000
var dash_power = 1000
var dashes = 2
var current_dir = 1
var current_ydir = 0

var coyete_timer: float = 0.0
var coyete_time: float = 0.4

var hold_timer: float = 0.0
var hold_dur: float = 0.3
var is_gliding: bool = false

func _physics_process(delta: float) -> void:
	# Get input directions
	var dir := Input.get_axis("ui_left", "ui_right")
	var ydir := Input.get_axis("ui_up", "ui_down")
	var current_accel = friction if is_on_floor() else air_friction

	# Track last pressed directions for directional dashing
	if Input.is_action_just_pressed("ui_left"):
		current_dir = -1
	if Input.is_action_just_pressed("ui_right"):
		current_dir = 1
	if Input.is_action_just_pressed("ui_up"):
		current_ydir = -1
	elif Input.is_action_just_pressed("ui_down"):
		current_ydir = 1
	elif dir != 0:
		current_dir = dir
		current_ydir = 0

	# Coyote time logic
	if not is_on_floor():
		coyete_timer += delta
	else:
		coyete_timer = 0.0

	# Jump input using coyote window
	if Input.is_action_just_pressed("ui_accept") and coyete_timer <= coyete_time and flaps > 0:
		coyete_timer = coyete_time
		flaps -= 1
		velocity.y = JUMP_VELOCITY

	# Glide mode activation/deactivation logic
	if Input.is_action_pressed("ui_accept") and not is_on_floor():
		hold_timer += delta
		if hold_timer >= hold_dur and not is_gliding and velocity.y > 0:
			is_gliding = true
			gravity = GLIDING_GRAVITY
	else:
		hold_timer = 0
		if is_gliding:
			is_gliding = false
			gravity = BASE_GRAVITY

	# Gravity and falling logic
	if not is_on_floor():
		if Input.is_action_pressed("ui_down"):
			gravity = DIVE_GRAVITY
		elif is_gliding:
			gravity = GLIDING_GRAVITY
		else:
			gravity = BASE_GRAVITY if velocity.y <= 0 else INCREASED_GRAVITY
			
		velocity.y += gravity * delta
	else:
		flaps = 1
		dashes = 2
		gravity = BASE_GRAVITY

	# Horizontal movement acceleration/friction
	if dir:
		velocity.x = move_toward(velocity.x, dir * SPEED, current_accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, current_accel * delta)

	if Input.is_action_just_pressed("Dash") and dashes > 0:
		var dash_dir = Vector2(dir, ydir)
		
		# If no movement or vertical keys are pressed, dash in the direction you last faced horizontally
		if dash_dir == Vector2.ZERO:
			dash_dir = Vector2(current_dir, 0)
		else:
			dash_dir = dash_dir.normalized()
			
		dashes -= 1
		var current_dash_power = dash_power * 1.4 if not is_on_floor() else dash_power
		velocity = dash_dir * current_dash_power

	# Store speeds before move_and_slide for wallkick / slam checks
	var incoming_speed_x = abs(velocity.x)
	var incoming_speed_y = velocity.y

	# Apply movement
	move_and_slide()

	# Slam check
	if is_on_floor() and incoming_speed_y > 50.0 and Input.is_action_pressed("ui_down") and Input.is_action_pressed("augment"):
		velocity.y = (incoming_speed_y * 1.1) * -1
		velocity.x = 0
		dashes = 2

	# Wallkick check
	if is_on_wall() and incoming_speed_x > 50.0 and Input.is_action_pressed("augment"):
		velocity.y = incoming_speed_x * -1
		velocity.x = 0 
		dashes = 2

	if is_on_floor() and Input.is_action_pressed("augment") and velocity.y > 50:
		velocity.x += velocity.y
