extends Node
## Reaction system - handles physical, chemical, and nuclear reactions

signal reaction_completed(result: Dictionary)
signal reaction_failed(reason: String)

# Reaction database
var reactions_db: Dictionary = {}

# Rarity configuration
var rarity_config: Dictionary = {}

func _ready() -> void:
	load_rarity_config()
	load_reaction_database()

func load_rarity_config() -> void:
	var config_path = "res://assets/rarity_config.json"

	if not FileAccess.file_exists(config_path):
		push_error("Rarity config not found at: " + config_path)
		rarity_config = {"elements": {}, "default_rarity": 0, "rarity_levels": {}}
		return

	var file = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		push_error("Failed to open rarity config")
		rarity_config = {"elements": {}, "default_rarity": 0, "rarity_levels": {}}
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)

	if error == OK:
		rarity_config = json.data
		print("Loaded rarity config with %d elements" % rarity_config.get("elements", {}).size())
	else:
		push_error("Failed to parse rarity config JSON: " + json.get_error_message())
		rarity_config = {"elements": {}, "default_rarity": 0, "rarity_levels": {}}

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

	# Check if this is a new discovery BEFORE adding to inventory
	var is_new = check_if_new_discovery(reaction["products"])
	var new_elements: Array = []

	# Register discoveries, apply tax, and track creation
	var final_products: Dictionary = {}

	for element in reaction["products"]:
		var amount = reaction["products"][element]
		var final_amount = amount

		if DiscoveryManager.would_be_new_discovery(element):
			# This is a first-time discovery!
			new_elements.append(element)
			var rarity = get_element_rarity(element)
			DiscoveryManager.discover_element(element, reaction.get("type", "reaction"), rarity)
		else:
			# Already discovered - check if registered and apply tax
			if DiscoveryManager.is_element_registered(element):
				# Apply 10% tax
				var tax_amount = int(amount * 0.1)

				# Check if element is tradeable (lock period over)
				var is_tradeable = DiscoveryManager.is_element_tradeable(element)

				if not is_tradeable:
					# During lock period: 2x compensation
					final_amount = amount * 2 - tax_amount
					print("Lock period active for %s: 2x compensation (receive %d, tax %d)" % [element, final_amount, tax_amount])
				else:
					# After tradeable: normal 1x with tax
					final_amount = amount - tax_amount
					print("Element %s taxed: receive %d, tax %d to treasury" % [element, final_amount, tax_amount])

				# Add tax to treasury
				DiscoveryManager.add_tax_to_treasury(element, tax_amount)

			# Track creation
			DiscoveryManager.track_collection(element, final_amount, "reaction")

		final_products[element] = final_amount

	# Add products to inventory (with tax applied)
	InventoryManager.add_elements(final_products)

	return {
		"success": true,
		"reaction": reaction,
		"products": reaction["products"],
		"charge_used": charge_required,
		"is_new_discovery": is_new,
		"new_elements": new_elements  # List of newly discovered elements
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
	var new_elements: Array = []

	if randf() < discovery_chance:
		# Discovered new undefined material!
		var is_new_discovery = DiscoveryManager.would_be_new_discovery(discovery_product)

		if is_new_discovery:
			# This is a first-time discovery!
			var rarity = get_element_rarity(discovery_product)
			DiscoveryManager.discover_element(discovery_product, "nuclear_failure", rarity)
			new_elements.append(discovery_product)
			discovered_new = true
		else:
			# Already discovered - just track creation
			DiscoveryManager.track_collection(discovery_product, 1, "reaction")

		InventoryManager.add_elements({discovery_product: 1})

	var error_msg = "❌ Nuclear reaction failed!"
	if discovered_new:
		error_msg += "\n\n🌟 But discovered new material: %s!" % discovery_product

	return {
		"success": false,
		"error": error_msg,
		"returned": failure_products,
		"charge_used": charge_used,
		"discovered_new": discovered_new,
		"new_material": discovery_product if discovered_new else "",
		"new_elements": new_elements
	}

func check_if_new_discovery(products: Dictionary) -> bool:
	# Check if any product is being created for the first time
	for element in products:
		# Use DiscoveryManager to check if this would be a new discovery
		if DiscoveryManager.would_be_new_discovery(element):
			return true

	return false

func get_element_lifetime_count(element: String) -> int:
	# Use DiscoveryManager's lifetime tracking
	return DiscoveryManager.get_lifetime_created(element)

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

## Get element rarity for discovery tracking
func get_element_rarity(element_id: String) -> int:
	# Check config for element rarity
	var elements = rarity_config.get("elements", {})
	if elements.has(element_id):
		return elements[element_id]

	# Use default rarity if not found
	return rarity_config.get("default_rarity", 0)
