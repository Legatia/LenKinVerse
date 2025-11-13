extends Control
## Wallet connection screen - first screen users see

@onready var connect_button: Button = $VBoxContainer/ConnectButton
@onready var status_label: Label = $VBoxContainer/StatusLabel

func _ready() -> void:
	# Check if already connected
	if WalletManager.is_connected:
		_on_wallet_connected(WalletManager.wallet_address)
	else:
		# Connect to wallet signals
		WalletManager.wallet_connected.connect(_on_wallet_connected)

func _on_connect_button_pressed() -> void:
	connect_button.disabled = true
	status_label.text = "Connecting to wallet..."

	# Request wallet connection
	WalletManager.connect_wallet()

	# Wait for result
	await get_tree().create_timer(2.0).timeout

	if WalletManager.is_connected:
		status_label.text = "Connected! Loading..."
	else:
		status_label.text = "Connection failed. Try again."
		connect_button.disabled = false

func _on_wallet_connected(address: String) -> void:
	status_label.text = "Connected: %s" % address

	# Request health permissions
	await request_health_permissions()

	# Transition to main game
	await get_tree().create_timer(1.0).timeout
	transition_to_main_game()

func request_health_permissions() -> void:
	status_label.text = "Requesting movement tracking..."

	var granted = await HealthManager.request_permissions()

	if granted:
		status_label.text = "Permissions granted!"
	else:
		status_label.text = "Movement tracking disabled"
		# Still allow playing without health data

func transition_to_main_game() -> void:
	# World should already be selected before reaching this screen
	# Proceed directly to game
	if GameManager.is_first_launch:
		# Go directly to main room
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	else:
		# Calculate offline rewards first
		get_tree().change_scene_to_file("res://scenes/ui/offline_rewards.tscn")
