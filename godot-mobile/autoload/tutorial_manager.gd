extends Node
## Manages tutorial system and first-time user onboarding

signal tutorial_step_completed(step_id: String)
signal tutorial_completed

var is_tutorial_completed: bool = false
var current_step: int = 0

var completed_steps: Array[String] = []

# Tutorial steps definition
var tutorial_steps: Array[Dictionary] = [
	{
		"id": "welcome",
		"title": "Welcome to LenKinVerse!",
		"message": "A blockchain alchemy lab on Solana.\n\nCollect materials by walking around in real life, then analyze and react them to create new elements!",
		"highlight": ""
	},
	{
		"id": "movement",
		"title": "Passive Collection",
		"message": "When you close the app and walk around, the game tracks your movement via HealthKit/Google Fit.\n\nEvery 50 meters = 1 chunk of raw lkC!",
		"highlight": ""
	},
	{
		"id": "storage",
		"title": "Storage Box 📦",
		"message": "Click on the Storage Box to view your inventory.\n\nManage raw materials, cleaned elements, and rare isotopes.",
		"highlight": "StorageBox"
	},
	{
		"id": "gloves",
		"title": "Alchemy Gloves ⚗️",
		"message": "Click the Gloves button (⚗️) at the bottom-left to analyze raw materials and perform reactions.\n\nLevel up your gloves by analyzing more materials!",
		"highlight": "GlovesButton"
	},
	{
		"id": "marketplace",
		"title": "Marketplace 🏪",
		"message": "Click on the Marketplace to buy, sell, or mint elements as NFTs on Solana.\n\nConnect your Phantom or Solflare wallet to trade!",
		"highlight": "Marketplace"
	},
	{
		"id": "hud",
		"title": "HUD Stats 📊",
		"message": "Top bar shows:\n⚡ Charge (for reactions)\n💰 Cleaned lkC\n⚫ Raw materials\n\nClick 📊 to view your profile and stats!",
		"highlight": ""
	},
	{
		"id": "complete",
		"title": "You're Ready!",
		"message": "Start by clicking the Gloves button (⚗️) to analyze your first materials.\n\nGood luck, Alchemist! ⚗️✨",
		"highlight": ""
	}
]

func _ready() -> void:
	load_tutorial_state()

func load_tutorial_state() -> void:
	var save_path = "user://tutorial.save"
	if not FileAccess.file_exists(save_path):
		is_tutorial_completed = false
		current_step = 0
		completed_steps = []
		return

	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			var data = json.data
			is_tutorial_completed = data.get("tutorial_completed", false)
			current_step = data.get("current_step", 0)
			var loaded_steps = data.get("completed_steps", [])
			completed_steps.clear()
			for step in loaded_steps:
				if step is String:
					completed_steps.append(step)

func save_tutorial_state() -> void:
	var save_data = {
		"tutorial_completed": is_tutorial_completed,
		"current_step": current_step,
		"completed_steps": completed_steps
	}

	var file = FileAccess.open("user://tutorial.save", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()

func should_show_tutorial() -> bool:
	return not is_tutorial_completed

func get_current_step() -> Dictionary:
	if current_step < tutorial_steps.size():
		return tutorial_steps[current_step]
	return {}

func advance_tutorial() -> void:
	if current_step < tutorial_steps.size():
		var step_id = tutorial_steps[current_step].get("id", "")
		completed_steps.append(step_id)
		tutorial_step_completed.emit(step_id)

		current_step += 1
		save_tutorial_state()

		# Check if tutorial is complete
		if current_step >= tutorial_steps.size():
			is_tutorial_completed = true
			save_tutorial_state()
			tutorial_completed.emit()

func reset_tutorial() -> void:
	is_tutorial_completed = false
	current_step = 0
	completed_steps = []
	save_tutorial_state()

func mark_completed() -> void:
	is_tutorial_completed = true
	current_step = tutorial_steps.size()
	save_tutorial_state()
	tutorial_completed.emit()
