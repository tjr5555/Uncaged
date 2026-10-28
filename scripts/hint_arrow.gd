extends Node2D

const LABEL_GAP = 18.0

@onready var arrow: TextureRect = $Arrow
@onready var label: Label = $DistanceLabel

var presence: float = 0.0

func setup(color: Color, show_label: bool) -> void:
	arrow.modulate = color
	label.modulate = color
	label.visible = show_label

func update_hint(pos: Vector2, angle: float, distance_text: String, alpha: float, arrow_scale: float) -> void:
	position = pos
	arrow.rotation = angle
	arrow.scale = Vector2.ONE * arrow_scale
	modulate.a = alpha
	visible = alpha > 0.01
	
	if not label.visible:
		return
	
	label.text = distance_text
	var label_size := label.get_minimum_size()
	label.size = label_size
	var radius := arrow.size.x * arrow_scale * 0.5 + LABEL_GAP
	label.position = -Vector2.from_angle(angle) * radius - label_size * 0.5
