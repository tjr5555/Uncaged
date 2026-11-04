extends Node2D
const TIER_FX = [
	{"amount": 10, "speed": 160.0, "ring": false, "sparkles": 0, "label_scale": 1.0},
	{"amount": 12, "speed": 180.0, "ring": false, "sparkles": 0, "label_scale": 1.05},
	{"amount": 16, "speed": 200.0, "ring": true, "sparkles": 4, "label_scale": 1.15},
	{"amount": 22, "speed": 230.0, "ring": true, "sparkles": 10, "label_scale": 1.3},
	{"amount": 34, "speed": 270.0, "ring": true, "sparkles": 22, "label_scale": 1.6},
]

var tier := 0
var color := Color.WHITE
var reward := 0

var ring_radius := 0.0
var ring_alpha := 0.0
var ring_width := 4.0
var ring_color := Color.WHITE

func _ready() -> void:
	var fx: Dictionary = TIER_FX[clampi(tier, 0, TIER_FX.size() - 1)]
	var zoom := get_viewport().get_canvas_transform().get_scale().x
	scale = Vector2.ONE * clampf(1.0 / maxf(zoom, 0.01), 1.0, 3.0)
	
	_burst(fx)
	if int(fx["sparkles"]) > 0:
		_sparkles(fx)
	if fx["ring"]:
		_ring()
	if reward > 0:
		_label(fx)
	
	get_tree().create_timer(1.6).timeout.connect(queue_free)

func _burst(fx: Dictionary) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = int(fx["amount"])
	p.lifetime = 0.7
	p.local_coords = true
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2(0.0, 520.0)
	p.initial_velocity_min = float(fx["speed"]) * 0.45
	p.initial_velocity_max = float(fx["speed"])
	p.damping_min = 40.0
	p.damping_max = 90.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color.darkened(0.3), 0.0))
	p.color_ramp = ramp
	add_child(p)
	p.emitting = true

func _sparkles(fx: Dictionary) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = int(fx["sparkles"])
	p.lifetime = 1.0
	p.local_coords = true
	p.texture = _soft_dot()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 18.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2(0.0, -40.0)
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 130.0
	p.damping_min = 60.0
	p.damping_max = 120.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var c := color.lerp(Color.WHITE, 0.6)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(c, 0.0))
	ramp.set_color(1, Color(c, 0.0))
	ramp.add_point(0.1, c)
	p.color_ramp = ramp
	add_child(p)
	p.emitting = true

func _ring() -> void:
	ring_color = color.lerp(Color.WHITE, 0.5)
	ring_width = 3.0 + float(tier)
	var max_radius := 40.0 + float(tier) * 14.0
	var t := create_tween().set_parallel()
	t.tween_method(_set_ring_radius, 8.0, max_radius, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_method(_set_ring_alpha, 0.9, 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _set_ring_radius(value: float) -> void:
	ring_radius = value
	queue_redraw()

func _set_ring_alpha(value: float) -> void:
	ring_alpha = value
	queue_redraw()

func _draw() -> void:
	if ring_alpha <= 0.0:
		return
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 48, Color(ring_color, ring_alpha), ring_width, true)

func _label(fx: Dictionary) -> void:
	var label := Label.new()
	label.text = "+" + str(reward)
	label.add_theme_font_size_override("font_size", int(26.0 * float(fx["label_scale"])))
	label.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.35))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	
	var label_size := label.get_minimum_size()
	label.size = label_size
	label.pivot_offset = label_size * 0.5
	label.position = Vector2(-label_size.x * 0.5, -label_size.y * 0.5 - 30.0)
	label.scale = Vector2.ONE * 0.4
	
	var t := create_tween().set_parallel()
	t.tween_property(label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "position:y", label.position.y - 70.0, 1.1).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.75)

func _soft_dot() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 10
	tex.height = 10
	return tex
