extends ColorRect

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return
	var view := get_viewport_rect().size
	var canvas_xf := get_viewport().get_canvas_transform()
	var center := canvas_xf.affine_inverse() * (view * 0.5)
	mat.set_shader_parameter("camera_pos", center)
	mat.set_shader_parameter("screen_size", view)
