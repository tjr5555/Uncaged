extends CanvasLayer

@onready var boost_bar: ProgressBar = $MarginContainer/BoostBar
@onready var quest_labels = [$questArea/quest1, $questArea/quest2, $questArea/quest3]

var target_value: float = 100.0

func _ready() -> void:
	QuestManager.connect("quests_updated", Callable(self, "_on_quests_updated"))
	clear_quests()

func set_boost(current: float, maximum: float) -> void:
	boost_bar.max_value = maximum
	target_value = current

func _process(delta: float) -> void:
	boost_bar.value = lerpf(boost_bar.value, target_value, 1.0 - exp(-15.0 * delta))
	$coinsLabel.text = "Coins: " + str(int(Global.total_coins))

func _on_quests_updated(quest_texts: Array) -> void:
	clear_quests()
	for i in range(min(quest_texts.size(), quest_labels.size())):
		quest_labels[i].text = quest_texts[i]
		quest_labels[i].visible = true

func clear_quests() -> void:
	for label in quest_labels:
		label.text = ""
		label.visible = false
