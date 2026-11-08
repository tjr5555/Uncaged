@tool
class_name TutorialTrigger
extends Area2D

@export var trigger_id := "":
	set(value):
		trigger_id = value
		queue_redraw()
@export var size := Vector2(200.0, 200.0):
	set(value):
		size = value
		_update_shape()
		queue_redraw()
@export var one_shot := true
@export var editor_color := Color(0.3, 0.85, 1.0, 0.2)

var _shape_node: CollisionShape2D
var _fired := false

func _ready() -> void:
	_update_shape()
	if Engine.is_editor_hint():
		return
	if trigger_id == "":
		push_error("TutorialTrigger '%s': Trigger ID is empty")
	monitorable = false
	body_entered.connect(_on_body_entered)

func _update_shape() -> void:
	if _shape_node == null:
		_shape_node = CollisionShape2D.new()
		add_child(_shape_node, false, Node.INTERNAL_MODE_FRONT)
	var rect := _shape_node.shape as RectangleShape2D
	if rect == null:
		rect = RectangleShape2D.new()
		_shape_node.shape = rect
	rect.size = size

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var area := Rect2(-size * 0.5, size)
	draw_rect(area, editor_color)
	draw_rect(area, Color(editor_color, 1.0), false, 2.0)
	draw_string(ThemeDB.fallback_font, area.position + Vector2(8.0, 26.0), trigger_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(editor_color, 1.0))

func _on_body_entered(body: Node2D) -> void:
	if _fired and one_shot:
		return
	if not body.is_in_group("player"):
		return
	_fired = true
	get_tree().call_group("tutorial_guide", "on_trigger", trigger_id)
