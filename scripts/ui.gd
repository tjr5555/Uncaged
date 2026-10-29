extends CanvasLayer

@onready var boost_bar: ProgressBar = $MarginContainer/BoostBar
@onready var dash_bar: ProgressBar = $MarginContainer/DashBar

var target_value: float = 100.0
var dash_display: float = 0.0
var last_mode: Global.Mode
var layout_tween: Tween
const COINS_TWEEN_TIME = 0.4
var coins_display: float = 0.0
var coins_target: float = 0.0
var coins_tween: Tween

const POP_SCALE = 1.2
const POP_UP_TIME = 0.12
const POP_DOWN_TIME = 0.45
const GAIN_COLOR = Color(0.22, 0.98, 0.45)

var pop_tween: Tween
var label_base_modulate: Color = Color.WHITE

func _ready() -> void:
	dash_bar.max_value = Global.max_dashes
	dash_display = float(Global.dashes)
	dash_bar.value = dash_display
	last_mode = Global.mode
	_set_layout(Global.mode, true)
	
	label_base_modulate = $coinsLabel.modulate
	coins_target = float(Global.total_coins)
	_set_coins_display(coins_target)

func set_boost(current: float, maximum: float) -> void:
	boost_bar.max_value = maximum
	target_value = current

func _set_layout(mode: Global.Mode, instant:bool) -> void:
	var boost_y := 25.0 if mode == Global.Mode.FLY else 150.0
	var dash_y := 150.0 if mode == Global.Mode.FLY else 25.0
	
	if layout_tween and layout_tween.is_valid():
		layout_tween.kill()
	
	if instant:
		boost_bar.position.y = boost_y
		dash_bar.position.y = dash_y
		return
	
	layout_tween = create_tween().set_parallel()
	layout_tween.tween_property(boost_bar, "position:y", boost_y, 1.0)
	layout_tween.tween_property(dash_bar, "position:y", dash_y, 1.0)

func _process(delta: float) -> void:
	boost_bar.value = lerpf(boost_bar.value, target_value, 1.0 - exp(-15.0 * delta))
	
	dash_bar.max_value = Global.max_dashes
	dash_display = lerpf(dash_display, float(Global.dashes), 1.0 - exp(-12.0 * delta))
	dash_bar.value = dash_display
	
	_check_coins()
	
	if Global.mode != last_mode:
		last_mode = Global.mode
		_set_layout(Global.mode, false)

func _set_coins_display(value: float) -> void:
	coins_display = value
	$coinsLabel.text = "Coins: " + str(roundi(coins_display))
	$coinsLabel.pivot_offset = Vector2(0.0, $coinsLabel.size.y * 0.5)

func _check_coins() -> void:
	var current := float(Global.total_coins)
	if current == coins_target:
		return
	
	var gained := current > coins_target
	coins_target = current
	
	if coins_tween and coins_tween.is_valid():
		coins_tween.kill()
	
	coins_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	coins_tween.tween_method(_set_coins_display, coins_display, coins_target, COINS_TWEEN_TIME)

	if gained:
		_pop_label()

func _pop_label() -> void:
	if pop_tween and pop_tween.is_valid():
		pop_tween.kill()
	
	var label: Label = $coinsLabel
	pop_tween = create_tween().set_parallel()
	pop_tween.tween_property(label, "scale", Vector2.ONE * POP_SCALE, POP_UP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(label, "modulate", GAIN_COLOR, POP_UP_TIME)
	pop_tween.chain().tween_property(label, "scale", Vector2.ONE, POP_DOWN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	pop_tween.tween_property(label, "modulate", label_base_modulate, POP_DOWN_TIME)
