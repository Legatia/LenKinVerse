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
signal balance_updated(sol_balance: float, alsol_balance: float)

var is_connected: bool = false
var wallet_address: String = ""
var public_key: String = ""

# Cached balances
var sol_balance: float = 0.0
var alsol_balance: float = 0.0

# Reference to native SolanaWallet singleton (if available)
var native_plugin = null
var use_mock_mode: bool = false

# Integration helpers
var solana_rpc: Node = null
var anchor_helper: Node = null
var metadata_uploader: Node = null

func _ready() -> void:
	# Initialize integration helpers
	_init_helpers()

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

## Initialize integration helpers
func _init_helpers() -> void:
	# Load integration scripts
	var SolanaRPC = load("res://addons/solana_integration/solana_rpc.gd")
	var AnchorHelper = load("res://addons/solana_integration/anchor_helper.gd")
	var MetadataUploader = load("res://addons/solana_integration/metadata_uploader.gd")

	solana_rpc = SolanaRPC.new()
	anchor_helper = AnchorHelper.new()
	metadata_uploader = MetadataUploader.new()

	add_child(solana_rpc)
	add_child(anchor_helper)
	add_child(metadata_uploader)

	# Connect signals
	solana_rpc.rpc_response.connect(_on_rpc_response)
	solana_rpc.rpc_error.connect(_on_rpc_error)
	metadata_uploader.upload_completed.connect(_on_metadata_uploaded)
	metadata_uploader.upload_failed.connect(_on_metadata_upload_failed)

	# Set cluster based on current world
	var cluster = WorldManager.get_current_world().get("cluster", "devnet")
	solana_rpc.set_cluster(cluster)

	print("✅ Solana integration helpers initialized")

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
# High-Level Blockchain Operations
# ============================================

## Update balances from blockchain
func update_balances() -> void:
	if not is_connected:
		return

	# Get SOL balance
	solana_rpc.get_balance(wallet_address)
	# Note: Response will come via _on_rpc_response signal

## Mint element NFT
func mint_element_nft(element_data: Dictionary) -> void:
	"""
	Complete NFT minting flow:
	1. Upload metadata to IPFS
	2. Build mint transaction
	3. Sign with wallet
	4. Send to blockchain
	"""
	if not is_connected:
		transaction_failed.emit("Wallet not connected")
		return

	print("🎨 Starting NFT mint for: %s" % element_data.get("element_name", "Unknown"))

	# Step 1: Upload metadata
	metadata_uploader.quick_upload(element_data)
	# Will continue in _on_metadata_uploaded

var pending_mint_element_data: Dictionary = {}

func _on_metadata_uploaded(metadata_uri: String) -> void:
	print("✅ Metadata uploaded: %s" % metadata_uri)

	# Step 2: Build mint transaction
	var mint_keypair = _generate_mint_keypair()
	var element_pda = anchor_helper.derive_element_account_pda(mint_keypair)

	var mint_instruction = anchor_helper.build_mint_element(
		wallet_address,
		mint_keypair,
		element_pda,
		metadata_uri,  # Used as metadata_account for now
		pending_mint_element_data
	)

	# Step 3: Get recent blockhash
	solana_rpc.get_recent_blockhash()
	# Will continue in _on_rpc_response with transaction building

func _on_metadata_upload_failed(error: String) -> void:
	transaction_failed.emit("Metadata upload failed: %s" % error)

## Swap SOL for alSOL
func swap_sol_for_alsol(sol_amount: float) -> void:
	if not is_connected:
		transaction_failed.emit("Wallet not connected")
		return

	var lamports = int(sol_amount * 1_000_000_000)

	var instruction = anchor_helper.build_swap_sol_for_alsol(
		wallet_address,
		lamports,
		"alSOL_mint_address",  # TODO: Replace with actual
		"marketplace_authority"  # TODO: Replace with actual
	)

	solana_rpc.get_recent_blockhash()
	# Will build and send transaction in _on_rpc_response

## Swap LKC for alSOL
func swap_lkc_for_alsol(lkc_amount: int) -> void:
	if not is_connected:
		transaction_failed.emit("Wallet not connected")
		return

	var swap_history_pda = anchor_helper.derive_swap_history_pda(wallet_address)

	var instruction = anchor_helper.build_swap_lkc_for_alsol(
		wallet_address,
		lkc_amount,
		"LKC_mint_address",  # TODO: Replace with actual
		"alSOL_mint_address",  # TODO: Replace with actual
		swap_history_pda,
		"marketplace_authority"  # TODO: Replace with actual
	)

	solana_rpc.get_recent_blockhash()
	# Will build and send transaction in _on_rpc_response

## Create marketplace listing
func create_marketplace_listing(element_nft_mint: String, price_sol: float) -> void:
	if not is_connected:
		transaction_failed.emit("Wallet not connected")
		return

	var price_lamports = int(price_sol * 1_000_000_000)
	var listing_pda = anchor_helper.derive_listing_pda(element_nft_mint)

	var instruction = anchor_helper.build_create_listing(
		wallet_address,
		element_nft_mint,
		price_lamports,
		listing_pda
	)

	solana_rpc.get_recent_blockhash()
	# Will build and send transaction in _on_rpc_response

## Buy from marketplace
func buy_marketplace_listing(listing_data: Dictionary) -> void:
	if not is_connected:
		transaction_failed.emit("Wallet not connected")
		return

	var instruction = anchor_helper.build_buy_listing(
		wallet_address,
		listing_data["seller"],
		listing_data["mint"],
		listing_data["listing_pda"],
		"alSOL_mint_address",  # TODO: Replace with actual
		"marketplace_authority"  # TODO: Replace with actual
	)

	solana_rpc.get_recent_blockhash()
	# Will build and send transaction in _on_rpc_response

## Query marketplace listings
func fetch_marketplace_listings() -> void:
	solana_rpc.get_program_accounts(anchor_helper.MARKETPLACE_PROGRAM_ID)
	# Results will come via _on_rpc_response

# ============================================
# RPC Signal Handlers
# ============================================

var pending_rpc_request: String = ""

func _on_rpc_response(result: Variant) -> void:
	print("📡 RPC response received: ", result)

	# Handle different response types
	if result is Dictionary:
		# Balance response
		if result.has("value") and result["value"] is int:
			sol_balance = result["value"] / 1_000_000_000.0
			balance_updated.emit(sol_balance, alsol_balance)
			print("💰 SOL Balance: %.4f" % sol_balance)

		# Blockhash response
		elif result.has("value") and result["value"].has("blockhash"):
			var blockhash = result["value"]["blockhash"]
			print("🔗 Recent blockhash: %s" % blockhash)
			# TODO: Build and sign transaction here

	elif result is Array:
		# Program accounts (marketplace listings)
		print("📋 Found %d program accounts" % result.size())
		# TODO: Parse and emit marketplace listings

func _on_rpc_error(error: String) -> void:
	push_error("RPC error: %s" % error)
	transaction_failed.emit("RPC error: %s" % error)

# ============================================
# Helpers
# ============================================

## Generate new mint keypair (placeholder)
func _generate_mint_keypair() -> String:
	# In real implementation, generate actual Solana keypair
	return "MintKeypair_%d" % Time.get_unix_time_from_system()

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
