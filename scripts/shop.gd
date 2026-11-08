extends Control

@export var hover_sound: AudioStream
@export var click_sound: AudioStream

#every upgrade is one entry in this list. To add a new one:
#1. add a variable for it to Global (for example: var gravity_scale := 1.0)
#2. add a Button to the GridContainer in the scene, with a Label as a child of the button
#3. copy an entry below and fill in the names
#
#keys:
#  id           any unique name
#  title        text shown on the button
#  var          the Global variable this upgrade changes
#  button       name of the Button node under GridContainer
#  label        name of the Label node under that button (shows "old -> new")
#  step         how much one purchase changes the value (negative to lower it)
#  mode         "add" (value + step) or "mult" (value * step)
#  price        starting price
#  price_scale  the price is multiplied by this after every purchase
#  decimals     decimals shown in the label
#  limit        optional: stops being buyable once the value reaches this
const UPGRADES = [
	{
		"id": "flight_speed", "title": "Flight Speed", "var": "base_flight_speed",
		"button": "flightSpeedButton", "label": "flightSpeedAmount",
		"step": 50.0, "mode": "add", "price": 150.0, "price_scale": 1.3, "decimals": 0, "limit": 1700,
	},
	{
		"id": "coin_mult", "title": "Coin Multiplier", "var": "base_coin_mult",
		"button": "coinMultiplierButton", "label": "coinMultLabel",
		"step": 0.25, "mode": "add", "price": 300.0, "price_scale": 1.5, "decimals": 2, "limit": 5.0,
	},
	{
		"id": "turn_rate", "title": "Turn Rate", "var": "base_turn_speed",
		"button": "flightControlButton", "label": "flightControlAmount",
		"step": 0.2, "mode": "add", "price": 150.0, "price_scale": 1.3, "decimals": 1, "limit": 6.2,
	},
	{
		"id": "brake_turn", "title": "Brake Turn Bonus", "var": "brake_turn_bonus",
		"button": "BrakeTurnBonusButton", "label": "brakeTurnBonusAmount",
		"step": 0.2, "mode": "add", "price": 120.0, "price_scale": 1.3, "decimals": 1, "limit": 2.6,
	},
	{
		"id": "brake_strength", "title": "Brake Strength", "var": "brake_decel_scale",
		"button": "brakeStrengthButton", "label": "brakeStrengthAmount",
		"step": 0.15, "mode": "add", "price": 150.0, "price_scale": 1.3, "decimals": 2, "limit": 1.6,
	},
	{
		"id": "magnet", "title": "Balloon Magnet", "var": "magnet_radius",
		"button": "magnetButton", "label": "magnetAmount",
		"step": 70.0, "mode": "add", "price": 500.0, "price_scale": 1.6, "decimals": 0, "limit": 350.0,
	},
]

var _audio := AudioStreamPlayer.new()
var _nodes := {} #upgrade id -> {"button": Button, "label: Label}

@onready var grid: Control = $PanelContainer/MarginContainer/GridContainer

func _ready() -> void:
	add_child(_audio)
	for b in find_children("*", "BaseButton", true, false):
		_setup(b)
	get_tree().node_added.connect(_on_node_added)
	
	for u in UPGRADES:
		var button := grid.get_node_or_null(u["button"]) as Button
		if button == null:
			push_error("Shop: could not find button node named: ", u["button"], " for upgrade: ", u["id"])
			continue
		
		var label := button.get_node_or_null(u["label"]) as Label
		if label == null:
			push_error("Shop: could not find label node named: ", u["label"], " inside button: ", u["button"])
			continue
		
		_nodes[u["id"]] = {"button": button, "label": label}
		button.pressed.connect(_buy.bind(u))
		_refresh(u)


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


func _level(u: Dictionary) -> int:
	return int(Global.upgrade_levels.get(u["id"], 0))


func _price(u: Dictionary) -> int:
	var raw := float(u["price"]) * pow(float(u["price_scale"]), _level(u))
	return int(snappedf(raw, 5.0))


func _buy(u: Dictionary) -> void:
	var id: String = u["id"]
	var price := _price(u)
	if _is_maxed(u) or Global.total_coins < price:
		return

	var current: Variant = Global.get(u["var"])
	var old := float(current)
	var next := _next_value(u, old)

	Global.total_coins -= price
	#keep integer variables as integers
	Global.set(u["var"], int(roundf(next)) if typeof(current) == TYPE_INT else next)
	Global.upgrade_levels[id] = _level(u) + 1

	_refresh_button(u)
	_roll(u, old, next)
	_pop(_nodes[id]["label"])
	SaveManager.save_game()


func _next_value(u: Dictionary, current: float) -> float:
	var next: float = current * u["step"] if u["mode"] == "mult" else current + u["step"]
	if u.has("limit"):
		next = minf(next, u["limit"]) if u["step"] > 0.0 else maxf(next, u["limit"])
	return next


func _is_maxed(u: Dictionary) -> bool:
	return _is_maxed_at(u, float(Global.get(u["var"])))


func _is_maxed_at(u: Dictionary, value: float) -> bool:
	if not u.has("limit"):
		return false
	if u["step"] > 0.0:
		return value >= u["limit"] - 0.0001
	return value <= u["limit"] + 0.0001


func _refresh(u: Dictionary) -> void:
	_set_label(float(Global.get(u["var"])), u)
	_refresh_button(u)


func _refresh_button(u: Dictionary) -> void:
	var button: Button = _nodes[u["id"]]["button"]
	if _is_maxed(u):
		button.text = u["title"] + "\nMAX"
		button.disabled = true
	else:
		button.text = u["title"] + "\nPrice: " + str(_price(u))
		button.disabled = false


func _set_label(value: float, u: Dictionary) -> void:
	var label: Label = _nodes[u["id"]]["label"]
	var d: int = u["decimals"]
	if _is_maxed_at(u, value):
		label.text = String.num(value, d)
	else:
		label.text = String.num(value, d) + " -> " + String.num(_next_value(u, value), d)


func _roll(u: Dictionary, from: float, to: float) -> void:
	var t := create_tween()
	t.tween_method(_set_label.bind(u), from, to, 0.3)


func _pop(c: Control) -> void:
	c.pivot_offset = c.size / 2.0
	var t := create_tween()
	t.tween_property(c, "scale", Vector2.ONE * 1.3, 0.08)
	t.tween_property(c, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_back_button_pressed() -> void:
	if get_parent() is CanvasLayer:
		get_parent().hide
	var boost_bar = get_node_or_null("/root/main/UI/MarginContainer/BoostBar")
	if boost_bar:
		boost_bar.visible = true
	else:
		push_error("Shop: couldn't find /root/main/UI/MarginContainer")
