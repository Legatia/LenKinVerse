extends Control
## Storage Box UI - displays and manages inventory

@onready var raw_materials_tab: VBoxContainer = $Panel/TabContainer/RawMaterials
@onready var elements_tab: VBoxContainer = $Panel/TabContainer/Elements
@onready var isotopes_tab: VBoxContainer = $Panel/TabContainer/Isotopes

func _ready() -> void:
	refresh_inventory()

	# Connect to inventory updates
	InventoryManager.inventory_changed.connect(refresh_inventory)

func refresh_inventory() -> void:
	# Clear existing items
	for child in raw_materials_tab.get_children():
		if child.name != "RawLKCItem":  # Keep template
			child.queue_free()

	# Populate raw materials
	for element in InventoryManager.raw_materials:
		var amount = InventoryManager.raw_materials[element]
		if amount > 0:
			add_raw_material_item(element, amount)

	# Populate elements
	for child in elements_tab.get_children():
		if child.name != "LKCItem":  # Keep template
			child.queue_free()

	for element in InventoryManager.elements:
		var amount = InventoryManager.elements[element]
		if amount > 0:
			add_element_item(element, amount, false)

	# Populate unregistered elements (special display)
	for element in InventoryManager.unregistered_elements:
		var amount = InventoryManager.unregistered_elements[element]
		if amount > 0:
			add_element_item(element, amount, true)

	# Populate isotopes
	for child in isotopes_tab.get_children():
		if child.name != "C14Item":  # Keep template
			child.queue_free()

	for isotope in InventoryManager.isotopes:
		add_isotope_item(isotope)

func add_raw_material_item(element: String, amount: int) -> void:
	var item = HBoxContainer.new()

	var label = Label.new()
	label.text = "⚫ raw %s × %d" % [element, amount]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_child(label)

	var button = Button.new()
	button.text = "ANALYZE"
	button.pressed.connect(func(): _analyze_material(element))
	item.add_child(button)

	raw_materials_tab.add_child(item)

func add_element_item(element: String, amount: int, is_unregistered: bool = false) -> void:
	var item = HBoxContainer.new()

	var label = Label.new()
	if is_unregistered:
		# Special display for unregistered elements
		label.text = "🔬 %s × %d [UNREGISTERED]" % [element, amount]
		label.add_theme_color_override("font_color", Color(0.96, 0.62, 0.04))  # Orange color
	else:
		label.text = "⚫ %s × %d" % [element, amount]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_child(label)

	if is_unregistered:
		# Add multiply button for unregistered elements
		var multiply_button = Button.new()
		multiply_button.text = "MULTIPLY"
		multiply_button.pressed.connect(func(): _multiply_unregistered(element))
		item.add_child(multiply_button)
	else:
		var info_button = Button.new()
		info_button.text = "INFO"
		item.add_child(info_button)

	var use_button = Button.new()
	use_button.text = "USE"
	item.add_child(use_button)

	elements_tab.add_child(item)

func add_isotope_item(isotope: Dictionary) -> void:
	var item = HBoxContainer.new()

	# Get current volume in units
	var volume = isotope.get("volume", 0.0)
	var reactions_available = int(volume * 2)  # Each unit supports 2 reactions

	# Color code based on volume remaining
	var volume_color = ""
	if volume >= 15:  # Healthy amount
		volume_color = "[color=#4CAF50]"  # Green
	elif volume >= 5:  # Medium
		volume_color = "[color=#FF9800]"  # Orange
	else:  # Low
		volume_color = "[color=#F44336]"  # Red

	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.custom_minimum_size = Vector2(220, 35)
	label.text = "💎 raw %s %s%.1f units[/color] ⚛️×%d" % [
		isotope.get("type", "?"),
		volume_color,
		volume,
		reactions_available
	]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_child(label)

	var use_button = Button.new()
	use_button.text = "USE"
	use_button.pressed.connect(func(): _use_isotope(isotope))
	item.add_child(use_button)

	isotopes_tab.add_child(item)

func _analyze_material(element: String) -> void:
	# Open gloves UI for analysis
	queue_free()
	var gloves_ui = load("res://scenes/ui/gloves_ui.tscn").instantiate()
	get_tree().root.add_child(gloves_ui)

func _use_isotope(isotope: Dictionary) -> void:
	print("Using isotope: ", isotope.get("type"))
	# TODO: Open reaction UI with this isotope selected

func _multiply_unregistered(element: String) -> void:
	# Open gloves UI for multiplication
	queue_free()
	var gloves_ui = load("res://scenes/ui/gloves_ui.tscn").instantiate()
	get_tree().root.add_child(gloves_ui)

	# Auto-select the unregistered element for multiplication
	gloves_ui.set_preselected_element(element)

	# Switch to Multiply tab (tab index 1)
	var tab_container = gloves_ui.get_node("Panel/TabContainer")
	if tab_container:
		tab_container.current_tab = 1

func _on_close_button_pressed() -> void:
	queue_free()
