extends CharacterBody2D

enum State { GROUND, FLYING }
var current_state = State.GROUND

const WALK_SPEED = 250.0
const TAKEOFF_FORCE = -400.0

const GRAVITY = 300.0
const DRAG = 0.0003
const FLAP_STRENGTH = 500.0
const MAX_FLY_SPEED = 900.0
const TURN_SPEED = 7.0

var flight_angle = 0.0

@onready var camera: Camera2D = $Camera
const MIN_ZOOM = Vector2(1.1, 1.1)
const MAX_ZOOM = Vector2(0.3, 0.3)

func _physics_process(delta: float) -> void:
	match current_state:
		State.GROUND:
			_process_ground(delta)
		State.FLYING:
			_process_flying(delta)
	
	var speed = velocity.length()
	var speed_ratio = clamp(speed / 700.0, 0.0, 1.0)
	camera.zoom = camera.zoom.lerp(MIN_ZOOM.lerp(MAX_ZOOM, speed_ratio), delta * 3.0)

func _process_ground(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0
	
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * WALK_SPEED
		scale.x = 1.0 if direction > 0 else -1.0
		flight_angle = 0.0 if direction > 0 else PI
	else:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED * delta * 6.0)
	
	rotation = 0.0
	
	if Input.is_action_just_pressed("flap"):
		current_state = State.FLYING
		velocity.y = TAKEOFF_FORCE
		velocity.x += scale.x * 250.0
	
	move_and_slide()
	
	if not is_on_floor() and velocity.y > 10.0:
		current_state = State.FLYING

func _process_flying(delta: float) -> void:
	var input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if input_vector.length() > 0.1:
		var target_angle = input_vector.angle()
		flight_angle = lerp_angle(flight_angle, target_angle, TURN_SPEED * delta)
	
	if cos(flight_angle) >= 0:
		scale.x = 1.0
		rotation = flight_angle
	else:
		scale.x = -1.0
		rotation = flight_angle - PI

	if Input.is_action_just_pressed("flap"):
		var thrust_dir = Vector2.RIGHT.rotated(flight_angle)
		velocity += thrust_dir * FLAP_STRENGTH
		
		if thrust_dir.y < 0:
			velocity.y -= 120.0
		
		if velocity.length() > MAX_FLY_SPEED:
			velocity = velocity.limit_length(MAX_FLY_SPEED)

	velocity.y += GRAVITY * delta
	velocity -= velocity * velocity.length() * DRAG * delta
	
	var speed = velocity.length()
	if speed > 80.0:
		var forward_dir = Vector2.RIGHT.rotated(flight_angle)
		velocity = velocity.slerp(forward_dir * speed, 0.08)

	move_and_slide()

	if is_on_floor():
		if abs(velocity.y) < 220.0 and speed < 350.0:
			current_state = State.GROUND
			velocity.x *= 0.5
			scale.x = 1.0
			rotation = 0.0
			flight_angle = 0.0
		else:
			velocity.y = -velocity.y * 0.25
