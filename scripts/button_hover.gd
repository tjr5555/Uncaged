extends Button

@export var hover_scale := 1.06
@export var press_scale := 0.95

var tween: Tween

func _ready() -> void:
	pivot_offset = size * 0.5
	mouse_entered.connect(_animate.bind(hover_scale))
	mouse_exited.connect(_animate.bind(1.0))
	focus_entered.connect(_animate.bind(hover_scale))
	focus_exited.connect(_animate.bind(1.0))
	button_down.connect(_animate.bind(press_scale))
	button_up.connect(_animate.bind(hover_scale))

func _animate(target: float) -> void:
	if tween and tween.is_valid():
		tween.kill()
	tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE * target, 0.15)
