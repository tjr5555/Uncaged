class_name Waypoint
extends Marker2D

@export var label_text: String = ""
@export var color: Color = Color.WHITE
@export var hide_within: float = 600.0
@export var active: bool = true
@export var show_distance: bool = true

func _enter_tree() -> void:
	add_to_group("waypoints")
