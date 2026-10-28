extends Control

@export var hover_sound: AudioStream
@export var click_sound: AudioStream

#Pricing variables, will scale depending on how good the upgrade is
var fsbp: float = 100.0 #flight speed base price
var cmbp: float = 100.0 #coin multiplier base price


#How much that stats increase and scale by
const FLIGHT_STEP := 20
const COIN_STEP := 1.5 #in this case, coin step is actually a multiplier so it would go from 1.5-2.25-3.37 instead of 1.5,2,2.5,3 etc.
const PRICE_SCALE := 1.25

var _audio := AudioStreamPlayer.new()

@onready var flight_button: Button = $PanelContainer/MarginContainer/GridContainer/flightSpeedButton
@onready var flight_amount: Label = $PanelContainer/MarginContainer/GridContainer/flightSpeedButton/flightSpeedAmount
@onready var coin_button: Button = $PanelContainer/MarginContainer/GridContainer/coinMultiplierButton
@onready var coin_amount: Label = $PanelContainer/MarginContainer/GridContainer/coinMultiplierButton/coinMultLabel


func _ready() -> void:
	add_child(_audio)
	for b in find_children("*", "BaseButton", true, false):
		_setup(b)
	get_tree().node_added.connect(_on_node_added)
	_update_price_ui()
	_set_speed_text(Global.base_flight_speed)
	_set_coin_text(Global.base_coin_mult)


func _on_node_added(node: Node) -> void:
	if node is BaseButton and is_ancestor_of(node):
		_setup(node)


func _setup(b: BaseButton) -> void:
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


func _update_price_ui() -> void:
	flight_button.text = "Flight Speed\nPrice: " + str(int(fsbp))
	coin_button.text = "Coin Multiplier\nPrice: " + str(int(cmbp))


func _set_speed_text(speed: float) -> void:
	flight_amount.text = str(int(speed)) + " -> " + str(int(speed) + FLIGHT_STEP)


func _set_coin_text(mult: float) -> void:
	coin_amount.text = String.num(mult, 2) + " -> " + String.num(mult * COIN_STEP, 2)




func _roll_speed(from: int, to: int) -> void:
	var t := create_tween()
	t.tween_method(_set_speed_text, float(from), float(to), 0.3)


func _roll_coin(from: float, to: float) -> void:
	var t := create_tween()
	t.tween_method(_set_coin_text, from, to, 0.3)


func _pop(c: Control) -> void:
	c.pivot_offset = c.size / 2.0
	var t := create_tween()
	t.tween_property(c, "scale", Vector2.ONE * 1.3, 0.08)
	t.tween_property(c, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_flight_speed_button_pressed() -> void:
	var old_speed: int = Global.base_flight_speed
	if Global.total_coins >= fsbp:
		Global.total_coins -= fsbp
		Global.base_flight_speed += FLIGHT_STEP
		fsbp *= PRICE_SCALE
		_update_price_ui()
		_roll_speed(old_speed, Global.base_flight_speed)
		_pop(flight_amount)
		print("Flight speed: " + str(Global.base_flight_speed))


func _on_coin_multiplier_button_pressed() -> void:
	var old_coin_mult: float = Global.base_coin_mult
	if Global.total_coins >= cmbp:
		Global.total_coins -= cmbp
		Global.base_coin_mult *= COIN_STEP
		cmbp *= PRICE_SCALE
		_update_price_ui()
		_roll_coin(old_coin_mult, Global.base_coin_mult)
		_pop(coin_amount)
		print("Coin multiplier: " + str(Global.base_coin_mult))
func _on_back_button_pressed() -> void:
	if get_parent() is CanvasLayer:
		get_parent().hide()
	var main_node = $/root/main
	if main_node:
		var boost_bar = main_node.get_node_or_null("UI/MarginContainer/BoostBar")
		if boost_bar:
			boost_bar.visible = true
