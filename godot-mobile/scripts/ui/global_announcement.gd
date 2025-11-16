extends Control
## Global Announcement - shows important game-wide events

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var message_label: Label = $Panel/VBoxContainer/MessageLabel
@onready var icon_label: Label = $Panel/VBoxContainer/IconLabel

func _ready() -> void:
	# Start hidden
	modulate.a = 0.0
	visible = true

func show_announcement(announcement_type: String, data: Dictionary) -> void:
	"""
	Show global announcement based on type
	Types: element_registered, element_tradeable, governor_action
	"""
	match announcement_type:
		"element_registered":
			_show_element_registered(data)
		"element_tradeable":
			_show_element_tradeable(data)
		"governor_action":
			_show_governor_action(data)

	# Animate in
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	tween.tween_interval(4.0)  # Show for 4 seconds
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(_on_announcement_complete)

func _show_element_registered(data: Dictionary) -> void:
	"""Show announcement when new element is registered"""
	var element_id = data.get("element_id", "Unknown")
	var governor = data.get("governor", "Unknown")
	var rarity = data.get("rarity", 0)

	icon_label.text = "🎉"
	title_label.text = "NEW ELEMENT REGISTERED!"

	var rarity_name = ["Common", "Uncommon", "Rare", "Legendary"][rarity]
	message_label.text = "%s\n\n[%s]\n\nGovernor: %s\n\nTradeable in 30 minutes\nWild spawns will activate!" % [
		element_id,
		rarity_name,
		governor
	]

func _show_element_tradeable(data: Dictionary) -> void:
	"""Show announcement when element becomes tradeable"""
	var element_id = data.get("element_id", "Unknown")

	icon_label.text = "💰"
	title_label.text = "ELEMENT NOW TRADEABLE!"

	message_label.text = "%s is now available!\n\n✅ Trade on DEX\n✅ Wild spawns active\n✅ Bridge to chain" % element_id

func _show_governor_action(data: Dictionary) -> void:
	"""Show governor-related announcements"""
	var element_id = data.get("element_id", "Unknown")
	var action = data.get("action", "Unknown")
	var amount = data.get("amount", 0)

	icon_label.text = "👑"
	title_label.text = "GOVERNOR ACTION"

	match action:
		"bridge_to_chain":
			message_label.text = "%s governor bridged %d units to chain!\n\nMore wild spawns incoming!" % [element_id, amount]
		"add_liquidity":
			message_label.text = "%s governor added %d alSOL liquidity!\n\nPrices stabilizing!" % [element_id, amount]

func _on_announcement_complete() -> void:
	queue_free()
