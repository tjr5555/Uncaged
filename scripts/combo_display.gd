extends Control

const LEVEL_COLORS = [
	Color(1.0, 1.0, 1.0),
	Color(0.45, 1.0, 0.55),
	Color(0.35, 0.85, 1.0),
	Color(0.78, 0.5, 1.0),
	Color(1.0, 0.6, 0.25),
	Color(1.0, 0.85, 0.3),
]

const LEVEL_WORDS = ["REDUNDANT", "OKAY", "NICE!", "BRUTAL!", "INSANE!", "UNCAGED!"]
const SHOW_AT = 2
const MAX_SHAKE = 14.0
const LOW_TIME = 0.3

@onready var box: Control = $Box
@onready var count_label: Label = %ComboCount
@onready var mult_label: Label = %ComboMultiplier
@onready var word_label: Label = %ComboWord
@onready var timer_bar: ProgressBar = %ComboBar

var box_base := Vector2.ZERO
var trauma := 0.0
var shown := false
var display_color := Color.WHITE
var bar_display := 0.0
var fill_style: StyleBoxFlat
var show_tween: Tween
var punch_tweens: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	box_base = box.position
	box.modulate.a = 0.0
	_style_bar()
	Combo.combo_changed.connect(_on_combo_changed)
	Combo.level_up.connect(_on_level_up)
	Combo.combo_ended.connect(_on_combo_ended)

func _process(delta: float) -> void:
	var time := Time.get_ticks_msec() / 1000.0
	
	var target_color: Color = LEVEL_COLORS[clampi(Combo.level, 0, LEVEL_COLORS.size() - 1)]
	if Combo.level >= LEVEL_COLORS.size() - 1:
		target_color = Color.from_hsv(fposmod(time * 0.5, 1.0), 0.5, 1.0)
	display_color = display_color.lerp(target_color, 1.0 - exp(-8.0 * delta))
	for label in [count_label, mult_label, word_label]:
		label.modulate = Color(display_color, label.modulate.a)
	fill_style.bg_color = display_color
	
	var ratio: float = Combo.time_ratio()
	bar_display = lerpf(bar_display, ratio, 1.0 - exp(-18.0 * delta))
	timer_bar.value = bar_display
	timer_bar.modulate.a = 0.55 + 0.45 * absf(sin(time * 14.0)) if shown and ratio < LOW_TIME else 1.0
	
	trauma = maxf(trauma - delta * 2.0, 0.0)
	var amount: float = trauma * trauma * Settings.screen_shake
	box.position = box_base + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amount * MAX_SHAKE
	box.rotation = randf_range(-1.0, 1.0) * 0.03 * amount

func _on_combo_changed(count: int, multiplier: float, _level: int) -> void:
	count_label.text = str(count)
	mult_label.text = "x" + _format_mult(multiplier)
	if count < SHOW_AT:
		return
	if not shown:
		_show()
	_punch(count_label, 1.45, 0.35, Tween.TRANS_BACK)
	trauma = minf(trauma + 0.2, 1.0)

func _on_level_up(level: int, multiplier: float) -> void:
	if not shown:
		return
	display_color = Color.WHITE
	mult_label.text = "x" + _format_mult(multiplier)
	_punch(mult_label, 1.9, 0.6, Tween.TRANS_ELASTIC)
	word_label.text = LEVEL_WORDS[clampi(level, 0, LEVEL_WORDS.size() - 1)]
	word_label.modulate.a = 1.0
	_punch(word_label, 1.7, 0.5, Tween.TRANS_BACK)
	trauma = minf(trauma + 0.5, 1.0)

func _on_combo_ended(count: int, bonus: int) -> void:
	if not shown:
		return
	shown = false
	word_label.text = "+%d BONUS" % bonus if bonus > 0 else "%d COMBO" % count
	word_label.modulate.a = 1.0
	_punch(word_label, 1.5, 0.4, Tween.TRANS_BACK)
	
	if show_tween and show_tween.is_valid():
		show_tween.kill()
	show_tween = create_tween()
	show_tween.tween_interval(0.7)
	show_tween.tween_property(box, "modulate:a", 0.0, 0.35)
	show_tween.parallel().tween_property(box, "scale", Vector2.ONE * 0.8, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

func _show() -> void:
	shown = true
	box.pivot_offset = box.size * 0.5
	if show_tween and show_tween.is_valid():
		show_tween.kill()
	word_label.text = ""
	box.scale = Vector2.ONE * 0.6
	show_tween = create_tween().set_parallel()
	show_tween.tween_property(box, "modulate:a", 1.0, 0.15)
	show_tween.tween_property(box, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _punch(node: Control, peak: float, time: float, trans: Tween.TransitionType) -> void:
	node.pivot_offset = node.size * 0.5
	var old: Tween = punch_tweens.get(node)
	if old and old.is_valid():
		old.kill()
	node.scale = Vector2.ONE * peak
	var t := create_tween()
	t.tween_property(node, "scale", Vector2.ONE, time).set_trans(trans).set_ease(Tween.EASE_OUT)
	punch_tweens[node] = t

func _format_mult(m: float) -> String:
	return str(int(m)) if is_equal_approx(m, roundf(m)) else "%.1f" % m

func _style_bar() -> void:
	fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color.WHITE
	fill_style.set_corner_radius_all(4)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.0, 0.0, 0.0, 0.35)
	track.set_corner_radius_all(4)
	timer_bar.add_theme_stylebox_override("fill", fill_style)
	timer_bar.add_theme_stylebox_override("background", track)
	timer_bar.show_percentage = false
	timer_bar.min_value = 0.0
	timer_bar.max_value = 1.0
	timer_bar.step = 0.0
