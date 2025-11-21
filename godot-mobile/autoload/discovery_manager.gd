extends Node
## Manages element discoveries and codex (encyclopedia of elements)

signal element_discovered(element_id: String, is_first_discovery: bool)
signal codex_updated()
signal element_became_tradeable(element_id: String)

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

# Global element registry (tracks which elements are registered as tokens)
var element_registry: Dictionary = {}
# Format:
# {
#   "element_id": {
#     "registered_at": 1699123456,
#     "governor": "wallet_address",
#     "co_governor": null,  # or wallet_address if co-governor exists
#     "is_tradeable": false,
#     "tradeable_at": 1699125256,  # registered_at + 1800 (30 min)
#     "treasury_balance": 0,
#     "total_taxed": 0
#   }
# }

# Registration queue (for handling race conditions)
var registration_queue: Dictionary = {}
# Format: {"element_id": "wallet_address_in_progress"}

func _ready() -> void:
	load_codex()

	# Start timer to check for tradeable elements
	var timer = Timer.new()
	timer.wait_time = 60.0  # Check every minute
	timer.timeout.connect(_check_tradeable_status)
	add_child(timer)
	timer.start()

## Register element discovery (called when element is created for first time)
func discover_element(element_id: String, discovery_method: String, rarity: int = 0, is_unregistered: bool = false) -> bool:
	"""
	Register a new element discovery
	Returns true if this is first discovery, false if already discovered
	is_unregistered: true if player chose to keep element unregistered
	"""
	var is_first_discovery = not codex.has(element_id)

	if is_first_discovery:
		var current_time = Time.get_unix_time_from_system()
		codex[element_id] = {
			"discovered_at": current_time,
			"total_created": 1,
			"times_used_in_reactions": 0,
			"first_discovery_method": discovery_method,
			"rarity": rarity,
			"is_unregistered": is_unregistered,
			"is_registered": false
		}

		if is_unregistered:
			print("🎉 NEW DISCOVERY (UNREGISTERED): %s via %s (10x isotope, can multiply)" % [element_id, discovery_method])
		else:
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
		"element_registry": element_registry,
		"registration_queue": registration_queue,
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
		element_registry = save_data.get("element_registry", {})
		registration_queue = save_data.get("registration_queue", {})
		file.close()

		print("📖 Codex loaded: %d elements discovered, %d registered" % [codex.size(), element_registry.size()])
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

## ========================================
## ELEMENT REGISTRATION SYSTEM
## ========================================

## Check if element is registered globally as a token
func is_element_registered(element_id: String) -> bool:
	return element_registry.has(element_id)

## Check if element is tradeable (30 min lock period passed)
func is_element_tradeable(element_id: String) -> bool:
	if not element_registry.has(element_id):
		return false

	var reg_data = element_registry[element_id]
	var current_time = Time.get_unix_time_from_system()
	var tradeable_at = reg_data.get("tradeable_at", 0)

	return current_time >= tradeable_at

## Get element governor wallet address
func get_element_governor(element_id: String) -> String:
	if not element_registry.has(element_id):
		return "Unknown"

	var reg_data = element_registry[element_id]
	var governor = reg_data.get("governor", "Unknown")
	var co_governor = reg_data.get("co_governor", null)

	if co_governor:
		return "%s & %s" % [governor.substr(0, 8), co_governor.substr(0, 8)]
	else:
		return governor.substr(0, 8) + "..."

## Check registration queue status
func check_registration_queue(element_id: String) -> String:
	"""
	Returns:
	- "available": No one registering, you can register
	- "in_queue": Someone else is registering
	- "registered": Already registered
	"""
	if is_element_registered(element_id):
		return "registered"

	if registration_queue.has(element_id):
		return "in_queue"

	return "available"

## Initiate registration (puts player in queue)
func initiate_registration(element_id: String, amount: int) -> void:
	# This would be called when player clicks "Register"
	# Puts them in queue while transaction processes
	var wallet_address = WalletManager.get_wallet_address()
	registration_queue[element_id] = wallet_address

	print("Player %s initiated registration for %s" % [wallet_address, element_id])

## Register element globally (called after successful blockchain transaction)
func register_element_globally(element_id: String, governor_wallet: String, rarity: int = 0, is_co_governor: bool = false) -> void:
	var current_time = Time.get_unix_time_from_system()

	if is_element_registered(element_id):
		# Already registered - add as co-governor
		element_registry[element_id]["co_governor"] = governor_wallet
		print("Added co-governor %s for %s" % [governor_wallet, element_id])
	else:
		# New registration
		element_registry[element_id] = {
			"registered_at": current_time,
			"governor": governor_wallet,
			"co_governor": null,
			"is_tradeable": false,
			"tradeable_at": current_time + 1800,  # 30 minutes
			"treasury_balance": 0,
			"total_taxed": 0,
			"rarity": rarity
		}

		print("Registered %s with governor %s (tradeable in 30 min)" % [element_id, governor_wallet])

	# Remove from queue
	if registration_queue.has(element_id):
		registration_queue.erase(element_id)

	# Add to codex if not already there
	if not codex.has(element_id):
		codex[element_id] = {
			"discovered_at": current_time,
			"total_created": 0,
			"times_used_in_reactions": 0,
			"first_discovery_method": "nuclear_fusion",
			"rarity": rarity,
			"is_registered": true
		}
	else:
		codex[element_id]["is_registered"] = true

	save_codex()
	element_discovered.emit(element_id, true)

## Add tax to treasury
func add_tax_to_treasury(element_id: String, amount: int) -> void:
	if not element_registry.has(element_id):
		push_error("Cannot tax unregistered element: %s" % element_id)
		return

	element_registry[element_id]["treasury_balance"] += amount
	element_registry[element_id]["total_taxed"] += amount

	save_codex()
	print("Added %d %s to treasury (total: %d)" % [amount, element_id, element_registry[element_id]["treasury_balance"]])

## Get treasury balance
func get_treasury_balance(element_id: String) -> int:
	if not element_registry.has(element_id):
		return 0
	return element_registry[element_id].get("treasury_balance", 0)

## Check if this discovery should show registration modal
func should_show_registration_modal(element_id: String) -> bool:
	"""
	Returns true if:
	1. Element not yet registered globally
	2. This is the first discovery of this element
	"""
	# Skip basic elements
	if element_id in ["lkC", "lkO", "lkN", "lkH", "lkSi"]:
		return false

	# Check if already registered
	if is_element_registered(element_id):
		return false

	# Check if this is first discovery
	return not is_discovered(element_id)

## ========================================
## WILD SPAWN SYSTEM
## ========================================

## Check tradeable status and emit signals
func _check_tradeable_status() -> void:
	var current_time = Time.get_unix_time_from_system()

	for element_id in element_registry:
		var reg_data = element_registry[element_id]

		# Skip if already marked as tradeable
		if reg_data.get("is_tradeable", false):
			continue

		# Check if lock period has passed
		var tradeable_at = reg_data.get("tradeable_at", 0)
		if current_time >= tradeable_at:
			# Mark as tradeable
			element_registry[element_id]["is_tradeable"] = true
			save_codex()

			# Emit signal for global announcement and wild spawn activation
			element_became_tradeable.emit(element_id)

			print("🎉 Element %s is now TRADEABLE! Wild spawns activated." % element_id)

## Get wild spawn chance for registered element
func get_wild_spawn_chance(element_id: String) -> float:
	"""
	Calculate wild spawn chance based on:
	- On-chain liquidity (treasury balance)
	- Total lkC in world (from InventoryManager)

	Formula: on_chain_liquidity / total_lkc_in_world
	Example: 10,000 Element_Z / 1,000,000 lkC = 0.01% (0.0001)
	"""
	if not is_element_registered(element_id):
		return 0.0

	if not is_element_tradeable(element_id):
		return 0.0

	var treasury_balance = get_treasury_balance(element_id)
	if treasury_balance <= 0:
		return 0.0

	# Get total lkC in world (from all players - for now use local inventory as proxy)
	# In production, this would be fetched from backend
	var total_lkc_in_world = _get_total_lkc_in_world()
	if total_lkc_in_world <= 0:
		return 0.0

	# Calculate spawn chance
	var spawn_chance = float(treasury_balance) / float(total_lkc_in_world)

	# Cap at 10% to prevent too high spawn rates
	return min(spawn_chance, 0.1)

## Get total lkC in world (mock for now)
func _get_total_lkc_in_world() -> int:
	"""
	Mock function - in production this would be fetched from backend
	For now, estimate based on local inventory
	"""
	# Base assumption: 1M lkC in world (will be tracked globally in production)
	var base_world_lkc = 1000000

	# Add player's lkC as contribution
	var player_lkc = InventoryManager.get_element_amount("lkC")
	player_lkc += InventoryManager.get_raw_material_amount("lkC")

	return base_world_lkc + player_lkc

## Get all tradeable registered elements
func get_tradeable_elements() -> Array:
	"""Returns array of element IDs that are tradeable"""
	var tradeable = []

	for element_id in element_registry:
		if is_element_tradeable(element_id):
			tradeable.append(element_id)

	return tradeable

## Get element spawn weight (for random selection)
func get_element_spawn_weight(element_id: String) -> float:
	"""
	Weight based on:
	- Rarity (lower rarity = higher weight)
	- Treasury balance (more balance = higher chance)
	"""
	if not element_registry.has(element_id):
		return 0.0

	var reg_data = element_registry[element_id]
	var rarity = reg_data.get("rarity", 0)
	var treasury = get_treasury_balance(element_id)

	# Rarity multiplier: Common (4x), Uncommon (3x), Rare (2x), Legendary (1x)
	var rarity_multiplier = 4 - rarity

	# Weight = treasury × rarity_multiplier
	return float(treasury) * rarity_multiplier
