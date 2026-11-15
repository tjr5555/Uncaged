extends Node

const KENNEY = "res://audio/kenney_interface-sounds/Audio/"
const POOL_SIZE = 16
const BUS = "SFX"
const SOFT_BUS = "SfxSoft"
const MASTER_DB = -4.0          #turns every sound up or down at once
const SOFTEN_CUTOFF_HZ = 6000.0 #lower = softer/duller, higher = brighter

#every sound in the game. files: Kenney names (no .ogg) or full res:// paths
#db: volume, base_pitch: fixed pitch, pitch: random variation (+-), cooldown: min seconds between plays
const SOUNDS = {
	#menus
	"ui_hover": {"files": ["drop_001"], "db": -20.0, "pitch": 0.04, "cooldown": 0.05},
	"ui_click": {"files": ["res://audio/denielcz-immersivecontrol-button-click-sound-463065.mp3"], "db": -14.0, "pitch": 0.03},
	"ui_back": {"files": ["click_004"], "db": -14.0, "pitch": 0.03},
	"ui_confirm": {"files": ["confirmation_004"], "db": -12.0},
	"ui_warning": {"files": ["error_005"], "db": -12.0},
	"ui_open": {"files": ["bong_001"], "db": -12.0},
	"ui_tab": {"files": ["switch_002"], "db": -14.0, "pitch": 0.03},
	"ui_toggle_on": {"files": ["toggle_002"], "db": -16.0},
	"ui_toggle_off": {"files": ["toggle_001"], "db": -16.0},
	"ui_slider": {"files": ["tick_002"], "db": -22.0, "pitch": 0.0, "cooldown": 0.07},
	"ui_reset": {"files": ["click_003"], "db": -12.0},
	"pause_open": {"files": ["bong_001"], "db": -12.0},
	"pause_close": {"files": ["bong_001"], "db": -14.0, "base_pitch": 0.85},
	#shop
	"shop_open": {"files": ["open_002"], "db": -14.0, "base_pitch": 0.9},
	"shop_close": {"files": ["minimize_002"], "db": -16.0, "base_pitch": 0.9},
	"shop_buy": {"files": ["confirmation_002"], "db": -10.0},
	"shop_maxed": {"files": ["confirmation_003"], "db": -8.0},
	"shop_deny": {"files": ["error_007"], "db": -10.0},
	#coins and combos
	"coin": {"files": ["glass_002"], "db": -18.0, "pitch": 0.03, "cooldown": 0.035},
	"balloon_rare": {"files": ["drop_004"], "db": -12.0, "pitch": 0.04},
	"combo_level": {"files": ["confirmation_001"], "db": -10.0, "pitch": 0.0},
	"combo_bonus": {"files": ["confirmation_004"], "db": -10.0},
	#movement
	"jump": {"files": ["drop_003"], "db": -18.0, "base_pitch": 1.2, "pitch": 0.05},
	"wall_jump": {"files": ["drop_003"], "db": -16.0, "base_pitch": 1.45, "pitch": 0.05},
	"dash": {"files": ["maximize_003"], "db": -12.0, "pitch": 0.05},
	"fly_on": {"files": ["maximize_003"], "db": -16.0, "base_pitch": 0.85},
	"fly_off": {"files": ["maximize_003"], "db": -18.0, "base_pitch": 0.65},
	"boost_empty": {"files": ["error_004"], "db": -14.0},
	"boost_ready": {"files": ["drop_003"], "db": -14.0},
	"wall_bounce": {"files": ["glass_006"], "db": -10.0, "pitch": 0.08, "cooldown": 1.0},
	#portals and transitions
	"portal_enter": {"files": ["maximize_002"], "db": -10.0, "base_pitch": 0.9},
	"portal_exit": {"files": ["maximize_003"], "db": -12.0},
	"transition": {"files": ["minimize_002"], "db": -20.0, "base_pitch": 0.85},
	#health
	"hurt": {"files": ["back_001"], "db": -10.0, "pitch": 0.06, "cooldown": 0.6},
	"hurt_fall": {"files": ["back_002"], "db": -10.0, "pitch": 0.05},
	"gas_warning": {"files": ["select_005"], "db": -12.0},
	"gas_tick": {"files": ["glitch_004"], "db": -18.0, "pitch": 0.08},
	"heartbeat": {"files": ["res://audio/fallThud.wav"], "db": -16.0, "base_pitch": 0.6, "pitch": 0.0},
	"faint": {"files": ["error_003"], "db": -8.0},
	"respawn": {"files": ["open_004"], "db": -12.0, "base_pitch": 0.9},
	#dialogue, tutorial and quests
	"dialogue_open": {"files": ["bong_001"], "db": -16.0},
	"dialogue_next": {"files": ["click_002"], "db": -16.0, "pitch": 0.05},
	"objective_done": {"files": ["confirmation_004"], "db": -10.0},
	"objective_new": {"files": ["drop_002"], "db": -14.0},
	"quest_complete": {"files": ["confirmation_003"], "db": -8.0},
	"quest_reward": {"files": ["maximize_003"], "db": -10.0, "base_pitch": 0.8},
}

var _streams := {}
var _last_played := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_soft_bus()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = SOFT_BUS
		add_child(p)
		_players.append(p)
	_load_sounds()
	get_tree().node_added.connect(_hook)
	_hook_existing.call_deferred()
	_connect_game_signals.call_deferred()


func play(sound: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var cfg: Dictionary = SOUNDS.get(sound, {})
	if cfg.is_empty():
		push_error("Sfx: no sound named '%s' in SOUNDS." % sound)
		return
	var streams: Array = _streams.get(sound, [])
	if streams.is_empty():
		return

	var now := Time.get_ticks_msec() / 1000.0
	var cooldown: float = cfg.get("cooldown", 0.0)
	if cooldown > 0.0 and now - float(_last_played.get(sound, -100.0)) < cooldown:
		return
	_last_played[sound] = now

	var p := _free_player()
	var jitter: float = cfg.get("pitch", 0.02)
	var base_pitch: float = cfg.get("base_pitch", 1.0)
	p.stream = streams.pick_random()
	p.pitch_scale = maxf(base_pitch * pitch * (1.0 + randf_range(-jitter, jitter)), 0.05)
	p.volume_db = float(cfg.get("db", 0.0)) + volume_db + MASTER_DB
	p.play()


func _make_soft_bus() -> void:
	if AudioServer.get_bus_index(SOFT_BUS) >= 0:
		return
	var target := BUS
	if AudioServer.get_bus_index(BUS) < 0:
		push_warning("Sfx: no audio bus named '%s', so sounds play on Master." % BUS)
		target = "Master"
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, SOFT_BUS)
	AudioServer.set_bus_send(idx, target)
	var filter := AudioEffectLowPassFilter.new()
	filter.cutoff_hz = SOFTEN_CUTOFF_HZ
	AudioServer.add_bus_effect(idx, filter)


func _load_sounds() -> void:
	for sound in SOUNDS:
		var cfg: Dictionary = SOUNDS[sound]
		if not cfg.has("files"):
			push_error("Sfx: sound '%s' has no \"files\" entry." % sound)
			_streams[sound] = []
			continue
		var list: Array = []
		for file in cfg["files"]:
			var path: String = file if String(file).begins_with("res://") else KENNEY + file + ".ogg"
			if ResourceLoader.exists(path):
				var stream: AudioStream = load(path)
				_disable_loop(stream)
				list.append(stream)
			else:
				push_error("Sfx: missing sound file '%s' (used by '%s')." % [path, sound])
		_streams[sound] = list


# sound effects are one-shots, so a stream that is set to loop in its Import tab
# would play forever on its pooled player; force looping off
func _disable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = false


func _free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	_next = (_next + 1) % _players.size()
	return _players[_next]


# ---------- automatic UI sounds ----------

func _hook_existing() -> void:
	for node in get_tree().root.find_children("*", "", true, false):
		_hook(node)


func _hook(node: Node) -> void:
	if node.has_meta("sfx_hooked"):
		return
	if node is BaseButton:
		node.set_meta("sfx_hooked", true)
		var b := node as BaseButton
		b.mouse_entered.connect(_on_button_hovered.bind(b))
		if b is CheckButton or b is CheckBox:
			b.toggled.connect(_on_toggled)
		else:
			b.pressed.connect(_on_button_pressed.bind(b))
	elif node is Slider:
		node.set_meta("sfx_hooked", true)
		(node as Slider).value_changed.connect(_on_slider_changed.bind(node))
	elif node is TabContainer:
		node.set_meta("sfx_hooked", true)
		(node as TabContainer).tab_changed.connect(_on_tab_changed)


func _on_button_hovered(b: BaseButton) -> void:
	if b.disabled or not b.is_visible_in_tree():
		return
	var sound := str(b.get_meta("sfx_hover", "ui_hover"))
	if sound != "":
		play(sound)


func _on_button_pressed(b: BaseButton) -> void:
	var sound := str(b.get_meta("sfx_press", _default_press(b)))
	if sound != "":
		play(sound)


func _default_press(b: BaseButton) -> String:
	var label := String(b.name)
	if b is Button:
		label += " " + (b as Button).text
	label = label.to_lower()
	if "back" in label or "close" in label:
		return "ui_back"
	return "ui_click"


func _on_toggled(pressed: bool) -> void:
	play("ui_toggle_on" if pressed else "ui_toggle_off")

func _on_slider_changed(value: float, slider: Slider) -> void:
	if not slider.is_visible_in_tree():
		return
	var span := slider.max_value - slider.min_value
	var t := (value - slider.min_value) / span if span > 0.0 else 0.0
	var volume := 0.0
	if "music" in String(slider.name).to_lower():
		volume = linear_to_db(maxf(t, 0.001))
	play("ui_slider", lerpf(0.85, 1.35, t), volume)

func _on_tab_changed(_tab: int) -> void:
	play("ui_tab")


# ---------- game events ----------

func _connect_game_signals() -> void:
	Combo.level_up.connect(_on_combo_level_up)
	Combo.combo_ended.connect(_on_combo_ended)
	QuestManager.quest_completed.connect(_on_quest_completed)
	SignalBus.finishquest1.connect(_on_quest_reward)
	SignalBus.finishquest2.connect(_on_quest_reward)


func _on_combo_level_up(level: int, _multiplier: float) -> void:
	play("combo_level", 1.0 + level * 0.07)


func _on_combo_ended(_count: int, bonus: int) -> void:
	if bonus > 0:
		play("combo_bonus")


func _on_quest_completed(_quest_name: String) -> void:
	play("quest_complete")


func _on_quest_reward() -> void:
	play("quest_reward")
