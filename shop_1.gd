extends Control  # attach to shop1

@export var hover_sound: AudioStream
@export var click_sound: AudioStream

# Pricing variables, will scale depending on how good the upgrade is
var fsbp: float = 100.0

var _audio := AudioStreamPlayer.new()

@onready var flight_button: Button = $PanelContainer/MarginContainer/GridContainer/flightSpeedButton
@onready var flight_amount: Label = $PanelContainer/MarginContainer/GridContainer/flightSpeedButton/flightSpeedAmount

func _ready() -> void:
	add_child(_audio)
	for b in find_children("*", "BaseButton", true, false):
		_setup(b)
	get_tree().node_added.connect(_on_node_added)
	_update_price_ui()
	_set_speed_text(Global.base_flight_speed)

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

func _set_speed_text(speed: float) -> void:
	flight_amount.text = str(int(speed)) + " -> " + str(int(speed) + 20)


func _roll_speed(from: int, to: int) -> void:
	var t := create_tween()
	t.tween_method(_set_speed_text, float(from), float(to), 0.3)

func _pop(c: Control) -> void:
	c.pivot_offset = c.size / 2.0
	var t := create_tween()
	t.tween_property(c, "scale", Vector2.ONE * 1.3, 0.08)
	t.tween_property(c, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_flight_speed_button_pressed() -> void:
	var old_speed: int = Global.base_flight_speed
	Global.base_flight_speed += 20
	fsbp *= 1.25
	_update_price_ui()
	_roll_speed(old_speed, Global.base_flight_speed)
	_pop(flight_amount)
