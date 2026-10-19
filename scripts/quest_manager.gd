extends Node

signal quests_updated(quest_texts: Array)
signal quest_completed(quest_name: String)

var active_quests = {}

func _process(_delta: float) -> void:
	#coin quests use Global.coin to keep track of the progress
	if active_quests.has("collect_coins"):
		var target = active_quests["collect_coins"]["target"]
		var current_coins = int(Global.total_coins)
		#only update if the value changed
		if active_quests["collect_coins"]["current"] != current_coins:
			active_quests["collect_coins"]["current"] = min(current_coins, target)
			_update_hud()
			if current_coins >= target and not active_quests["collect_coins"].get("completed", false):
				active_quests["collect_coins"]["completed"] = true
				emit_signal("quest_completed", active_quests["collect_coins"]["name"])
				_update_hud()

func add_quest(quest_id: String, quest_name: String, description: String, required_amount: int = 1):
	if active_quests.has(quest_id):
		return
		
	var initial_progress = 0
	if quest_id == "collect_coins":
		initial_progress = min(int(Global.total_coins), required_amount)

	active_quests[quest_id] = {
		"name": quest_name,
		"description": description,
		"current": initial_progress,
		"target": required_amount,
		"completed": false
	}
	_update_hud()

func _update_hud():
	var quest_texts = []
	for q_id in active_quests:
		var q = active_quests[q_id]
		var progress = str(q["current"]) + "/" + str(q["target"])
		quest_texts.append(q["name"] + ": " + q["description"] + " (" + progress + ")")
	
	emit_signal("quests_updated", quest_texts)
