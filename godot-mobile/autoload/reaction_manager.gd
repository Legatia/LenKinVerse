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
			"reactants": {"lkC": 5},
			"products": {"Coal": 1},
			"type": "compression",
			"name": "Coal Formation",
			"description": "Compress 5 lkC into Coal"
		}
	]

	# Chemical reactions (2 charge per unit)
	reactions_db["chemical"] = [
		{
			"reactants": {"lkC": 1, "lkO": 2},
			"products": {"CO2": 1},
			"type": "combustion",
			"name": "Carbon Dioxide Formation",
			"description": "Combine Carbon and Oxygen"
		},
		{
			"reactants": {"lkH": 2, "lkO": 1},
			"products": {"H2O": 1},
			"type": "synthesis",
			"name": "Water Formation",
			"description": "Combine Hydrogen and Oxygen"
		}
	]

	# Nuclear reactions (5 charge per unit, requires isotope catalyst)
	# Each reaction consumes 0.5 volume units from isotope
	reactions_db["nuclear"] = [
		{
			"reactants": {"lkC": 1},
			"catalyst": "lkC14",  # Raw isotope material
			"catalyst_volume_consumed": 0.5,  # Each unit supports 2 reactions
			"products": {"lkO": 2},
			"type": "nuclear_fusion",
			"name": "Carbon Fusion to Oxygen",
			"description": "Use C14 catalyst to fuse Carbon into Oxygen",
			"success_rate": 0.10,  # 10% chance
			"failure_products": {"lkC": 1},  # Returns pure lkC on failure
			"failure_discovery_chance": 0.001,  # 0.1% chance during failure
			"failure_discovery_product": "Carbon_X"  # Undefined new material
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
		var succeeded = randf() < success_rate

		if not succeeded:
			# Failed nuclear reaction - return materials and maybe discover new element
			return handle_failed_nuclear(reactants, catalyst, reaction, charge_required)

	# Consume reactants
	if not InventoryManager.consume_elements(reactants):
		return {
			"success": false,
			"error": "Failed to consume reactants"
		}

	# Consume catalyst volume if nuclear
	if mode == "nuclear" and catalyst.has("id"):
		var volume_consumed = reaction.get("catalyst_volume_consumed", 0.5)
		if not InventoryManager.consume_isotope_volume(catalyst["id"], volume_consumed):
			return {
				"success": false,
				"error": "Failed to consume isotope volume"
			}

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

func handle_failed_nuclear(reactants: Dictionary, catalyst: Dictionary, reaction: Dictionary, charge_used: int) -> Dictionary:
	# On nuclear failure:
	# - Return pure reactant materials
	# - 0.1% chance to discover new undefined material
	# - Still consume isotope volume and charge

	var failure_products = reaction.get("failure_products", {})
	var discovery_chance = reaction.get("failure_discovery_chance", 0.001)
	var discovery_product = reaction.get("failure_discovery_product", "Unknown")

	# Consume originals
	InventoryManager.consume_elements(reactants)

	# Consume isotope volume even on failure
	if catalyst.has("id"):
		var volume_consumed = reaction.get("catalyst_volume_consumed", 0.5)
		InventoryManager.consume_isotope_volume(catalyst["id"], volume_consumed)

	# Consume charge
	consume_gloves_charge(charge_used)

	# Return failure products (pure lkC)
	if not failure_products.is_empty():
		InventoryManager.add_elements(failure_products)

	# Check for rare discovery during failure
	var discovered_new = false
	if randf() < discovery_chance:
		# Discovered new undefined material!
		InventoryManager.add_elements({discovery_product: 1})
		discovered_new = true

	var error_msg = "❌ Nuclear reaction failed!"
	if discovered_new:
		error_msg += "\n\n🌟 But discovered new material: %s!" % discovery_product

	return {
		"success": false,
		"error": error_msg,
		"returned": failure_products,
		"charge_used": charge_used,
		"discovered_new": discovered_new,
		"new_material": discovery_product if discovered_new else ""
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
