extends Node
## Manages Solana wallet connection via native mobile wallet adapter
## Requires SolanaWallet GDExtension plugin for iOS/Android
##
## Plugin Specification: docs/SOLANA_PLUGIN_SPEC.md
## Implementation Guide: docs/SOLANA_PLUGIN_IMPLEMENTATION.md

signal wallet_connected(address: String)
signal wallet_disconnected()
signal transaction_completed(signature: String)
signal transaction_failed(error: String)

var is_connected: bool = false
var wallet_address: String = ""
var public_key: String = ""

# Reference to native SolanaWallet singleton (if available)
var native_plugin = null
var use_mock_mode: bool = false

func _ready() -> void:
	# Try to load native SolanaWallet plugin
	if Engine.has_singleton("SolanaWallet"):
		native_plugin = Engine.get_singleton("SolanaWallet")
		use_mock_mode = false
		print("✅ SolanaWallet plugin loaded - using native implementation")

		# Connect to plugin signals
		native_plugin.wallet_connected.connect(_on_native_wallet_connected)
		native_plugin.wallet_connection_failed.connect(_on_native_connection_failed)
		native_plugin.transaction_signed.connect(_on_native_transaction_signed)
		native_plugin.transaction_failed.connect(_on_native_transaction_failed)
		native_plugin.wallet_disconnected.connect(_on_native_wallet_disconnected)
	else:
		use_mock_mode = true
		push_warning("⚠️ SolanaWallet plugin not found - using MOCK mode for development")
		push_warning("   See docs/SOLANA_PLUGIN_SPEC.md for plugin implementation details")

	load_wallet_data()

## Connect to Phantom/Solflare/other Solana mobile wallet
func connect_wallet() -> void:
	if not use_mock_mode and native_plugin:
		# Use native plugin (signal-based API)
		native_plugin.authorize({
			"cluster": WorldManager.get_current_world().get("cluster", "mainnet-beta"),
			"app_name": "LenKinVerse",
			"app_icon": "res://icon.svg"
		})
	else:
		# Mock implementation for development
		_mock_connect_wallet()

## Disconnect from wallet
func disconnect_wallet() -> void:
	if not use_mock_mode and native_plugin:
		native_plugin.disconnect()
	else:
		_mock_disconnect_wallet()

## Sign and send a transaction
func sign_transaction(transaction: Dictionary) -> void:
	if not use_mock_mode and native_plugin:
		native_plugin.sign_transaction(transaction)
	else:
		_mock_sign_transaction(transaction)

## Sign a message for verification
func sign_message(message: String) -> void:
	if not use_mock_mode and native_plugin:
		native_plugin.sign_message(message)
	else:
		_mock_sign_message(message)

## Get SOL balance for connected wallet
func get_balance() -> float:
	if not use_mock_mode and native_plugin:
		return native_plugin.get_balance(wallet_address)
	else:
		return _mock_get_balance()

# ============================================
# Native Plugin Signal Handlers
# ============================================

func _on_native_wallet_connected(address: String, pub_key: String) -> void:
	wallet_address = address
	public_key = pub_key
	is_connected = true
	save_wallet_data()
	wallet_connected.emit(address)
	print("✅ Wallet connected: ", address)

func _on_native_connection_failed(error: String) -> void:
	is_connected = false
	transaction_failed.emit(error)
	push_error("❌ Wallet connection failed: " + error)

func _on_native_transaction_signed(signature: String) -> void:
	transaction_completed.emit(signature)
	print("✅ Transaction signed: ", signature)

func _on_native_transaction_failed(error: String) -> void:
	transaction_failed.emit(error)
	push_error("❌ Transaction failed: " + error)

func _on_native_wallet_disconnected() -> void:
	is_connected = false
	wallet_address = ""
	public_key = ""
	save_wallet_data()
	wallet_disconnected.emit()
	print("ℹ️ Wallet disconnected")

# ============================================
# Mock Implementation (for development)
# ============================================

func _mock_connect_wallet() -> void:
	await get_tree().create_timer(1.0).timeout
	wallet_address = "8x7fMockSolanaAddress2kQ9"
	public_key = "8x7fMockPublicKey2kQ9"
	is_connected = true
	save_wallet_data()
	wallet_connected.emit(wallet_address)
	print("🔧 Mock wallet connected: ", wallet_address)

func _mock_disconnect_wallet() -> void:
	wallet_address = ""
	public_key = ""
	is_connected = false
	save_wallet_data()
	wallet_disconnected.emit()
	print("🔧 Mock wallet disconnected")

func _mock_sign_transaction(transaction: Dictionary) -> void:
	if not is_connected:
		transaction_failed.emit("Wallet not connected")
		return

	await get_tree().create_timer(1.0).timeout
	var mock_signature = "mock_tx_%d" % Time.get_unix_time_from_system()
	transaction_completed.emit(mock_signature)
	print("🔧 Mock transaction signed: ", mock_signature)

func _mock_sign_message(message: String) -> void:
	if not is_connected:
		transaction_failed.emit("Wallet not connected")
		return

	await get_tree().create_timer(0.5).timeout
	var mock_signature = "mock_msg_%d" % Time.get_unix_time_from_system()
	transaction_completed.emit(mock_signature)
	print("🔧 Mock message signed: ", mock_signature)

func _mock_get_balance() -> float:
	if not is_connected:
		return 0.0
	# Mock balance of 2.47 SOL
	return 2.47

# ============================================
# Save/Load
# ============================================

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

		if is_connected and wallet_address != "":
			wallet_connected.emit(wallet_address)
