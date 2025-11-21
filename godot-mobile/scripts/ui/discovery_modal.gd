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

# New registration UI elements
@onready var registration_container: VBoxContainer = $Panel/VBox/RegistrationContainer
@onready var registration_info: Label = $Panel/VBox/RegistrationContainer/RegistrationInfo
@onready var register_button: Button = $Panel/VBox/RegistrationContainer/RegisterButton
@onready var keep_unregistered_button: Button = $Panel/VBox/RegistrationContainer/KeepUnregisteredButton
@onready var queue_status_label: Label = $Panel/VBox/RegistrationContainer/QueueStatusLabel

var element_id: String = ""
var element_data: Dictionary = {}
var is_first_global_discovery: bool = false
var discovery_amount: int = 1

func _ready() -> void:
	# Connect buttons
	close_button.pressed.connect(_on_close_pressed)
	share_button.pressed.connect(_on_share_pressed)

	# Connect registration buttons (check if nodes exist)
	if register_button:
		register_button.pressed.connect(_on_register_pressed)
	if keep_unregistered_button:
		keep_unregistered_button.pressed.connect(_on_keep_unregistered_pressed)

	# Start entrance animation
	if animation_player:
		animation_player.play("discovery_entrance")

## Show discovery for element
func show_discovery(elem_id: String, discovery_method: String, rarity: int = 0, amount: int = 1, first_global: bool = false) -> void:
	element_id = elem_id
	discovery_amount = amount
	is_first_global_discovery = first_global
	element_data = DiscoveryManager.get_discovery_data(elem_id)

	# Check if this is already registered globally
	var already_registered = DiscoveryManager.is_element_registered(elem_id)

	# Update UI
	if first_global and not already_registered:
		title_label.text = "🎉 WORLD FIRST DISCOVERY! 🎉"
	else:
		title_label.text = "🎉 NEW DISCOVERY! 🎉"

	# Get element icon/emoji
	var icon = AssetManager.get_element_icon(elem_id, rarity)
	if icon is String:
		element_icon_label.text = icon
	else:
		element_icon_label.text = "✨"  # Fallback

	element_name_label.text = _get_element_full_name(elem_id)

	# Show rarity from config
	var rarity_levels = ReactionManager.rarity_config.get("rarity_levels", {})
	var rarity_str = str(rarity)

	if rarity_levels.has(rarity_str):
		var rarity_data = rarity_levels[rarity_str]
		var rarity_name = rarity_data.get("name", "Common")
		var rarity_color = Color(rarity_data.get("color", "#9CA3AF"))

		rarity_label.text = "⭐ %s" % rarity_name
		rarity_label.add_theme_color_override("font_color", rarity_color)
	else:
		# Fallback if config missing
		rarity_label.text = "⭐ Common"
		rarity_label.add_theme_color_override("font_color", Color(0.61, 0.64, 0.67))

	# Show description
	description_label.text = DiscoveryManager.get_element_description(elem_id)

	# Show discovery stats
	var method = discovery_method.replace("_", " ").capitalize()
	stats_label.text = "Discovered via: %s\nAmount: %d" % [method, amount]

	# Show/hide registration UI based on whether element is already registered
	if registration_container:
		if already_registered:
			# Already registered - show tax info
			registration_container.visible = true
			_show_tax_info()
		elif first_global:
			# First discovery globally - show registration choice
			registration_container.visible = true
			_show_registration_choice()
		else:
			# Not first, just add to personal codex
			registration_container.visible = false
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

## Show registration choice UI
func _show_registration_choice() -> void:
	if not registration_info or not register_button or not keep_unregistered_button:
		return

	registration_info.text = """💎 WORLD FIRST DISCOVERY! 💎

You are the FIRST to discover this element!

🏛️ REGISTER AS TOKEN (10 alSOL):
• Become Governor (Money Manager)
• Earn 10%% tax on all future discoveries
• Global announcement to all players
• Element becomes tradeable after 30 min
• Element spawns in wild after 30 min

🔬 KEEP UNREGISTERED (FREE):
• 10x isotope discovery rate (1%% vs 0.1%%)
• Multiply with gloves (uses LKC as catalyst)
• Secret advantage - only you know it exists
• Can register later (but lose governorship)
• Perks disappear once registered

Choose wisely!"""

	register_button.visible = true
	register_button.text = "Register Token (10 alSOL)"
	keep_unregistered_button.visible = true
	keep_unregistered_button.text = "Keep Unregistered (Free)"

	if queue_status_label:
		queue_status_label.visible = false

	# Hide share and close buttons until choice is made
	if share_button:
		share_button.visible = false
	close_button.text = "Decide Later"

## Show tax info for already-registered elements
func _show_tax_info() -> void:
	if not registration_info or not register_button or not keep_unregistered_button:
		return

	var governor_name = DiscoveryManager.get_element_governor(element_id)
	var is_tradeable = DiscoveryManager.is_element_tradeable(element_id)

	var tax_rate = 10  # 10% tax
	var taxed_amount = int(discovery_amount * 0.1)
	var received_amount = discovery_amount - taxed_amount

	var compensation_text = ""
	if not is_tradeable:
		# During lock period - 2x compensation
		received_amount = discovery_amount * 2 - taxed_amount
		compensation_text = "\n✨ 2x COMPENSATION (Lock Period Active)"

	registration_info.text = """ℹ️ ELEMENT ALREADY REGISTERED

Governor: %s
Status: %s
Tax: %d%% (%d units to treasury)
You receive: %d units%s

This element has been discovered and registered by another player.""" % [
		governor_name,
		"🔒 Locked (tradeable soon)" if not is_tradeable else "✅ Tradeable",
		tax_rate,
		taxed_amount,
		received_amount,
		compensation_text
	]

	register_button.visible = false
	keep_unregistered_button.visible = false
	if queue_status_label:
		queue_status_label.visible = false

	# Show close button normally
	close_button.text = "Close"
	if share_button:
		share_button.visible = true

## Handle registration button press
func _on_register_pressed() -> void:
	# Check if player has enough alSOL
	var alsol_balance = WalletManager.get_alsol_balance()
	if alsol_balance < 10:
		if registration_info:
			registration_info.text = "❌ INSUFFICIENT BALANCE\n\nYou need 10 alSOL to register.\nYour balance: %.2f alSOL\n\nChoose 'Keep Unregistered' for free." % alsol_balance
		return

	# Check registration queue
	var queue_status = DiscoveryManager.check_registration_queue(element_id)

	if queue_status == "in_queue":
		# Someone else is registering
		if queue_status_label:
			queue_status_label.visible = true
			queue_status_label.text = "⏳ Another player is registering...\nYou are in queue. Waiting for confirmation..."

		register_button.disabled = true

		# Start monitoring queue
		_monitor_registration_queue()
		return

	# Initiate registration
	DiscoveryManager.initiate_registration(element_id, discovery_amount)

	# Update UI
	if queue_status_label:
		queue_status_label.visible = true
		queue_status_label.text = "💫 Processing registration...\nWaiting for blockchain confirmation..."

	register_button.disabled = true
	keep_unregistered_button.disabled = true

	# Mock registration (in real version, wait for WalletManager transaction)
	await _perform_registration()

## Handle keep unregistered button press
func _on_keep_unregistered_pressed() -> void:
	# Store as unregistered element
	InventoryManager.add_unregistered_element(element_id, discovery_amount)

	# Add to personal codex as unregistered
	var rarity = element_data.get("rarity", 0)
	DiscoveryManager.discover_element(element_id, "nuclear_fusion", rarity, true)  # true = unregistered

	# Update UI
	if registration_info:
		registration_info.text = """✅ KEPT UNREGISTERED

The element has been added to your inventory as unregistered.

🔬 Active Perks:
• 10x isotope rate when processing (1%%)
• Can multiply with gloves using LKC
• Secret - invisible to other players

⚠️ These perks end if element is registered by anyone."""

	register_button.visible = false
	keep_unregistered_button.visible = false

	# Enable close
	close_button.text = "Close"
	if share_button:
		share_button.visible = true

## Monitor registration queue (called when player is waiting in line)
func _monitor_registration_queue() -> void:
	while true:
		await get_tree().create_timer(1.0).timeout

		var queue_status = DiscoveryManager.check_registration_queue(element_id)

		if queue_status == "registered":
			# Registration completed by someone else
			var governor = DiscoveryManager.get_element_governor(element_id)

			if governor == WalletManager.get_wallet_address():
				# We became co-governor!
				if registration_info:
					registration_info.text = """🎉 CO-GOVERNOR ASSIGNED!

You registered simultaneously with another player.

Your Role: Element School Master (Future)
Revenue Share: 50%% of tax revenue
Joint liquidity pool created.

Global announcement sent!"""
			else:
				# Someone else became governor
				if registration_info:
					registration_info.text = """ℹ️ ELEMENT REGISTERED

Another player completed registration first.
They are now the governor.

Your element has been converted to registered status.
Tax applies to future discoveries."""

			register_button.visible = false
			keep_unregistered_button.visible = false
			if queue_status_label:
				queue_status_label.visible = false

			close_button.text = "Close"
			if share_button:
				share_button.visible = true

			break
		elif queue_status == "available":
			# Now it's our turn!
			if queue_status_label:
				queue_status_label.text = "✅ Your turn! Processing registration..."

			await _perform_registration()
			break

## Perform the actual registration (mock for now, will call WalletManager in production)
func _perform_registration() -> void:
	# Mock delay for blockchain transaction
	await get_tree().create_timer(2.0).timeout

	# In production: await WalletManager.register_element_token(element_id, 10.0)

	# Mock: Assume success
	var success = true
	var is_co_governor = false  # Random check in mock

	if success:
		# Register element in discovery manager
		var rarity = element_data.get("rarity", 0)
		var wallet_address = WalletManager.get_wallet_address()

		DiscoveryManager.register_element_globally(
			element_id,
			wallet_address,
			rarity,
			is_co_governor
		)

		# Show global announcement
		AnnouncementManager.announce_element_registered(
			element_id,
			wallet_address,
			rarity
		)

		# Update UI
		if registration_info:
			if is_co_governor:
				registration_info.text = """🎉 CO-GOVERNOR ASSIGNED!

You and another player registered simultaneously!

Your Role: Element School Master (Future)
Revenue Share: 50%% of tax revenue

Global announcement sent to all players!
Element will be tradeable in 30 minutes."""
			else:
				registration_info.text = """🎉 REGISTRATION SUCCESSFUL!

You are now the GOVERNOR of %s!

💰 Benefits:
• Earn 10%% tax on all discoveries
• Manage element liquidity
• Global announcement sent!

🔒 30-minute lock period active
Element becomes tradeable and spawns in wild after lock.""" % _get_element_full_name(element_id)

		register_button.visible = false
		keep_unregistered_button.visible = false
		if queue_status_label:
			queue_status_label.visible = false

		close_button.text = "Close"
		if share_button:
			share_button.visible = true
	else:
		# Failed
		if registration_info:
			registration_info.text = "❌ REGISTRATION FAILED\n\nTransaction failed. Please try again.\nYour alSOL has been refunded."

		register_button.disabled = false
		keep_unregistered_button.disabled = false
		if queue_status_label:
			queue_status_label.visible = false
