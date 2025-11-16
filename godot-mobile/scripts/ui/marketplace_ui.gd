extends Control
## Marketplace UI - buy, sell, and mint tokens/NFTs

@onready var wallet_label: Label = $Panel/VBoxContainer/WalletInfo/WalletLabel
@onready var balance_label: Label = $Panel/VBoxContainer/WalletInfo/BalanceLabel
@onready var inventory_container: VBoxContainer = $Panel/VBoxContainer/TabContainer/Sell/InventoryContainer
@onready var mintable_items: VBoxContainer = $Panel/VBoxContainer/TabContainer/Mint/MintableItems

# Get alSOL tab nodes
@onready var sol_input: LineEdit = $"Panel/VBoxContainer/TabContainer/Get alSOL/ScrollContainer/VBoxContainer/SOLPanel/VBoxContainer/AmountContainer/SOLInput"
@onready var sol_result_label: Label = $"Panel/VBoxContainer/TabContainer/Get alSOL/ScrollContainer/VBoxContainer/SOLPanel/VBoxContainer/ResultLabel"
@onready var buy_sol_button: Button = $"Panel/VBoxContainer/TabContainer/Get alSOL/ScrollContainer/VBoxContainer/SOLPanel/VBoxContainer/BuySOLButton"

@onready var lkc_input: LineEdit = $"Panel/VBoxContainer/TabContainer/Get alSOL/ScrollContainer/VBoxContainer/LKCPanel/VBoxContainer/AmountContainer/LKCInput"
@onready var lkc_result_label: Label = $"Panel/VBoxContainer/TabContainer/Get alSOL/ScrollContainer/VBoxContainer/LKCPanel/VBoxContainer/ResultLabel"
@onready var limit_progress: ProgressBar = $"Panel/VBoxContainer/TabContainer/Get alSOL/ScrollContainer/VBoxContainer/LKCPanel/VBoxContainer/LimitPanel/VBoxContainer/ProgressBar"
@onready var usage_label: Label = $"Panel/VBoxContainer/TabContainer/Get alSOL/ScrollContainer/VBoxContainer/LKCPanel/VBoxContainer/LimitPanel/VBoxContainer/UsageLabel"
@onready var reset_label: Label = $"Panel/VBoxContainer/TabContainer/Get alSOL/ScrollContainer/VBoxContainer/LKCPanel/VBoxContainer/LimitPanel/VBoxContainer/ResetLabel"
@onready var buy_lkc_button: Button = $"Panel/VBoxContainer/TabContainer/Get alSOL/ScrollContainer/VBoxContainer/LKCPanel/VBoxContainer/BuyLKCButton"

# alSOL swap state
const LKC_PER_ALSOL: int = 1_000_000
const MIN_ALSOL_LAMPORTS: int = 1_000_000  # 0.001 alSOL
const WEEK_IN_SECONDS: int = 7 * 24 * 60 * 60
const MAX_WEEKLY_ALSOL_LAMPORTS: int = 1_000_000_000  # 1 alSOL

var weekly_alsol_used_lamports: int = 0
var week_start_time: int = 0

func _ready() -> void:
	update_wallet_info()
	populate_sell_inventory()
	populate_mintable_items()

	# Load swap history
	load_swap_history()
	update_alsol_ui()

	# Connect to wallet events
	WalletManager.wallet_connected.connect(func(_addr): update_wallet_info())
	WalletManager.wallet_disconnected.connect(func(): update_wallet_info())

	# Connect alSOL swap UI events
	sol_input.text_changed.connect(_on_sol_input_changed)
	lkc_input.text_changed.connect(_on_lkc_input_changed)
	buy_sol_button.pressed.connect(_on_buy_sol_pressed)
	buy_lkc_button.pressed.connect(_on_buy_lkc_pressed)

func update_wallet_info() -> void:
	if WalletManager.is_connected:
		var address = WalletManager.wallet_address
		var short_address = "%s...%s" % [address.substr(0, 4), address.substr(-4, 4)]
		wallet_label.text = "Wallet: %s" % short_address

		# Get balance
		var balance = await WalletManager.get_balance()
		balance_label.text = "Balance: %.2f SOL" % balance
	else:
		wallet_label.text = "Wallet: Not Connected"
		balance_label.text = "Balance: 0.00 SOL"

func populate_sell_inventory() -> void:
	# Clear existing items (keep empty label template)
	for child in inventory_container.get_children():
		if child.name != "EmptyLabel":
			child.queue_free()

	# Check if we have any elements to sell
	var has_items = false
	for element in InventoryManager.elements:
		var amount = InventoryManager.elements[element]
		if amount >= 10:  # Minimum 10 to sell
			has_items = true
			add_sellable_item(element, amount)

	# Show/hide empty label
	var empty_label = inventory_container.get_node("EmptyLabel")
	empty_label.visible = not has_items

func add_sellable_item(element: String, amount: int) -> void:
	var item = HBoxContainer.new()

	var label = Label.new()
	label.text = "⚫ %s × %d" % [element, amount]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_child(label)

	var sell_button = Button.new()
	sell_button.text = "SELL"
	sell_button.pressed.connect(func(): _start_selling(element, amount))
	item.add_child(sell_button)

	inventory_container.add_child(item)

func _start_selling(element: String, max_amount: int) -> void:
	print("Starting sell flow for: ", element, " (max: ", max_amount, ")")
	# TODO: Show sell dialog with amount/price inputs

func populate_mintable_items() -> void:
	# Clear existing
	for child in mintable_items.get_children():
		if child.name != "EmptyLabel":
			child.queue_free()

	# Check for mintable elements (compounds only)
	var has_mintable = false
	for element in InventoryManager.elements:
		# Skip basic elements, only allow compounds
		if element in ["lkC", "lkO", "lkN", "lkSi"]:
			continue

		var amount = InventoryManager.elements[element]
		if amount >= 1:
			has_mintable = true
			add_mintable_item(element, amount)

	# Show/hide empty label
	var empty_label = mintable_items.get_node("EmptyLabel")
	empty_label.visible = not has_mintable

func add_mintable_item(element: String, amount: int) -> void:
	var panel = Panel.new()

	var vbox = VBoxContainer.new()
	vbox.offset_left = 10
	vbox.offset_top = 10
	vbox.offset_right = -10
	vbox.offset_bottom = -10
	panel.add_child(vbox)

	var label = Label.new()
	label.text = "🔴 %s × %d → Mint as Token?" % [element, amount]
	vbox.add_child(label)

	var mint_button = Button.new()
	mint_button.text = "MINT TOKEN (Cost: 0.05 SOL)"
	mint_button.pressed.connect(func(): _mint_token(element, amount))
	vbox.add_child(mint_button)

	mintable_items.add_child(panel)

func _mint_token(element: String, amount: int) -> void:
	if not WalletManager.is_connected:
		show_message("Please connect wallet first!")
		return

	var balance = await WalletManager.get_balance()
	if balance < 0.05:
		show_message("Insufficient SOL for minting (need 0.05 SOL)")
		return

	show_message("🎨 Minting %s as NFT..." % element)

	# Build element data for NFT
	var element_data = {
		"element_id": element,
		"element_name": _get_element_full_name(element),
		"symbol": element,
		"rarity": _get_element_rarity(element),
		"amount": amount,
		"generation_method": _get_generation_method(element),
		"discovered_at": Time.get_unix_time_from_system()
	}

	# Connect to transaction signals
	var on_success: Callable
	var on_failure: Callable

	on_success = func(signature: String):
		show_message("✅ NFT minted successfully!\nSignature: %s" % signature)
		# Consume elements from inventory
		InventoryManager.consume_elements({element: amount})
		# Refresh UI
		populate_mintable_items()
		WalletManager.transaction_completed.disconnect(on_success)
		WalletManager.transaction_failed.disconnect(on_failure)

	on_failure = func(error: String):
		show_message("❌ Minting failed: %s" % error)
		WalletManager.transaction_completed.disconnect(on_success)
		WalletManager.transaction_failed.disconnect(on_failure)

	WalletManager.transaction_completed.connect(on_success)
	WalletManager.transaction_failed.connect(on_failure)

	# Start minting process
	WalletManager.mint_element_nft(element_data)

## Get full element name
func _get_element_full_name(symbol: String) -> String:
	match symbol:
		"lkC": return "Lennard-Kinsium Carbon"
		"lkO": return "Lennard-Kinsium Oxygen"
		"lkH": return "Lennard-Kinsium Hydrogen"
		"CO2": return "Carbon Dioxide"
		"H2O": return "Water"
		"Coal": return "Coal"
		_: return symbol

## Get element rarity
func _get_element_rarity(symbol: String) -> int:
	# Basic elements: Common (0)
	if symbol in ["lkC", "lkO", "lkH"]:
		return 0
	# Simple compounds: Uncommon (1)
	elif symbol in ["CO2", "H2O"]:
		return 1
	# Processed materials: Rare (2)
	elif symbol in ["Coal"]:
		return 2
	# Unknown/special: Rare (2)
	else:
		return 2

## Get generation method
func _get_generation_method(symbol: String) -> String:
	# Check if it was created via reaction
	if symbol in ["CO2", "H2O", "Coal"]:
		return "chemical_reaction"
	# Basic elements from walking
	else:
		return "walk_mining"

func show_message(text: String) -> void:
	print(text)
	# TODO: Show proper toast/modal

func _on_close_button_pressed() -> void:
	queue_free()

# ========================================
# alSOL SWAP SYSTEM
# ========================================

func load_swap_history() -> void:
	if not FileAccess.file_exists("user://swap_history.save"):
		week_start_time = int(Time.get_unix_time_from_system())
		weekly_alsol_used_lamports = 0
		return

	var file = FileAccess.open("user://swap_history.save", FileAccess.READ)
	if file:
		var data = file.get_var()
		week_start_time = data.get("week_start", int(Time.get_unix_time_from_system()))
		weekly_alsol_used_lamports = data.get("weekly_used", 0)
		file.close()

	# Check if week has passed, reset if so
	var current_time = int(Time.get_unix_time_from_system())
	if current_time - week_start_time >= WEEK_IN_SECONDS:
		week_start_time = current_time
		weekly_alsol_used_lamports = 0
		save_swap_history()

func save_swap_history() -> void:
	var data = {
		"week_start": week_start_time,
		"weekly_used": weekly_alsol_used_lamports
	}

	var file = FileAccess.open("user://swap_history.save", FileAccess.WRITE)
	if file:
		file.store_var(data)
		file.close()

func update_alsol_ui() -> void:
	# Update weekly limit UI
	var used_alsol = weekly_alsol_used_lamports / 1_000_000_000.0
	var max_alsol = MAX_WEEKLY_ALSOL_LAMPORTS / 1_000_000_000.0

	limit_progress.value = used_alsol / max_alsol
	usage_label.text = "Used: %.3f / %.3f alSOL" % [used_alsol, max_alsol]

	# Calculate time until reset
	var current_time = int(Time.get_unix_time_from_system())
	var time_until_reset = WEEK_IN_SECONDS - (current_time - week_start_time)
	var days = int(time_until_reset / 86400)
	var hours = int((time_until_reset % 86400) / 3600)
	var minutes = int((time_until_reset % 3600) / 60)
	reset_label.text = "Resets in: %dd %dh %dm" % [days, hours, minutes]

func _on_sol_input_changed(new_text: String) -> void:
	if new_text.is_empty():
		sol_result_label.text = "→ You get: 0.000 alSOL"
		return

	var sol_amount = new_text.to_float()
	if sol_amount <= 0:
		sol_result_label.text = "→ Invalid amount"
		sol_result_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
		return

	# 1:1 ratio for SOL
	sol_result_label.text = "→ You get: %.3f alSOL" % sol_amount
	sol_result_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))

func _on_lkc_input_changed(new_text: String) -> void:
	if new_text.is_empty():
		lkc_result_label.text = "→ You get: 0.000 alSOL"
		return

	var lkc_amount = new_text.to_int()
	if lkc_amount <= 0:
		lkc_result_label.text = "→ Invalid amount"
		lkc_result_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
		return

	# Calculate with precision (same logic as smart contract)
	var alsol_raw = (lkc_amount as float) * 1_000_000_000.0 / LKC_PER_ALSOL
	# Round down to 3 decimals
	var alsol_lamports = int(alsol_raw / 1_000_000.0) * 1_000_000
	var alsol_amount = alsol_lamports / 1_000_000_000.0

	# Check minimum
	if alsol_lamports < MIN_ALSOL_LAMPORTS:
		lkc_result_label.text = "→ Below minimum (need %d LKC)" % (MIN_ALSOL_LAMPORTS / 1000)
		lkc_result_label.add_theme_color_override("font_color", Color(0.96, 0.62, 0.04))
		return

	# Check weekly limit
	var remaining_lamports = MAX_WEEKLY_ALSOL_LAMPORTS - weekly_alsol_used_lamports
	if alsol_lamports > remaining_lamports:
		var remaining_alsol = remaining_lamports / 1_000_000_000.0
		lkc_result_label.text = "→ Exceeds weekly limit (%.3f left)" % remaining_alsol
		lkc_result_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
		return

	lkc_result_label.text = "→ You get: %.3f alSOL" % alsol_amount
	lkc_result_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))

func _on_buy_sol_pressed() -> void:
	if not WalletManager.is_connected:
		show_message("❌ Please connect wallet first!")
		return

	var sol_text = sol_input.text
	if sol_text.is_empty():
		show_message("❌ Please enter SOL amount")
		return

	var sol_amount = sol_text.to_float()
	if sol_amount <= 0:
		show_message("❌ Invalid SOL amount")
		return

	# Check balance
	var balance = await WalletManager.get_balance()
	if balance < sol_amount:
		show_message("❌ Insufficient SOL balance (have: %.3f)" % balance)
		return

	show_message("🔄 Swapping %.3f SOL for alSOL..." % sol_amount)

	# Connect to transaction signals
	var on_success: Callable
	var on_failure: Callable

	on_success = func(signature: String):
		show_message("✅ Successfully swapped %.3f SOL → %.3f alSOL!\nSignature: %s" % [sol_amount, sol_amount, signature])
		sol_input.text = ""
		update_wallet_info()
		WalletManager.transaction_completed.disconnect(on_success)
		WalletManager.transaction_failed.disconnect(on_failure)

	on_failure = func(error: String):
		show_message("❌ Swap failed: %s" % error)
		WalletManager.transaction_completed.disconnect(on_success)
		WalletManager.transaction_failed.disconnect(on_failure)

	WalletManager.transaction_completed.connect(on_success)
	WalletManager.transaction_failed.connect(on_failure)

	# Call blockchain integration method
	WalletManager.swap_sol_for_alsol(sol_amount)

func _on_buy_lkc_pressed() -> void:
	if not WalletManager.is_connected:
		show_message("❌ Please connect wallet first!")
		return

	var lkc_text = lkc_input.text
	if lkc_text.is_empty():
		show_message("❌ Please enter LKC amount")
		return

	var lkc_amount = lkc_text.to_int()
	if lkc_amount <= 0:
		show_message("❌ Invalid LKC amount")
		return

	# Calculate alSOL with precision
	var alsol_raw = (lkc_amount as float) * 1_000_000_000.0 / LKC_PER_ALSOL
	var alsol_lamports = int(alsol_raw / 1_000_000.0) * 1_000_000
	var alsol_amount = alsol_lamports / 1_000_000_000.0

	# Validate minimum
	if alsol_lamports < MIN_ALSOL_LAMPORTS:
		show_message("❌ Amount too small (min: 0.001 alSOL = 1,000 LKC)")
		return

	# Validate weekly limit
	var remaining_lamports = MAX_WEEKLY_ALSOL_LAMPORTS - weekly_alsol_used_lamports
	if alsol_lamports > remaining_lamports:
		var remaining_alsol = remaining_lamports / 1_000_000_000.0
		show_message("❌ Exceeds weekly limit! Only %.3f alSOL remaining" % remaining_alsol)
		return

	# Check LKC inventory
	var lkc_balance = InventoryManager.get_element_amount("lkC")
	if lkc_balance < lkc_amount:
		show_message("❌ Insufficient LKC (have: %d, need: %d)" % [lkc_balance, lkc_amount])
		return

	show_message("🔄 Swapping %d LKC for %.3f alSOL..." % [lkc_amount, alsol_amount])

	# Connect to transaction signals
	var on_success: Callable
	var on_failure: Callable

	on_success = func(signature: String):
		# Consume LKC from inventory on successful swap
		if InventoryManager.consume_elements({"lkC": lkc_amount}):
			# Update swap history
			weekly_alsol_used_lamports += alsol_lamports
			save_swap_history()
			update_alsol_ui()

			show_message("✅ Successfully swapped %d LKC → %.3f alSOL!\nSignature: %s" % [lkc_amount, alsol_amount, signature])
			lkc_input.text = ""
			update_wallet_info()
		else:
			show_message("⚠️ Swap succeeded but failed to consume LKC from inventory")

		WalletManager.transaction_completed.disconnect(on_success)
		WalletManager.transaction_failed.disconnect(on_failure)

	on_failure = func(error: String):
		show_message("❌ Swap failed: %s" % error)
		WalletManager.transaction_completed.disconnect(on_success)
		WalletManager.transaction_failed.disconnect(on_failure)

	WalletManager.transaction_completed.connect(on_success)
	WalletManager.transaction_failed.connect(on_failure)

	# Call blockchain integration method
	WalletManager.swap_lkc_for_alsol(lkc_amount)
