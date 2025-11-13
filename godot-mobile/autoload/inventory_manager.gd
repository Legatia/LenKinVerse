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
	var isotope = {
		"id": "isotope_%d" % Time.get_unix_time_from_system(),
		"type": isotope_type,
		"amount": 1,
		"discovered_at": Time.get_unix_time_from_system(),
		"decay_time": Time.get_unix_time_from_system() + (24 * 60 * 60)  # 24 hours
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

## Check for decayed isotopes
func _check_isotope_decay() -> void:
	var current_time = Time.get_unix_time_from_system()
	var removed = false

	isotopes = isotopes.filter(func(i):
		if i.get("decay_time", 0) <= current_time:
			removed = true
			return false
		return true
	)

	if removed:
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
