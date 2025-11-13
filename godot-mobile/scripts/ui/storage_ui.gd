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
			add_element_item(element, amount)

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

func add_element_item(element: String, amount: int) -> void:
	var item = HBoxContainer.new()

	var label = Label.new()
	label.text = "⚫ %s × %d" % [element, amount]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_child(label)

	var info_button = Button.new()
	info_button.text = "INFO"
	item.add_child(info_button)

	var use_button = Button.new()
	use_button.text = "USE"
	item.add_child(use_button)

	elements_tab.add_child(item)

func add_isotope_item(isotope: Dictionary) -> void:
	var item = HBoxContainer.new()

	var time_left = isotope.get("decay_time", 0) - Time.get_unix_time_from_system()
	var hours_left = max(0, int(time_left / 3600.0))

	var label = Label.new()
	label.text = "💎 %s × %d ⏱️%dh" % [
		isotope.get("type", "?"),
		isotope.get("amount", 1),
		hours_left
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

func _on_close_button_pressed() -> void:
	queue_free()
