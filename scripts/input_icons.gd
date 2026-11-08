class_name InputIcons
extends RefCounted

const BASE_PATH = "res://assets/kenney_input-prompts_1.5/KeyboardMouse/Vector/"
const HIDDEN_KEYS = ["enter", "kp enter"]
const KEY_NAMES = {
	"left": "arrow_left",
	"right": "arrow_right",
	"up": "arrow_up",
	"down": "arrow_down",
	"pageup": "page_up",
	"pagedown": "page_down",
	"equal": "equals",
	"slash": "slash_forward",
	"backslash": "slash_back",
	"quoteleft": "tilde",
	"bracketleft": "bracket_open",
	"bracketright": "bracket_close",
}
const MOUSE_NAMES = {
	MOUSE_BUTTON_LEFT: "mouse_left",
	MOUSE_BUTTON_RIGHT: "mouse_right",
	MOUSE_BUTTON_MIDDLE:  "mouse_scroll",
	MOUSE_BUTTON_WHEEL_UP: "mouse_scroll_up",
	MOUSE_BUTTON_WHEEL_DOWN: "mouse_scroll_down",
}

static var _cache: Dictionary = {}

static func icons_for(action: StringName, max_icons: int = 2) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	if not InputMap.has_action(action):
		push_error("InputIcons: no input action named '%s'" % action)
		return result
	for event in InputMap.action_get_events(action):
		var path := _path_for(event)
		if path == "":
			continue
		var tex := _load(path)
		if tex and not result.has(tex):
			result.append(tex)
		if result.size() >= max_icons:
			break
	return result

static func _path_for(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		var key_name := OS.get_keycode_string(code).to_lower()
		if key_name == "" or HIDDEN_KEYS.has(key_name):
			return ""
		key_name = KEY_NAMES.get(key_name, key_name)
		return BASE_PATH + "keyboard_%s_outline.svg" % key_name
	if event is InputEventMouseButton:
		var button := (event as InputEventMouseButton).button_index
		if MOUSE_NAMES.has(button):
			return BASE_PATH + "%s_outline.svg" % MOUSE_NAMES[button]
	return ""

static func _load(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	else:
		push_warning("InputIcons: missing icon file!: " + path)
	_cache[path] = tex
	return tex
