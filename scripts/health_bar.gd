extends Control

const GLOW_SHADER = preload("res://shaders/combo_glow.gdshader")
const BAR_SIZE = Vector2(460, 20)
const COLOR_HIGH = Color(0.4, 0.9, 0.5)
const COLOR_MID = Color(1.0, 0.82, 0.3)
const COLOR_LOW = Color(1.0, 0.35, 0.35)
const CHUNK_COLOR = Color(1.0, 0.95, 0.9)
const HURT_GLOW = Color(1.0, 0.2, 0.2)

@export var bottom_margin := 56.0
@export var hide_delay := 3.0
@export var low_health := 0.3

var health: Node
var ratio := 1.0
var fill_ratio := 1.0
var chunk_ratio := 1.0
var chunk_hold := 0.0
var since_change := 999.0
var flash := 0.0
var shake := 0.0
var hurt_pulse := 0.0
var current := 100.0
var maximum := 100.0
var heartbeat_timer := 0.0

const VIGNETTE_SHADER = preload("res://shaders/low_hp_vignette.gdshader")
@export var vignette_strength := 0.6
var vignette_material: ShaderMaterial

var holder: Control
var chunk: Panel
var fill: Panel
var fill_style: StyleBoxFlat
var label: Label
var glow_material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -BAR_SIZE.x * 0.5
	offset_right = BAR_SIZE.x * 0.5
	offset_bottom = -bottom_margin
	offset_top = -bottom_margin - BAR_SIZE.y
	modulate.a = 0.0
	_build_bar()
	_build_glow.call_deferred()
	_connect_health()


func _process(delta: float) -> void:
	if health == null:
		_connect_health()

	fill_ratio = lerpf(fill_ratio, ratio, 1.0 - exp(-14.0 * delta))
	if chunk_ratio < fill_ratio:
		chunk_ratio = fill_ratio
	else:
		chunk_hold -= delta
		if chunk_hold <= 0.0:
			chunk_ratio = move_toward(chunk_ratio, fill_ratio, 0.6 * delta)

	var inner := BAR_SIZE.x - 6.0
	fill.size.x = inner * fill_ratio
	chunk.size.x = inner * chunk_ratio

	var color := _color_for(fill_ratio)
	if ratio > 0.0 and ratio < low_health:
		var t := Time.get_ticks_msec() / 1000.0
		color = color.lerp(Color.WHITE, 0.25 * (0.5 + 0.5 * sin(t * 8.0)))
	flash = maxf(flash - delta * 4.0, 0.0)
	fill_style.bg_color = color.lerp(Color.WHITE, flash)

	shake = maxf(shake - delta * 5.0, 0.0)
	holder.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 6.0 * shake * shake * Settings.screen_shake

	since_change += delta
	var want_visible := ratio < 0.999 or since_change < hide_delay
	modulate.a = move_toward(modulate.a, 1.0 if want_visible else 0.0, delta * (4.0 if want_visible else 1.5))

	label.text = "%d / %d" % [roundi(current), roundi(maximum)]

	hurt_pulse = maxf(hurt_pulse - delta * 2.0, 0.0)
	var heartbeat_below := 0.2
	if ratio > 0.0 and ratio < heartbeat_below and not Global.in_transition:
		heartbeat_timer -= delta
		if heartbeat_timer <= 0.0:
			heartbeat_timer = lerpf(0.8, 1.4, ratio / heartbeat_below)
			Sfx.play("heartbeat")
			get_tree().create_timer(0.16).timeout.connect(func(): Sfx.play("heartbeat", 0.92, -5.0))
	else:
		heartbeat_timer = 0.0
	
	if glow_material:
		var low := clampf((low_health - ratio) / low_health, 0.0, 1.0) if ratio > 0.0 else 0.0
		glow_material.set_shader_parameter("intensity", low * 0.8)
		glow_material.set_shader_parameter("pulse", hurt_pulse)
	if vignette_material:
		var low_amount := clampf((low_health - ratio) / low_health, 0.0, 1.0) if ratio > 0.0 else 0.0
		var beat := 0.85 + 0.15 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
		vignette_material.set_shader_parameter("intensity", low_amount * vignette_strength * beat)

func _connect_health() -> void:
	health = get_tree().get_first_node_in_group("player_health")
	if health == null:
		return
	health.health_changed.connect(_on_health_changed)
	health.damaged.connect(_on_damaged)
	_on_health_changed(health.current, health.max_health)
	fill_ratio = ratio
	chunk_ratio = ratio


func _on_health_changed(value: float, max_value: float) -> void:
	current = value
	maximum = max_value
	var new_ratio := clampf(value / maxf(max_value, 1.0), 0.0, 1.0)
	if new_ratio < ratio - 0.001:
		chunk_hold = 0.45
	if absf(new_ratio - ratio) > 0.001:
		since_change = 0.0
	ratio = new_ratio


func _on_damaged(_amount: float, _source: String, continuous: bool) -> void:
	since_change = 0.0
	if continuous:
		hurt_pulse = maxf(hurt_pulse, 0.25)
		return
	flash = 1.0
	shake = 1.0
	hurt_pulse = 1.0


func _color_for(r: float) -> Color:
	if r > 0.6:
		return COLOR_MID.lerp(COLOR_HIGH, inverse_lerp(0.6, 1.0, r))
	if r > 0.3:
		return COLOR_LOW.lerp(COLOR_MID, inverse_lerp(0.3, 0.6, r))
	return COLOR_LOW


func _build_bar() -> void:
	holder = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	var track := _make_panel(Color(0.0, 0.0, 0.0, 0.5), 10)
	track.size = BAR_SIZE
	holder.add_child(track)

	chunk = _make_panel(CHUNK_COLOR, 7)
	chunk.position = Vector2(3, 3)
	chunk.size = Vector2(BAR_SIZE.x - 6.0, BAR_SIZE.y - 6.0)
	holder.add_child(chunk)

	fill = _make_panel(COLOR_HIGH, 7)
	fill.position = Vector2(3, 3)
	fill.size = Vector2(BAR_SIZE.x - 6.0, BAR_SIZE.y - 6.0)
	fill_style = fill.get_theme_stylebox("panel") as StyleBoxFlat
	holder.add_child(fill)

	label = Label.new()
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("outline_size", 5)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, -28)
	label.size = Vector2(BAR_SIZE.x, 24)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(label)


func _make_panel(color: Color, radius: int) -> Panel:
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel

func _build_glow() -> void:
	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette_material = ShaderMaterial.new()
	vignette_material.shader = VIGNETTE_SHADER
	vignette.material = vignette_material
	get_parent().add_child(vignette)

	var glow := ColorRect.new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow_material = ShaderMaterial.new()
	glow_material.shader = GLOW_SHADER
	glow_material.set_shader_parameter("glow_color", HURT_GLOW)
	glow_material.set_shader_parameter("rainbow", 0.0)
	glow.material = glow_material
	get_parent().add_child(glow)
