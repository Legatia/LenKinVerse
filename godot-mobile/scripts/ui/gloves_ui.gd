extends Control
## Alchemy Gloves UI - analyze raw materials and perform reactions

# Gloves state
var level: int = 3
var analysis_count: int = 2470
var charge: int = 43
var charge_capacity: int = 100

# Level configuration
const LEVEL_CONFIG = {
	1: {"analyses": 0, "batch_size": 1, "speed": 1.0, "capacity": 50, "recharge_cost": 100},
	2: {"analyses": 500, "batch_size": 5, "speed": 0.8, "capacity": 75, "recharge_cost": 90},
	3: {"analyses": 2000, "batch_size": 10, "speed": 0.5, "capacity": 100, "recharge_cost": 80},
	4: {"analyses": 5000, "batch_size": 25, "speed": 0.3, "capacity": 150, "recharge_cost": 70},
	5: {"analyses": 10000, "batch_size": 50, "speed": 0.1, "capacity": 200, "recharge_cost": 50},
}

@onready var charge_bar: ProgressBar = $Panel/ChargeBar
@onready var charge_label: Label = $Panel/ChargeBar/ChargeLabel
@onready var progress_label: Label = $Panel/ProgressLabel
@onready var raw_lkc_label: Label = $Panel/TabContainer/Analyze/RawLKCLabel

# Reactions tab nodes (declared early for _ready access)
@onready var elements_grid: GridContainer = $Panel/TabContainer/Reactions/ElementsContainer/ElementsGrid
@onready var physical_button: Button = $Panel/TabContainer/Reactions/ModeSelector/PhysicalButton
@onready var chemical_button: Button = $Panel/TabContainer/Reactions/ModeSelector/ChemicalButton
@onready var nuclear_button: Button = $Panel/TabContainer/Reactions/ModeSelector/NuclearButton
@onready var reactant_slots: HBoxContainer = $Panel/TabContainer/Reactions/ReactantSlots
@onready var isotope_slot: Button = $Panel/TabContainer/Reactions/IsotopeSlot
@onready var reaction_charge_label: Label = $Panel/TabContainer/Reactions/ChargeLabel
@onready var react_button: Button = $Panel/TabContainer/Reactions/ReactButton

func _ready() -> void:
	load_gloves_data()
	update_ui()

	# Connect to inventory updates
	InventoryManager.inventory_changed.connect(update_ui)
	InventoryManager.inventory_changed.connect(populate_reaction_elements)

	# Connect reaction buttons
	physical_button.pressed.connect(func(): _on_mode_selected("physical"))
	chemical_button.pressed.connect(func(): _on_mode_selected("chemical"))
	nuclear_button.pressed.connect(func(): _on_mode_selected("nuclear"))
	react_button.pressed.connect(_on_react_button_pressed)
	isotope_slot.pressed.connect(_on_isotope_slot_pressed)

	# Connect reactant slots
	for i in range(3):
		var slot = reactant_slots.get_child(i)
		slot.pressed.connect(func(): _on_reactant_slot_pressed(i))

	# Populate elements list
	populate_reaction_elements()

func update_ui() -> void:
	# Update charge bar
	charge_bar.max_value = charge_capacity
	charge_bar.value = charge
	charge_label.text = "Charge: %d/%d ⚡" % [charge, charge_capacity]

	# Update progress
	var next_level_threshold = get_next_level_threshold()
	if next_level_threshold > 0:
		progress_label.text = "Progress: %s/%s → Lv.%d" % [
			format_number(analysis_count),
			format_number(next_level_threshold),
			level + 1
		]
	else:
		progress_label.text = "MAX LEVEL (Lv.5)"

	# Update raw materials
	var raw_lkc = InventoryManager.get_raw_material_amount("lkC")
	raw_lkc_label.text = "⚫ raw lkC × %d" % raw_lkc

func get_next_level_threshold() -> int:
	if level >= 5:
		return 0
	return LEVEL_CONFIG[level + 1]["analyses"]

func format_number(num: int) -> String:
	if num >= 1000:
		return "%d,%03d" % [num / 1000, num % 1000]
	return str(num)

func _on_analyze_1_pressed() -> void:
	if charge < 1:
		show_message("Not enough charge!")
		return

	var raw_lkc = InventoryManager.get_raw_material_amount("lkC")
	if raw_lkc < 1:
		show_message("No raw lkC to analyze!")
		return

	# Perform analysis
	analyze_raw_material(1)

func _on_analyze_10_pressed() -> void:
	var batch_size = LEVEL_CONFIG[level]["batch_size"]

	if charge < batch_size:
		show_message("Not enough charge! Need %d ⚡" % batch_size)
		return

	var raw_lkc = InventoryManager.get_raw_material_amount("lkC")
	if raw_lkc < batch_size:
		show_message("Not enough raw lkC! Need %d" % batch_size)
		return

	# Perform batch analysis
	analyze_raw_material(batch_size)

func analyze_raw_material(count: int) -> void:
	var results = []
	var processing_speed = LEVEL_CONFIG[level]["speed"]

	for i in range(count):
		# Simulate chunk data (12-20 base, 95% efficiency for example)
		var base_amount = randi_range(12, 20)
		var efficiency = 0.95
		var final_amount = int(base_amount * efficiency)

		# Roll for isotope (0.1% chance)
		var isotope_found = randf() < 0.001

		# Consume raw material and charge
		InventoryManager.consume_raw_material("lkC", final_amount)
		charge -= 1

		# Add cleaned element
		InventoryManager.add_elements({"lkC": final_amount})

		# Add isotope if discovered
		if isotope_found:
			InventoryManager.add_isotope("C14")

		# Increment analysis count
		analysis_count += 1

		results.append({
			"amount": final_amount,
			"isotope": isotope_found
		})

		# Wait for processing speed
		if i < count - 1:
			await get_tree().create_timer(processing_speed).timeout

	# Check for level up
	check_level_up()

	# Save and update
	save_gloves_data()
	update_ui()

	# Show results
	show_analysis_results(results)

func check_level_up() -> void:
	var next_threshold = get_next_level_threshold()
	if next_threshold > 0 and analysis_count >= next_threshold:
		level += 1
		charge_capacity = LEVEL_CONFIG[level]["capacity"]
		show_message("🎉 LEVEL UP! Now Lv.%d" % level)

func _on_recharge_pressed() -> void:
	var recharge_cost = LEVEL_CONFIG[level]["recharge_cost"]
	var raw_lkc = InventoryManager.get_raw_material_amount("lkC")

	if raw_lkc < recharge_cost:
		show_message("Not enough raw lkC! Need %d" % recharge_cost)
		return

	# Consume raw lkC
	if InventoryManager.consume_raw_material("lkC", recharge_cost):
		# Add charge
		charge = min(charge + 10, charge_capacity)
		save_gloves_data()
		update_ui()
		show_message("Recharged +10 ⚡")

func show_analysis_results(results: Array) -> void:
	var total_lkc = 0
	var isotopes_found = 0

	for result in results:
		total_lkc += result["amount"]
		if result["isotope"]:
			isotopes_found += 1

	var message = "✨ ANALYSIS COMPLETE ✨\n\nGained: +%d lkC" % total_lkc

	if isotopes_found > 0:
		message += "\n\n🌟 ISOTOPE DISCOVERED!\n+%d C14" % isotopes_found

	show_message(message)

func show_message(text: String) -> void:
	# TODO: Show proper modal/toast
	print(text)

	# Simple label popup for now
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(80, 200)
	label.size = Vector2(200, 100)
	add_child(label)

	await get_tree().create_timer(2.0).timeout
	label.queue_free()

func save_gloves_data() -> void:
	var save_data = {
		"level": level,
		"analysis_count": analysis_count,
		"charge": charge,
		"charge_capacity": charge_capacity
	}

	var file = FileAccess.open("user://gloves.save", FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()

func load_gloves_data() -> void:
	if not FileAccess.file_exists("user://gloves.save"):
		return

	var file = FileAccess.open("user://gloves.save", FileAccess.READ)
	if file:
		var save_data = file.get_var()
		level = save_data.get("level", 1)
		analysis_count = save_data.get("analysis_count", 0)
		charge = save_data.get("charge", 50)
		charge_capacity = save_data.get("charge_capacity", 50)
		file.close()

func _on_close_button_pressed() -> void:
	queue_free()

# ========================================
# REACTIONS TAB
# ========================================

# Reaction state
var selected_mode: String = "physical"
var selected_reactants: Dictionary = {}  # {element: amount}
var selected_isotope: Dictionary = {}

func _on_mode_selected(mode: String) -> void:
	selected_mode = mode

	# Update button states
	physical_button.button_pressed = (mode == "physical")
	chemical_button.button_pressed = (mode == "chemical")
	nuclear_button.button_pressed = (mode == "nuclear")

	# Update UI
	update_reaction_ui()

func populate_reaction_elements() -> void:
	if not elements_grid:
		return

	# Clear existing buttons
	for child in elements_grid.get_children():
		child.queue_free()

	# Add buttons for each available element
	for element in InventoryManager.elements:
		var amount = InventoryManager.elements[element]
		if amount > 0:
			add_element_button(element, amount)

func add_element_button(element: String, amount: int) -> void:
	var button = Button.new()
	button.text = "%s\n×%d" % [element, amount]
	button.custom_minimum_size = Vector2(60, 50)
	button.pressed.connect(func(): _on_element_selected(element))
	elements_grid.add_child(button)

func _on_element_selected(element: String) -> void:
	# Add to reactants or increase amount
	if selected_reactants.has(element):
		selected_reactants[element] += 1
	else:
		selected_reactants[element] = 1

	update_reaction_ui()

func _on_reactant_slot_pressed(slot_index: int) -> void:
	# Remove element from this slot
	var keys = selected_reactants.keys()
	if slot_index < keys.size():
		var element = keys[slot_index]
		selected_reactants[element] -= 1
		if selected_reactants[element] <= 0:
			selected_reactants.erase(element)

	update_reaction_ui()

func _on_isotope_slot_pressed() -> void:
	# Show isotope selection
	if InventoryManager.isotopes.is_empty():
		show_message("No isotopes available!")
		return

	# For now, select first available isotope
	selected_isotope = InventoryManager.isotopes[0]
	update_reaction_ui()

func update_reaction_ui() -> void:
	# Update reactant slots
	var keys = selected_reactants.keys()
	for i in range(3):
		var slot = reactant_slots.get_child(i)
		if i < keys.size():
			var element = keys[i]
			var amount = selected_reactants[element]
			slot.text = "%s×%d" % [element, amount]
		else:
			slot.text = "+"

	# Update isotope slot
	if selected_isotope.is_empty():
		isotope_slot.text = "No Isotope Selected"
	else:
		isotope_slot.text = "💎 %s" % selected_isotope.get("type", "?")

	# Calculate charge required
	var total_units = 0
	for element in selected_reactants:
		total_units += selected_reactants[element]

	var multiplier = 1
	match selected_mode:
		"physical": multiplier = 1
		"chemical": multiplier = 2
		"nuclear": multiplier = 5

	var charge_required = total_units * multiplier
	reaction_charge_label.text = "Charge Required: %d ⚡" % charge_required

func _on_react_button_pressed() -> void:
	if selected_reactants.is_empty():
		show_message("Select elements to react!")
		return

	# Perform reaction
	var result = ReactionManager.perform_reaction(
		selected_reactants,
		selected_mode,
		selected_isotope
	)

	if result.get("success"):
		# Success!
		var products = result.get("products", {})
		var reaction = result.get("reaction", {})

		var message = "✨ REACTION SUCCESS! ✨\n\n"
		message += "%s\n\n" % reaction.get("name", "Unknown Reaction")

		for product in products:
			message += "+%d %s\n" % [products[product], product]

		show_message(message)

		# Show discovery modal for each newly discovered element
		var new_elements = result.get("new_elements", [])
		if new_elements.size() > 0:
			# Show discovery modal for first new element
			await get_tree().create_timer(0.5).timeout
			_show_discovery_modal(new_elements[0], reaction.get("type", "reaction"))

			# Show additional discoveries if there are more
			for i in range(1, new_elements.size()):
				await get_tree().create_timer(1.0).timeout
				_show_discovery_modal(new_elements[i], reaction.get("type", "reaction"))

		# Clear selection
		selected_reactants.clear()
		selected_isotope = {}
		update_reaction_ui()

		# Update main UI (charge changed)
		load_gloves_data()
		update_ui()
		populate_reaction_elements()

	else:
		# Failed
		var error = result.get("error", "Unknown error")
		show_message("❌ REACTION FAILED\n\n" + error)

func _show_discovery_modal(element_id: String, discovery_method: String) -> void:
	# Get element rarity
	var rarity = ReactionManager.get_element_rarity(element_id)

	# Load discovery modal scene
	var modal_scene = load("res://scenes/ui/discovery_modal.tscn")
	if modal_scene:
		var modal = modal_scene.instantiate()
		get_tree().root.add_child(modal)
		modal.show_discovery(element_id, discovery_method, rarity)
	else:
		push_error("Failed to load discovery modal scene")
