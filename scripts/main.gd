extends Node2D

@export var island_scenes: Array[PackedScene] = []
@export var player: Node2D
@export var world_seed := 12345
@export var chunk_size := 3000.0
@export var load_radius := 2          # chunks loaded around the player
@export var unload_radius := 3        # chunks farther than this get freed (forced to be > load_radius)
@export var chunks_per_frame := 4     # spreads spawning over several frames to avoid hitches
@export var safe_radius := 4000.0     # no islands within this distance of the origin

@export_group("Clumping")
@export_range(0.0, 1.0) var empty_chunk_chance := 0.35  # chance a chunk has no islands (makes gaps between clumps)
@export var min_islands_per_chunk := 2   # islands in a clump (when the chunk isn't empty)
@export var max_islands_per_chunk := 4
@export var cluster_radius := 1100.0     # how spread out a clump is (smaller = tighter clump)

@export_group("Spacing")
@export var min_spacing := 1000.0     # min distance between island centers. Must be >= widest island * max scale + a gap
@export var edge_margin := 500.0      # must be >= min_spacing / 2 so islands in neighboring chunks can't touch
@export var island_scale := 1.0       # keep at 1 to match other tiles
@export var scale_min := 0.8          # random size range (multiplied by island_scale)
@export var scale_max := 1.4

@export var debug_prints := false     # log spawns/unloads to the Output panel

var loaded: Dictionary = {}           # Vector2i -> Array[Node2D]
var pending: Array[Vector2i] = []     # chunks waiting to be generated
var player_chunk := Vector2i(999999, 999999)

func _ready() -> void:
	$player.boost_changed.connect($UI.set_boost)

func _process(_delta: float) -> void:
	if player == null:
		return

	var pc := Vector2i((player.global_position / chunk_size).floor())
	if pc != player_chunk:
		player_chunk = pc
		_queue_nearby(pc)
		pending.sort_custom(_closer_to_player)
		_unload_far()

	_process_pending()

func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

func _closer_to_player(a: Vector2i, b: Vector2i) -> bool:
	return _chebyshev(a, player_chunk) < _chebyshev(b, player_chunk)

func _queue_nearby(c: Vector2i) -> void:
	for x in range(c.x - load_radius, c.x + load_radius + 1):
		for y in range(c.y - load_radius, c.y + load_radius + 1):
			var coord := Vector2i(x, y)
			if not loaded.has(coord) and not pending.has(coord):
				pending.append(coord)

func _process_pending() -> void:
	var done := 0
	while done < chunks_per_frame and not pending.is_empty():
		var coord: Vector2i = pending.pop_front()
		# Skip chunks that fell out of range while waiting
		if _chebyshev(coord, player_chunk) > load_radius or loaded.has(coord):
			continue
		loaded[coord] = _generate_chunk(coord)
		done += 1

func _unload_far() -> void:
	# Never unload anything inside the load ring, whatever the Inspector says
	var keep_radius := maxi(unload_radius, load_radius + 1)
	for coord in loaded.keys():
		if _chebyshev(coord, player_chunk) > keep_radius:
			if debug_prints:
				print("unloading chunk ", coord)
			for island in loaded[coord]:
				if is_instance_valid(island):
					island.queue_free()
			loaded.erase(coord)

func _generate_chunk(coord: Vector2i) -> Array[Node2D]:
	var result: Array[Node2D] = []
	if island_scenes.is_empty():
		return result

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(coord.x, coord.y, world_seed))

	# Some chunks are left empty so clumps are separated by open sky
	if rng.randf() < empty_chunk_chance:
		return result

	# Islands stay inside this rectangle, so any two islands in neighboring
	# chunks are at least 2 * margin apart (>= min_spacing when edge_margin is half of it)
	var margin := minf(edge_margin, chunk_size * 0.5 - 1.0)
	var origin := Vector2(coord) * chunk_size
	var area := Rect2(origin + Vector2(margin, margin), Vector2(chunk_size - margin * 2.0, chunk_size - margin * 2.0))

	# One clump center per chunk
	var center := Vector2(
		rng.randf_range(area.position.x, area.end.x),
		rng.randf_range(area.position.y, area.end.y))

	var lo := mini(min_islands_per_chunk, max_islands_per_chunk)
	var count := rng.randi_range(lo, maxi(max_islands_per_chunk, lo))
	var positions: Array[Vector2] = []

	for i in count:
		for attempt in 16:
			# Random point inside the clump disc (sqrt gives an even spread)
			var angle := rng.randf() * TAU
			var dist := sqrt(rng.randf()) * cluster_radius
			var pos := center + Vector2.from_angle(angle) * dist
			pos.x = clampf(pos.x, area.position.x, area.end.x)
			pos.y = clampf(pos.y, area.position.y, area.end.y)

			if pos.length() < safe_radius:
				continue
			if _too_close(pos, positions):
				continue

			positions.append(pos)
			var scene: PackedScene = island_scenes[rng.randi() % island_scenes.size()]
			var island := scene.instantiate() as Node2D
			var s := rng.randf_range(scale_min, scale_max) * island_scale
			var flip := -1.0 if rng.randf() < 0.5 else 1.0
			# Set the transform BEFORE adding to the tree so the island is never
			# processed or drawn at (0, 0) with the wrong scale for a frame.
			island.position = pos  # spawner sits at (0, 0), so local == global
			island.scale = Vector2(s * flip, s)
			add_child(island)
			result.append(island)
			if debug_prints:
				print("spawned ", island.name, " at ", pos, " (chunk ", coord, ")")
			break
	return result

func _too_close(pos: Vector2, others: Array[Vector2]) -> bool:
	for o in others:
		if o.distance_to(pos) < min_spacing:
			return true
	return false
