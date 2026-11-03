extends Label

@export var bob_height := 10.0
@export var bob_period := 4.8
@export var breathe_amount := 0.02
@export var breathe_period := 7.0

var base_y := 0.0

func _ready() -> void:
	await get_tree().process_frame
	base_y = position.y
	pivot_offset = size * 0.5
	
	var bob := create_tween().set_loops()
	bob.tween_method(_apply_bob, 0.0, TAU, bob_period)
	
	var breathe := create_tween().set_loops()
	breathe.tween_method(_apply_breathe, 0.0, TAU, breathe_period)

func _apply_bob(phase: float) -> void:
	position.y = base_y + sin(phase) * bob_height

func _apply_breathe(phase: float) -> void:
	scale = Vector2.ONE * (1.0 + sin(phase) * breathe_amount)
