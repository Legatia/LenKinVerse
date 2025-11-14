extends Node
## Solana RPC Helper - Query blockchain and send transactions

# RPC endpoints
const RPC_MAINNET = "https://api.mainnet-beta.solana.com"
const RPC_DEVNET = "https://api.devnet.solana.com"
const RPC_TESTNET = "https://api.testnet.solana.com"

var rpc_url: String = RPC_DEVNET  # Default to devnet
var http_client: HTTPRequest

signal rpc_response(result: Variant)
signal rpc_error(error: String)

func _ready() -> void:
	http_client = HTTPRequest.new()
	add_child(http_client)
	http_client.request_completed.connect(_on_request_completed)

## Set RPC cluster
func set_cluster(cluster: String) -> void:
	match cluster:
		"mainnet-beta", "mainnet":
			rpc_url = RPC_MAINNET
		"devnet":
			rpc_url = RPC_DEVNET
		"testnet":
			rpc_url = RPC_TESTNET
		_:
			push_error("Invalid cluster: %s" % cluster)

## Get SOL balance for address
func get_balance(address: String) -> void:
	var payload = {
		"jsonrpc": "2.0",
		"id": 1,
		"method": "getBalance",
		"params": [address]
	}
	_make_rpc_call(payload)

## Get recent blockhash
func get_recent_blockhash() -> void:
	var payload = {
		"jsonrpc": "2.0",
		"id": 1,
		"method": "getLatestBlockhash",
		"params": [{"commitment": "confirmed"}]
	}
	_make_rpc_call(payload)

## Get token account balance
func get_token_balance(token_account: String) -> void:
	var payload = {
		"jsonrpc": "2.0",
		"id": 1,
		"method": "getTokenAccountBalance",
		"params": [token_account]
	}
	_make_rpc_call(payload)

## Get program accounts (for querying marketplace listings)
func get_program_accounts(program_id: String, filters: Array = []) -> void:
	var payload = {
		"jsonrpc": "2.0",
		"id": 1,
		"method": "getProgramAccounts",
		"params": [
			program_id,
			{
				"encoding": "base64",
				"filters": filters
			}
		]
	}
	_make_rpc_call(payload)

## Get account info
func get_account_info(account: String) -> void:
	var payload = {
		"jsonrpc": "2.0",
		"id": 1,
		"method": "getAccountInfo",
		"params": [
			account,
			{"encoding": "base64"}
		]
	}
	_make_rpc_call(payload)

## Send transaction to blockchain
func send_transaction(signed_transaction_base64: String, skip_preflight: bool = false) -> void:
	var payload = {
		"jsonrpc": "2.0",
		"id": 1,
		"method": "sendTransaction",
		"params": [
			signed_transaction_base64,
			{
				"skipPreflight": skip_preflight,
				"encoding": "base64"
			}
		]
	}
	_make_rpc_call(payload)

## Simulate transaction before sending
func simulate_transaction(transaction_base64: String) -> void:
	var payload = {
		"jsonrpc": "2.0",
		"id": 1,
		"method": "simulateTransaction",
		"params": [
			transaction_base64,
			{"encoding": "base64"}
		]
	}
	_make_rpc_call(payload)

## Get transaction confirmation status
func get_signature_status(signature: String) -> void:
	var payload = {
		"jsonrpc": "2.0",
		"id": 1,
		"method": "getSignatureStatuses",
		"params": [[signature]]
	}
	_make_rpc_call(payload)

## Get transaction details
func get_transaction(signature: String) -> void:
	var payload = {
		"jsonrpc": "2.0",
		"id": 1,
		"method": "getTransaction",
		"params": [
			signature,
			{"encoding": "json", "maxSupportedTransactionVersion": 0}
		]
	}
	_make_rpc_call(payload)

## Get minimum rent exemption for account size
func get_minimum_balance_for_rent_exemption(data_size: int) -> void:
	var payload = {
		"jsonrpc": "2.0",
		"id": 1,
		"method": "getMinimumBalanceForRentExemption",
		"params": [data_size]
	}
	_make_rpc_call(payload)

## Get token accounts by owner
func get_token_accounts_by_owner(owner: String, mint: String = "") -> void:
	var filters = {}
	if mint.is_empty():
		filters = {"programId": "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"}  # SPL Token program
	else:
		filters = {"mint": mint}

	var payload = {
		"jsonrpc": "2.0",
		"id": 1,
		"method": "getTokenAccountsByOwner",
		"params": [
			owner,
			filters,
			{"encoding": "jsonParsed"}
		]
	}
	_make_rpc_call(payload)

## Internal: Make RPC call
func _make_rpc_call(payload: Dictionary) -> void:
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify(payload)

	var error = http_client.request(rpc_url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		rpc_error.emit("HTTP request failed: %s" % error_string(error))

## Internal: Handle RPC response
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		rpc_error.emit("RPC error: HTTP %d" % response_code)
		return

	var json = JSON.new()
	var parse_error = json.parse(body.get_string_from_utf8())

	if parse_error != OK:
		rpc_error.emit("Failed to parse JSON response")
		return

	var response = json.data

	if response.has("error"):
		rpc_error.emit("RPC error: %s" % response["error"].get("message", "Unknown error"))
		return

	if response.has("result"):
		rpc_response.emit(response["result"])
	else:
		rpc_error.emit("Invalid RPC response format")
