extends CanvasLayer

const FOG_SHADER = preload("res://shaders/fog.gdshader")

@export var fog_in_time := 0.9
@export var fog_out_time := 1.6
@export var min_hold := 0.4
@export var max_hold := 4.0
@export var fog_color := Color(0.93, 0.95, 1.0)

var fog: ColorRect
var fog_material: ShaderMaterial
var busy := false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	fog = ColorRect.new()
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog_material = ShaderMaterial.new()
	fog_material.shader = FOG_SHADER
	fog_material.set_shader_parameter("coverage", 0.0)
	fog_material.set_shader_parameter("fog_color", fog_color)
	fog_material.set_shader_parameter("shade_color", fog_color.darkened(0.2))
	fog.material = fog_material
	fog.visible = false
	add_child(fog)

func preload_scene(path: String) -> void:
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(path)

func change_scene(path: String) -> void:
	if busy:
		return
	busy = true
	fog.mouse_filter = Control.MOUSE_FILTER_STOP
	preload_scene(path)
	
	await _fog_to(1.0, fog_in_time).finished
	var packed: PackedScene = await _finish_loading(path)
	if packed != null:
		get_tree().change_scene_to_packed(packed)
	await _wait_for_world()
	await _fog_to(0.0, fog_out_time).finished
	
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busy = false

func _finish_loading(path: String) -> PackedScene:
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
		return ResourceLoader.load_threaded_get(path) as PackedScene
	return load(path) as PackedScene

func _wait_for_world() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	
	var manager = get_tree().get_first_node_in_group("world_manager")
	if manager != null and manager.has_method("set_world_burst"):
		manager.set_world_burst(true)
	
	var waited := 0.0
	while waited < max_hold:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if waited < min_hold:
			continue
		if manager == null or not manager.has_method("is_world_ready") or manager.is_world_ready():
			break
	
	if manager != null and manager.has_method("set_world_burst"):
		manager.set_world_burst(false)

func _fog_to(target: float, time: float) -> Tween:
	fog.visible = true
	var current := float(fog_material.get_shader_parameter("coverage"))
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_set_coverage, current, target, time)
	if target <= 0.0:
		tween.tween_callback(func(): fog.visible = false)
	return tween

func _set_coverage(value: float) -> void:
	fog_material.set_shader_parameter("coverage", value)
