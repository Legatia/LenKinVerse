extends Node
## Manages global announcements for important game events

const AnnouncementScene = preload("res://scenes/ui/global_announcement.tscn")

# Queue of pending announcements
var announcement_queue: Array[Dictionary] = []
var current_announcement: Control = null

func _ready() -> void:
	# Connect to discovery manager for element events
	DiscoveryManager.element_became_tradeable.connect(_on_element_tradeable)

	# Start processing queue
	var timer = Timer.new()
	timer.wait_time = 0.5
	timer.timeout.connect(_process_queue)
	add_child(timer)
	timer.start()

## Show announcement (adds to queue)
func show_announcement(announcement_type: String, data: Dictionary) -> void:
	announcement_queue.append({
		"type": announcement_type,
		"data": data
	})

## Process announcement queue
func _process_queue() -> void:
	# Skip if currently showing an announcement
	if current_announcement != null and is_instance_valid(current_announcement):
		return

	# Skip if queue is empty
	if announcement_queue.is_empty():
		return

	# Show next announcement
	var announcement = announcement_queue.pop_front()
	_show_next_announcement(announcement["type"], announcement["data"])

## Show next announcement from queue
func _show_next_announcement(announcement_type: String, data: Dictionary) -> void:
	# Get root to add announcement
	var root = get_tree().root

	# Create announcement
	var announcement_instance = AnnouncementScene.instantiate()
	root.add_child(announcement_instance)

	# Track current announcement
	current_announcement = announcement_instance

	# Show announcement
	announcement_instance.show_announcement(announcement_type, data)

	print("📢 Global Announcement: %s" % announcement_type)

## ========================================
## EVENT HANDLERS
## ========================================

func _on_element_tradeable(element_id: String) -> void:
	"""Called when an element becomes tradeable (30 min lock ended)"""
	var reg_data = DiscoveryManager.element_registry.get(element_id, {})

	show_announcement("element_tradeable", {
		"element_id": element_id,
		"governor": reg_data.get("governor", "Unknown"),
		"rarity": reg_data.get("rarity", 0)
	})

## Called when element is registered (from discovery modal)
func announce_element_registered(element_id: String, governor: String, rarity: int) -> void:
	show_announcement("element_registered", {
		"element_id": element_id,
		"governor": governor.substr(0, 8) + "...",
		"rarity": rarity
	})

## Called when governor performs bridge action
func announce_governor_action(element_id: String, action: String, amount: int) -> void:
	show_announcement("governor_action", {
		"element_id": element_id,
		"action": action,
		"amount": amount
	})
