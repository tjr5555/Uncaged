extends Control

@export var hover_sound: AudioStream
@export var click_sound: AudioStream
@export var buy_sound: AudioStream
@export var deny_sound: AudioStream
@export var blur_background := true

# Every upgrade is 1 entry in this list, to add a new one:
# 1. Add a variable for it to Global (e.g. var gravity_scale := 1.0)
# 2. Add it to SAVED_GLOBALs in save_manager.gd
# 3. Copy an entry below and fill it in, the card gets built automatically
# Keys:
# id        any unique name (also the save key for its level)
# title     name displayed for the card
# desc      a short description
# accent    the card's color
# var       the Global.gd variable that gets changed on upgrade
# step      how much one purchase changes the value 
# mode      "add" (value + step) or "mult" (value * step)
# price     starting price
# price_scale     the price is multiplied by this after every purchase
# decimals        decimals shown for the value
# limit           OPTIONAL: disables after value reaches this
# --- See below for examples

const UPGRADES = [
	{
		"id": "flight_speed", "title": "Flight Speed", "var": "base_flight_speed",
		"desc": "Raises your cruising speed in flight.", "accent": Color(0.45, 0.72, 1.0),
		"step": 50.0, "mode": "add", "price": 150.0, "price_scale": 1.3, "decimals": 0, "limit": 1700,
	},
	{
		"id": "coin_mult", "title": "Coin Multiplier", "var": "base_coin_mult",
		"desc": "Earn more coins from every balloon.", "accent": Color(1.0, 0.82, 0.3),
		"step": 0.25, "mode": "add", "price": 300.0, "price_scale": 1.5, "decimals": 2, "limit": 5.0,
	},
	{
		"id": "turn_rate", "title": "Turn Rate", "var": "base_turn_speed",
		"desc": "Turn tighter and react faster in the air.", "accent": Color(0.45, 0.95, 0.6),
		"step": 0.2, "mode": "add", "price": 150.0, "price_scale": 1.3, "decimals": 1, "limit": 6.2,
	},
	{
		"id": "brake_turn", "title": "Brake Turn Bonus", "var": "brake_turn_bonus",
		"desc": "Turn even sharper while braking.", "accent": Color(0.78, 0.5, 1.0),
		"step": 0.2, "mode": "add", "price": 120.0, "price_scale": 1.3, "decimals": 1, "limit": 2.6,
	},
	{
		"id": "brake_strength", "title": "Brake Strength", "var": "brake_decel_scale",
		"desc": "Slow down faster when braking.", "accent": Color(1.0, 0.6, 0.25),
		"step": 0.15, "mode": "add", "price": 150.0, "price_scale": 1.3, "decimals": 2, "limit": 1.6,
	},
	{
		"id": "magnet", "title": "Balloon Magnet", "var": "magnet_radius",
		"desc": "Pulls nearby balloons towards you.", "accent": Color(1.0, 0.45, 0.6),
		"step": 70.0, "mode": "add", "price": 500.0, "price_scale": 1.6, "decimals": 0, "limit": 350.0,
	},
]

const BLUR_SHADER = preload("res://shaders/ui_blur.gdshader")
const COIN_COLOR = Color(1.0, 0.82, 0.3)
const CARD_COLOR = Color(0.07, 0.1, 0.17, 0.92)
const TEXT = Color(0.95, 0.97, 1.0)
const TEXT_DIM = Color(0.64, 0.7, 0.8)
const DENY_COLOR = Color(1.0, 0.45, 0.45)
const CARD_SIZE = Vector2(480, 300)
const CARD_PADDING = 28.0
const MAX_PIPS = 12
const PIP_GAP = 6.0

var _audio := AudioStreamPlayer.new()
var _cards := {}
var _coin_label: Label
var _coin_texture_big: ImageTexture
var _coin_texture_small: ImageTexture
var _coins_target := -1.0
var _coins_shown := 0.0
var _coin_tween: Tween

func _ready() -> void:
	add_child(_audio)
	theme = UiTheme.build()
	_coin_texture_big = _make_coin_texture(30)
	_coin_texture_small = _make_coin_texture(24)
	_build_ui()

	var extra_button := get_node_or_null("Button")
	if extra_button:
		move_child(extra_button, -1)

	for b in find_children("*", "BaseButton", true, false):
		_setup(b)
	get_tree().node_added.connect(_on_node_added)

	var layer := get_parent() as CanvasLayer
	if layer:
		layer.visibility_changed.connect(_on_layer_visibility_changed)

	for u in UPGRADES:
		_refresh(u)
	_set_coins_instant()
func _process(delta: float) -> void:
	var coins := float(Global.total_coins)
	if is_equal_approx(coins, _coins_target):
		return
	_coins_target = coins
	if _coin_tween and _coin_tween.is_valid():
		_coin_tween.kill()
	_coin_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_coin_tween.tween_method(_set_coins_shown, _coins_shown, coins, 0.4)
	for u in UPGRADES:
		_refresh_button(u)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var layer := get_parent() as CanvasLayer
	if layer and not layer.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_button_pressed()

func _build_ui() -> void:
	if blur_background:
		var backdrop := ColorRect.new()
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = BLUR_SHADER
		mat.set_shader_parameter("amount", 1.0)
		backdrop.material = mat
		add_child(backdrop)
	
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 96)
	root.add_theme_constant_override("margin_right", 96)
	root.add_theme_constant_override("margin_top", 72)
	root.add_theme_constant_override("margin_bottom", 64)
	add_child(root)
	
	var column := VBoxContainer.new()
	column.add_theme_constant_override("seperation", 36)
	root.add_child(column)
	
	var header := HBoxContainer.new()
	column.add_child(header)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("seperation", 2)
	header.add_child(titles)
	var title := _label("Shop", 52, TEXT)
	title.theme_type_variation = &"HeaderLarge"
	titles.add_child(title)
	titles.add_child(_label("Spend your coins on upgrades", 22, TEXT_DIM))
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	header.add_child(_build_coin_pill())
	
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(center)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_seperation", 28)
	grid.add_theme_constant_override("v_seperation", 28)
	center.add_child(grid)
	for u in UPGRADES:
		grid.add_child(_build_card(u))
	
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("seperation", 20)
	column.add_child(footer)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(200, 64)
	back.pressed.connect(_on_back_button_pressed)
	footer.add_child(back)
	footer.add_child(_label("Esc to close", 20, TEXT_DIM))

func _build_coin_pill() -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.35)
	style.set_corner_radius_all(40)
	style.set_border_width_all(2)
	style.border_color = Color(COIN_COLOR, 0.5)
	style.content_margin_left = 22
	style.content_margin_right = 26
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", style)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("seperation", 12)
	pill.add_child(row)
	
	var coin := TextureRect.new()
	coin.texture = _coin_texture_big
	coin.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(coin)
	_coin_label = _label("0", 32, COIN_COLOR)
	row.add_child(_coin_label)
	return pill

func _build_card(u: Dictionary) -> PanelContainer:
	var accent: Color = u.get("accent", Color(0.45, 0.72, 1.0))
	
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_COLOR
	style.set_corner_radius_all(18)
	style.border_width_top = 6
	style.border_color = accent
	style.content_margin_left = CARD_PADDING
	style.content_margin_right = CARD_PADDING
	style.content_margin_top = 22
	style.content_margin_bottom = 24
	
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = CARD_SIZE
	
	var box := VBoxContainer.new()
	box.add_theme_constant_override("seperation", 14)
	card.add_child(box)
	
	var top := HBoxContainer.new()
	box.add_child(top)
	var title := _label(u["title"], 30, TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var level := _label("", 22, accent)
	top.add_child(level)
	
	var desc := _label(u.get("desc", ""), 21, TEXT_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = CARD_SIZE.x - CARD_PADDING * 2.0
	box.add_child(desc)
	
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("seperation", int(PIP_GAP))
	box.add_child(pips)
	
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	
	var stat := HBoxContainer.new()
	stat.add_theme_constant_override("seperation", 12)
	box.add_child(stat)
	var now := _label("", 34, TEXT)
	var arrow := _label("->", 26, TEXT_DIM)
	var next := _label("", 34, accent)
	stat.add_child(now)
	stat.add_child(arrow)
	stat.add_child(next)
	
	var buy := Button.new()
	buy.custom_minimum_size.y = 64
	buy.pressed.connect(_buy.bind(u))
	box.add_child(buy)
	
	_cards[u["id"]] = {
		"card": card, "style": style, "accent": accent, "level": level, "pips": pips,
		"now": now, "arrow": arrow, "next": next, "buy": buy, "filled": 0,
	}
	return card

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _make_coin_texture(size: int) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var r := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var col := COIN_COLOR
			if d > r - 3.0:
				col = COIN_COLOR.darkened(0.3)
			elif d < r * 0.45:
				col = COIN_COLOR.lightened(0.25)
			img.set_pixel(x, y, Color(col, clampf(r - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

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
		_play(sound)

func _level(u: Dictionary) -> int:
	return int(Global.upgrade_levels.get(u["id"], 0))

func _price(u: Dictionary) -> int:
	var raw := float(u["price"]) * pow(float(u["price_scale"]), _level(u))
	return int(snappedf(raw, 5.0))

func _buy(u: Dictionary) -> void:
	var id: String = u["id"]
	if _is_maxed(u):
		return
	var price := _price(u)
	if float(Global.total_coins) < price:
		_deny(u)
		return
	
	var current: Variant = Global.get(u["var"])
	if current == null:
		push_error("Shop: Global has no variable named '%s' (used by upgrade '%s')." % [u["var"], u["id"]])
		return
	var old := float(current)
	var next := _next_value(u, old)
	
	Global.total_coins -= price
	Global.set(u["var"], int(roundf(next)) if typeof(current) == TYPE_INT else next)
	Global.upgrade_levels[id] = _level(u) + 1
	
	_refresh(u)
	_roll(u, old, next)
	_celebrate(u)
	_play(buy_sound)
	SaveManager.save_game()

func _next_value(u: Dictionary, current: float) -> float:
	var next: float = current * u["step"] if u["mode"] == "mult" else current + u["step"]
	if u.has("limit"):
		next = minf(next, u["limit"] if u["step"] > 0.0 else maxf(next, u["limit"]))
	return next

func _is_maxed(u: Dictionary) -> bool:
	return _is_maxed_at(u, _value(u))

func _is_maxed_at(u: Dictionary, value: float) -> bool:
	if not u.has("limit"):
		return false
	if u["step"] > 0.0:
		return value >= u["limit"] - 0.0001
	return value <= u["limit"] + 0.0001

func _remaining_levels(u: Dictionary, value: float) -> int:
	if not u.has("limit"):
		return 0
	var count := 0
	var v := value
	while count < 60 and not _is_maxed_at(u, v):
		var nv := _next_value(u, v)
		if is_equal_approx(nv, v):
			break
		v = nv
		count += 1
	return count

func _refresh(u: Dictionary) -> void:
	var c: Dictionary = _cards[u["id"]]
	var value := _value(u)
	var level := _level(u)
	var total := level + _remaining_levels(u, value)
	
	if _is_maxed_at(u, value):
		c["level"].text = "MAX"
	elif u.has("limit"):
		c["level"].text = "Lv %d / %d" % [level, total]
	else:
		c["level"].text = "Lv %d" % level
	
	_update_pips(c, level, total)
	_set_stat(value, u)
	_refresh_button(u)

func _update_pips(c: Dictionary, level: int, total: int) -> void:
	var pips: HBoxContainer = c["pips"]
	for child in pips.get_children():
		pips.remove_child(child)
		child.queue_free()
	if total <= 0:
		c["filled"] = 0
		return
	
	var segments := mini(total, MAX_PIPS)
	var filled := int(roundf(float(level) / float(total) * segments))
	var width := (CARD_SIZE.x - CARD_PADDING * 2.0 - PIP_GAP * (segments - 1)) / segments
	var accent: Color = c["accent"]
	for i in segments:
		pips.add_child(_make_pip(width, accent if i < filled else Color(1.0, 1.0, 1.0, 0.12)))
	c["filled"] = filled

func _make_pip(width: float, color: Color) -> Panel:
	var pip := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(4)
	pip.add_theme_stylebox_override("panel", box)
	pip.custom_minimum_size = Vector2(width, 10)
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pip

func _set_stat(value: float, u: Dictionary) -> void:
	var c: Dictionary = _cards[u["id"]]
	var d: int = u["decimals"]
	var maxed := _is_maxed_at(u, value)
	c["now"].text = String.num(value, d)
	c["arrow"].visible = not maxed
	c["next"].visible = not maxed
	if not maxed:
		c["next"].text = String.num(_next_value(u, value), d)

func _refresh_button(u: Dictionary) -> void:
	var c: Dictionary = _cards[u["id"]]
	var buy: Button = c["buy"]
	if _is_maxed(u):
		buy.text = "Maxed"
		buy.icon = null
		buy.disabled = true
		buy.modulate.a = 0.6
		return
	
	var price := _price(u)
	var affordable := float(Global.total_coins) >= price
	var color := TEXT if affordable else DENY_COLOR
	buy.text = "  " + _format_number(price)
	buy.icon = _coin_texture_small
	buy.disabled = false
	buy.modulate.a = 1.0 if affordable else 0.8
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		buy.add_theme_color_override(key, color)

func _roll(u: Dictionary, from: float, to: float) -> void:
	var t := create_tween()
	t.tween_method(_set_stat.bind(u), from, to, 0.3)

func _celebrate(u: Dictionary) -> void:
	var c: Dictionary = _cards[u["id"]]
	var card: Control = c["card"]
	card.pivot_offset = card.size * 0.5
	var t := create_tween()
	t.tween_property(card, "scale", Vector2.ONE * 1.04, 0.08)
	t.tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	var style: StyleBoxFlat = c["style"]
	var accent: Color = c["accent"]
	var flash := create_tween()
	flash.tween_method(func(col: Color): style.border_color = col, Color.WHITE, accent, 0.45)
	
	var pips: HBoxContainer = c["pips"]
	var filled: int = c["filled"]
	if filled > 0 and filled <= pips.get_child_count():
		var pip: Control = pips.get_child(filled - 1)
		pip.pivot_offset = pip.custom_minimum_size * 0.5
		pip.scale = Vector2(1.0, 1.8)
		create_tween().tween_property(pip, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _deny(u: Dictionary) -> void:
	var card: Control = _cards[u["id"]]["card"]
	card.pivot_offset = card.size * 0.5
	var t := create_tween()
	for i in 4:
		var dir := 1.0 if i % 2 == 0 else -1.0
		t.tween_property(card, "rotation", 0.025 * dir * (1.0 - float(i) / 4.0), 0.04)
	t.tween_property(card, "rotation", 0.0, 0.05)
	_flash_coins(DENY_COLOR)
	_play(deny_sound)

func _set_coins_instant() -> void:
	_coins_target = float(Global.total_coins)
	_set_coins_shown(_coins_target)

func _set_coins_shown(value: float) -> void:
	_coins_shown = value
	_coin_label.text = _format_number(roundi(value))

func _flash_coins(color: Color) -> void:
	_coin_label.modulate = color
	create_tween().tween_property(_coin_label, "modulate", Color.WHITE, 0.45)

func _format_number(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out

func _on_layer_visibility_changed() -> void:
	var layer := get_parent() as CanvasLayer
	if layer and layer.visible:
		_play_open()

func _play_open() -> void:
	for u in UPGRADES:
		_refresh(u)
	_set_coins_instant()
	var i := 0
	for u in UPGRADES:
		var card: Control = _cards[u["id"]]["card"]
		card.pivot_offset = card.size * 0.5
		card.modulate.a = 0.0
		card.scale = Vector2.ONE * 0.94
		var t := create_tween()
		t.tween_interval(0.05 * i)
		t.tween_property(card, "modulate:a", 1.0, 0.2)
		t.parallel().tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		i += 1

func _play(stream: AudioStream) -> void:
	if stream == null:
		return
	_audio.stream = stream
	_audio.play()

func _on_back_button_pressed() -> void:
	if get_parent() is CanvasLayer:
		get_parent().hide()
		Global.INPUT_LOCKED = false
	var boost_bar = get_node_or_null("/root/main/UI/MarginContainer/BoostBar")
	if boost_bar:
		boost_bar.visible = true
	else:
		push_error("Shop: couldn't find /root/main/UI/MarginContainer/BoostBar")

func _value(u: Dictionary) -> float:
	var v: Variant = Global.get(u["var"])
	if v == null:
		push_error("Shop: Global has no variable named '%s' (used by upgrade '%s')." % [u["var"], u["id"]])
		return 0.0
	return float(v)
