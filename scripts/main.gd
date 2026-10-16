extends Node2D

func _ready() -> void:
	$player.boost_changed.connect($UI.set_boost)
