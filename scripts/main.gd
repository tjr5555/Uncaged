extends Node2D

@export var island_scenes: Array[PackedScene] = []
@export var player: Node2D
@export var world_seed := 12345
@export var chunk_size := 3000.0
@export var load_radius := 2        # chunks loaded around the player
@export var unload_radius := 3      # chunks farther than this get unloaded
@export var safe_radius := 5000.0   # no islands within this distance of world origin

@export_group("Streaming")
@export var prefetch_time := 1.2
@export var spawn_budget_ms := 2.0
@export var fade_in_time := 0.6

@export_group("Regions")
@export var region_size := 24000.0
@export_range(0.0, 1.0) var sparse_empty_chance := 0.85
@export_range(0.0, 1.0) var dense_empty_chance := 0.1

@export_group("Clumping")
@export var min_islands_per_chunk := 2  # islands in a clump (when the chunk isnt empty)
@export var max_islands_per_chunk := 4
@export var cluster_radius := 1100.0    # how spread out a clump is (smaller = tighter clump)

@export_group("Spacing")
@export var min_spacing := 1000.0      # min distance between island centers. MUST be >= widest island * max scale + a small gap
@export var edge_margin := 500.0       # must be >= min_spacing / 2 so islands in neighboring chunks cant touch
@export var island_scale := 1.0
@export var scale_min := 0.8           # random size range (multiplied by island_scale)
@export var scale_max := 1.4

@export_group("Balloons")
@export var balloon_scene: PackedScene
@export var min_lines_per_island := 2
@export var max_lines_per_island := 3
@export var min_line_length := 4
@export var max_line_length := 8
@export var balloon_spacing := 90.0
@export var balloon_clearance := 140.0
@export var max_line_bend := 120.0
@export_range(0.0, 1.0) var sky_line_chance := 0.35
@export var max_sky_lines := 2
@export var hue_step := 0.035

@export_group("")
@export var debug_prints := false     # log spawns/unloads to Output

var loaded: Dictionary = {}
var chunk_tokens: Dictionary = {}
var spawn_queue: Array[Dictionary] = []
var next_token := 0
var center_chunk := Vector2i(999999, 999999)
var ahead_chunk := Vector2i(999999, 999999)
var islands_root: Node2D
var noise := FastNoiseLite.new()

var balloons_root: Node2D
var island_bounds: Array[Rect2] = []
var popped_until: Dictionary = {}

func _ready() -> void:
	$player.boost_changed.connect($UI.set_boost)
	
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
	
	islands_root = Node2D.new()
	islands_root.name = "Islands"
	add_child(islands_root)
	balloons_root = Node2D.new()
	balloons_root.name = "Balloons"
	add_child(balloons_root)
	if player != null and player.get_parent() == self:
		move_child(islands_root, player.get_index())
		move_child(balloons_root, player.get_index())
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0 / maxf(region_size, 1.0)
	
	for scene in island_scenes:
		island_bounds.append(_measure_scene(scene))

func _process(_delta: float) -> void:
	if player == null:
		return
	
	var focus := _focus_point()
	var pc := _chunk_of(player.global_position)
	var ac := _chunk_of(focus)
	
	if pc != center_chunk or ac != ahead_chunk:
		center_chunk = pc
		ahead_chunk = ac
		_unload_far()
		_load_around(pc)
		_load_around(ac)
		_sort_queue(focus)
	
	_spawn_from_queue()

func _focus_point() -> Vector2:
	var body := player as CharacterBody2D
	if body == null:
		return player.global_position
	return player.global_position + body.velocity * prefetch_time

func _chunk_of(pos: Vector2) -> Vector2i:
	return Vector2i((pos / chunk_size).floor())

func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

func _load_around(c: Vector2i) -> void:
	for x in range(c.x - load_radius, c.x + load_radius + 1):
		for y in range(c.y - load_radius, c.y + load_radius + 1):
			var coord := Vector2i(x, y)
			if not loaded.has(coord):
				_plan_chunk(coord)

func _unload_far() -> void:
	var keep_radius := maxi(unload_radius, load_radius + 1)
	for coord in loaded.keys():
		if _chebyshev(coord, center_chunk) > keep_radius and _chebyshev(coord, ahead_chunk) > keep_radius:
			if debug_prints:
				print("unloading chunk ", coord)
			for island in loaded[coord]:
				if is_instance_valid(island):
					island.queue_free()
			loaded.erase(coord)
			chunk_tokens.erase(coord)

func _density_at(p: Vector2) -> float:
	return clampf(noise.get_noise_2dv(p) * 0.7 + 0.5, 0.0, 1.0)

func _plan_chunk(coord: Vector2i) -> void:
	var nodes: Array[Node2D] = []
	loaded[coord] = nodes
	next_token += 1
	var token := next_token
	chunk_tokens[coord] = token
	
	var island_rects := _plan_islands(coord, token)
	_plan_balloons(coord, token, island_rects)

func _plan_islands(coord: Vector2i, token: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if island_scenes.is_empty():
		return rects
	
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(coord.x, coord.y, world_seed))
	
	var origin := Vector2(coord) * chunk_size
	var density := _density_at(origin + Vector2.ONE * chunk_size * 0.5)
	if rng.randf() < lerpf(sparse_empty_chance, dense_empty_chance, density):
		return rects
	
	var margin := clampf(maxf(edge_margin, min_spacing * 0.5), 0.0, chunk_size * 0.5 - 1.0)
	var area := Rect2(origin + Vector2(margin, margin), Vector2.ONE * (chunk_size - margin * 2.0))
	var center_area := area.grow(-minf(cluster_radius * 0.5, area.size.x * 0.5 - 1.0))
	var center := Vector2(
		rng.randf_range(center_area.position.x, center_area.end.x),
		rng.randf_range(center_area.position.y, center_area.end.y))
	
	var lo := mini(min_islands_per_chunk, max_islands_per_chunk)
	var hi := maxi(min_islands_per_chunk, max_islands_per_chunk)
	var count := clampi(roundi(lerpf(lo, hi, density) + rng.randf_range(-0.75, 0.75)), lo, hi)
	var positions: Array[Vector2] = []
	
	for i in count:
		for attempt in 16:
			var pos := center + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * cluster_radius
			if not area.has_point(pos) or pos.length() < safe_radius or _too_close(pos, positions):
				continue
			
			positions.append(pos)
			var s := rng.randf_range(scale_min, scale_max) * island_scale
			var flip := -1.0 if rng.randf() < 0.5 else 1.0
			var scene_index := rng.randi() % island_scenes.size()
			var scale_vec := Vector2(s * flip, s)
			spawn_queue.append({
				"coord": coord,
				"token": token,
				"kind": "island",
				"scene": island_scenes[scene_index],
				"pos": pos,
				"scale": scale_vec,
			})
			if scene_index < island_bounds.size():
				rects.append(Transform2D(0.0, scale_vec, 0.0, pos) * island_bounds[scene_index])
			break
	
	return rects

func _is_entry_live(entry: Dictionary) -> bool:
	return chunk_tokens.get(entry["coord"], -1) == entry["token"]

func _sort_queue(focus: Vector2) -> void:
	spawn_queue.assign(spawn_queue.filter(_is_entry_live))
	spawn_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: float = (a["pos"] as Vector2).distance_squared_to(focus)
		var db: float = (b["pos"] as Vector2).distance_squared_to(focus)
		return da > db
	)

func _spawn_from_queue() -> void:
	var start := Time.get_ticks_usec()
	var budget := int(spawn_budget_ms * 1000.0)
	
	while not spawn_queue.is_empty():
		var entry: Dictionary = spawn_queue.pop_back()
		if not _is_entry_live(entry):
			continue
		_spawn_entry(entry)
		if Time.get_ticks_usec() - start >= budget:
			break

func _spawn_entry(entry: Dictionary) -> void:
	var scene: PackedScene = entry["scene"]
	var node := scene.instantiate() as Node2D
	if node == null:
		return
	
	var is_balloon: bool = entry.get("kind", "island") == "balloon"
	node.position = entry["pos"]
	node.scale = entry["scale"]
	if is_balloon:
		node.set("tint", entry["tint"])
	
	var target_alpha := node.modulate.a
	if fade_in_time > 0.0:
		node.modulate.a = 0.0
	
	(balloons_root if is_balloon else islands_root).add_child(node)
	(loaded[entry["coord"]] as Array).append(node)
	
	if is_balloon:
		_setup_spawned_balloon(node, entry["id"])
	
	if fade_in_time > 0.0:
		node.create_tween().tween_property(node, "modulate:a", target_alpha, fade_in_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if debug_prints:
		print("spawned ", node.name, " at ", node.position, " (chunk ", entry["coord"], ")")

func _setup_spawned_balloon(balloon: Node2D, id: Vector3i) -> void:
	if balloon.has_signal("popped"):
		balloon.connect("popped", _on_balloon_popped.bind(id))
	
	if popped_until.has(id):
		var remaining: float = popped_until[id] - _now()
		if remaining > 0.0 and balloon.has_method("start_popped"):
			balloon.call("start_popped", remaining)
		else:
			popped_until.erase(id)

func _on_balloon_popped(respawn_time: float, id: Vector3i) -> void:
	popped_until[id] = _now() + respawn_time

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _too_close(pos: Vector2, others: Array[Vector2]) -> bool:
	for o in others:
		if o.distance_to(pos) < min_spacing:
			return true
	
	return false


func _plan_balloons(coord: Vector2i, token: int, island_rects: Array[Rect2]) -> void:
	if balloon_scene == null:
		return
	
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector4i(coord.x, coord.y, world_seed, 7))
	
	var chunk_rect := Rect2(Vector2(coord) * chunk_size, Vector2.ONE * chunk_size).grow(-100.0)
	var placed: Array[Vector2] = []
	var index := 0
	var lo := mini(min_lines_per_island, max_lines_per_island)
	var hi := maxi(min_lines_per_island, max_lines_per_island)
	
	for rect in island_rects:
		for line in rng.randi_range(lo, hi):
			index = _try_line(rng, coord, token, rect, true, island_rects, chunk_rect, placed, index)
	
	for line in max_sky_lines:
		if rng.randf() < sky_line_chance:
			index = _try_line(rng, coord, token, Rect2(), false, island_rects, chunk_rect, placed, index)

func _try_line(rng: RandomNumberGenerator, coord: Vector2i, token: int, island_rect: Rect2, near_island: bool, island_rects: Array[Rect2], chunk_rect: Rect2, placed: Array[Vector2], index: int) -> int:
	for attempt in 8:
		var pick := _island_anchor(rng, island_rect) if near_island else _sky_anchor(rng, chunk_rect)
		var anchor: Vector2 = pick[0]
		var dir: Vector2 = pick[1]
		var count := rng.randi_range(mini(min_line_length, max_line_length), maxi(min_line_length, max_line_length))
		var bend := 0.0 if rng.randf() < 0.4 else rng.randf_range(-max_line_bend, max_line_bend)
		var points := _line_points(anchor, dir, count, bend)
		if not _line_fits(points, island_rects, chunk_rect, placed):
			continue
		
		var base_hue := rng.randf()
		for i in points.size():
			var hue := fposmod(base_hue + hue_step * i, 1.0)
			placed.append(points[i])
			spawn_queue.append({
				"coord": coord,
				"token": token,
				"kind": "balloon",
				"id": Vector3i(coord.x, coord.y, index),
				"scene": balloon_scene,
				"pos": points[i],
				"scale": Vector2.ONE,
				"tint": Color.from_hsv(hue, rng.randf_range(0.6, 0.85), rng.randf_range(0.93, 1.0)),
			})
			index += 1
		return index
	return index

func _island_anchor(rng: RandomNumberGenerator, rect: Rect2) -> Array:
	var side := rng.randf()
	var gap := balloon_clearance + rng.randf_range(40.0, 260.0)
	if side < 0.5:
		return [Vector2(rng.randf_range(rect.position.x, rect.end.x), rect.position.y - gap), Vector2.from_angle(rng.randf_range(-0.35, 0.35))]
	if side < 0.7:
		return [Vector2(rect.position.x - gap, rng.randf_range(rect.position.y - 200.0, rect.end.y)), Vector2.from_angle(PI * 0.5 + rng.randf_range(-0.5, 0.5))]
	if side < 0.9:
		return [Vector2(rect.end.x + gap, rng.randf_range(rect.position.y - 200.0, rect.end.y)), Vector2.from_angle(PI * 0.5 + rng.randf_range(-0.5, 0.5))]
	return [Vector2(rng.randf_range(rect.position.x, rect.end.x), rect.end.y + gap), Vector2.from_angle(rng.randf_range(-0.35, 0.35))]

func _sky_anchor(rng: RandomNumberGenerator, chunk_rect: Rect2) -> Array:
	var anchor := Vector2(
		rng.randf_range(chunk_rect.position.x, chunk_rect.end.x),
		rng.randf_range(chunk_rect.position.y, chunk_rect.end.y))
	return [anchor, Vector2.from_angle(rng.randf_range(-PI, PI))]

func _line_points(anchor: Vector2, dir: Vector2, count: int, bend: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var normal := dir.orthogonal()
	for i in count:
		var t := 0.5 if count == 1 else float(i) / float(count - 1)
		var along := (t - 0.5) * balloon_spacing * float(count - 1)
		points.append(anchor + dir * along + normal * sin(t * PI) * bend)
	return points

func _line_fits(points: Array[Vector2], island_rects: Array[Rect2], chunk_rect: Rect2, placed: Array[Vector2]) -> bool:
	var min_gap := balloon_spacing * 0.8
	for p in points:
		if not chunk_rect.has_point(p) or p.length() < safe_radius:
			return false
		for r in island_rects:
			if r.grow(balloon_clearance).has_point(p):
				return false
		for q in placed:
			if p.distance_to(q) < min_gap:
				return false
	return true

func _measure_scene(scene: PackedScene) -> Rect2:
	var root := scene.instantiate()
	var layers: Array[Node] = root.find_children("*", "TileMapLayer", true, false)
	if root is TileMapLayer:
		layers.append(root)
	
	var bounds := Rect2()
	var has_bounds := false
	for node in layers:
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
	
	root.free()
	if not has_bounds:
		return Rect2(-300.0, -100.0, 600.0, 250.0)
	return bounds

func _relative_transform(node: Node, root: Node) -> Transform2D:
	var xf := Transform2D.IDENTITY
	var current := node
	while current != null and current != root:
		if current is Node2D:
			xf = (current as Node2D).transform * xf
		current = current.get_parent()
	return xf
