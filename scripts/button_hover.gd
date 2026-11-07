extends Button

@export var hover_scale := 1.06
@export var press_scale := 0.95
@export var hover_tint := Color(1.0, 1.0, 1.0)
@export var tween_time := 0.15

var tween: Tween

func _ready() -> void:
	pivot_offset = size * 0.5
	resized.connect(func(): pivot_offset = size * 0.5)
	mouse_entered.connect(_animate.bind(hover_scale, true))
	mouse_exited.connect(_animate.bind(1.0, false))
	focus_entered.connect(_animate.bind(hover_scale, true))
	focus_exited.connect(_animate.bind(1.0, false))
	button_down.connect(_animate.bind(press_scale, true))
	button_up.connect(_animate.bind(hover_scale, true))

func _animate(target_scale: float, highlighted: bool) -> void:
	if tween and tween.is_valid():
		tween.kill()
	tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE * target_scale, tween_time)
	tween.tween_property(self, "self_modulate", hover_tint if highlighted else Color.WHITE, tween_time)
