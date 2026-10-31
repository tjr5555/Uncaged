extends Area2D

signal popped(respawn_time: float)

@export var respawn_time := 60.0

@onready var anim: AnimatedSprite2D = $AnimationSprite
@onready var collision: CollisionShape2D = $Collision

var coin_value = 10
var tint := Color(0, 0, 0, 0)
var current_regen_time := 0.0
var is_popped := false

func _ready() -> void:
	anim.frame = 0
	if not anim.animation_finished.is_connected(_on_animation_finished):
		anim.animation_finished.connect(_on_animation_finished)
	if tint.a > 0.0:
		anim.self_modulate = tint
	else:
		anim.self_modulate = Color.from_hsv(randf(), randf_range(0.6, 0.9), randf_range(0.93, 1.0))
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	current_regen_time += delta
	if current_regen_time >= respawn_time:
		respawn()

func pop() -> void:
	if is_popped:
		return
	is_popped = true
	current_regen_time = 0.0
	anim.play("pop")
	collision.set_deferred("disabled", true)
	set_physics_process(true)
	popped.emit(respawn_time)

func start_popped(remaining: float) -> void:
	is_popped = true
	current_regen_time = maxf(respawn_time - remaining, 0.0)
	anim.visible = false
	collision.set_deferred("disabled", true)
	set_physics_process(true)

func _on_animation_finished() -> void:
	if anim.animation == "pop":
		anim.visible = false

func respawn() -> void:
	is_popped = false
	anim.visible = true
	anim.frame = 0
	collision.set_deferred("disabled", false)
	set_physics_process(false)

func _on_body_entered(body: Node2D) -> void:
	if is_popped or not body.is_in_group("player"):
		return
	pop()
	$AudioStreamPlayer2D.play()
	Global.total_coins += coin_value * Global.base_coin_mult
	Global.dashes += 1
