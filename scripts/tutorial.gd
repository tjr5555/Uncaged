extends Node2D




func _on_npcdectzone_1_body_entered(body: Node2D) -> void:
	if not body.is_in_group("tilemap"):
		$npc2.visible = false


func _on_npcdectzone_2_body_entered(body: Node2D) -> void:
	if not body.is_in_group("tilemap"):
		$npc22.visible = false
