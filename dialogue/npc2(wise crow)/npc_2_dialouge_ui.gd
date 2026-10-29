extends Control

signal dialogue_finished
signal give_quest(quest_id, title, description, target_count)

# Set these per NPC instance (the NPC script forwards them here)
@export_file("*.json") var d_file: String = "res://dialouge/npc2(wise crow)/dialogue files/wiseCrowDialogue.json"
@export var npc_name: String = "wise crow" # speaker name that uses crow_font

@export var audio_stream_player: AudioStreamPlayer

# Add export variables to assign your fonts in the Inspector
@export var crow_font: Font
@export var player_font: Font

# Quest settings (leave gives_quest off for plain tutorial NPCs)
@export var gives_quest: bool = false
@export var quest_id: String = "collect_coins"
@export var quest_title: String = "Coin Collector"
@export var quest_description: String = "Collect coins"
@export var quest_target: int = 500

const LETTER_TIME: float = 0.04
const PUNCTUATION_TIME: float = 0.3

var dialogue = []
var current_dialogue_id = 0
var d_active = false
var tween: Tween


func _ready():
	$NinePatchRect.visible = false
	if gives_quest and not is_connected("give_quest", Callable(QuestManager, "add_quest")):
		connect("give_quest", Callable(QuestManager, "add_quest"))


func start():
	if d_active:
		return
	dialogue = load_dialogue()
	if dialogue.is_empty():
		return
	d_active = true
	$NinePatchRect.visible = true
	current_dialogue_id = -1
	next_script()


func load_dialogue() -> Array:
	if not FileAccess.file_exists(d_file):
		push_error("Dialogue file not found: " + d_file)
		return []

	var file := FileAccess.open(d_file, FileAccess.READ)
	var content = JSON.parse_string(file.get_as_text())
	if content == null:
		push_error("Dialogue JSON failed to parse: " + d_file)
		return []

	# Simplest format: the file is just an array of lines
	if content is Array:
		return content

	# Also accepts an object, e.g. {"first_encounter": [...], "completed_dialogue": [...]}
	if content is Dictionary and not content.is_empty():
		var quest_done: bool = gives_quest and QuestManager.active_quests.has(quest_id) and QuestManager.active_quests[quest_id].get("completed", false)
		if quest_done and content.has("completed_dialogue"):
			return content["completed_dialogue"]
		return content.values()[0]

	push_error("Dialogue file is empty or has an unexpected format: " + d_file)
	return []


func _input(event):
	if not d_active:
		return

	if event.is_action_pressed("chat"):
		if tween and tween.is_running():
			stop_sound()
			tween.kill()
			$NinePatchRect/Chatarea.visible_characters = -1
		else:
			next_script()


func next_script():
	current_dialogue_id += 1
	if current_dialogue_id >= len(dialogue):
		d_active = false
		$NinePatchRect.visible = false
		stop_sound()
		emit_signal("dialogue_finished")
		if gives_quest:
			emit_signal("give_quest", quest_id, quest_title, quest_description, quest_target)
		return

	var current_data = dialogue[current_dialogue_id]
	var speaker_name = current_data['name']

	$NinePatchRect/Name.text = speaker_name

	apply_speaker_font(speaker_name)
	animate_text(current_data['text'])


func apply_speaker_font(speaker_name: String):
	var selected_font: Font = null
	if speaker_name.strip_edges().to_lower() == npc_name.strip_edges().to_lower():
		selected_font = crow_font
	else:
		selected_font = player_font

	_set_font($NinePatchRect/Name, selected_font)
	_set_font($NinePatchRect/Chatarea, selected_font)


func _set_font(node: Control, font: Font) -> void:
	var font_name := "normal_font" if node is RichTextLabel else "font"
	if font:
		node.add_theme_font_override(font_name, font)
	else:
		node.remove_theme_font_override(font_name)


func animate_text(text: String):
	stop_sound()
	if tween:
		tween.kill()

	tween = create_tween()

	var chat_area = $NinePatchRect/Chatarea
	chat_area.text = text
	chat_area.visible_characters = 0

	var index: int = 0
	var last_punct_index: int = 0
	var text_length: int = text.length()

	play_sound()

	for letter in text:
		index += 1

		if not (letter in [".", "?", "!", ","] or index == text_length):
			continue

		var duration = (index - last_punct_index) * LETTER_TIME

		tween.tween_callback(play_sound)
		tween.tween_method(_reveal_char, last_punct_index, index, duration)

		tween.tween_callback(stop_sound)
		if letter == ",":
			tween.tween_interval(PUNCTUATION_TIME / 2.0)
		elif letter in [".", "?", "!"]:
			tween.tween_interval(PUNCTUATION_TIME)

		last_punct_index = index

	tween.tween_callback(stop_sound)


func _reveal_char(v: int):
	var chat_area = $NinePatchRect/Chatarea
	if chat_area.visible_characters == v:
		return

	chat_area.visible_characters = v


func play_sound():
	if audio_stream_player and not audio_stream_player.playing:
		audio_stream_player.play()


func stop_sound():
	if audio_stream_player and audio_stream_player.playing:
		audio_stream_player.stop()
