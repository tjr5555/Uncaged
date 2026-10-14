extends Area2D

@onready var anim: AnimatedSprite2D = $AnimationSprite

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func pop():
	anim.frame = 0
	anim.play("pop")


func _on_animation_sprite_animation_finished() -> void:
	queue_free()


func _on_animation_sprite_frame_changed() -> void:
	if anim.frame >= 8:
		$Collision.disabled = true
	else:
		$Collision.disabled = false
