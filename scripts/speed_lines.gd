extends Control

const SPEED_START = 1500.0
const SPEED_FULL = 2200.0
const FALL_START = 1200.0
const FALL_FULL = 1700.0

const MAX_STREAKS = 48
const SPAWN_RATE = 80.0
const MIN_LIFE = 0.35
const MAX_LIFE = 0.7
const MIN_LENGTH = 60.0
const MAX_LENGTH = 180.0
const MIN_WIDTH = 1.5
const MAX_WIDTH = 3.0
const FLOW_SPEED = 400.0

const INNER_CLEAR = 0.5
const MAX_ALPHA = 0.35
const STREAK_COLOR = Color(1.0, 1.0, 1.0)
const VELOCITY_SMOOTH = 10.0
const TURN_STIFFNESS = 150.0
const TURN_DAMPING = 24.5
const INTENSITY_RISE = 2.5
const INTENSITY_FALL = 1.2
const STREAK_TURN_MIN = 5.0
const STREAK_TURN_MAX = 12.5
const TRAIL_SPACING = 6.0

var streaks: Array[Dictionary] = []
var intensity: float = 0.0
var flow_dir: Vector2 = Vector2.UP
var flow_speed: float = FLOW_SPEED
var spawn_accumulator: float = 0.0

var smoothed_velocity: Vector2 = Vector2.ZERO
var flow_angle: float = -PI / 2.0
var flow_turn_speed: float = 0.0



func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	var raw_velocity := player.velocity if player != null else Vector2.ZERO
	smoothed_velocity = smoothed_velocity.lerp(raw_velocity, 1.0 - exp(-VELOCITY_SMOOTH * delta))
	
	var speed := smoothed_velocity.length()
	var speed_t := smoothstep(SPEED_START, SPEED_FULL, speed)
	var fall_t := smoothstep(FALL_START, FALL_FULL, smoothed_velocity.y)
	var target_intensity := maxf(speed_t, fall_t)
	
	var rate := INTENSITY_RISE if target_intensity > intensity else INTENSITY_FALL
	intensity = lerpf(intensity, target_intensity, 1.0 - exp(-rate * delta))
	
	if speed > 50.0:
		var target_angle := (-smoothed_velocity).angle()
		var diff := angle_difference(flow_angle, target_angle)
		flow_turn_speed += (diff * TURN_STIFFNESS - flow_turn_speed * TURN_DAMPING) * delta
	else:
		flow_turn_speed *= exp(-TURN_DAMPING * delta)
	
	flow_angle = wrapf(flow_angle + flow_turn_speed * delta, -PI, PI)
	flow_dir = Vector2.from_angle(flow_angle)
	flow_speed = FLOW_SPEED * lerpf(0.6, 1.6, intensity)
	
	_spawn_streaks(delta)
	_move_streaks(delta)
	queue_redraw()






func _spawn_streaks(delta: float) -> void:
	if intensity < 0.02:
		spawn_accumulator = 0.0
		return
	
	spawn_accumulator += SPAWN_RATE * intensity * delta
	while spawn_accumulator >= 1.0 and streaks.size() < MAX_STREAKS:
		spawn_accumulator -= 1.0
		streaks.append(_new_streak())
	spawn_accumulator = minf(spawn_accumulator, 1.0)

func _new_streak() -> Dictionary:
	var view := get_viewport_rect().size
	var center := view * 0.5
	var pos := Vector2.ZERO
	
	for attempt in 8:
		pos = Vector2(randf() * view.x, randf() * view.y)
		if ((pos - center) / center).length() > INNER_CLEAR:
			break
	
	return {
		"trail": PackedVector2Array([pos]),
		"dir": flow_dir,
		"turn": randf_range(STREAK_TURN_MIN, STREAK_TURN_MAX),
		"life": 0.0,
		"max_life": randf_range(MIN_LIFE, MAX_LIFE),
		"length": randf_range(MIN_LENGTH, MAX_LENGTH),
		"width": randf_range(MIN_WIDTH, MAX_WIDTH),
		"speed": randf_range(0.7, 1.3),
		"alpha": randf_range(0.5, 1.0),
	}

func _move_streaks(delta: float) -> void:
	var bounds := get_viewport_rect().grow(MAX_LENGTH)
	
	for i in range(streaks.size() -1, -1, -1):
		var s: Dictionary = streaks[i]
		var life: float = s["life"] + delta
		var dir: Vector2 = s["dir"]
		var turn: float = s["turn"]
		var speed_mult: float = s["speed"]
		var base_length: float = s["length"]
		var trail: PackedVector2Array = s["trail"]
		
		dir = dir.slerp(flow_dir, 1.0 - exp(-turn * delta)).normalized()
		var head := trail[0] + dir * flow_speed * speed_mult * delta
		
		if trail.size() >= 2 and head.distance_to(trail[1]) < TRAIL_SPACING:
			trail[0] = head
		else:
			trail.insert(0, head)
		
		trail = _trim_trail(trail, base_length * lerpf(0.6, 1.0, intensity))
		
		s["life"] = life
		s["dir"] = dir
		s["trail"] = trail
		
		if life >= float(s["max_life"]) or not bounds.has_point(head):
			streaks.remove_at(i)

func _trim_trail(trail: PackedVector2Array, max_length: float) -> PackedVector2Array:
	var total := 0.0
	for j in range(1, trail.size()):
		var seg := trail[j -1].distance_to(trail[j])
		if total + seg >= max_length:
			var kept := trail.slice(0, j + 1)
			kept[j] = trail[j - 1].move_toward(trail[j], max_length - total)
			return kept
		total += seg
	return trail

func _draw() -> void:
	if streaks.is_empty():
		return
	
	var center := get_viewport_rect().size * 0.5
	
	for s in streaks:
		var trail: PackedVector2Array = s["trail"]
		if trail.size() < 2:
			continue
		
		var head := trail[0]
		var life: float = s["life"]
		var max_life: float = s["max_life"]
		var width: float = s["width"]
		var alpha_mult: float = s["alpha"]
		
		var fade := sin(clampf(life / max_life, 0.0, 1.0) * PI)
		var radial := ((head - center) / center).length()
		var edge := smoothstep(INNER_CLEAR * 0.8, 1.0, radial)
		var a := MAX_ALPHA * intensity * fade * edge * alpha_mult
		if a < 0.005:
			continue
		
		var total := 0.0
		for j in range(1, trail.size()):
			total += trail[j - 1].distance_to(trail[j])
		if total <= 0.0:
			continue
		
		var core := PackedColorArray()
		var glow := PackedColorArray()
		var walked := 0.0
		for j in trail.size():
			if j > 0:
				walked += trail[j - 1].distance_to(trail[j])
			var k := pow(1.0 - walked / total, 1.5)
			core.append(Color(STREAK_COLOR, a * k))
			glow.append(Color(STREAK_COLOR, a * 0.3 * k))
		
		draw_polyline_colors(trail, glow, width * 3.0, true)
		draw_polyline_colors(trail, core, width, true)
