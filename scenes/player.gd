extends CharacterBody2D

const SPEED = 500.0
const JUMP_VELOCITY = -500.0
var BASE_GRAVITY = 800.0
var DIVE_GRAVITY = 1600.0
var GLIDING_GRAVITY = 200.0

var gravity = BASE_GRAVITY
var flaps = 1
var flap_boost = 0
var air_friction = 2000
var friction = 5000
var dash_power = 1000
var dashes = 2


var hold_timer: float = 0.0
var hold_dur: float = 0.3
var is_gliding: bool = false
func _physics_process(delta: float) -> void:






	# Handle gravity and diving
	if not is_on_floor():
		# Check if holding down to dive, or if gliding
		if Input.is_action_pressed("ui_down"):
			gravity = DIVE_GRAVITY
		elif is_gliding:
			gravity = GLIDING_GRAVITY
		else:
			gravity = BASE_GRAVITY
			
		velocity.y += gravity * delta
	else:
		flaps = 1
		dashes = 2
		gravity = BASE_GRAVITY
	var incoming_speed_x = abs(velocity.x)
	var incoming_speed_y = velocity.y
	
	move_and_slide()
	
	
	
	
	if is_on_wall() and incoming_speed_x > 50.0 and Input.is_action_pressed("augment"):
		print("is on wall")
		velocity.y += incoming_speed_x/1.5 * -1
		velocity.x = 0 
		dashes = 2
	# Get horizontal input direction and handle movement/friction
	var dir := Input.get_axis("ui_left", "ui_right")
	var ydir := Input.get_axis("ui_up", "ui_down")
	var current_accel = friction if is_on_floor() else air_friction

	if is_on_floor() and Input.is_action_pressed("augment") and velocity.y > 50:
		velocity.x += velocity.y

	if dir:
		velocity.x = move_toward(velocity.x, dir * SPEED, current_accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, current_accel * delta)



	if Input.is_action_just_pressed("Dash") and dashes > 0:
		dashes -= 1
		velocity.x = dash_power * 1.4 * dir
		velocity.y = dash_power * ydir


	# Handle jump / flap
	if Input.is_action_just_pressed("ui_accept") and flaps > 0:
		flaps -= 1
		print("Flaps left: " + str(flaps))
		velocity.y = JUMP_VELOCITY
		print("ydir:" + str(ydir))
		if dir != 0:
			velocity.x += flap_boost * dir
#Glide mode logic
	if Input.is_action_pressed("ui_accept"):
		hold_timer += delta
		if hold_timer >= hold_dur and is_gliding == false:
			print("glide mode on!")
			is_gliding = true
			gravity = GLIDING_GRAVITY
			print("current gravity: " + str(gravity))

	else:
		hold_timer = 0
		if is_gliding:
			print("glide mode off!")
			is_gliding = false
			gravity = BASE_GRAVITY
