extends Control

@export var hover_sound: AudioStream
@export var click_sound: AudioStream

var _audio := AudioStreamPlayer.new()

# To add an upgrade, add an entry here (the key is the button's node name).
# Use "add" to increase the stat by a fixed amount, or "mult" to multiply it.
var upgrades := {
	"flightSpeedButton": {
		"title": "Flight Speed", "stat": "base_flight_speed",
		"price": 100.0, "price_mult": 1.25, "add": 20.0,
	},
	"coinMultiplierButton": {
		"title": "Coin Multiplier", "stat": "base_coin_mult",
		"price": 1000.0, "price_mult": 1.6, "mult": 1.5,
	},
}

func _ready() -> void:
	add_child(_audio)

	# Hover/press animation on every button, including back
	for b in find_children("*", "BaseButton", true, false):
		_setup_animation(b)

	# Hook up and display every upgrade
	for id in upgrades:
		var button: Button = find_child(id)
		button.pressed.connect(_buy.bind(id))
		_refresh(id)

# --- Buying ---

func _buy(id: String) -> void:
	var u: Dictionary = upgrades[id]
	if Global.total_coins < u.price:
		return

	var old_value: float = Global.get(u.stat)
	Global.total_coins -= int(u.price)
	Global.set(u.stat, _next(u, old_value))
	u.price *= u.price_mult

	_refresh_price(id)
	_roll(id, old_value, Global.get(u.stat))
	_pop(_label(id))

func _next(u: Dictionary, value: float) -> float:
	return value + u.add if u.has("add") else value * u.mult

# --- UI ---

func _label(id: String) -> Label:
	return find_child(id).find_children("*", "Label", false)[0]

func _refresh(id: String) -> void:
	_refresh_price(id)
	_set_amount(Global.get(upgrades[id].stat), id)

func _refresh_price(id: String) -> void:
	var u: Dictionary = upgrades[id]
	find_child(id).text = u.title + "\nPrice: " + str(int(u.price))

func _set_amount(value: float, id: String) -> void:
	var next := _next(upgrades[id], value)
	_label(id).text = String.num(value, 2) + " -> " + String.num(next, 2)

func _roll(id: String, from: float, to: float) -> void:
	create_tween().tween_method(_set_amount.bind(id), from, to, 0.3)

func _pop(c: Control) -> void:
	c.pivot_offset = c.size / 2.0
	var t := create_tween()
	t.tween_property(c, "scale", Vector2.ONE * 1.3, 0.08)
	t.tween_property(c, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# --- Hover / press animation ---

func _setup_animation(b: BaseButton) -> void:
	b.pivot_offset = b.size / 2.0
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	b.mouse_entered.connect(_grow.bind(b, 1.05, hover_sound))
	b.mouse_exited.connect(_grow.bind(b, 1.0, null))
	b.button_down.connect(_grow.bind(b, 0.95, click_sound))
	b.button_up.connect(_grow.bind(b, 1.05, null))

func _grow(b: BaseButton, amount: float, sound: AudioStream) -> void:
	if b.disabled:
		return
	var t := b.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "scale", Vector2.ONE * amount, 0.1)
	if sound:
		_audio.stream = sound
		_audio.play()

# --- Back button ---

func _on_back_button_pressed() -> void:
	if get_parent() is CanvasLayer:
		get_parent().hide()
	var boost_bar = get_node_or_null("/root/main/UI/MarginContainer/BoostBar")
	if boost_bar:
		boost_bar.visible = true
