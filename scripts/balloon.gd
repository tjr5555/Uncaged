extends Area2D

@onready var anim: AnimatedSprite2D = $AnimationSprite
@onready var collision: CollisionShape2D = $Collision
var coin_value = 100000000

@onready var player = $"../player"
var regen_timer = 2
var current_regen_time = 0.0
var is_popped = false

func _ready() -> void:
	anim.frame = 0
	if not anim.is_connected("animation_finished", Callable(self, "_on_animation_finished")):
		anim.connect("animation_finished", Callable(self, "_on_animation_finished"))
	$AnimationSprite.self_modulate = Color.from_hsv(randf(), randf_range(0.6, 0.9), randf_range(0.93, 1.0))

func _physics_process(delta: float) -> void:
	if is_popped:
		current_regen_time += delta
		if current_regen_time >= regen_timer:
			respawn()

func pop():
	if is_popped:
		return
	is_popped = true
	current_regen_time = 0.0
	anim.play("pop")
	collision.set_deferred("disabled", true)

func _on_animation_finished() -> void:
	if anim.animation == "pop":
		anim.visible = false

func respawn():
	is_popped = false
	anim.visible = true
	anim.frame = 0
	collision.set_deferred("disabled", false)

func _on_body_entered(body: Node2D) -> void:
	if not is_popped:
		pop()
		$AudioStreamPlayer2D.play()
		Global.total_coins += coin_value
		print(str(Global.total_coins))
		player.dashes += 1
		print(str(player.dashes))
