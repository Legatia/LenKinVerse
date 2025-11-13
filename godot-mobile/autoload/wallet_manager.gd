extends Node
## Manages Solana wallet connection via native mobile wallet adapter
## Requires native plugin for iOS/Android

signal wallet_connected(address: String)
signal wallet_disconnected()
signal transaction_completed(signature: String)
signal transaction_failed(error: String)

var is_connected: bool = false
var wallet_address: String = ""
var public_key: String = ""

# This will interface with native Solana Mobile Wallet Adapter plugin
var native_plugin = null

func _ready() -> void:
	# Try to load native plugin
	if Engine.has_singleton("SolanaMobileWallet"):
		native_plugin = Engine.get_singleton("SolanaMobileWallet")
		print("Solana wallet plugin loaded")
	else:
		push_warning("Solana wallet plugin not found - using mock mode")

	load_wallet_data()

## Connect to Phantom/Solflare wallet
func connect_wallet() -> void:
	if native_plugin:
		# Call native plugin
		var result = await native_plugin.authorize({
			"cluster": "mainnet-beta",
			"app_name": "LenKinVerse",
			"app_uri": "https://lenkinverse.com"
		})

		if result.success:
			wallet_address = result.address
			public_key = result.public_key
			is_connected = true
			save_wallet_data()
			wallet_connected.emit(wallet_address)
		else:
			push_error("Wallet connection failed: " + str(result.error))
	else:
		# Mock connection for testing
		_mock_connect_wallet()

## Mock wallet connection for testing without plugin
func _mock_connect_wallet() -> void:
	await get_tree().create_timer(1.0).timeout
	wallet_address = "8x7f...2kQ9"
	public_key = "8x7fMockPublicKey2kQ9"
	is_connected = true
	save_wallet_data()
	wallet_connected.emit(wallet_address)
	print("Mock wallet connected: ", wallet_address)

## Disconnect wallet
func disconnect_wallet() -> void:
	wallet_address = ""
	public_key = ""
	is_connected = false
	save_wallet_data()
	wallet_disconnected.emit()

## Sign transaction
func sign_transaction(transaction_data: Dictionary) -> String:
	if not is_connected:
		push_error("Wallet not connected")
		return ""

	if native_plugin:
		var result = await native_plugin.sign_transaction(transaction_data)
		if result.success:
			transaction_completed.emit(result.signature)
			return result.signature
		else:
			transaction_failed.emit(result.error)
			return ""
	else:
		# Mock signature
		await get_tree().create_timer(1.0).timeout
		var mock_signature = "mock_sig_%d" % Time.get_unix_time_from_system()
		transaction_completed.emit(mock_signature)
		return mock_signature

## Sign message for authentication
func sign_message(message: String) -> String:
	if not is_connected:
		push_error("Wallet not connected")
		return ""

	if native_plugin:
		var result = await native_plugin.sign_message(message)
		return result.signature if result.success else ""
	else:
		# Mock signature
		await get_tree().create_timer(0.5).timeout
		return "mock_msg_sig_%d" % Time.get_unix_time_from_system()

## Get wallet balance
func get_balance() -> float:
	if not is_connected:
		return 0.0

	if native_plugin:
		var result = await native_plugin.get_balance(wallet_address)
		return result.balance if result.success else 0.0
	else:
		# Mock balance
		return 2.47

## Save wallet connection state
func save_wallet_data() -> void:
	var save_data = {
		"is_connected": is_connected,
		"wallet_address": wallet_address,
		"public_key": public_key
	}

	var file = FileAccess.open("user://wallet.save", FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()

## Load wallet connection state
func load_wallet_data() -> void:
	if not FileAccess.file_exists("user://wallet.save"):
		return

	var file = FileAccess.open("user://wallet.save", FileAccess.READ)
	if file:
		var save_data = file.get_var()
		is_connected = save_data.get("is_connected", false)
		wallet_address = save_data.get("wallet_address", "")
		public_key = save_data.get("public_key", "")
		file.close()

		if is_connected:
			wallet_connected.emit(wallet_address)
