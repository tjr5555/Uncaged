extends CanvasLayer

@onready var boost_bar: ProgressBar = $MarginContainer/BoostBar
@onready var dash_bar: ProgressBar = $MarginContainer/DashBar

var target_value: float = 100.0

func _ready() -> void:
	dash_bar.max_value = Global.max_dashes

func set_boost(current: float, maximum: float) -> void:
	boost_bar.max_value = maximum
	target_value = current

func _process(delta: float) -> void:
	boost_bar.value = lerpf(boost_bar.value, target_value, 1.0 - exp(-15.0 * delta))
	$coinsLabel.text = "Coins: " + str(int(Global.total_coins))
	dash_bar.value = Global.dashes
	
	if Global.mode == Global.Mode.FLY:
		var tween = create_tween().set_parallel()
		tween.tween_property(boost_bar, "position:y", 25.0, 1.0)
		tween.tween_property(dash_bar, "position:y", 150, 1.0)
	else:
		var tween = create_tween().set_parallel()
		tween.tween_property(boost_bar, "position:y", 150, 1.0)
		tween.tween_property(dash_bar, "position:y", 25.0, 1.0)
