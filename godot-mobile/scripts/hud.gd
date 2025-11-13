extends CanvasLayer
## HUD overlay with stats display and menu button

@onready var charge_label: Label = $TopBar/ChargeLabel
@onready var lkc_label: Label = $TopBar/LKCLabel
@onready var raw_label: Label = $TopBar/RawLabel
@onready var profile_button: Button = $TopBar/ProfileButton

func _ready() -> void:
	# Connect profile button
	profile_button.pressed.connect(_on_profile_button_pressed)

	# Update stats on ready
	update_stats()

	# Connect to inventory changes
	if InventoryManager.has_signal("inventory_changed"):
		InventoryManager.inventory_changed.connect(update_stats)

func _process(_delta: float) -> void:
	# Update stats every frame for real-time display
	update_stats()

func update_stats() -> void:
	# Get gloves charge
	var gloves_data = load_gloves_data()
	var charge = gloves_data.get("current_charge", 0)
	charge_label.text = "⚡ %d" % charge

	# Get lkC (cleaned elements)
	var lkc = InventoryManager.elements.get("lkC", 0)
	lkc_label.text = "💰 %s lkC" % format_number(lkc)

	# Get raw lkC
	var raw = InventoryManager.raw_materials.get("lkC", 0)
	raw_label.text = "⚫ %s raw" % format_number(raw)

func load_gloves_data() -> Dictionary:
	var save_path = "user://gloves.save"
	if not FileAccess.file_exists(save_path):
		return {"current_charge": 50}

	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			return json.data

	return {"current_charge": 50}

func format_number(num: int) -> String:
	if num < 1000:
		return str(num)

	var str_num = str(num)
	var result = ""
	var counter = 0

	for i in range(str_num.length() - 1, -1, -1):
		if counter == 3:
			result = "," + result
			counter = 0
		result = str_num[i] + result
		counter += 1

	return result

func _on_profile_button_pressed() -> void:
	# Load and show profile UI
	var profile_scene = load("res://scenes/ui/profile_ui.tscn")
	if profile_scene:
		var profile_instance = profile_scene.instantiate()
		get_tree().root.add_child(profile_instance)
	else:
		push_error("Failed to load profile UI scene")
