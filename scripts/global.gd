extends Node

enum Mode { GROUND, FLY }

var mode: Mode = Mode.GROUND
var INPUT_LOCKED = false 

#shop variables
var total_coins = 0
var base_flight_speed: int = 800.0
var base_turn_speed: float = 4.2
var brake_turn_bonus := 1.6   #added to the turn boost while braking (base is 1.6)
var brake_decel_scale := 1.0  #multiplies brake strength (higher = stops faster)
var gravity_scale := 1.0      #multiplies flight gravity (lower = steadier speed in climbs and dives)
var turn_accel_scale := 1.0   #multiplies how fast the bird reaches full turn speed (higher = snappier)
var magnet_radius := 0.0
var upgrade_levels: Dictionary = {}



var max_dashes: int = 2
var dashes: int = 2
var dash_target: int 
var has_medallion := false
var in_transition := false
var return_portal_id := ""

var base_coin_mult = 1.0

const BALLOON_SHADER = preload("res://shaders/balloon_shader.gdshader")

const BALLOON_TIERS = [
	{"color": Color(0.92, 0.22, 0.22), "value": 10, "weight": 45.0, "shimmer": 0.0, "sparkle": 0.0, "shine": Color(1.0, 1.0, 1.0)},
	{"color": Color(0.25, 0.5, 0.95), "value": 20, "weight": 28.0, "shimmer": 0.0, "sparkle": 0.0, "shine": Color(1.0, 1.0, 1.0)},
	{"color": Color(0.3, 0.8, 0.35), "value": 35, "weight": 15.0, "shimmer": 0.25, "sparkle": 0.0, "shine": Color(0.9, 1.0, 0.9)},
	{"color": Color(0.62, 0.32, 0.9), "value": 60, "weight": 9.0, "shimmer": 0.55, "sparkle": 0.4, "shine": Color(0.95, 0.85, 1.0)},
	{"color": Color(1.0, 0.8, 0.2), "value": 100, "weight": 3.0, "shimmer": 1.0, "sparkle": 1.0, "shine": Color(1.0, 0.95, 0.7)},
]

var _balloon_materials: Dictionary = {}

func pick_balloon_tier_index(roll: float) -> int:
	var total := 0.0
	for tier in BALLOON_TIERS:
		total += tier["weight"]
	var target := roll * total
	for i in BALLOON_TIERS.size():
		target -= BALLOON_TIERS[i]["weight"]
		if target <= 0.0:
			return i
	return BALLOON_TIERS.size() - 1

func pick_balloon_tier(roll: float) -> Dictionary:
	return BALLOON_TIERS[pick_balloon_tier_index(roll)]

func get_balloon_material(tier_index: int) -> ShaderMaterial:
	var tier: Dictionary = BALLOON_TIERS[tier_index]
	if float(tier["shimmer"]) <= 0.0 and float(tier["sparkle"]) <= 0.0:
		return null
	if not _balloon_materials.has(tier_index):
		var mat := ShaderMaterial.new()
		mat.shader = BALLOON_SHADER
		mat.set_shader_parameter("shimmer_strength", tier["shimmer"])
		mat.set_shader_parameter("sparkle_strength", tier["sparkle"])
		mat.set_shader_parameter("shine_color", tier["shine"])
		_balloon_materials[tier_index] = mat
	return _balloon_materials[tier_index]

# Max variation in balloon hue, saturation, and darkness
const BALLOON_HUE_JITTER = 0.02
const BALLOON_SAT_JITTER = 0.06
const BALLOON_DARKEN = 0.1


func vary_balloon_color(base: Color, rng: RandomNumberGenerator) -> Color:
	var h := fposmod(base.h + rng.randf_range(-BALLOON_HUE_JITTER, BALLOON_HUE_JITTER), 1.0)
	var s := clampf(base.s + rng.randf_range(-BALLOON_SAT_JITTER, BALLOON_SAT_JITTER), 0.0, 1.0)
	var v := clampf(base.v + rng.randf_range(-BALLOON_DARKEN, 0.03), 0.0, 1.0)
	return Color.from_hsv(h, s, v)
