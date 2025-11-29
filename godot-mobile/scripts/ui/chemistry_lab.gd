extends Control
## Chemistry Lab UI - Full chemistry system with energy management

# Nodes
@onready var energy_bar: ProgressBar = $EnergyPanel/EnergyBar
@onready var energy_label: Label = $EnergyPanel/EnergyLabel
@onready var regen_label: Label = $EnergyPanel/RegenLabel

@onready var tab_container: TabContainer = $TabContainer
@onready var reaction_list: VBoxContainer = $TabContainer/Reactions/ReactionList
@onready var inventory_list: VBoxContainer = $TabContainer/Inventory/InventoryList
@onready var discovery_list: VBoxContainer = $TabContainer/Discoveries/DiscoveryList

@onready var reaction_filter: OptionButton = $TabContainer/Reactions/FilterPanel/TypeFilter
@onready var reaction_detail_panel: Panel = $ReactionDetailPanel
@onready var result_popup: Panel = $ResultPopup

# State
var selected_reaction: Dictionary = {}
var current_filter: String = "all"

# Reaction type icons/colors
const REACTION_COLORS = {
	"physical": Color(0.8, 0.8, 0.8),  # Gray
	"chemical": Color(0.3, 0.7, 1.0),  # Blue
	"nuclear": Color(1.0, 0.3, 0.3)    # Red
}

func _ready() -> void:
	# Connect to Chemistry API Manager
	ChemistryAPIManager.energy_updated.connect(_on_energy_updated)
	ChemistryAPIManager.reactions_loaded.connect(_on_reactions_loaded)
	ChemistryAPIManager.inventory_loaded.connect(_on_inventory_loaded)
	ChemistryAPIManager.reaction_completed.connect(_on_reaction_completed)
	ChemistryAPIManager.reaction_failed.connect(_on_reaction_failed)

	# Setup filter
	reaction_filter.add_item("All Reactions", 0)
	reaction_filter.add_item("Physical", 1)
	reaction_filter.add_item("Chemical", 2)
	reaction_filter.add_item("Nuclear", 3)
	reaction_filter.item_selected.connect(_on_filter_selected)

	# Hide detail panel initially
	reaction_detail_panel.visible = false
	result_popup.visible = false

	# Auto-refresh energy every 10 seconds
	var timer = Timer.new()
	timer.wait_time = 10.0
	timer.timeout.connect(func(): ChemistryAPIManager.fetch_player_energy())
	add_child(timer)
	timer.start()

	# Load initial data
	_refresh_all_data()

## ============================================================================
## DATA LOADING
## ============================================================================

func _refresh_all_data() -> void:
	ChemistryAPIManager.fetch_all_reactions()
	ChemistryAPIManager.fetch_player_inventory()
	ChemistryAPIManager.fetch_player_energy()

func _on_energy_updated(energy_data: Dictionary) -> void:
	var current = energy_data.get("current_energy", 0)
	var max_energy = energy_data.get("max_energy", 100)
	var percentage = energy_data.get("energy_percentage", 0)
	var time_until_full = energy_data.get("time_until_full", "")

	# Update energy bar
	energy_bar.max_value = max_energy
	energy_bar.value = current
	energy_label.text = "%d⚡ / %d⚡ (%d%%)" % [current, max_energy, percentage]

	# Update regen label
	if current >= max_energy:
		regen_label.text = "FULL ENERGY"
		regen_label.modulate = Color(0.3, 1.0, 0.3)  # Green
	else:
		regen_label.text = "Full in: %s (1⚡/3min)" % time_until_full
		regen_label.modulate = Color(1.0, 1.0, 1.0)

func _on_reactions_loaded(reactions: Array) -> void:
	_populate_reaction_list(reactions)

func _on_inventory_loaded(inventory: Dictionary) -> void:
	_populate_inventory_list(inventory)

## ============================================================================
## REACTION LIST
## ============================================================================

func _populate_reaction_list(reactions: Array) -> void:
	# Clear existing
	for child in reaction_list.get_children():
		child.queue_free()

	var filtered_reactions = _filter_reactions(reactions)

	for reaction in filtered_reactions:
		var reaction_button = _create_reaction_button(reaction)
		reaction_list.add_child(reaction_button)

	if filtered_reactions.size() == 0:
		var label = Label.new()
		label.text = "No reactions available"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reaction_list.add_child(label)

func _filter_reactions(reactions: Array) -> Array:
	if current_filter == "all":
		return reactions

	var filtered = []
	for reaction in reactions:
		var type = reaction.get("reaction_type", "")
		if type == current_filter:
			filtered.append(reaction)
	return filtered

func _create_reaction_button(reaction: Dictionary) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(0, 80)

	# Get reaction info
	var name = reaction.get("reaction_name", "Unknown")
	var type = reaction.get("reaction_type", "chemical")
	var energy_cost = reaction.get("energy_cost", 0)
	var success_rate = float(reaction.get("success_rate", 1.0)) * 100.0

	# Build button text
	var text = "[%s] %s\n" % [type.to_upper(), name]
	text += "Energy: %d⚡ | Success: %.0f%%\n" % [energy_cost, success_rate]

	# Show inputs
	var inputs = reaction.get("inputs", [])
	var input_text = ""
	for input in inputs:
		if input_text != "":
			input_text += " + "
		input_text += "%d %s" % [input.get("amount", 1), input.get("id", "")]
	text += "→ " + input_text

	button.text = text

	# Color by type
	var color = REACTION_COLORS.get(type, Color.WHITE)
	button.modulate = color

	# Connect
	button.pressed.connect(func(): _on_reaction_selected(reaction))

	return button

func _on_reaction_selected(reaction: Dictionary) -> void:
	selected_reaction = reaction
	_show_reaction_detail(reaction)

func _on_filter_selected(index: int) -> void:
	match index:
		0: current_filter = "all"
		1: current_filter = "physical"
		2: current_filter = "chemical"
		3: current_filter = "nuclear"

	_populate_reaction_list(ChemistryAPIManager.cached_reactions)

## ============================================================================
## REACTION DETAIL PANEL
## ============================================================================

func _show_reaction_detail(reaction: Dictionary) -> void:
	reaction_detail_panel.visible = true

	# Build detail text
	var name = reaction.get("reaction_name", "Unknown")
	var type = reaction.get("reaction_type", "chemical")
	var energy_cost = reaction.get("energy_cost", 0)
	var success_rate = float(reaction.get("success_rate", 1.0)) * 100.0

	var detail_label = reaction_detail_panel.get_node("DetailLabel")
	var inputs_label = reaction_detail_panel.get_node("InputsLabel")
	var outputs_label = reaction_detail_panel.get_node("OutputsLabel")
	var perform_button = reaction_detail_panel.get_node("PerformButton")
	var close_button = reaction_detail_panel.get_node("CloseButton")

	# Detail
	detail_label.text = "%s\n[%s Reaction]\n\nEnergy: %d⚡\nSuccess Rate: %.0f%%" % [
		name,
		type.capitalize(),
		energy_cost,
		success_rate
	]

	# Inputs
	var inputs = reaction.get("inputs", [])
	var inputs_text = "Requires:\n"
	for input in inputs:
		var amount = input.get("amount", 1)
		var id = input.get("id", "")
		var have = ChemistryAPIManager.get_inventory_element_amount(id)
		var have_compound = ChemistryAPIManager.get_inventory_compound_amount(id)
		var total_have = have + have_compound

		inputs_text += "• %d %s (have: %d)\n" % [amount, id, total_have]
	inputs_label.text = inputs_text

	# Outputs
	var outputs = reaction.get("outputs", [])
	var outputs_text = "Produces:\n"
	for output in outputs:
		outputs_text += "• %d %s\n" % [output.get("amount", 1), output.get("id", "")]
	outputs_label.text = outputs_text

	# Check if can perform
	var can_perform = _can_perform_reaction(reaction)
	perform_button.disabled = not can_perform

	if not can_perform:
		perform_button.text = "Cannot Perform (check materials/energy)"
	else:
		perform_button.text = "Perform Reaction"

	# Connect buttons
	if not perform_button.pressed.is_connected(_on_perform_reaction):
		perform_button.pressed.connect(_on_perform_reaction)
	if not close_button.pressed.is_connected(_on_close_detail):
		close_button.pressed.connect(_on_close_detail)

func _can_perform_reaction(reaction: Dictionary) -> bool:
	# Check energy
	var energy_cost = reaction.get("energy_cost", 0)
	var current_energy = ChemistryAPIManager.get_current_energy()
	if current_energy < energy_cost:
		return false

	# Check materials
	var inputs = reaction.get("inputs", [])
	for input in inputs:
		var amount = input.get("amount", 1)
		var id = input.get("id", "")
		var have = ChemistryAPIManager.get_inventory_element_amount(id)
		var have_compound = ChemistryAPIManager.get_inventory_compound_amount(id)

		if (have + have_compound) < amount:
			return false

	return true

func _on_perform_reaction() -> void:
	var reaction_id = selected_reaction.get("id", 0)
	if reaction_id <= 0:
		return

	print("🧪 Performing reaction: ", selected_reaction.get("reaction_name"))
	ChemistryAPIManager.perform_reaction(reaction_id)

	# Hide detail panel
	reaction_detail_panel.visible = false

func _on_close_detail() -> void:
	reaction_detail_panel.visible = false

## ============================================================================
## REACTION RESULT
## ============================================================================

func _on_reaction_completed(result: Dictionary) -> void:
	_show_result_popup(result)
	_refresh_all_data()

func _on_reaction_failed(error: String) -> void:
	_show_error_popup(error)

func _show_result_popup(result: Dictionary) -> void:
	result_popup.visible = true

	var title_label = result_popup.get_node("TitleLabel")
	var result_label = result_popup.get_node("ResultLabel")
	var close_button = result_popup.get_node("CloseButton")

	var success = result.get("success", false)
	var reaction_name = result.get("reaction_name", "")
	var energy_spent = result.get("energy_spent", 0)

	if success:
		title_label.text = "✅ REACTION SUCCESS!"
		title_label.modulate = Color(0.3, 1.0, 0.3)

		var outputs = result.get("outputs_created", [])
		var outputs_text = "Reaction: %s\nEnergy: %d⚡\n\nProduced:\n" % [reaction_name, energy_spent]

		for output in outputs:
			outputs_text += "• %d %s\n" % [output.get("amount", 1), output.get("id", "")]

		# Check for discovery
		if result.has("discovery"):
			var discovery = result.get("discovery")
			outputs_text += "\n🎉 FIRST DISCOVERY!\n"
			outputs_text += "Compound: %s\n" % discovery.get("compound_id", "")
			outputs_text += "Tax-free until: %s" % discovery.get("tax_free_until", "")

		result_label.text = outputs_text
	else:
		title_label.text = "❌ REACTION FAILED"
		title_label.modulate = Color(1.0, 0.3, 0.3)

		result_label.text = "Reaction: %s\nEnergy: %d⚡\n\nMaterials consumed but reaction failed.\nTry again!" % [
			reaction_name,
			energy_spent
		]

	if not close_button.pressed.is_connected(_on_close_result):
		close_button.pressed.connect(_on_close_result)

func _show_error_popup(error: String) -> void:
	result_popup.visible = true

	var title_label = result_popup.get_node("TitleLabel")
	var result_label = result_popup.get_node("ResultLabel")
	var close_button = result_popup.get_node("CloseButton")

	title_label.text = "⚠️ ERROR"
	title_label.modulate = Color(1.0, 0.5, 0.0)
	result_label.text = error

	if not close_button.pressed.is_connected(_on_close_result):
		close_button.pressed.connect(_on_close_result)

func _on_close_result() -> void:
	result_popup.visible = false

## ============================================================================
## INVENTORY TAB
## ============================================================================

func _populate_inventory_list(inventory: Dictionary) -> void:
	# Clear existing
	for child in inventory_list.get_children():
		child.queue_free()

	# Elements
	var elements_header = Label.new()
	elements_header.text = "=== ELEMENTS ==="
	elements_header.add_theme_font_size_override("font_size", 20)
	inventory_list.add_child(elements_header)

	var elements = inventory.get("elements", [])
	for element in elements:
		var label = Label.new()
		label.text = "• %s × %s" % [element.get("item_id", ""), element.get("amount", "0")]
		inventory_list.add_child(label)

	if elements.size() == 0:
		var label = Label.new()
		label.text = "(no elements)"
		label.modulate = Color(0.5, 0.5, 0.5)
		inventory_list.add_child(label)

	# Compounds
	var compounds_header = Label.new()
	compounds_header.text = "\n=== COMPOUNDS ==="
	compounds_header.add_theme_font_size_override("font_size", 20)
	inventory_list.add_child(compounds_header)

	var compounds = inventory.get("compounds", [])
	for compound in compounds:
		var label = Label.new()
		label.text = "• %s × %s" % [compound.get("item_id", ""), compound.get("amount", "0")]
		inventory_list.add_child(label)

	if compounds.size() == 0:
		var label = Label.new()
		label.text = "(no compounds)"
		label.modulate = Color(0.5, 0.5, 0.5)
		inventory_list.add_child(label)
