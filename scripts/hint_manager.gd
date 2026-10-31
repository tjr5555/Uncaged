extends Control

const ARROW_SCENE = preload("res://scenes/hint_arrow.tscn")
const MARGIN_LEFT = 48.0
const MARGIN_TOP = 170.0
const MARGIN_RIGHT = 48.0
const MARGIN_BOTTOM = 48.0
const NEAR_DISTANCE = 2000.0
const FAR_DISTANCE = 20000.0
const VANISH_DISTANCE = 99999999
const FAR_ALPHA = 0.1
const FADE_OUT_TIME = 0.8
const MAX_SCALE = 0.2
const MIN_SCALE = 0.08
const PRECISE_RANGE_M = 300.0
const FAR_STEP = 10
const LABEL_MIN_SCALE = 0.8
const LABEL_MAX_SCALE = 1.25

var arrows: Dictionary = {}

func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		_clear_arrows()
		return
	
	var alive := _sync_arrows(get_tree().get_nodes_in_group("waypoints"))
	
	var viewport_size := get_viewport_rect().size
	var screen_center := viewport_size * 0.5
	var safe_rect := Rect2(Vector2(MARGIN_LEFT, MARGIN_TOP), viewport_size - Vector2(MARGIN_LEFT + MARGIN_RIGHT, MARGIN_TOP + MARGIN_BOTTOM))
	var canvas_xf := get_viewport().get_canvas_transform()
	
	for id in alive:
		_update_arrow(alive[id] as Waypoint, arrows[id], player, canvas_xf, screen_center, safe_rect, delta)

func _sync_arrows(targets: Array[Node]) -> Dictionary:
	var alive := {}
	for t in targets:
		var id := t.get_instance_id()
		alive[id] = t
		if not arrows.has(id):
			arrows[id] = _make_arrow(t as Waypoint)
	
	for id in arrows.keys():
		if not alive.has(id):
			arrows[id].queue_free()
			arrows.erase(id)
	
	return alive

func _make_arrow(target: Waypoint) -> Node2D:
	var arrow := ARROW_SCENE.instantiate()
	add_child(arrow)
	arrow.setup(target.color, target.show_distance or target.label_text != "")
	return arrow

func _label_text(target: Waypoint, distance: float) -> String:
	var meters := distance / 10.0
	var step := 1 if meters < PRECISE_RANGE_M else FAR_STEP
	
	var parts := PackedStringArray()
	if target.label_text != "":
		parts.append(target.label_text)
	if target.show_distance:
		parts.append(str(snappedi(int(meters), step)) + " m")
	return "  ".join(parts)

func _update_arrow(target: Waypoint, arrow: Node2D, player: Node2D, canvas_xf: Transform2D, screen_center: Vector2, safe_rect: Rect2, delta: float) -> void:
	var screen_pos := canvas_xf * target.global_position
	var distance := player.global_position.distance_to(target.global_position)
	
	var presence_target := 1.0 if distance <= VANISH_DISTANCE else 0.0
	arrow.presence = move_toward(arrow.presence, presence_target, delta / FADE_OUT_TIME)
	
	if not target.active or distance < target.hide_within or safe_rect.has_point(screen_pos):
		arrow.visible = false
		return
	
	var dir := screen_pos - screen_center
	if dir.is_zero_approx():
		arrow.visible = false
		return
	
	var distance_alpha := clampf(remap(distance, NEAR_DISTANCE, FAR_DISTANCE, 1.0, FAR_ALPHA), FAR_ALPHA, 1.0)
	var arrow_scale := clampf(remap(distance, NEAR_DISTANCE, FAR_DISTANCE, MAX_SCALE, MIN_SCALE), MIN_SCALE, MAX_SCALE)
	var closeness := inverse_lerp(MIN_SCALE, MAX_SCALE, arrow_scale)
	var label_scale := lerpf(LABEL_MIN_SCALE, LABEL_MAX_SCALE, closeness)
	var edge_pos := _ray_to_rect_edge(screen_center, dir, safe_rect)
	
	arrow.update_hint(edge_pos, dir.angle(), _label_text(target, distance), distance_alpha * arrow.presence, arrow_scale, label_scale)






func _ray_to_rect_edge(origin: Vector2, dir: Vector2, rect: Rect2) -> Vector2:
	var t := INF
	if dir.x > 0.0:
		t = minf(t, (rect.end.x - origin.x) / dir.x)
	elif dir.x < 0.0:
		t = minf(t, (rect.position.x - origin.x) / dir.x)
	if dir.y > 0.0:
		t = minf(t, (rect.end.y - origin.y) / dir.y)
	elif dir.y < 0.0:
		t = minf(t, (rect.position.y - origin.y) / dir.y)
	return origin + dir * t

func _clear_arrows() -> void:
	for id in arrows.keys():
		arrows[id].queue_free()
	arrows.clear()
