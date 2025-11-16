extends Node
## Manages all player inventory: raw materials, elements, isotopes, items

signal inventory_changed()
signal isotope_discovered(isotope_type: String)

# Raw materials (unprocessed) - includes raw isotopes
var raw_materials: Dictionary = {
	"lkC": 0,
	"lkC14": 0  # Raw isotope material
}

# Elements (processed)
var elements: Dictionary = {
	"lkC": 0
}

# Unregistered elements (have special perks)
var unregistered_elements: Dictionary = {}
# Format: {"element_id": amount}

# Isotopes with decay timers
var isotopes: Array[Dictionary] = []

# Items/NFTs
var items: Array[Dictionary] = []

# Raw chunks (for detailed tracking)
var raw_chunks: Array[Dictionary] = []

func _ready() -> void:
	load_inventory()

	# Start decay timer for isotopes
	var timer = Timer.new()
	timer.wait_time = 60.0  # Check every minute
	timer.timeout.connect(_check_isotope_decay)
	add_child(timer)
	timer.start()

## Add raw material chunks from movement rewards
func add_raw_chunks(chunks: Array) -> void:
	raw_chunks.append_array(chunks)

	# Update raw materials total
	for chunk in chunks:
		var element = chunk.get("element", "lkC")
		var amount = chunk.get("final_amount", 0)
		add_raw_material(element, amount)

	save_inventory()

## Add raw material amount
func add_raw_material(element: String, amount: int) -> void:
	if not raw_materials.has(element):
		raw_materials[element] = 0
	raw_materials[element] += amount

	# Roll for wild spawns of registered elements
	_roll_wild_spawns(element, amount)

	inventory_changed.emit()
	save_inventory()

## Consume raw material
func consume_raw_material(element: String, amount: int) -> bool:
	if not raw_materials.has(element) or raw_materials[element] < amount:
		return false

	raw_materials[element] -= amount
	inventory_changed.emit()
	save_inventory()
	return true

## Remove analyzed chunk
func remove_raw_chunk(chunk_id: String) -> void:
	raw_chunks = raw_chunks.filter(func(c): return c.get("id") != chunk_id)
	save_inventory()

## Add processed elements
func add_elements(elements_dict: Dictionary) -> void:
	for element in elements_dict:
		if not elements.has(element):
			elements[element] = 0
		elements[element] += elements_dict[element]

	inventory_changed.emit()
	save_inventory()

## Consume elements for reactions
func consume_elements(elements_dict: Dictionary) -> bool:
	# Check if we have enough
	for element in elements_dict:
		if not elements.has(element) or elements[element] < elements_dict[element]:
			return false

	# Consume
	for element in elements_dict:
		elements[element] -= elements_dict[element]

	inventory_changed.emit()
	save_inventory()
	return true

## Add unregistered element
func add_unregistered_element(element_id: String, amount: int) -> void:
	if not unregistered_elements.has(element_id):
		unregistered_elements[element_id] = 0
	unregistered_elements[element_id] += amount
	inventory_changed.emit()
	save_inventory()
	print("Added %d unregistered %s (10x isotope rate, can multiply with gloves)" % [amount, element_id])

## Consume unregistered element
func consume_unregistered_element(element_id: String, amount: int) -> bool:
	if not unregistered_elements.has(element_id) or unregistered_elements[element_id] < amount:
		return false

	unregistered_elements[element_id] -= amount
	if unregistered_elements[element_id] <= 0:
		unregistered_elements.erase(element_id)

	inventory_changed.emit()
	save_inventory()
	return true

## Get unregistered element amount
func get_unregistered_element_amount(element_id: String) -> int:
	return unregistered_elements.get(element_id, 0)

## Check if element is unregistered in inventory
func has_unregistered_element(element_id: String) -> bool:
	return unregistered_elements.has(element_id) and unregistered_elements[element_id] > 0

## Convert unregistered element to registered (when element gets registered globally)
func convert_unregistered_to_registered(element_id: String) -> void:
	if unregistered_elements.has(element_id):
		var amount = unregistered_elements[element_id]
		unregistered_elements.erase(element_id)

		# Add to regular elements
		if not elements.has(element_id):
			elements[element_id] = 0
		elements[element_id] += amount

		inventory_changed.emit()
		save_inventory()
		print("Converted %d unregistered %s to registered (perks lost)" % [amount, element_id])

## Add discovered isotope as raw material
func add_isotope(isotope_type: String) -> void:
	# Isotopes are discovered as raw materials with volume in units
	# Volume is random between 12-28 units
	# Volume decays over time (halves every 6 hours) AND consumed during reactions (0.5 per reaction)
	var volume = randi_range(12, 28)

	var current_time = Time.get_unix_time_from_system()
	var isotope = {
		"id": "isotope_%d" % current_time,
		"type": isotope_type,
		"volume": float(volume),  # Units of raw isotope material
		"discovered_at": current_time,
		"last_decay_at": current_time,  # Track last decay time
	}

	isotopes.append(isotope)
	isotope_discovered.emit(isotope_type)
	inventory_changed.emit()
	save_inventory()

	print("Discovered %s with %d volume units (each unit = 2 reactions, halves every 6h)" % [isotope_type, volume])

## Remove isotope (used in reaction)
func remove_isotope(isotope_id: String) -> bool:
	var original_size = isotopes.size()
	isotopes = isotopes.filter(func(i): return i.get("id") != isotope_id)

	if isotopes.size() < original_size:
		inventory_changed.emit()
		save_inventory()
		return true
	return false

## Consume isotope volume for reaction (0.5 units per reaction)
func consume_isotope_volume(isotope_id: String, volume_to_consume: float) -> bool:
	for isotope in isotopes:
		if isotope.get("id") == isotope_id:
			var current_volume = isotope.get("volume", 0.0)
			if current_volume >= volume_to_consume:
				isotope["volume"] = current_volume - volume_to_consume

				# Remove isotope if volume depleted
				if isotope["volume"] <= 0:
					isotopes = isotopes.filter(func(i): return i.get("id") != isotope_id)

				inventory_changed.emit()
				save_inventory()
				return true
			return false
	return false

## Check for time-based isotope decay (halves every 6 hours)
func _check_isotope_decay() -> void:
	const DECAY_INTERVAL: int = 6 * 60 * 60  # 6 hours in seconds
	var current_time = Time.get_unix_time_from_system()
	var changed = false

	for isotope in isotopes:
		var last_decay = isotope.get("last_decay_at", isotope.get("discovered_at", current_time))
		var time_elapsed = current_time - last_decay

		# Calculate how many 6-hour periods have passed
		var decay_periods = int(time_elapsed / DECAY_INTERVAL)

		if decay_periods > 0:
			# Apply decay: halve volume for each period
			var current_volume = isotope.get("volume", 0.0)
			for i in range(decay_periods):
				current_volume *= 0.5

			isotope["volume"] = current_volume
			isotope["last_decay_at"] = last_decay + (decay_periods * DECAY_INTERVAL)
			changed = true

			print("Isotope %s decayed: %.2f units (decayed %d times)" % [isotope.get("type"), current_volume, decay_periods])

	# Remove isotopes with depleted volume (from decay or reactions)
	var original_size = isotopes.size()
	isotopes = isotopes.filter(func(i): return i.get("volume", 0) > 0)

	if isotopes.size() < original_size:
		changed = true
		print("Removed %d depleted isotope(s)" % (original_size - isotopes.size()))

	if changed:
		inventory_changed.emit()
		save_inventory()

## Get total raw material amount
func get_raw_material_amount(element: String) -> int:
	return raw_materials.get(element, 0)

## Get element amount
func get_element_amount(element: String) -> int:
	return elements.get(element, 0)

## Get available isotopes of type
func get_isotopes_of_type(isotope_type: String) -> Array[Dictionary]:
	return isotopes.filter(func(i): return i.get("type") == isotope_type)

## Save inventory to disk
func save_inventory() -> void:
	var save_data = {
		"raw_materials": raw_materials,
		"elements": elements,
		"unregistered_elements": unregistered_elements,
		"isotopes": isotopes,
		"items": items,
		"raw_chunks": raw_chunks
	}

	var file = FileAccess.open("user://inventory.save", FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()

## Load inventory from disk
func load_inventory() -> void:
	if not FileAccess.file_exists("user://inventory.save"):
		return

	var file = FileAccess.open("user://inventory.save", FileAccess.READ)
	if file:
		var save_data = file.get_var()
		raw_materials = save_data.get("raw_materials", {"lkC": 0})
		elements = save_data.get("elements", {"lkC": 0})
		unregistered_elements = save_data.get("unregistered_elements", {})
		isotopes = save_data.get("isotopes", [])
		items = save_data.get("items", [])
		raw_chunks = save_data.get("raw_chunks", [])
		file.close()

		# Ensure all isotopes have last_decay_at field for legacy saves
		var current_time = Time.get_unix_time_from_system()
		for isotope in isotopes:
			if not isotope.has("last_decay_at"):
				isotope["last_decay_at"] = isotope.get("discovered_at", current_time)
			# Ensure volume is float
			if isotope.has("volume") and typeof(isotope["volume"]) == TYPE_INT:
				isotope["volume"] = float(isotope["volume"])

		inventory_changed.emit()

## ========================================
## WILD SPAWN SYSTEM
## ========================================

## Roll for wild spawns when collecting raw materials
func _roll_wild_spawns(collected_element: String, amount: int) -> void:
	"""
	When collecting raw materials (e.g., lkC), roll for registered element spawns
	Only applies to basic elements like lkC that are collected from walking/mining
	"""
	# Only roll for basic collection elements
	if collected_element not in ["lkC", "lkO", "lkN", "lkH", "lkSi"]:
		return

	# Get all tradeable elements
	var tradeable_elements = DiscoveryManager.get_tradeable_elements()
	if tradeable_elements.is_empty():
		return

	# Roll for each unit collected
	for i in range(amount):
		# Check each tradeable element
		for element_id in tradeable_elements:
			var spawn_chance = DiscoveryManager.get_wild_spawn_chance(element_id)

			# Roll for spawn
			if randf() < spawn_chance:
				# Wild spawn discovered!
				_add_wild_spawn(element_id)

## Add wild spawn to inventory
func _add_wild_spawn(element_id: String) -> void:
	"""Add a wild-spawned registered element (as raw material first)"""
	# Add as raw material
	if not raw_materials.has("raw_" + element_id):
		raw_materials["raw_" + element_id] = 0
	raw_materials["raw_" + element_id] += 1

	print("✨ WILD SPAWN! Found 1 raw %s" % element_id)

	# Track in discovery stats
	DiscoveryManager.track_collection(element_id, 1, "wild_spawn")

	# Emit signal for UI notification
	inventory_changed.emit()
