extends Node
## Manages all player inventory: raw materials, elements, isotopes, items

signal inventory_changed()
signal isotope_discovered(isotope_type: String)

# Raw materials (unprocessed)
var raw_materials: Dictionary = {
	"lkC": 0
}

# Elements (processed)
var elements: Dictionary = {
	"lkC": 0
}

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

## Add discovered isotope
func add_isotope(isotope_type: String) -> void:
	var current_time = Time.get_unix_time_from_system()
	var isotope = {
		"id": "isotope_%d" % current_time,
		"type": isotope_type,
		"volume": 1.0,  # Starts at 100% volume
		"discovered_at": current_time,
		"last_decay_check": current_time,
		"decay_time": current_time + (24 * 60 * 60)  # Still track final expiry
	}

	isotopes.append(isotope)
	isotope_discovered.emit(isotope_type)
	inventory_changed.emit()
	save_inventory()

## Remove isotope (used in reaction)
func remove_isotope(isotope_id: String) -> bool:
	var original_size = isotopes.size()
	isotopes = isotopes.filter(func(i): return i.get("id") != isotope_id)

	if isotopes.size() < original_size:
		inventory_changed.emit()
		save_inventory()
		return true
	return false

## Check for isotope volume decay (halves every 6 hours)
func _check_isotope_decay() -> void:
	const DECAY_INTERVAL: int = 6 * 60 * 60  # 6 hours in seconds
	const MIN_VOLUME: float = 0.06  # Remove when below 6% volume

	var current_time = Time.get_unix_time_from_system()
	var changed = false

	for isotope in isotopes:
		var last_check = isotope.get("last_decay_check", isotope.get("discovered_at", 0))
		var time_since_check = current_time - last_check

		# Calculate how many 6-hour periods have passed
		var decay_periods = int(time_since_check / DECAY_INTERVAL)

		if decay_periods > 0:
			# Halve volume for each period: volume * (0.5 ^ periods)
			var current_volume = isotope.get("volume", 1.0)
			var new_volume = current_volume * pow(0.5, decay_periods)

			isotope["volume"] = new_volume
			isotope["last_decay_check"] = last_check + (decay_periods * DECAY_INTERVAL)
			changed = true

	# Remove isotopes below minimum volume
	var original_size = isotopes.size()
	isotopes = isotopes.filter(func(i): return i.get("volume", 1.0) >= MIN_VOLUME)

	if isotopes.size() < original_size:
		changed = true

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
		isotopes = save_data.get("isotopes", [])
		items = save_data.get("items", [])
		raw_chunks = save_data.get("raw_chunks", [])
		file.close()

		inventory_changed.emit()
