extends Control

const GLOW_SHADER = preload("res://shaders/combo_glow.gdshader")
const POP_EFFECT = preload("res://scripts/pop_effect.gd")

@export var level_colors: Array[Color] = [
	Color(1.0, 1.0, 1.0),
	Color(0.45, 1.0, 0.55),
	Color(0.35, 0.85, 1.0),
	Color(0.78, 0.5, 1.0),
	Color(1.0, 0.6, 0.25),
	Color(1.0, 0.85, 0.3),
]
@export var vignette_from_level := 2
@export var aura_from_level := 3
@export var sparkle_from_level := 4
@export var burst_from_level := 3
@export var hitstop_time := 0.05
@export var hitstop_scale := 0.15

var glow_material: ShaderMaterial
var aura: CPUParticles2D
var sparkles: CPUParticles2D
var aura_owner: Node
var color := Color.WHITE
var intensity := 0.0
var pulse := 0.0
var rainbow := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var glow := ColorRect.new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow_material = ShaderMaterial.new()
	glow_material.shader = GLOW_SHADER
	glow.material = glow_material
	add_child(glow)

	Combo.combo_changed.connect(_on_combo_changed)
	Combo.level_up.connect(_on_level_up)


func _process(delta: float) -> void:
	var max_level: int = Combo.MULTIPLIERS.size() - 1
	var level: int = Combo.level if Combo.count > 0 else 0
	var top := max_level > 0 and level >= max_level

	color = color.lerp(level_colors[clampi(level, 0, level_colors.size() - 1)], 1.0 - exp(-6.0 * delta))

	var target_intensity := 0.0
	if level >= vignette_from_level:
		target_intensity = float(level - vignette_from_level + 1) / float(maxi(max_level - vignette_from_level + 1, 1))
	intensity = lerpf(intensity, target_intensity, 1.0 - exp(-4.0 * delta))
	rainbow = lerpf(rainbow, 1.0 if top else 0.0, 1.0 - exp(-3.0 * delta))
	pulse = maxf(pulse - delta * 1.8, 0.0)

	glow_material.set_shader_parameter("glow_color", color)
	glow_material.set_shader_parameter("intensity", intensity)
	glow_material.set_shader_parameter("pulse", pulse)
	glow_material.set_shader_parameter("rainbow", rainbow)

	_update_aura(level, top)


func _on_combo_changed(_count: int, _multiplier: float, level: int) -> void:
	if level >= vignette_from_level:
		pulse = maxf(pulse, 0.25)


func _on_level_up(level: int, _multiplier: float) -> void:
	pulse = 1.0
	if level < burst_from_level:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		var burst = POP_EFFECT.new()
		burst.tier = 4
		burst.color = level_colors[clampi(level, 0, level_colors.size() - 1)]
		burst.reward = 0
		get_tree().current_scene.add_child(burst)
		burst.global_position = player.global_position
	if hitstop_time > 0.0:
		_hitstop()


func _hitstop() -> void:
	Engine.time_scale = hitstop_scale
	await get_tree().create_timer(hitstop_time, true, false, true).timeout
	Engine.time_scale = 1.0


func _update_aura(level: int, top: bool) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	if aura == null or not is_instance_valid(aura) or aura_owner != player:
		_build_aura(player)

	aura.emitting = level >= aura_from_level
	sparkles.emitting = level >= sparkle_from_level

	var tint := color
	if top:
		tint = Color.from_hsv(fposmod(Time.get_ticks_msec() / 1000.0 * 0.5, 1.0), 0.55, 1.0)
	aura.modulate = tint
	sparkles.modulate = tint.lerp(Color.WHITE, 0.5)

	var zoom := get_viewport().get_canvas_transform().get_scale().x
	var s := clampf(1.0 / maxf(zoom, 0.01), 1.0, 3.0)
	aura.scale = Vector2.ONE * s
	sparkles.scale = Vector2.ONE * s


func _build_aura(player: Node2D) -> void:
	aura = _make_emitter(36, 0.6, 14.0, Vector2(10.0, 30.0), Vector2(0.6, 1.2))
	sparkles = _make_emitter(14, 0.9, 22.0, Vector2(20.0, 70.0), Vector2(0.3, 0.7))
	player.add_child(aura)
	player.add_child(sparkles)
	aura_owner = player


func _make_emitter(amount: int, lifetime: float, radius: float, speed: Vector2, size: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.emitting = false
	p.show_behind_parent = true
	p.texture = _soft_dot()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.damping_min = 20.0
	p.damping_max = 40.0
	p.scale_amount_min = size.x
	p.scale_amount_max = size.y
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.2))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 0.9))
	ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	p.color_ramp = ramp
	return p


func _soft_dot() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 16
	tex.height = 16
	return tex
