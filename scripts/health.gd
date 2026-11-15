class_name Health
extends Node

signal health_changed(current: float, maximum: float)
signal damaged(amount: float, source: String, continous: bool)
signal died

@export var max_health := 100.0
@export var regen_delay := 10.0
@export var regen_start_rate := 0.5   #HP per second when healing begins
@export var regen_growth := 0.3    #how fast healing speeds up (higher = ramps up sooner)
@export var regen_max_rate := 10.0   #healing never goes faster than this
@export var invulnerable_time := 0.8

var current := 100.0
var dead := false
var _since_damage := 999.0
var _regen_time := 0.0
var _iframes := 0.0

func _ready() -> void:
	add_to_group("player_health")
	current = max_health
	health_changed.emit.call_deferred(current, max_health)

func _process(delta: float) -> void:
	_iframes = maxf(_iframes - delta, 0.0)
	if dead:
		return
	_since_damage += delta
	if _since_damage >= regen_delay and current < max_health:
		_regen_time += delta
		var rate := minf(regen_start_rate * exp(regen_growth * _regen_time), regen_max_rate)
		_set_health(current + rate * delta)
	else:
		_regen_time = 0.0

func damage(amount: float, source: String = "", continous: bool = false) -> void:
	if dead or amount <= 0.0 or Global.in_transition:
		return
	if not continous:
		if _iframes > 0.0:
			return
		_iframes = invulnerable_time
	_since_damage = 0.0
	_regen_time = 0.0
	_set_health(current - amount)
	damaged.emit(amount, source, continous)
	if current <= 0.0:
		dead = true
		died.emit()

func heal_full() -> void:
	dead = false
	_iframes = 0.0
	_since_damage = 999.0
	_regen_time = 0.0
	_set_health(max_health)

func is_invulnerable() -> bool:
	return _iframes > 0.0

func _set_health(value: float) -> void:
	current = clampf(value, 0.0, max_health)
	health_changed.emit(current, max_health)
