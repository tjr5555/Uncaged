extends Node

signal combo_changed(count: int, multiplier: float, level: int)
signal level_up(level: int, multiplier: float)
signal combo_ended(count: int, bonus: int)

const THRESHOLDS = [0, 10, 15, 20, 25, 35]
const MULTIPLIERS = [1.0, 1.25, 1.5, 1.75, 2, 3.0]
const BASE_WINDOW = 2.4
const MIN_WINDOW = 1.4
const WINDOW_SHRINK = 0.03
const MEDALLION_DRAIN = 0.6 #combo drain if you have the medallion

var count := 0
var level := 0
var bonus := 0
var time_left := 0.0
var window := BASE_WINDOW

func _process(delta: float) -> void:
	if count == 0 or Global.in_transition:
		return
	var drain := MEDALLION_DRAIN if Global.has_medallion else 1.0
	time_left -= delta * drain
	if time_left <= 0.0:
		_end()

func register_pop(base_value: float) -> int:
	count += 1
	window = maxf(BASE_WINDOW - float(count) * WINDOW_SHRINK, MIN_WINDOW)
	time_left = window
	
	var new_level := _level_for(count)
	var leveled := new_level > level
	level = new_level
	
	var mult: float = MULTIPLIERS[level]
	var reward := roundi(base_value * mult)
	bonus += reward - roundi(base_value)
	
	combo_changed.emit(count, mult, level)
	if leveled:
		level_up.emit(level, mult)
	return reward

func time_ratio() -> float:
	if count == 0:
		return 0.0
	return clampf(time_left / window, 0.0, 1.0)

func _end() -> void:
	var final_count := count
	var final_bonus := bonus
	count = 0
	level = 0
	bonus = 0
	time_left = 0.0
	combo_ended.emit(final_count, final_bonus)

func _level_for(c: int) -> int:
	var result := 0
	for i in THRESHOLDS.size():
		if c >= int(THRESHOLDS[i]):
			result = i
	return result
