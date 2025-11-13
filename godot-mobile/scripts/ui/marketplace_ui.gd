extends Control
## Marketplace UI - buy, sell, and mint tokens/NFTs

@onready var wallet_label: Label = $Panel/VBoxContainer/WalletInfo/WalletLabel
@onready var balance_label: Label = $Panel/VBoxContainer/WalletInfo/BalanceLabel
@onready var inventory_container: VBoxContainer = $Panel/VBoxContainer/TabContainer/Sell/InventoryContainer
@onready var mintable_items: VBoxContainer = $Panel/VBoxContainer/TabContainer/Mint/MintableItems

func _ready() -> void:
	update_wallet_info()
	populate_sell_inventory()
	populate_mintable_items()

	# Connect to wallet events
	WalletManager.wallet_connected.connect(func(_addr): update_wallet_info())
	WalletManager.wallet_disconnected.connect(func(): update_wallet_info())

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

	show_message("Minting %s as token..." % element)

	# Sign transaction
	var tx_data = {
		"type": "mint_token",
		"element": element,
		"amount": amount
	}

	var signature = await WalletManager.sign_transaction(tx_data)

	if signature != "":
		show_message("Token minted successfully!\nSignature: %s" % signature)
		# Refresh UI
		populate_mintable_items()
	else:
		show_message("Minting failed. Please try again.")

func show_message(text: String) -> void:
	print(text)
	# TODO: Show proper toast/modal

func _on_close_button_pressed() -> void:
	queue_free()
