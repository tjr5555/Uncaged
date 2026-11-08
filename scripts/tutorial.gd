extends Node2D

func _ready() -> void:
	$player/Camera.zoom = Vector2(1.3,1.3)
	$player.scale = Vector2(0.75,0.75)
	$player.base_zoom = Vector2(1.3, 1.3)

func _on_npcdectzone_1_body_entered(body: Node2D) -> void:
	if not body.is_in_group("tilemap"):
		$npc2.visible = false

func _on_npcdectzone_2_body_entered(body: Node2D) -> void:
	if not body.is_in_group("tilemap"):
		$npc22.visible = false

func _on_npcdectzone_3_body_entered(body: Node2D) -> void:
	if not body.is_in_group("tilemap"):
		$npc23.visible = false

func _on_npcdectzone_4_body_entered(body: Node2D) -> void:
	pass # Replace with function body.
	if not body.is_in_group("tilemap"):
		$npc24.visible = false
