extends CanvasLayer

signal stage_changed(stage_id: String)

@export var level_path: NodePath = ^".."
@export var complete_sound: AudioStream
@export var stage_sound: AudioStream

const STAGES = [
	{
		"id": "walk",
		"objective": "Explore the path ahead",
		"prompts": [{"actions": ["ui_left", "ui_right"], "label": "Walk"}],
		"done_on_trigger": "ditch",
	},
	{
		"id": "meet_crow",
		"objective": "Talk to the Wise Crow",
		"prompts": [],
		"talk_to": "npc2",
		"done_on_dialogue": "npc2",
	},
	{
		"id": "climb",
		"objective": "Climb out of the ditch",
		"prompts": [{"actions": ["ui_accept"], "label": "Jump / Wall jump"}],
		"done_on_trigger": "ditch_exit",
	},
	{
		"id": "find_crow",
		"objective": "Find the Wise Crow",
		"prompts": [{"actions": ["ui_left", "ui_right"], "label": "Walk"}],
		"talk_to": "npc22",
		"done_on_dialogue": "npc22",
	},
	{
		"id": "glide",
		"objective": "Glide across the gap",
		"prompts": [{"actions": ["ui_accept"], "label": "Hold in the air to glide"}],
		"done_on_trigger": "gap_crossed",
	},
	{
		"id": "crow_again",
		"objective": "Talk to the Wise Crow again",
		"prompts": [],
		"talk_to": "npc23",
		"done_on_dialogue": "npc23",
	},
	{
		"id": "continue",
		"objective": "Keep going",
		"prompts": [],
	},
]

const CARD_MARGIN = Vector2(48.0, 48.0)
const CARD_HIDDEN_X = -900.0
const PROMPT_BOTTOM_MARGIN = 56
const ICON_SIZE = 48.0
const COMPLETE_HOLD = 0.9
const ACCENT = Color(0.45, 0.72, 1.0)
const DONE_COLOR = Color(0.45, 0.95, 0.6)
const TEXT = Color(0.95, 0.97, 1.0)
const TEXT_DIM = Color(0.7, 0.76, 0.86)

var level: Node
var stage_index := -1
var completing := false
var fired_triggers: Dictionary = {}
var talk_npc: Node
var watched_dialogue: Node
var prompt_key := ""

var root: Control
var objective_card: PanelContainer
var card_style: StyleBoxFlat
var caption_label: Label
var objective_label: Label
var prompt_panel: PanelContainer
var prompt_row: HBoxContainer
var objective_tween: Tween
var prompt_tween: Tween
var audio := AudioStreamPlayer.new()


func _ready() -> void:
	layer = 20
	add_to_group("tutorial_guide")
	level = get_node_or_null(level_path)
	if level == null:
		push_error("TutorialGuide: Level Path doesn't point to a node, so NPCs can't be found.")
	add_child(audio)
	_build_ui()
	_set_stage(0)


func _process(_delta: float) -> void:
	if stage_index < 0 or stage_index >= STAGES.size():
		return
	var key := "stage"
	var prompts: Array = STAGES[stage_index]["prompts"]
	if _any_dialogue_active():
		key = "chat"
		prompts = [{"actions": ["chat"], "label": "Continue"}]
	elif _near_talk_target():
		key = "talk"
		prompts = [{"actions": ["augment"], "label": "Talk"}]
	key += str(stage_index)
	if key != prompt_key:
		prompt_key = key
		_show_prompts(prompts)


func on_trigger(trigger_id: String) -> void:
	fired_triggers[trigger_id] = true
	_check_trigger()


func current_stage_id() -> String:
	if stage_index < 0 or stage_index >= STAGES.size():
		return ""
	return STAGES[stage_index]["id"]


func _check_trigger() -> void:
	if completing or stage_index < 0 or stage_index >= STAGES.size():
		return
	var stage: Dictionary = STAGES[stage_index]
	if stage.has("done_on_trigger") and fired_triggers.has(stage["done_on_trigger"]):
		_complete_stage()


func _set_stage(index: int) -> void:
	_stop_watching_dialogue()
	stage_index = index
	prompt_key = ""
	talk_npc = null
	if index >= STAGES.size():
		return

	var stage: Dictionary = STAGES[index]
	_show_objective(stage["objective"])
	if stage.has("talk_to"):
		talk_npc = _find_npc(stage["talk_to"])
	if stage.has("done_on_dialogue"):
		var ui := _dialogue_ui_of(_find_npc(stage["done_on_dialogue"]))
		if ui:
			ui.connect("dialogue_finished", _on_watched_dialogue_finished)
			watched_dialogue = ui
	if index > 0 and stage_sound:
		_play(stage_sound)
	stage_changed.emit(stage["id"])
	_check_trigger.call_deferred()


func _complete_stage() -> void:
	if completing:
		return
	completing = true
	_stop_watching_dialogue()
	_flash_complete()
	if complete_sound:
		_play(complete_sound)
	var t := create_tween()
	t.tween_interval(COMPLETE_HOLD)
	t.tween_callback(_advance_stage)


func _advance_stage() -> void:
	completing = false
	_set_stage(stage_index + 1)


func _on_watched_dialogue_finished() -> void:
	_complete_stage.call_deferred()


func _stop_watching_dialogue() -> void:
	if watched_dialogue and is_instance_valid(watched_dialogue) and watched_dialogue.is_connected("dialogue_finished", _on_watched_dialogue_finished):
		watched_dialogue.disconnect("dialogue_finished", _on_watched_dialogue_finished)
	watched_dialogue = null


func _find_npc(npc_name: String) -> Node:
	if level == null:
		return null
	var npc := level.get_node_or_null(npc_name)
	if npc == null:
		push_error("TutorialGuide: no node named '%s' in the tutorial scene." % npc_name)
	return npc


func _dialogue_ui_of(npc: Node) -> Node:
	if npc == null:
		return null
	for child in npc.get_children():
		if child.has_signal("dialogue_finished"):
			return child
	push_error("TutorialGuide: '%s' has no dialogue UI child with a dialogue_finished signal." % npc.name)
	return null


func _near_talk_target() -> bool:
	if talk_npc == null or not is_instance_valid(talk_npc):
		return false
	return bool(talk_npc.get("player_is_in_chat_zone")) and not bool(talk_npc.get("is_chatting"))


func _any_dialogue_active() -> bool:
	for ui in get_tree().get_nodes_in_group("dialogue_ui"):
		if bool(ui.get("d_active")):
			return true
	return false


func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.build()
	add_child(root)

	card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.05, 0.08, 0.14, 0.72)
	card_style.set_corner_radius_all(14)
	card_style.border_width_left = 6
	card_style.border_color = ACCENT
	card_style.content_margin_left = 28
	card_style.content_margin_right = 28
	card_style.content_margin_top = 16
	card_style.content_margin_bottom = 18

	objective_card = PanelContainer.new()
	objective_card.add_theme_stylebox_override("panel", card_style)
	objective_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_card.position = Vector2(CARD_HIDDEN_X, CARD_MARGIN.y)
	objective_card.modulate.a = 0.0
	root.add_child(objective_card)

	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 4)
	objective_card.add_child(card_box)

	caption_label = _make_label("OBJECTIVE", 18, ACCENT)
	card_box.add_child(caption_label)
	objective_label = _make_label("", 30, TEXT)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.custom_minimum_size.x = 380.0
	card_box.add_child(objective_label)

	var prompt_style := StyleBoxFlat.new()
	prompt_style.bg_color = Color(0.05, 0.08, 0.14, 0.55)
	prompt_style.set_corner_radius_all(32)
	prompt_style.content_margin_left = 28
	prompt_style.content_margin_right = 28
	prompt_style.content_margin_top = 12
	prompt_style.content_margin_bottom = 12

	prompt_panel = PanelContainer.new()
	prompt_panel.add_theme_stylebox_override("panel", prompt_style)
	prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_panel.visible = false
	root.add_child(prompt_panel)

	prompt_row = HBoxContainer.new()
	prompt_row.add_theme_constant_override("separation", 36)
	prompt_row.alignment = BoxContainer.ALIGNMENT_CENTER
	prompt_panel.add_child(prompt_row)
	_recenter_prompts()


func _show_objective(text: String) -> void:
	if objective_tween and objective_tween.is_valid():
		objective_tween.kill()
	objective_tween = create_tween()
	if objective_card.modulate.a > 0.01:
		objective_tween.tween_property(objective_card, "position:x", CARD_HIDDEN_X, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		objective_tween.parallel().tween_property(objective_card, "modulate:a", 0.0, 0.3)
	objective_tween.tween_callback(_apply_objective.bind(text))
	objective_tween.tween_property(objective_card, "position:x", CARD_MARGIN.x, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	objective_tween.parallel().tween_property(objective_card, "modulate:a", 1.0, 0.3)


func _apply_objective(text: String) -> void:
	objective_label.text = text
	objective_label.add_theme_color_override("font_color", TEXT)
	caption_label.text = "OBJECTIVE"
	caption_label.add_theme_color_override("font_color", ACCENT)
	card_style.border_color = ACCENT
	objective_card.position.x = CARD_HIDDEN_X
	objective_card.size = Vector2.ZERO


func _flash_complete() -> void:
	caption_label.text = "COMPLETE"
	caption_label.add_theme_color_override("font_color", DONE_COLOR)
	objective_label.add_theme_color_override("font_color", TEXT.lerp(DONE_COLOR, 0.5))
	card_style.border_color = DONE_COLOR
	objective_card.pivot_offset = objective_card.size * 0.5
	var t := create_tween()
	t.tween_property(objective_card, "scale", Vector2.ONE * 1.06, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(objective_card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_prompts(prompts: Array) -> void:
	if prompt_tween and prompt_tween.is_valid():
		prompt_tween.kill()
	prompt_tween = create_tween()
	if prompt_panel.visible:
		prompt_tween.tween_property(prompt_panel, "modulate:a", 0.0, 0.12)
	prompt_tween.tween_callback(_rebuild_prompts.bind(prompts))
	if not prompts.is_empty():
		prompt_tween.tween_property(prompt_panel, "modulate:a", 1.0, 0.2)


func _rebuild_prompts(prompts: Array) -> void:
	for child in prompt_row.get_children():
		prompt_row.remove_child(child)
		child.queue_free()
	for prompt in prompts:
		prompt_row.add_child(_make_prompt(prompt))
	prompt_panel.visible = not prompts.is_empty()
	prompt_panel.modulate.a = 0.0
	_recenter_prompts.call_deferred()


func _recenter_prompts() -> void:
	prompt_panel.size = Vector2.ZERO
	prompt_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, PROMPT_BOTTOM_MARGIN)
	prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _make_prompt(prompt: Dictionary) -> HBoxContainer:
	var item := HBoxContainer.new()
	item.add_theme_constant_override("separation", 8)
	item.alignment = BoxContainer.ALIGNMENT_CENTER

	var per_action: Array = []
	var slots := 0
	for action in prompt["actions"]:
		var icons := InputIcons.icons_for(action)
		per_action.append(icons)
		slots = maxi(slots, icons.size())

	for slot in slots:
		if slot > 0:
			item.add_child(_make_label("/", 24, TEXT_DIM))
		for icons in per_action:
			if slot < icons.size():
				item.add_child(_make_icon(icons[slot]))

	if slots > 0:
		var gap := Control.new()
		gap.custom_minimum_size.x = 4.0
		item.add_child(gap)
	item.add_child(_make_label(prompt["label"], 26, TEXT))
	return item


func _make_icon(tex: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.45))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _play(stream: AudioStream) -> void:
	audio.stream = stream
	audio.play()
