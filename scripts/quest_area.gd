extends Control

@onready var quest_labels: Array = [$quest1, $quest2, $quest3]

func _ready() -> void:
	QuestManager.quests_updated.connect(_on_quests_updated)
	QuestManager.refresh() #show current state right away


func _on_quests_updated(quest_texts: Array) -> void:
	for i in quest_labels.size():
		var label = quest_labels[i]
		if i < quest_texts.size():
			label.text = quest_texts[i]
			label.visible = true
		else:
			label.text = ""
			label.visible = false

	if quest_texts.is_empty():
		quest_labels[0].text = "No quests"
		quest_labels[0].visible = true
