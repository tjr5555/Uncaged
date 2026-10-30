extends Node2D

@export var island_scenes: Array[PackedScene] = []
@export var player: Node2D
@export var world_seed := 12345
@export var chunk_size := 3000.0
@export var load_radius := 2        #chunks loaded around the player (5x5 grid)
@export var unload_radius := 3      #chunks farther than this get freed
@export var safe_radius := 4000.0   #no islands within this distance of the origin
@export var max_islands_per_chunk := 2
@export var min_spacing := 1500.0
@export var edge_margin := 750.0    #keep at min_spacing / 2 so neighboring chunks can't overlap
@export var island_scale := 1.0     #keep at 1 to match other tiles

var loaded: Dictionary = {}  # Vector2i -> Array[Node2D]
var last_chunk := Vector2i(999999, 999999)

func _ready() -> void:
	$player.boost_changed.connect($UI.set_boost)

func _process(_delta: float) -> void:
	var c := Vector2i((player.global_position / chunk_size).floor())
	if c == last_chunk:
		return
	last_chunk = c
	_load_nearby(c)
	_unload_far(c)

func _load_nearby(c: Vector2i) -> void:
	for x in range(c.x - load_radius, c.x + load_radius + 1):
		for y in range(c.y - load_radius, c.y + load_radius + 1):
			var coord := Vector2i(x, y)
			if not loaded.has(coord):
				loaded[coord] = _generate_chunk(coord)

func _unload_far(c: Vector2i) -> void:
	for coord in loaded.keys():
		var d: int = max(abs(coord.x - c.x), abs(coord.y - c.y))
		if d > unload_radius:
			for island in loaded[coord]:
				island.queue_free()
			loaded.erase(coord)

func _generate_chunk(coord: Vector2i) -> Array[Node2D]:
	var result: Array[Node2D] = []
	if island_scenes.is_empty():
		return result

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(coord.x, coord.y, world_seed))

	var origin := Vector2(coord) * chunk_size
	var positions: Array[Vector2] = []
	var count := rng.randi_range(0, max_islands_per_chunk)

	for i in count:
		for attempt in 8:
			var pos := origin + Vector2(
				rng.randf_range(edge_margin, chunk_size - edge_margin),
				rng.randf_range(edge_margin, chunk_size - edge_margin))

			if pos.length() < safe_radius:
				continue
			if _too_close(pos, positions):
				continue

			positions.append(pos)
			var scene: PackedScene = island_scenes[rng.randi() % island_scenes.size()]
			var island := scene.instantiate() as Node2D
			add_child(island)
			island.global_position = pos
			var s := rng.randf_range(0.8, 1.4) * island_scale
			var flip := -1.0 if rng.randf() < 0.5 else 1.0
			island.scale = Vector2(s * flip, s)
			result.append(island)
			break
	return result

func _too_close(pos: Vector2, others: Array[Vector2]) -> bool:
	for o in others:
		if o.distance_to(pos) < min_spacing:
			return true
	return false
