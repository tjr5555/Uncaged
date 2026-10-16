extends CanvasLayer

@onready var boost_bar: ProgressBar = $MarginContainer/BoostBar

var target_value: float = 100.0

func set_boost(current: float, maximum: float) -> void:
	boost_bar.max_value = maximum
	target_value = current

func _process(delta: float) -> void:
	boost_bar.value = lerpf(boost_bar.value, target_value, 1.0 - exp(-15.0 * delta))
	$coinsLabel.text = "Coins: " + str(Global.total_coins)
