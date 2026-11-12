extends Node2D

const FOG_SHADER = preload("res://shaders/fog.gdshader")

const LAYERS = [
	{"scale": 0.35, "haze": 0.6, "parallax": 0.25, "y": Vector2(0.42, 0.58), "count": 5, "sides_only": false, "speed": 0.5, "weight": 0.45},
	{"scale": 0.6, "haze": 0.32, "parallax": 0.55, "y": Vector2(0.55, 0.75), "count": 3, "sides_only": false, "speed": 0.75, "weight": 0.35},
	{"scale": 0.95, "haze": 0.08, "parallax": 1.0, "y": Vector2(0.8, 1.0), "count": 2, "sides_only": true, "speed": 1.0, "weight": 0.2},
]

@export var island_scenes: Array[PackedScene] = []
@export var balloon_scene: PackedScene
@export var portal_scene: PackedScene
@export var haze_color := Color(0.85, 0.9, 0.97)
@export var sky_node: CanvasItem
@export var mouse_parallax := 40.0
@export var parallax_smooth := 3.0

@export_group("Portal")
@export var portal_color := Color(0.55, 0.35, 1.0)
@export var portal_anchor := Vector2(0.8, 0.52)
@export var portal_face_left := true

@export_group("Balloons")
@export var balloon_interval := Vector2(0.5, 1.3)
@export var balloon_rise_speed := Vector2(50.0, 110.0)
@export var balloon_base_scale := 1.35
@export var prewarm_balloons := 10

@export_group("Clouds")
@export var far_cloud_coverage := 0.42
@export var far_cloud_alpha := 0.6
@export var near_cloud_coverage := 0.32
@export var near_cloud_alpha := 0.35

var layers: Array[Node2D] = []
var balloon_roots: Array[Node2D] = []
var balloons: Array[Dictionary] = []
var hazed: Array[Dictionary] = []
var spawn_timer := 0.0
var mouse_offset := Vector2.ZERO

func _ready() -> void:
	if island_scenes.is_empty():
		push_warning("MenuWorld: Island Scenes is empty in Exports")
	if balloon_scene == null:
		push_warning("MenuWorld: Balloon scene not set in Exports")
	if portal_scene == null:
		push_warning("MenuWorld: Portal scene not set in Exports")
	
	var view := get_viewport_rect().size
	
	for i in LAYERS.size():
		if i == 1:
			_add_clouds(view, far_cloud_coverage, far_cloud_alpha, Vector2(0.02, 0.0), 2.5)
		
		var layer := Node2D.new()
		add_child(layer)
		var balloon_root := Node2D.new()
		layer.add_child(balloon_root)
		var island_root := Node2D.new()
		layer.add_child(island_root)
		
		layers.append(layer)
		balloon_roots.append(balloon_root)
		_place_islands(island_root, LAYERS[i], view)
	
	_place_portal(view)
	_add_clouds(view, near_cloud_coverage, near_cloud_alpha, Vector2(0.035, 0.0), 1.6)
	
	for k in prewarm_balloons:
		_spawn_balloon(randf_range(0.0, view.y))

func _process(delta: float) -> void:
	_update_parallax(delta)
	
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = randf_range(balloon_interval.x, balloon_interval.y)
		_spawn_balloon(get_viewport_rect().size.y + 80.0)
	
	_move_balloons(delta)
	
	if sky_node != null:
		_apply_haze()

func _place_islands(root: Node2D, cfg: Dictionary, view: Vector2) -> void:
	if island_scenes.is_empty():
		return
	
	var count: int = cfg["count"]
	var y_range: Vector2 = cfg["y"]
	var s: float = cfg["scale"]
	
	for k in count:
		var scene: PackedScene = island_scenes.pick_random()
		var island := scene.instantiate() as Node2D
		var bounds := _measure_bounds(island)
		
		var x_t := (float(k) + randf_range(0.2, 0.8)) / float(count)
		if cfg["sides_only"]:
			x_t = randf_range(0.0, 0.2) if k % 2 == 0 else randf_range(0.8, 1.0)
		
		var target := Vector2(lerpf(-0.05, 1.05, x_t) * view.x, randf_range(y_range.x, y_range.y) * view.y)
		var flip := -1.0 if randf() < 0.5 else 1.0
		island.scale = Vector2(s * flip, s)
		island.position = target - bounds.get_center() * island.scale
		root.add_child(island)
		
		_register_haze(island, cfg["haze"])
		_start_bob(island, randf_range(6.0, 14.0) * s, randf_range(3.5, 6.0))

func _place_portal(view: Vector2) -> void:
	if portal_scene == null:
		return
	
	var cfg: Dictionary = LAYERS[1]
	var portal := portal_scene.instantiate() as Node2D
	portal.set("color", portal_color)
	portal.set("face_left", portal_face_left)
	portal.set("label_text", "")
	portal.set("decorative", true)
	portal.position = Vector2(portal_anchor.x * view.x, portal_anchor.y * view.y)
	portal.scale = Vector2.ONE * float(cfg["scale"])
	layers[1].add_child(portal)
	_start_bob(portal, 8.0, 5.0)

func _add_clouds(view: Vector2, coverage: float, alpha: float, drift: Vector2, scale_amount: float) -> void:
	var rect := ColorRect.new()
	rect.size = view
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = FOG_SHADER
	mat.set_shader_parameter("coverage", coverage)
	mat.set_shader_parameter("edge_bias", 0.0)
	mat.set_shader_parameter("drift", drift)
	mat.set_shader_parameter("cloud_scale", scale_amount)
	mat.set_shader_parameter("fog_color", Color(1.0, 1.0, 1.0))
	mat.set_shader_parameter("shade_color", haze_color)
	rect.material = mat
	rect.modulate.a = alpha
	add_child(rect)

func _spawn_balloon(start_y: float) -> void:
	if balloon_scene == null:
		return
	
	var layer_index := _pick_balloon_layer()
	var cfg: Dictionary = LAYERS[layer_index]
	var layer_scale: float = cfg["scale"]
	
	var balloon := balloon_scene.instantiate() as Node2D
	balloon.scale = Vector2.ONE * balloon_base_scale * layer_scale
	balloon.position = Vector2(randf() * get_viewport_rect().size.x, start_y)
	balloon.set("monitoring", false)
	balloon.set("monitorable", false)
	balloon_roots[layer_index].add_child(balloon)
	_register_haze(balloon, cfg["haze"])
	
	balloons.append({
		"node": balloon,
		"speed": randf_range(balloon_rise_speed.x, balloon_rise_speed.y) * float(cfg["speed"]),
		"base_x": balloon.position.x,
		"phase": randf() * TAU,
		"sway": randf_range(6.0, 18.0) * layer_scale,
		"sway_speed": randf_range(0.6, 1.2),
	})

func _pick_balloon_layer() -> int:
	var roll := randf()
	for i in LAYERS.size():
		roll -= float(LAYERS[i]["weight"])
		if roll <= 0.0:
			return i
	return LAYERS.size() - 1

func _move_balloons(delta: float) -> void:
	var t:= Time.get_ticks_msec() / 1000.0
	for i in range(balloons.size() -1, -1, -1):
		var b: Dictionary = balloons[i]
		var node: Node2D = b["node"]
		if not is_instance_valid(node):
			balloons.remove_at(i)
			continue
		
		node.position.y -= float(b["speed"]) * delta
		node.position.x = float(b["base_x"]) + sin(t * float(b["sway_speed"]) + float(b["phase"])) * float(b["sway"])
		
		if node.position.y < -120.0:
			node.queue_free()
			balloons.remove_at(i)

func _update_parallax(delta: float) -> void:
	var view := get_viewport_rect().size
	var target := (get_viewport().get_mouse_position() / view - Vector2(0.5, 0.5)) * 2.0
	target = target.clamp(Vector2(-1.0, -1.0), Vector2(1.0, 1.0))
	mouse_offset = mouse_offset.lerp(target, 1.0 - exp(-parallax_smooth * delta))
	
	for i in layers.size():
		layers[i].position = -mouse_offset * mouse_parallax * float(LAYERS[i]["parallax"])

func _start_bob(node: Node2D, amplitude: float, period: float) -> void:
	var base_y := node.position.y
	var base_rotation := node.rotation
	var offset := randf() * TAU
	var tween := node.create_tween().set_loops()
	tween.tween_method(func(phase: float): 
		node.position.y = base_y + sin(phase) * amplitude
		node.rotation = base_rotation + cos(phase) * 0.008
		, offset, offset + TAU, period)

func _register_haze(node: CanvasItem, amount: float) -> void:
	node.modulate = Color.WHITE.lerp(haze_color, amount)
	hazed.append({"node": node, "amount": amount})

func _apply_haze() -> void:
	var tint := haze_color * sky_node.modulate
	tint.a = 1.0
	for i in range(hazed.size() - 1, -1. -1):
		var entry: Dictionary = hazed[i]
		var node = entry["node"]
		if not is_instance_valid(node):
			hazed.remove_at(i)
			continue
		var target := Color.WHITE.lerp(tint, float(entry["amount"]))
		target.a = node.modulate.a
		node.modulate = target

func _measure_bounds(root: Node) -> Rect2:
	var found: Array[Node] = root.find_children("*", "TileMapLayer", true, false)
	if root is TileMapLayer:
		found.append(root)
	
	var bounds := Rect2()
	var has_bounds := false
	for node in found:
		var layer := node as TileMapLayer
		if layer.tile_set == null:
			continue
		var used := layer.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		var tile_size := Vector2(layer.tile_set.tile_size)
		var top_left := layer.map_to_local(used.position) - tile_size * 0.5
		var rect := _relative_transform(layer, root) * Rect2(top_left, Vector2(used.size) * tile_size)
		bounds = bounds.merge(rect) if has_bounds else rect
		has_bounds = true
	return bounds

func _relative_transform(node: Node, root: Node) -> Transform2D:
	var xf := Transform2D.IDENTITY
	var current := node
	while current != null and current != root:
		if current is Node2D:
			xf = (current as Node2D).transform * xf
		current = current.get_parent()
	return xf
