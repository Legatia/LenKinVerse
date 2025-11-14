extends Node
## Manages element discoveries and codex (encyclopedia of elements)

signal element_discovered(element_id: String, is_first_discovery: bool)
signal codex_updated()

# Discovered elements with metadata
var codex: Dictionary = {}
# Format:
# {
#   "CO2": {
#     "discovered_at": 1699123456,
#     "total_created": 15,
#     "times_used_in_reactions": 3,
#     "first_discovery_method": "chemical_reaction",
#     "rarity": 1
#   }
# }

# Lifetime stats for all elements (including basic ones)
var lifetime_stats: Dictionary = {}
# Format:
# {
#   "lkC": {
#     "total_collected": 1247,
#     "total_consumed": 523,
#     "total_created_via_reaction": 124
#   }
# }

func _ready() -> void:
	load_codex()

## Register element discovery (called when element is created for first time)
func discover_element(element_id: String, discovery_method: String, rarity: int = 0) -> bool:
	"""
	Register a new element discovery
	Returns true if this is first discovery, false if already discovered
	"""
	var is_first_discovery = not codex.has(element_id)

	if is_first_discovery:
		var current_time = Time.get_unix_time_from_system()
		codex[element_id] = {
			"discovered_at": current_time,
			"total_created": 1,
			"times_used_in_reactions": 0,
			"first_discovery_method": discovery_method,
			"rarity": rarity
		}

		print("🎉 NEW DISCOVERY: %s via %s" % [element_id, discovery_method])
		element_discovered.emit(element_id, true)
	else:
		# Already discovered - just increment counter
		codex[element_id]["total_created"] += 1
		element_discovered.emit(element_id, false)

	codex_updated.emit()
	save_codex()

	return is_first_discovery

## Increment creation count for element
func increment_created(element_id: String, amount: int = 1) -> void:
	if codex.has(element_id):
		codex[element_id]["total_created"] += amount
		save_codex()

## Increment usage count (when element is used in reaction)
func increment_used_in_reaction(element_id: String, amount: int = 1) -> void:
	if codex.has(element_id):
		codex[element_id]["times_used_in_reactions"] += amount
		save_codex()

## Track lifetime collection stats (for all elements, including basics)
func track_collection(element_id: String, amount: int, source: String) -> void:
	"""
	Track element collection regardless of discovery status
	source: "walk_mining", "reaction", "marketplace", "offline_reward"
	"""
	if not lifetime_stats.has(element_id):
		lifetime_stats[element_id] = {
			"total_collected": 0,
			"total_consumed": 0,
			"total_created_via_reaction": 0
		}

	if source == "reaction":
		lifetime_stats[element_id]["total_created_via_reaction"] += amount
	else:
		lifetime_stats[element_id]["total_collected"] += amount

	save_codex()

## Track element consumption
func track_consumption(element_id: String, amount: int) -> void:
	if not lifetime_stats.has(element_id):
		lifetime_stats[element_id] = {
			"total_collected": 0,
			"total_consumed": 0,
			"total_created_via_reaction": 0
		}

	lifetime_stats[element_id]["total_consumed"] += amount
	save_codex()

## Check if element has been discovered
func is_discovered(element_id: String) -> bool:
	return codex.has(element_id)

## Get element discovery data
func get_discovery_data(element_id: String) -> Dictionary:
	return codex.get(element_id, {})

## Get lifetime total created count
func get_lifetime_created(element_id: String) -> int:
	if codex.has(element_id):
		return codex[element_id].get("total_created", 0)
	return 0

## Get lifetime collection stats
func get_lifetime_stats(element_id: String) -> Dictionary:
	return lifetime_stats.get(element_id, {
		"total_collected": 0,
		"total_consumed": 0,
		"total_created_via_reaction": 0
	})

## Get all discovered elements (sorted by discovery date)
func get_discovered_elements() -> Array:
	var discovered = []
	for element_id in codex:
		var data = codex[element_id].duplicate()
		data["element_id"] = element_id
		discovered.append(data)

	# Sort by discovery date (newest first)
	discovered.sort_custom(func(a, b): return a["discovered_at"] > b["discovered_at"])

	return discovered

## Get discovery count by rarity
func get_discovery_count_by_rarity() -> Dictionary:
	var counts = {
		0: 0,  # Common
		1: 0,  # Uncommon
		2: 0,  # Rare
		3: 0   # Legendary
	}

	for element_id in codex:
		var rarity = codex[element_id].get("rarity", 0)
		if counts.has(rarity):
			counts[rarity] += 1

	return counts

## Get total discovery count
func get_total_discoveries() -> int:
	return codex.size()

## Get discovery progress (for achievements)
func get_discovery_progress() -> Dictionary:
	"""
	Returns discovery progress for different categories
	"""
	var total_elements = 20  # TODO: Define total possible elements

	return {
		"total_discovered": codex.size(),
		"total_possible": total_elements,
		"percentage": (codex.size() as float / total_elements) * 100.0,
		"by_rarity": get_discovery_count_by_rarity()
	}

## Check if this would be a new discovery
func would_be_new_discovery(element_id: String) -> bool:
	# Skip basic elements - they're always "known"
	if element_id in ["lkC", "lkO", "lkN", "lkH", "lkSi"]:
		return false

	return not codex.has(element_id)

## Save codex to disk
func save_codex() -> void:
	var save_data = {
		"version": "1.0",
		"codex": codex,
		"lifetime_stats": lifetime_stats,
		"saved_at": Time.get_unix_time_from_system()
	}

	var file = FileAccess.open("user://codex.save", FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()

## Load codex from disk
func load_codex() -> void:
	if not FileAccess.file_exists("user://codex.save"):
		print("📖 Starting new codex")
		return

	var file = FileAccess.open("user://codex.save", FileAccess.READ)
	if file:
		var save_data = file.get_var()
		codex = save_data.get("codex", {})
		lifetime_stats = save_data.get("lifetime_stats", {})
		file.close()

		print("📖 Codex loaded: %d elements discovered" % codex.size())
		codex_updated.emit()

## Reset codex (for testing/debugging)
func reset_codex() -> void:
	codex.clear()
	lifetime_stats.clear()
	save_codex()
	print("🗑️ Codex reset")
	codex_updated.emit()

## Get element name with formatting
func get_element_display_name(element_id: String) -> String:
	if is_discovered(element_id):
		return element_id
	else:
		return "???"

## Get element description
func get_element_description(element_id: String) -> String:
	"""
	Returns element description (could be expanded to load from config)
	"""
	var descriptions = {
		"CO2": "Carbon dioxide - produced from carbon and oxygen reaction",
		"H2O": "Water - produced from hydrogen and oxygen reaction",
		"Coal": "Compressed carbon material - created from pure carbon",
		"Carbon_X": "Unknown carbon variant - discovered during failed nuclear reactions"
	}

	if is_discovered(element_id):
		return descriptions.get(element_id, "No description available")
	else:
		return "Undiscovered element"
