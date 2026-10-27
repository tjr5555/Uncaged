extends CanvasLayer

@onready var boost_bar: ProgressBar = $MarginContainer/BoostBar
@onready var dash_bar: ProgressBar = $MarginContainer/DashBar

var target_value: float = 100.0
var dash_display: float = 0.0
var last_mode: Global.Mode
var layout_tween: Tween

func _ready() -> void:
	dash_bar.max_value = Global.max_dashes
	dash_display = float(Global.dashes)
	dash_bar.value = dash_display
	last_mode = Global.mode
	_set_layout(Global.mode, true)

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
	
	$coinsLabel.text = "Coins: " + str(int(Global.total_coins))
	
	if Global.mode != last_mode:
		last_mode = Global.mode
		_set_layout(Global.mode, false)
