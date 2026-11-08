@tool
class_name GhostPath
extends Path2D

@export var stage_id := ""
@export var appear_after := 6.0
@export var speed := 380.0
@export var end_pause := 1.0
@export var timing: Curve
@export var default_animation := "hop"
@export var rotate_with_path := false
@export var sprite_faces_left := true

@export_group("Look")
@export var ghost_color := Color(0.75, 0.9, 1.0, 0.55)
@export var dot_color := Color(1.0, 1.0, 1.0)
@export var dot_spacing := 22.0
@export var dot_radius := 3.5
@export var dot_alpha := 0.25
@export var dot_alpha_bright := 0.85
@export var trail_length := 260.0
@export var fade_time := 0.4

var ghost: AnimatedSprite2D
var sprite_offset := Vector2.ZERO
var base_scale := Vector2.ONE
var markers: Array = []
var active := false
var showing := false
var stuck_time := 0.0
var progress := 0.0
var pause_left := 0.0
var ghost_offset := -1.0
var fade_tween: Tween
var guide: Node

func _ready() -> void:
	if Engine.is_editor_hint():
		if curve and not curve.changed.is_connected(queue_redraw):
			curve.changed.connect(queue_redraw)
		return
	
	modulate.a = 0.0
	visible = false
	if curve == null or curve.point_count < 2:
		push_error("GhostPath '%s': the path needs at least 2 points" % name)
		return
	if stage_id == "":
		push_error("GhostPath '%s': Stage ID is empty" % name)
	_collect_markers()
	_build_ghost.call_deferred()
	_connect_guide.call_deferred()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not active or ghost == null:
		return
	if not showing:
		if not _dialogue_active():
			stuck_time += delta
		if stuck_time >= appear_after:
			_show()
		return
	_advance(delta)
	queue_redraw()

func _collect_markers() -> void:
	for child in get_children():
		if child is Marker2D:
			var anim := String(child.name).to_lower().rstrip("0123456789")
			markers.append([curve.get_closest_offset(child.position), anim])
			child.visible = false
	markers.sort_custom(func(a, b): return a[0] < b[0])

func _build_ghost() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var source: AnimatedSprite2D = null
	if player:
		source = player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if source == null:
		push_error("GhostPath '%s': couldn't find players AnimatedSprite2D")
		return
	
	ghost = AnimatedSprite2D.new()
	ghost.sprite_frames = source.sprite_frames
	base_scale = source.scale.abs()
	ghost.scale = base_scale
	sprite_offset = source.position
	ghost.self_modulate = ghost_color
	add_child(ghost)
	_place_ghost(0.0)

func _connect_guide() -> void:
	guide = get_tree().get_first_node_in_group("tutorial_guide")
	if guide == null:
		push_warning("GhostPath: no tutorial guide found" % name)
		return
	guide.connect("stage_changed", _on_stage_changed)
	_on_stage_changed(guide.call("current_stage_id"))

func _on_stage_changed(id: String) -> void:
	var is_mine := id == stage_id
	if is_mine == active:
		return
	active = is_mine
	stuck_time = 0.0
	if not active:
		_hide()

func _show() -> void:
	showing = true
	visible = true
	progress = 0.0
	pause_left = 0.0
	_fade_to(1.0)

func _hide() -> void:
	showing = false
	ghost_offset = -1.0
	_fade_to(0.0)

func _fade_to(alpha: float) -> void:
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", alpha, fade_time)
	if alpha <= 0.0:
		fade_tween.tween_callback(func(): visible = false)

func _advance(delta: float) -> void:
	if pause_left > 0.0:
		pause_left -= delta
		if pause_left <= 0.0:
			progress = 0.0
		return
	progress += delta * speed / maxf(curve.get_baked_length(), 1.0)
	if progress >= 1.0:
		progress = 1.0
		pause_left = end_pause
	_place_ghost(progress)

func _place_ghost(t: float) -> void:
	if ghost == null:
		return
	var length := curve.get_baked_length()
	var eased := timing.sample(t) if timing else t
	var offset := clampf(eased, 0.0, 1.0) * length
	ghost_offset = offset
	
	var pos := curve.sample_baked(offset)
	var dir := curve.sample_baked(minf(offset + 6.0, length)) - curve.sample_baked(maxf(offset - 6.0, 0.0))
	ghost.position = pos + sprite_offset
	ghost.modulate.a = smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.92, 1.0, t))
	
	if rotate_with_path:
		if dir.length() > 0.01:
			ghost.rotation = dir.angle()
			ghost.flip_h = sprite_faces_left
			ghost.scale = Vector2(base_scale.x, base_scale.y * (1.0 if dir.x >= 0.0 else -1.0))
	else:
		ghost.rotation = 0.0
		ghost.scale = base_scale
		if absf(dir.x) > 0.5:
			ghost.flip_h = (dir.x < 0.0) != sprite_faces_left
	
	var anim := _animation_at(offset)
	if ghost.animation != anim and ghost.sprite_frames.has_animation(anim):
		ghost.play(anim)
	elif not ghost.is_playing():
		ghost.play()

func _animation_at(offset: float) -> String:
	var anim := default_animation
	for m in markers:
		if offset >= m[0]:
			anim = m[1]
		else:
			break
	return anim

func _dialogue_active() -> bool:
	for ui in get_tree().get_nodes_in_group("dialogue_ui"):
		if bool(ui.get("d_active")):
			return true
	return false

func _draw() -> void:
	if curve == null or curve.point_count < 2:
		return
	var length := curve.get_baked_length()
	if length <= 0.0:
		return
	var count := int(length / dot_spacing)
	for i in count + 1:
		var off := minf(i * dot_spacing, length)
		var a := dot_alpha
		if not Engine.is_editor_hint() and ghost_offset >= 0.0:
			var behind := ghost_offset - off
			if behind >= 0.0 and behind <= trail_length:
				a = lerpf(dot_alpha_bright, dot_alpha, behind / trail_length)
		draw_circle(curve.sample_baked(off), dot_radius, Color(dot_color, a), true, -1.0, true)
