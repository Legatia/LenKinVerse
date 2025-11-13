extends Control
## World/Blockchain selection screen

@onready var world_container: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/WorldContainer
@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $Panel/VBoxContainer/SubtitleLabel

# Preload world button scene (we'll create buttons dynamically)
var world_button_scene: PackedScene

func _ready() -> void:
	create_world_buttons()

func create_world_buttons() -> void:
	# Clear existing buttons
	for child in world_container.get_children():
		child.queue_free()

	# Create button for each world
	for world_id in WorldManager.worlds.keys():
		var world_data = WorldManager.worlds[world_id]

		if not world_data.get("enabled", false):
			continue

		# Create button container
		var button = Button.new()
		button.custom_minimum_size = Vector2(280, 100)

		# Create rich label for button content
		var vbox = VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# World name with icon
		var name_label = Label.new()
		name_label.text = "%s %s" % [world_data.get("icon", ""), world_data.get("display_name", "")]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(name_label)

		# Description
		var desc_label = Label.new()
		desc_label.text = world_data.get("description", "")
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(desc_label)

		# Add vbox to button
		button.add_child(vbox)

		# Center the vbox
		vbox.position = Vector2(10, 10)
		vbox.size = Vector2(260, 80)

		# Connect button signal
		button.pressed.connect(_on_world_selected.bind(world_id))

		# Style button with world color (via modulate)
		var world_color = world_data.get("color", Color.WHITE)
		button.modulate = Color(world_color.r * 0.3 + 0.7, world_color.g * 0.3 + 0.7, world_color.b * 0.3 + 0.7, 1.0)

		world_container.add_child(button)

func _on_world_selected(world_id: String) -> void:
	# Save selection
	WorldManager.select_world(world_id)

	# Show confirmation
	var world_data = WorldManager.worlds[world_id]
	title_label.text = "✅ %s Selected!" % world_data.get("display_name", "")
	subtitle_label.text = "Loading game..."

	# Disable all buttons
	for button in world_container.get_children():
		if button is Button:
			button.disabled = true

	# Transition to main game after brief delay
	await get_tree().create_timer(1.5).timeout
	transition_to_game()

func transition_to_game() -> void:
	# Check if this is first launch (to show tutorial)
	if GameManager.is_first_launch:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	else:
		# Calculate offline rewards first
		get_tree().change_scene_to_file("res://scenes/ui/offline_rewards.tscn")
