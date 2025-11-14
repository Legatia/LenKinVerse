extends Control
## Discovery modal - shows celebration when discovering new element

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var element_icon_label: Label = $Panel/VBox/ElementIcon
@onready var element_name_label: Label = $Panel/VBox/ElementNameLabel
@onready var rarity_label: Label = $Panel/VBox/RarityLabel
@onready var description_label: Label = $Panel/VBox/DescriptionLabel
@onready var stats_label: Label = $Panel/VBox/StatsLabel
@onready var close_button: Button = $Panel/VBox/CloseButton
@onready var share_button: Button = $Panel/VBox/ShareButton
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var element_id: String = ""
var element_data: Dictionary = {}

func _ready() -> void:
	# Connect buttons
	close_button.pressed.connect(_on_close_pressed)
	share_button.pressed.connect(_on_share_pressed)

	# Start entrance animation
	if animation_player:
		animation_player.play("discovery_entrance")

## Show discovery for element
func show_discovery(elem_id: String, discovery_method: String, rarity: int = 0) -> void:
	element_id = elem_id
	element_data = DiscoveryManager.get_discovery_data(elem_id)

	# Update UI
	title_label.text = "🎉 NEW DISCOVERY! 🎉"

	# Get element icon/emoji
	var icon = AssetManager.get_element_icon(elem_id, rarity)
	if icon is String:
		element_icon_label.text = icon
	else:
		element_icon_label.text = "✨"  # Fallback

	element_name_label.text = _get_element_full_name(elem_id)

	# Show rarity
	var rarity_names = ["Common", "Uncommon", "Rare", "Legendary"]
	var rarity_colors = [
		Color(0.61, 0.64, 0.67),  # Gray
		Color(0.06, 0.72, 0.51),  # Green
		Color(0.23, 0.51, 0.96),  # Blue
		Color(0.55, 0.36, 0.97)   # Purple
	]

	if rarity < rarity_names.size():
		rarity_label.text = "⭐ %s" % rarity_names[rarity]
		rarity_label.add_theme_color_override("font_color", rarity_colors[rarity])

	# Show description
	description_label.text = DiscoveryManager.get_element_description(elem_id)

	# Show discovery stats
	var discovery_date = Time.get_datetime_string_from_unix_time(element_data.get("discovered_at", 0))
	var method = discovery_method.replace("_", " ").capitalize()
	stats_label.text = "Discovered via: %s\nDate: %s" % [method, discovery_date]

	# Add to codex (if not already added)
	if not DiscoveryManager.is_discovered(elem_id):
		DiscoveryManager.discover_element(elem_id, discovery_method, rarity)

## Get full element name
func _get_element_full_name(elem_id: String) -> String:
	var names = {
		"CO2": "Carbon Dioxide",
		"H2O": "Water",
		"Coal": "Coal",
		"Carbon_X": "Carbon-X (Unknown)",
		"lkC": "Lennard-Kinsium Carbon",
		"lkO": "Lennard-Kinsium Oxygen",
		"lkH": "Lennard-Kinsium Hydrogen"
	}
	return names.get(elem_id, elem_id)

func _on_close_pressed() -> void:
	# Play exit animation
	if animation_player and animation_player.has_animation("discovery_exit"):
		animation_player.play("discovery_exit")
		await animation_player.animation_finished

	queue_free()

func _on_share_pressed() -> void:
	# TODO: Share to social media
	var share_text = "I just discovered %s in LenKinVerse! 🎉 #LenKinVerse #Web3Gaming" % _get_element_full_name(element_id)
	print("Share: ", share_text)

	# On mobile, could use OS.shell_open() or native share
	# For now, just copy to clipboard
	DisplayServer.clipboard_set(share_text)

	var original_text = share_button.text
	share_button.text = "Copied!"
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(share_button):
		share_button.text = original_text
