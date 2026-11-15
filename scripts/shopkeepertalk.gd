extends Control

signal dialogue_finished
signal line_shown(line_data)   #fires for every line, so you can react to extra keys like "hush_money"

@export_file("*.json") var d_file: String = "res://dialogue/shop/shopDialogue.json"
@export var npc_name: String = "Shop Keeper"   #speaker name that uses npc_font (spaces/case are ignored)

@export var auto_start: bool = true            #start talking as soon as the scene loads (turn off if something else calls start())
@export var lock_choices_until_text_done: bool = true   # buttons are visible the whole time, but can only be clicked after the last line finishes typing
@export var audio_stream_player: AudioStreamPlayer      #only used as a template (stream, bus, volume); blips play on a private player made in code
@export var npc_sprite: AnimatedSprite2D       #the shopkeeper's AnimatedSprite2D (drag it in)
@export var max_blip_length: float = 0.1       #a letter blip never plays longer than this (seconds)

#the speaker name uses the node called "Name" (Label or RichTextLabel). If there is none, the name is put in front of the text ("You: Cool!")
@export var show_name_in_text: bool = true

#fonts and sizes (a size of 0 keeps the theme's default size)
@export var npc_font: Font
@export_range(0, 200) var npc_font_size: int = 0
@export var player_font: Font
@export_range(0, 200) var player_font_size: int = 0

@export_group("Dialogue pitches")
@export var question_inflection_pitch: float = 1.4
@export var ellipsies_sentence_pitch: float = 0.9
@export var normal_sentence_pitch: float = 1.0
@export var exclamation_sentence_pitch: float = 1.5
@export_group("")

const LETTER_TIME: float = 0.04
const PUNCTUATION_TIME: float = 0.3
const BLIP_VOICES: int = 4   # blips rotate through this many players, so each letter gets a fresh one

var dialogues: Dictionary = {}
var current_node: Dictionary = {}
var lines: Array = []
var choices: Array = []
var line_index: int = -1
var d_active: bool = false
var waiting_for_choice: bool = false
var tween: Tween
var _blip_pool: Array[AudioStreamPlayer] = []
var _blip_next: int = 0
var _blip_timer: Timer

@onready var chat_area = $Chatarea
@onready var name_label: Control = get_node_or_null("Name")
@onready var start_button: Button = get_node_or_null("Button")
@onready var choice_buttons: Array = [
	$choice1,
	$choice2,
]


func _ready():
	# hard cap on blip length, so a blip can never run on
	_blip_timer = Timer.new()
	_blip_timer.one_shot = true
	_blip_timer.timeout.connect(stop_sound)
	add_child(_blip_timer)
	_setup_blip_player()

	add_to_group("dialogue_ui")
	_set_ui_visible(false)
	for i in choice_buttons.size():
		choice_buttons[i].pressed.connect(_on_choice_pressed.bind(i))
	#the "Button" node starts the dialogue when pressed (and hides while talking)
	if start_button:
		start_button.pressed.connect(start)
	if auto_start:
		start.call_deferred()


func _exit_tree() -> void:
	stop_sound()


# Blips play on a small pool of private, non-looping players that this script owns.
# The exported player is only read for its stream/bus/volume and is silenced, so
# Autoplay, Max Polyphony or sharing that node with other scripts can't cause stacking.
func _setup_blip_player() -> void:
	if not audio_stream_player:
		push_warning("Dialogue: no audio_stream_player assigned, so there will be no letter sounds.")
		return
	var s: AudioStream = audio_stream_player.stream
	if s:
		if s is AudioStreamWAV:
			(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
		elif s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = false
		elif s is AudioStreamMP3:
			(s as AudioStreamMP3).loop = false
	for i in BLIP_VOICES:
		var p := AudioStreamPlayer.new()
		p.stream = s
		p.bus = audio_stream_player.bus
		p.volume_db = audio_stream_player.volume_db
		p.autoplay = false
		add_child(p)
		_blip_pool.append(p)
	audio_stream_player.autoplay = false
	audio_stream_player.stop()


#only the text (and name) show/hide, so the sprite and the rest of the shop stay visible
func _set_ui_visible(v: bool) -> void:
	chat_area.visible = v
	if name_label:
		name_label.visible = v
	if start_button:
		start_button.visible = not v
	if not v:
		_hide_choices()


func _hide_choices() -> void:
	for b in choice_buttons:
		b.visible = false


func start():
	if d_active:
		return
	var data := load_dialogue()
	if data.is_empty():
		return
	dialogues = data["dialogues"]
	var start_id: String = data.get("start", dialogues.keys()[0])
	d_active = true
	Sfx.play("dialogue_open")
	_set_ui_visible(true)
	go_to_dialogue(start_id)


func load_dialogue() -> Dictionary:
	if not FileAccess.file_exists(d_file):
		push_error("Dialogue file not found: " + d_file)
		return {}
	var file := FileAccess.open(d_file, FileAccess.READ)
	var content = JSON.parse_string(file.get_as_text())
	if content == null:
		push_error("Dialogue JSON failed to parse (check for trailing commas!): " + d_file)
		return {}
	if not (content is Dictionary) or not content.has("dialogues"):
		push_error("Dialogue file needs a top-level \"dialogues\" object: " + d_file)
		return {}
	return content


func go_to_dialogue(id: String):
	if not dialogues.has(id):
		push_error("Dialogue id not found: " + id)
		end_dialogue()
		return
	current_node = dialogues[id]
	lines = current_node.get("lines", [])
	choices = current_node.get("choices", [])
	line_index = -1
	waiting_for_choice = false
	_setup_choices()
	next_script()


#buttons appear together with the text and stay visible; they only get hidden when the dialogue ends (or this dialogue has no choices)
func _setup_choices() -> void:
	for i in choice_buttons.size():
		var has_choice: bool = i < choices.size()
		choice_buttons[i].visible = has_choice
		choice_buttons[i].disabled = lock_choices_until_text_done
		if has_choice:
			choice_buttons[i].text = choices[i].get("text", "...")
			choice_buttons[i].move_to_front()


func _input(event):
	if not d_active or waiting_for_choice:
		return
	if event.is_action_pressed("chat"):
		if tween and tween.is_running():
			#skip the typing effect
			stop_sound()
			tween.kill()
			chat_area.visible_characters = -1
			_on_line_typed()
		elif not (_is_last_line() and not choices.is_empty()):
			Sfx.play("dialogue_next")
			next_script()


func _is_last_line() -> bool:
	return line_index >= lines.size() - 1


func next_script():
	line_index += 1
	if line_index >= lines.size():
		_finish_lines()
		return

	var line: Dictionary = lines[line_index]
	var speaker_name: String = line.get("name", "")
	change_sprite(line.get("sprite", line.get("anim", "")))
	apply_speaker_font(speaker_name)

	var text: String = line.get("text", "")
	if name_label:
		name_label.text = speaker_name
	elif show_name_in_text and speaker_name != "":
		text = speaker_name + ": " + text
	animate_text(text)
	line_shown.emit(line)


#called when the lines of the current dialogue are used up and there are no choices
func _finish_lines():
	if not choices.is_empty():
		_show_choices()
		return
	var next_id = current_node.get("next", null)
	if next_id != null and dialogues.has(str(next_id)):
		go_to_dialogue(str(next_id))
	else:
		end_dialogue()


#called when the current line finished typing (naturally or skipped)
func _on_line_typed():
	stop_sound()
	if _is_last_line() and not choices.is_empty():
		_show_choices()


func _show_choices():
	if waiting_for_choice:
		return
	waiting_for_choice = true
	for i in choices.size():
		choice_buttons[i].disabled = false
	choice_buttons[0].grab_focus()   # lets keyboard / controller pick too


func _on_choice_pressed(index: int):
	if index >= choices.size() or (lock_choices_until_text_done and not waiting_for_choice):
		return
	var next_id = choices[index].get("next", null)
	waiting_for_choice = false
	if next_id != null and dialogues.has(str(next_id)):
		go_to_dialogue(str(next_id))
	else:
		end_dialogue()


func end_dialogue():
	d_active = false
	waiting_for_choice = false
	if tween:
		tween.kill()
	stop_sound()
	_set_ui_visible(false)
	dialogue_finished.emit()


func close():
	if not d_active:
		return
	end_dialogue()


func _normalize(s: String) -> String:
	return s.replace(" ", "").to_lower()


func apply_speaker_font(speaker_name: String):
	var is_npc := _normalize(speaker_name) == _normalize(npc_name)
	var font: Font = npc_font if is_npc else player_font
	var text_size: int = npc_font_size if is_npc else player_font_size
	_set_font(chat_area, font, text_size)
	if name_label:
		_set_font(name_label, font, text_size)


func _set_font(node: Control, font: Font, size: int) -> void:
	var is_rich := node is RichTextLabel
	var font_name := "normal_font" if is_rich else "font"
	var size_name := "normal_font_size" if is_rich else "font_size"
	if font:
		node.add_theme_font_override(font_name, font)
	else:
		node.remove_theme_font_override(font_name)
	if size > 0:
		node.add_theme_font_size_override(size_name, size)
	else:
		node.remove_theme_font_size_override(size_name)


func animate_text(text: String):
	stop_sound()
	if tween:
		tween.kill()

	chat_area.text = text
	chat_area.visible_characters = 0
	if chat_area is RichTextLabel:
		chat_area.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING

	if text.is_empty():
		chat_area.visible_characters = -1
		_on_line_typed()
		return

	tween = create_tween()
	var pitches := sentence_inflection(text)   # one pitch per character
	var text_length := text.length()

	for i in text_length:
		var letter := text[i]
		tween.tween_callback(_type_letter.bind(i + 1, pitches[i], letter))

		var wait := LETTER_TIME
		var next_is_punct := i + 1 < text_length and text[i + 1] in [".", "?", "!"]
		if letter == ",":
			wait += PUNCTUATION_TIME / 2.0
		elif letter in [".", "?", "!"] and not next_is_punct:
			wait += PUNCTUATION_TIME   # pause only after the last mark of "..." or "?!"
		tween.tween_interval(wait)
		if wait > LETTER_TIME:
			tween.tween_callback(stop_sound)

	tween.finished.connect(_on_line_typed)


# reveals one more letter and plays a blip for it (no blip for spaces/punctuation)
func _type_letter(count: int, pitch: float, letter: String) -> void:
	chat_area.visible_characters = count
	if letter.strip_edges() == "" or letter in [".", "?", "!", ","]:
		return
	play_blip(pitch)


# restarts the sound every letter, so each one gets its own blip
func play_blip(pitch: float = 1.0) -> void:
	if _blip_pool.is_empty() or not d_active:
		return
	_blip_next = (_blip_next + 1) % _blip_pool.size()
	var p := _blip_pool[_blip_next]
	p.pitch_scale = pitch * randf_range(0.97, 1.03)
	p.play()
	_blip_timer.start(max_blip_length)


func stop_sound() -> void:
	if _blip_timer:
		_blip_timer.stop()
	for p in _blip_pool:
		p.stop()


func change_sprite(anim_name: String):
	if anim_name == "" or not npc_sprite:
		return
	if npc_sprite.sprite_frames.has_animation(anim_name):
		npc_sprite.play(anim_name)


#returns one pitch per character of `text`, so the tween loop can just look it up.
func sentence_inflection(text: String) -> PackedFloat32Array:
	var pitches := PackedFloat32Array()
	pitches.resize(text.length())
	pitches.fill(normal_sentence_pitch)   #anything not in a finished sentence stays normal

	var start := 0
	var i := 0
	while i < text.length():
		if text[i] in [".", "?", "!"]:
			var end := i
			while end + 1 < text.length() and text[end + 1] in [".", "?", "!"]:
				end += 1

			var sentence := text.substr(start, end - start + 1)
			var target := get_ending_pitch(sentence)
			var glide := not sentence.ends_with("!")   # exclamations stay flat

			var length := end - start + 1
			for k in length:
				var progress := float(k + 1) / length
				pitches[start + k] = lerpf(normal_sentence_pitch, target, progress) if glide else target

			start = end + 1
			i = end + 1
		else:
			i += 1
	return pitches


func get_ending_pitch(sentence: String) -> float:
	var t := sentence.strip_edges()
	if t.ends_with("..."):
		return ellipsies_sentence_pitch
	if t.ends_with("?"):
		return question_inflection_pitch
	if t.ends_with("!"):
		return exclamation_sentence_pitch
	return normal_sentence_pitch


func _on_button_2_pressed() -> void:
	print("return pressed")
	end_dialogue()
