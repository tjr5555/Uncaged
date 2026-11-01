extends Node

signal quests_updated(quest_texts: Array)
signal quest_completed(quest_name: String)

var active_quests = {}

# -1 means "not read yet" (avoids depending on autoload order with Global)
var _last_coins: int = -1


func _process(_delta: float) -> void:
	var coins := int(Global.total_coins)
	if _last_coins < 0:
		_last_coins = coins
		return

	var gained := coins - _last_coins
	_last_coins = coins

	#only coins you gain count toward the quest, so spending on upgrades
	#never lowers your progress.
	if gained > 0 and active_quests.has("collect_coins"):
		_add_progress("collect_coins", gained)


func _add_progress(quest_id: String, amount: int) -> void:
	var q = active_quests[quest_id]
	if q["completed"]:
		return

	q["current"] = min(q["current"] + amount, q["target"])
	if q["current"] >= q["target"]:
		q["completed"] = true
		quest_completed.emit(q["name"])
	_update_hud()


func add_quest(quest_id: String, quest_name: String, description: String, required_amount: int = 1) -> void:
	if active_quests.has(quest_id):
		return

	var initial_progress := 0
	if quest_id == "collect_coins":
		#coins you are already holding count as a head start
		initial_progress = min(int(Global.total_coins), required_amount)

	active_quests[quest_id] = {
		"name": quest_name,
		"description": description,
		"current": initial_progress,
		"target": required_amount,
		"completed": false
	}

	#already enough coins when the quest is accepted
	if initial_progress >= required_amount:
		active_quests[quest_id]["completed"] = true
		quest_completed.emit(quest_name)

	_update_hud()


#call this from your HUD's _ready so it shows quests that already exist
func refresh() -> void:
	_update_hud()


func _update_hud() -> void:
	var quest_texts := []
	for q_id in active_quests:
		var q = active_quests[q_id]
		var progress = str(q["current"]) + "/" + str(q["target"])
		quest_texts.append(q["name"] + ": " + q["description"] + " (" + progress + ")")

	quests_updated.emit(quest_texts)
