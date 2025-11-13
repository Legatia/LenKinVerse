extends Node
## Manages blockchain/world selection and state

signal world_changed(world_id: String)

enum World {
	SOLANA,
	ETHEREUM_BASE,
	SUI
}

var current_world: String = ""
var world_selected: bool = false

# World configurations
var worlds: Dictionary = {
	"solana": {
		"name": "Solana",
		"display_name": "Solana",
		"icon": "☀️",
		"color": Color(0.573, 0.122, 0.729),  # Purple
		"description": "Fast, low-cost transactions\nNative Solana Mobile support",
		"enabled": true
	},
	"ethereum_base": {
		"name": "Ethereum - Base",
		"display_name": "Base (Ethereum L2)",
		"icon": "🔵",
		"color": Color(0.0, 0.318, 0.784),  # Blue
		"description": "Ethereum L2 by Coinbase\nLow fees, EVM compatible",
		"enabled": true
	},
	"sui": {
		"name": "Sui",
		"display_name": "Sui Network",
		"icon": "🌊",
		"color": Color(0.314, 0.784, 0.878),  # Cyan
		"description": "High throughput blockchain\nMove programming language",
		"enabled": true
	}
}

func _ready() -> void:
	load_world_selection()

func load_world_selection() -> void:
	var save_path = "user://world.save"
	if not FileAccess.file_exists(save_path):
		current_world = ""
		world_selected = false
		return

	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			var data = json.data
			current_world = data.get("current_world", "")
			world_selected = data.get("world_selected", false)

func save_world_selection() -> void:
	var save_data = {
		"current_world": current_world,
		"world_selected": world_selected
	}

	var file = FileAccess.open("user://world.save", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()

func select_world(world_id: String) -> void:
	if worlds.has(world_id):
		current_world = world_id
		world_selected = true
		save_world_selection()
		world_changed.emit(world_id)
		print("Selected world: ", worlds[world_id].get("display_name"))
	else:
		push_error("Invalid world ID: " + world_id)

func get_current_world() -> Dictionary:
	if current_world != "" and worlds.has(current_world):
		return worlds[current_world]
	return {}

func get_world_display_name() -> String:
	var world_data = get_current_world()
	if world_data.is_empty():
		return "No World Selected"
	return world_data.get("display_name", "Unknown")

func reset_world_selection() -> void:
	current_world = ""
	world_selected = false
	save_world_selection()

func has_world_selected() -> bool:
	return world_selected and current_world != ""
