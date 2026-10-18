extends Control

signal dialogue_finished

@export_file("*.json") var d_file
@export var audio_stream_player: AudioStreamPlayer

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
	var file = FileAccess.open("res://dialouge/npc1/parrot_dialogue.json", FileAccess.READ)
	var content = JSON.parse_string(file.get_as_text())
	return content


func _input(event):
	if not d_active:
		return

	if event.is_action_pressed("chat"):
		if tween and tween.is_running():
			# Stop the tween, display full text, and stop the sound
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

	$NinePatchRect/Name.text = dialogue[current_dialogue_id]['name']
	animate_text(dialogue[current_dialogue_id]['text'])


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

	#start looping audio at the beginning of the line
	play_sound()

	for letter in text:
		index += 1

		if not (letter in [".", "?", "!", ","] or index == text_length):
			continue

		var duration = (index - last_punct_index) * LETTER_TIME
		
		#continue audio
		tween.tween_callback(play_sound)
		tween.tween_method(_reveal_char, last_punct_index, index, duration)

		#stop audio for punctuation
		tween.tween_callback(stop_sound)
		if letter == ",":
			tween.tween_interval(PUNCTUATION_TIME / 2.0)
		elif letter in [".", "?", "!"]:
			tween.tween_interval(PUNCTUATION_TIME)

		last_punct_index = index

	# Stop audio once text completes naturally
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
