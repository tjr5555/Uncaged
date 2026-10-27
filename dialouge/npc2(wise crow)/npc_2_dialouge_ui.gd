extends Control

signal dialogue_finished

@export_file("*.json") var d_file
@export var audio_stream_player: AudioStreamPlayer

# Add export variables to assign your fonts in the Inspector
@export var wisecrow_font: Font
@export var player_font: Font

const LETTER_TIME: float = 0.04
const PUNCTUATION_TIME: float = 0.3

var dialogue = []
var current_dialogue_id = 0
var d_active = false
var tween: Tween


func _ready():
	$NinePatchRect.visible = false


func start():
	if d_active:
		return
	d_active = true
	$NinePatchRect.visible = true
	dialogue = load_dialogue()
	current_dialogue_id = -1
	next_script()


func load_dialogue():
	if d_file == "":
		push_error("Dialogue file path is not set in the Inspector!")
		return []

	var file = FileAccess.open(d_file, FileAccess.READ)
	if file == null:
		push_error("Failed to open dialogue file: " + d_file)
		return []

	var content = JSON.parse_string(file.get_as_text())
	
	# If the JSON is structured as an array
	if content is Array:
		return content

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
		return

	var current_data = dialogue[current_dialogue_id]
	var speaker_name = current_data['name']

	$NinePatchRect/Name.text = speaker_name

	apply_speaker_font(speaker_name)
	animate_text(current_data['text'])


func apply_speaker_font(speaker_name: String):
	var name_label = $NinePatchRect/Name
	var chat_area = $NinePatchRect/Chatarea

	var selected_font: Font = null
	if speaker_name.strip_edges().to_lower() == "Wise Crow":
		selected_font = wisecrow_font
	else:
		selected_font = player_font

	if selected_font:
		name_label.add_theme_font_override("normal_font", selected_font)
		chat_area.add_theme_font_override("normal_font", selected_font)

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
