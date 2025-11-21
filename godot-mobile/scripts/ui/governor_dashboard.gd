extends Control
## Governor Dashboard - manage your governed elements

@onready var elements_container: VBoxContainer = $Panel/ScrollContainer/ElementsContainer
@onready var no_elements_label: Label = $Panel/NoElementsLabel
@onready var close_button: Button = $Panel/CloseButton

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	refresh_governed_elements()

func refresh_governed_elements() -> void:
	# Clear existing items
	for child in elements_container.get_children():
		child.queue_free()

	# Get player wallet address
	var wallet_address = WalletManager.get_wallet_address()

	# Find all elements governed by player
	var governed_elements = []
	for element_id in DiscoveryManager.element_registry:
		var reg_data = DiscoveryManager.element_registry[element_id]
		var governor = reg_data.get("governor", "")
		var co_governor = reg_data.get("co_governor", null)

		# Check if player is governor or co-governor
		if governor == wallet_address or co_governor == wallet_address:
			governed_elements.append({
				"element_id": element_id,
				"is_governor": governor == wallet_address,
				"is_co_governor": co_governor == wallet_address,
				"data": reg_data
			})

	# Show appropriate UI
	if governed_elements.is_empty():
		no_elements_label.visible = true
		elements_container.visible = false
	else:
		no_elements_label.visible = false
		elements_container.visible = true

		# Add UI for each governed element
		for element in governed_elements:
			_add_governor_panel(element)

func _add_governor_panel(element: Dictionary) -> void:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(0, 200)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)

	# Header
	var header = HBoxContainer.new()
	vbox.add_child(header)

	var name_label = Label.new()
	name_label.text = element["element_id"]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)

	var role_label = Label.new()
	if element["is_governor"]:
		role_label.text = "👑 GOVERNOR"
		role_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	else:
		role_label.text = "🎓 CO-GOVERNOR"
		role_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	header.add_child(role_label)

	# Status
	var status_label = Label.new()
	var is_tradeable = DiscoveryManager.is_element_tradeable(element["element_id"])
	if is_tradeable:
		status_label.text = "Status: ✅ TRADEABLE"
		status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		var time_remaining = element["data"].get("tradeable_at", 0) - Time.get_unix_time_from_system()
		var minutes = int(time_remaining / 60)
		status_label.text = "Status: 🔒 LOCKED (%d min)" % minutes
		status_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0))
	vbox.add_child(status_label)

	# Treasury info
	var treasury_balance = DiscoveryManager.get_treasury_balance(element["element_id"])
	var total_taxed = element["data"].get("total_taxed", 0)

	var treasury_label = Label.new()
	treasury_label.text = "Treasury: %d units\nTotal Taxed: %d units" % [treasury_balance, total_taxed]
	vbox.add_child(treasury_label)

	# Separator
	var separator = HSeparator.new()
	vbox.add_child(separator)

	# Actions (only for governor, not co-governor)
	if element["is_governor"]:
		var actions_label = Label.new()
		actions_label.text = "Governor Actions:"
		vbox.add_child(actions_label)

		# Bridge to chain button
		var bridge_button = Button.new()
		bridge_button.text = "Bridge %d to Chain (Mock)" % min(treasury_balance, 100)
		bridge_button.disabled = treasury_balance < 100 or not is_tradeable
		bridge_button.pressed.connect(func(): _on_bridge_pressed(element["element_id"]))
		vbox.add_child(bridge_button)

		# View analytics button
		var analytics_button = Button.new()
		analytics_button.text = "View Analytics"
		analytics_button.pressed.connect(func(): _on_analytics_pressed(element["element_id"]))
		vbox.add_child(analytics_button)
	else:
		var co_gov_info = Label.new()
		co_gov_info.text = "Co-governors have view access only.\nGovernor manages treasury & bridge."
		co_gov_info.autowrap_mode = TextServer.AUTOWRAP_WORD
		co_gov_info.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		vbox.add_child(co_gov_info)

	elements_container.add_child(panel)

func _on_bridge_pressed(element_id: String) -> void:
	"""Bridge treasury balance to on-chain"""
	var treasury_balance = DiscoveryManager.get_treasury_balance(element_id)
	var amount_to_bridge = min(treasury_balance, 100)

	if amount_to_bridge <= 0:
		print("No treasury balance to bridge")
		return

	# Mock bridge operation
	print("Bridging %d %s to chain..." % [amount_to_bridge, element_id])

	# Deduct from treasury
	DiscoveryManager.element_registry[element_id]["treasury_balance"] -= amount_to_bridge
	DiscoveryManager.save_codex()

	# Show announcement
	AnnouncementManager.announce_governor_action(
		element_id,
		"bridge_to_chain",
		amount_to_bridge
	)

	# Refresh UI
	refresh_governed_elements()

	print("✅ Bridged %d %s to chain!" % [amount_to_bridge, element_id])

func _on_analytics_pressed(element_id: String) -> void:
	"""Show analytics for governed element"""
	var reg_data = DiscoveryManager.element_registry.get(element_id, {})
	var codex_data = DiscoveryManager.codex.get(element_id, {})

	var message = "📊 ANALYTICS: %s\n\n" % element_id
	message += "Registered: %s\n" % Time.get_datetime_string_from_unix_time(reg_data.get("registered_at", 0))
	message += "Total Created (Global): %d\n" % codex_data.get("total_created", 0)
	message += "Total Taxed: %d\n" % reg_data.get("total_taxed", 0)
	message += "Treasury Balance: %d\n" % reg_data.get("treasury_balance", 0)
	message += "Rarity: %d\n" % reg_data.get("rarity", 0)

	# Show as simple print for now (could be a modal)
	print(message)

	# TODO: Create analytics modal

func _on_close_pressed() -> void:
	queue_free()
