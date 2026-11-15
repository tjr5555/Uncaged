extends Control

const COIN_COLOR = Color(1.0, 0.82, 0.3)
const TEXT = Color(0.97, 0.95, 0.88)
const SPEND_COLOR = Color(1.0, 0.45, 0.45)
const MAX_FLYING = 14

@export var fly_time := 0.55
@export var roll_time := 0.35
@export var show_popups := true

var _pill: PanelContainer
var _pill_style: StyleBoxFlat
var _coin_icon: TextureRect
var _label: Label
var _coin_tex: ImageTexture
var _coin_tex_small: ImageTexture
var _shown := 0.0
var _target := 0.0
var _in_flight := 0
var _flying := 0
var _roll_tween: Tween
var _bump_tween: Tween
var _flash_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.build()
	_coin_tex = _make_coin_texture(34)
	_coin_tex_small = _make_coin_texture(22)
	_build()
	_target = float(Global.total_coins)
	_set_shown(_target)
	Global.coins_gained.connect(_on_coins_gained)
	Combo.combo_ended.connect(_on_combo_ended)


func _process(_delta: float) -> void:
	var target := float(Global.total_coins) - _in_flight
	if is_equal_approx(target, _target):
		return
	var spent := target < _target
	_target = target
	_roll_to(target)
	if spent:
		_flash(SPEND_COLOR)


func _build() -> void:
	_pill_style = StyleBoxFlat.new()
	_pill_style.bg_color = Color(0.0, 0.0, 0.0, 0.38)
	_pill_style.set_corner_radius_all(40)
	_pill_style.set_border_width_all(2)
	_pill_style.border_color = Color(COIN_COLOR, 0.55)
	_pill_style.content_margin_left = 18
	_pill_style.content_margin_right = 26
	_pill_style.content_margin_top = 10
	_pill_style.content_margin_bottom = 10

	_pill = PanelContainer.new()
	_pill.add_theme_stylebox_override("panel", _pill_style)
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.resized.connect(func(): _pill.pivot_offset = _pill.size * 0.5)
	add_child(_pill)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_pill.add_child(row)

	_coin_icon = TextureRect.new()
	_coin_icon.texture = _coin_tex
	_coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_coin_icon.custom_minimum_size = Vector2(34, 34)
	_coin_icon.pivot_offset = Vector2(17, 17)
	row.add_child(_coin_icon)

	_label = _make_label("0", 34, TEXT)
	row.add_child(_label)

func _on_coins_gained(amount: int, color: Color, world_pos: Vector2) -> void:
	if not show_popups or _flying >= MAX_FLYING or not is_visible_in_tree():
		_bump(color)
		Sfx.play("coin", _coin_pitch(amount))
		return
	_in_flight += amount
	_flying += 1
	var view := get_viewport().get_visible_rect().size
	var start := (get_viewport().get_canvas_transform() * world_pos).clamp(Vector2(40, 40), view - Vector2(40, 40))
	_spawn_flyer(amount, color, start)

func _on_flyer_arrived(flyer: Control, amount: int, color: Color) -> void:
	_in_flight = maxi(_in_flight - amount, 0)
	_flying = maxi(_flying - 1, 0)
	flyer.queue_free()
	_bump(color)
	Sfx.play("coin", _coin_pitch(amount))


func _coin_pitch(amount: int) -> float:
	return 0.95 + clampf(float(amount) / 150.0, 0.0, 1.0) * 0.45


func _spawn_flyer(amount: int, color: Color, start: Vector2) -> void:
	var flyer := HBoxContainer.new()
	flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flyer.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.texture = _coin_tex_small
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	flyer.add_child(icon)
	flyer.add_child(_make_label("+" + str(amount), 26, color.lerp(Color.WHITE, 0.35)))
	add_child(flyer)
	flyer.top_level = true

	var flyer_size := flyer.get_combined_minimum_size()
	flyer.size = flyer_size
	flyer.pivot_offset = flyer_size * 0.5
	var from := start - flyer_size * 0.5
	var to := _coin_icon.global_position + _coin_icon.size * 0.5 - flyer_size * 0.5
	var ctrl := from.lerp(to, 0.25) + Vector2(0.0, -140.0)
	flyer.position = from
	flyer.scale = Vector2.ONE * 0.5

	var t := create_tween()
	t.tween_property(flyer, "scale", Vector2.ONE * 1.1, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.08)
	t.tween_method(_move_flyer.bind(flyer, from, ctrl, to), 0.0, 1.0, fly_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_callback(_on_flyer_arrived.bind(flyer, amount, color))


func _move_flyer(t: float, flyer: Control, a: Vector2, c: Vector2, b: Vector2) -> void:
	flyer.position = a.lerp(c, t).lerp(c.lerp(b, t), t)
	flyer.scale = Vector2.ONE * lerpf(1.1, 0.55, t)
	flyer.modulate.a = 1.0 - smoothstep(0.75, 1.0, t)

func _on_combo_ended(_count: int, bonus: int) -> void:
	if bonus <= 0:
		return
	_bump(COIN_COLOR, 1.25)
	_flash(COIN_COLOR.lightened(0.3))
	var tag := _make_label("+" + _format(bonus) + " combo bonus", 22, COIN_COLOR)
	add_child(tag)
	tag.position = Vector2(_pill.size.x * 0.5 - tag.get_combined_minimum_size().x * 0.5, _pill.size.y + 4)
	var t := create_tween().set_parallel()
	t.tween_property(tag, "position:y", tag.position.y + 30.0, 1.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.tween_property(tag, "modulate:a", 0.0, 0.5).set_delay(0.9)
	t.chain().tween_callback(tag.queue_free)


func _bump(color: Color, strength: float = 1.12) -> void:
	if _bump_tween and _bump_tween.is_valid():
		_bump_tween.kill()
	_bump_tween = create_tween().set_parallel()
	_pill.scale = Vector2.ONE * strength
	_bump_tween.tween_property(_pill, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_coin_icon.scale = Vector2(0.2, 1.0)
	_bump_tween.tween_property(_coin_icon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pill_style.border_color = color.lerp(Color.WHITE, 0.3)
	_bump_tween.tween_method(func(c: Color): _pill_style.border_color = c, _pill_style.border_color, Color(COIN_COLOR, 0.55), 0.4)


func _flash(color: Color) -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_label.modulate = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_label, "modulate", Color.WHITE, 0.45)


func _roll_to(value: float) -> void:
	if _roll_tween and _roll_tween.is_valid():
		_roll_tween.kill()
	_roll_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_roll_tween.tween_method(_set_shown, _shown, value, roll_time)


func _set_shown(value: float) -> void:
	_shown = value
	_label.text = _format(roundi(value))


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1, 0.8))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_coin_texture(px: int) -> ImageTexture:
	var img := Image.create_empty(px, px, false, Image.FORMAT_RGBA8)
	var r := px * 0.5
	for y in px:
		for x in px:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var col := COIN_COLOR
			if d > r - 3.0:
				col = COIN_COLOR.darkened(0.3)
			elif d < r * 0.45:
				col = COIN_COLOR.lightened(0.25)
			img.set_pixel(x, y, Color(col, clampf(r - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _format(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out
