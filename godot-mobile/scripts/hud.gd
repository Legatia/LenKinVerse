extends CanvasLayer
## HUD overlay with stats display and menu button

@onready var charge_label: Label = $TopBar/ChargeLabel
@onready var lkc_label: Label = $TopBar/LKCLabel
@onready var raw_label: Label = $TopBar/RawLabel
@onready var profile_button: Button = $TopBar/ProfileButton
@onready var gloves_button: Button = $GlovesButton

func _ready() -> void:
	# Load button icons from asset_config.json
	_setup_gloves_button_icon()
	_setup_profile_button_icon()

	# Connect buttons
	profile_button.pressed.connect(_on_profile_button_pressed)
	gloves_button.pressed.connect(_on_gloves_button_pressed)

	# Update stats on ready
	update_stats()

	# Connect to inventory changes
	if InventoryManager.has_signal("inventory_changed"):
		InventoryManager.inventory_changed.connect(update_stats)

func _setup_gloves_button_icon() -> void:
	"""Programmatically load and apply gloves icon from asset_config.json"""
	var icon_texture = AssetManager.get_ui_icon("gloves_button")

	if icon_texture is Texture2D:
		# Create an ImageTexture to resize the icon
		var image = icon_texture.get_image()
		# Resize to match corner button size (30x30)
		image.resize(30, 30, Image.INTERPOLATE_LANCZOS)
		var resized_texture = ImageTexture.create_from_image(image)

		# Set the icon for the button
		gloves_button.icon = resized_texture
		# Clear any text that might be showing emoji
		gloves_button.text = ""
		# Set icon alignment
		gloves_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Disable expand to prevent stretching
		gloves_button.expand_icon = false
		print("HUD: Loaded gloves icon from asset_config.json (resized to 30x30)")
	else:
		# Fallback: Use emoji if icon loading fails
		var fallback = AssetManager.get_ui_fallback("gloves_button")
		gloves_button.text = fallback
		# Reduce font size to match button better
		gloves_button.add_theme_font_size_override("font_size", 24)
		print("HUD: Using fallback emoji for gloves button")

func _setup_profile_button_icon() -> void:
	"""Programmatically load and apply profile icon from asset_config.json"""
	var icon_texture = AssetManager.get_ui_icon("profile_button")

	if icon_texture is Texture2D:
		# Create an ImageTexture to resize the icon
		var image = icon_texture.get_image()
		# Resize to match top bar button size (24x24 for smaller top buttons)
		image.resize(24, 24, Image.INTERPOLATE_LANCZOS)
		var resized_texture = ImageTexture.create_from_image(image)

		# Set the icon for the button
		profile_button.icon = resized_texture
		# Clear any text that might be showing emoji
		profile_button.text = ""
		# Set icon alignment
		profile_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Disable expand to prevent stretching
		profile_button.expand_icon = false
		print("HUD: Loaded profile icon from asset_config.json (resized to 24x24)")
	else:
		# Fallback: Use emoji if icon loading fails
		var fallback = AssetManager.get_ui_fallback("profile_button")
		profile_button.text = fallback
		# Reduce font size to match button better
		profile_button.add_theme_font_size_override("font_size", 20)
		print("HUD: Using fallback emoji for profile button")

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

func _on_gloves_button_pressed() -> void:
	# Load and show gloves UI
	var gloves_scene = load("res://scenes/ui/gloves_ui.tscn")
	if gloves_scene:
		var gloves_instance = gloves_scene.instantiate()
		get_tree().root.add_child(gloves_instance)
	else:
		push_error("Failed to load gloves UI scene")
