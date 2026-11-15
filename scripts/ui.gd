extends CanvasLayer

@onready var boost_bar: ProgressBar = $MarginContainer/BoostBar
@onready var dash_bar: ProgressBar = $MarginContainer/DashBar

var target_value: float = 100.0
var dash_display: float = 0.0
var last_mode: Global.Mode
var layout_tween: Tween

const BOOST_RESTART = 20.0
const EMPTY_COLOR = Color(1.0, 0.35, 0.35)

var boost_empty := false
var last_boost := 100.0
var boost_base_x := 0.0
var boost_fx_tween: Tween
var boost_audio := AudioStreamPlayer.new()

func _ready() -> void:
	add_child(boost_audio)
	boost_bar.add_to_group("boost_bar")
	dash_bar.max_value = Global.max_dashes
	dash_display = float(Global.dashes)
	dash_bar.value = dash_display
	last_mode = Global.mode
	_set_layout(Global.mode, true)

func set_boost(current: float, maximum: float) -> void:
	boost_bar.max_value = maximum
	target_value = current
	if current <= 0.0 and last_boost > 0.0:
		_on_boost_emptied()
	elif boost_empty and current >= BOOST_RESTART:
		_on_boost_recovered()
	last_boost = current

func _set_layout(mode: Global.Mode, instant: bool) -> void:
	var boost_y := 25.0 if mode == Global.Mode.FLY else 150.0
	var dash_y := 150.0 if mode == Global.Mode.FLY else 25.0
	
	if layout_tween and layout_tween.is_valid():
		layout_tween.kill()
	
	if instant:
		boost_bar.position.y = boost_y
		dash_bar.position.y = dash_y
		return
	
	layout_tween = create_tween().set_parallel()
	layout_tween.tween_property(boost_bar, "position:y", boost_y, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	layout_tween.tween_property(dash_bar, "position:y", dash_y, 1.0)

func _process(delta: float) -> void:
	boost_bar.value = lerpf(boost_bar.value, target_value, 1.0 - exp(-15.0 * delta))
	if boost_empty:
		var t := Time.get_ticks_msec() / 1000.0
		boost_bar.modulate = Color.WHITE.lerp(EMPTY_COLOR, 0.65 + 0.35 * sin(t * 10.0))
	else:
		boost_bar.modulate = boost_bar.modulate.lerp(Color.WHITE, 1.0 - exp(-8.0 * delta))
	
	dash_bar.max_value = Global.max_dashes
	dash_display = lerpf(dash_display, float(Global.dashes), 1.0 - exp(-12.0 * delta))
	dash_bar.value = dash_display
	
	if Global.mode != last_mode:
		last_mode = Global.mode
		_set_layout(Global.mode, false)

func _on_boost_emptied() -> void:
	Sfx.play("boost_empty")
	boost_empty = true
	if boost_fx_tween and boost_fx_tween.is_valid() and boost_fx_tween.is_running():
		boost_fx_tween.kill()
	else:
		boost_base_x = boost_bar.position.x
	
	var strength := 1.0 * Settings.screen_shake
	boost_fx_tween = create_tween()
	for i in 6:
		var dir := 1.0 if i % 2 == 0 else -1.0
		boost_fx_tween.tween_property(boost_bar, "position:x", boost_base_x + dir * strength * (1.0 - float(i) / 6.0), 0.035)
	boost_fx_tween.tween_property(boost_bar, "position:x", boost_base_x, 0.035)

func _on_boost_recovered() -> void:
	Sfx.play("boost_ready")
	boost_empty = false
	boost_bar.pivot_offset = boost_bar.size * 0.5
	var t := create_tween()
	t.tween_property(boost_bar, "scale", Vector2(1.06, 1.25), 0.08)
	t.tween_property(boost_bar, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
