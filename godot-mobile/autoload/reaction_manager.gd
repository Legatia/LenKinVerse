extends Node
## Reaction system - handles physical, chemical, and nuclear reactions

signal reaction_completed(result: Dictionary)
signal reaction_failed(reason: String)

# Reaction database
var reactions_db: Dictionary = {}

func _ready() -> void:
	load_reaction_database()

func load_reaction_database() -> void:
	# Physical reactions (1 charge per unit)
	reactions_db["physical"] = [
		{
			"reactants": {"lkC": 10},
			"products": {"Coal": 1},
			"type": "compression",
			"name": "Coal Formation"
		}
	]

	# Chemical reactions (2 charge per unit)
	reactions_db["chemical"] = [
		{
			"reactants": {"lkC": 1, "lkO": 2},
			"products": {"CO2": 1},
			"type": "combustion",
			"name": "Carbon Dioxide Formation"
		},
		{
			"reactants": {"lkH": 2, "lkO": 1},
			"products": {"H2O": 1},
			"type": "synthesis",
			"name": "Water Formation"
		}
	]

	# Nuclear reactions (5 charge per unit, requires isotope)
	reactions_db["nuclear"] = [
		{
			"reactants": {"lkC": 1},
			"catalyst": "C14",
			"products": {"lkN": 1},
			"type": "beta_decay",
			"name": "Carbon-14 Decay",
			"success_rate": 0.05  # 5% chance
		}
	]

## Attempt a reaction
func perform_reaction(reactants: Dictionary, mode: String, catalyst: Dictionary = {}) -> Dictionary:
	# Calculate total charge required
	var total_units = 0
	for element in reactants:
		total_units += reactants[element]

	var charge_per_unit = get_charge_multiplier(mode)
	var charge_required = total_units * charge_per_unit

	# Check charge
	var gloves_charge = get_gloves_charge()
	if gloves_charge < charge_required:
		return {
			"success": false,
			"error": "Insufficient charge (need %d ⚡)" % charge_required
		}

	# Check reactants availability
	for element in reactants:
		var available = InventoryManager.get_element_amount(element)
		if available < reactants[element]:
			return {
				"success": false,
				"error": "Insufficient %s (need %d, have %d)" % [element, reactants[element], available]
			}

	# Find matching reaction
	var reaction = find_reaction(reactants, mode, catalyst)

	if not reaction:
		return {
			"success": false,
			"error": "No known reaction for these materials"
		}

	# Check for nuclear reaction success
	if mode == "nuclear":
		var success_rate = reaction.get("success_rate", 0.05)
		if randf() > success_rate:
			# Failed nuclear reaction - return some materials
			return handle_failed_nuclear(reactants, charge_required)

	# Consume reactants
	if not InventoryManager.consume_elements(reactants):
		return {
			"success": false,
			"error": "Failed to consume reactants"
		}

	# Consume catalyst if nuclear
	if mode == "nuclear" and catalyst.has("id"):
		InventoryManager.remove_isotope(catalyst["id"])

	# Consume charge
	consume_gloves_charge(charge_required)

	# Add products
	InventoryManager.add_elements(reaction["products"])

	# Check if this is a new discovery
	var is_new = check_if_new_discovery(reaction["products"])

	return {
		"success": true,
		"reaction": reaction,
		"products": reaction["products"],
		"charge_used": charge_required,
		"is_new_discovery": is_new
	}

func find_reaction(reactants: Dictionary, mode: String, catalyst: Dictionary) -> Dictionary:
	var reactions = reactions_db.get(mode, [])

	for reaction in reactions:
		# Check if reactants match
		if not reactants_match(reactants, reaction["reactants"]):
			continue

		# For nuclear, check catalyst
		if mode == "nuclear":
			var required_catalyst = reaction.get("catalyst", "")
			if catalyst.is_empty() or catalyst.get("type") != required_catalyst:
				continue

		return reaction

	return {}

func reactants_match(provided: Dictionary, required: Dictionary) -> bool:
	if provided.size() != required.size():
		return false

	for element in required:
		if not provided.has(element):
			return false
		if provided[element] != required[element]:
			return false

	return true

func handle_failed_nuclear(reactants: Dictionary, charge_used: int) -> Dictionary:
	# Return 50-80% of materials on nuclear failure
	var return_rate = randf_range(0.5, 0.8)
	var returned = {}

	for element in reactants:
		var amount_to_return = int(reactants[element] * return_rate)
		if amount_to_return > 0:
			returned[element] = amount_to_return

	# Consume originals
	InventoryManager.consume_elements(reactants)

	# Return some back
	if not returned.is_empty():
		InventoryManager.add_elements(returned)

	# Still consume charge
	consume_gloves_charge(charge_used)

	return {
		"success": false,
		"error": "Nuclear reaction failed! Returned %d%% of materials" % int(return_rate * 100),
		"returned": returned,
		"charge_used": charge_used
	}

func check_if_new_discovery(products: Dictionary) -> bool:
	# Check if any product is being created for the first time
	for element in products:
		# Skip basic elements
		if element in ["lkC", "lkO", "lkN", "lkH", "lkSi"]:
			continue

		# Check if we've ever had this before
		var total_collected = get_element_lifetime_count(element)
		if total_collected == 0:
			return true

	return false

func get_element_lifetime_count(element: String) -> int:
	# TODO: Track lifetime collection stats
	# For now, check current inventory
	return InventoryManager.get_element_amount(element)

func get_charge_multiplier(mode: String) -> int:
	match mode:
		"physical": return 1
		"chemical": return 2
		"nuclear": return 5
		_: return 1

func get_gloves_charge() -> int:
	# TODO: Get from gloves save file
	if FileAccess.file_exists("user://gloves.save"):
		var file = FileAccess.open("user://gloves.save", FileAccess.READ)
		if file:
			var data = file.get_var()
			file.close()
			return data.get("charge", 0)
	return 0

func consume_gloves_charge(amount: int) -> void:
	if not FileAccess.file_exists("user://gloves.save"):
		return

	var file = FileAccess.open("user://gloves.save", FileAccess.READ)
	if not file:
		return

	var data = file.get_var()
	file.close()

	data["charge"] = max(0, data.get("charge", 0) - amount)

	var write_file = FileAccess.open("user://gloves.save", FileAccess.WRITE)
	if write_file:
		write_file.store_var(data)
		write_file.close()
