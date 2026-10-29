extends CharacterBody2D

# Set these per instance in the Inspector
@export_file("*.json") var dialogue_file: String
@export var npc_name: String = "wise crow"

const SPEED = 50.0
const MAX_DISTANCE = 10.0
const ACCELERATION = 100.0
var current_state = IDLE
var dir = Vector2.ZERO
var start_pos: Vector2

var is_roaming = true
var is_chatting = false
var player_is_in_chat_zone = false

enum {
	IDLE,
	MOVE
}

func _ready() -> void:
	$Label.visible = false
	randomize()
	start_pos = position
	$Timer.start()

	# Pass this instance's settings to its dialogue UI
	if dialogue_file != "":
		$npc2DialougeUI.d_file = dialogue_file
	$npc2DialougeUI.npc_name = npc_name

func _physics_process(delta: float) -> void:
	var target_velocity = Vector2.ZERO

	if is_roaming and not is_chatting:
		match current_state:
			IDLE:
				target_velocity = Vector2.ZERO
			MOVE:
				target_velocity = dir * SPEED
	velocity = velocity.move_toward(target_velocity, ACCELERATION * delta)

	move_and_slide()
	if position.distance_to(start_pos) > MAX_DISTANCE:
		dir = (start_pos - position).normalized()
		current_state = MOVE

	if Input.is_action_just_pressed("augment") and player_is_in_chat_zone == true:
		$Label.visible = false
		$npc2DialougeUI.start()
		is_roaming = false
		is_chatting = true


func choose(array):
	array.shuffle()
	return array.front()

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_is_in_chat_zone = true
		hide_label()

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_is_in_chat_zone = false
		hide_label()

func _on_timer_timeout() -> void:
	$Timer.wait_time = choose([2.0, 4.0, 5.0])

	# If getting close to the boundary limit, bias movement back home
	if position.distance_to(start_pos) > MAX_DISTANCE - 50.0:
		dir = (start_pos - position).normalized()
		current_state = MOVE
	else:
		current_state = choose([IDLE, MOVE])
		if current_state == MOVE:
			dir = choose([Vector2.RIGHT, Vector2.LEFT])


func hide_label():
	if player_is_in_chat_zone == true:
		$Label.visible = true
	else:
		$Label.visible = false


func _on_npc_1_dialouge_ui_dialogue_finished() -> void:
	is_chatting = false
	is_roaming = true
