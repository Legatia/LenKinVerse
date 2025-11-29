extends Node
## Chemistry API Manager - connects to ReAgenyx backend chemistry system

signal energy_updated(energy_data: Dictionary)
signal reaction_completed(result: Dictionary)
signal reaction_failed(error: String)
signal elements_loaded(elements: Array)
signal compounds_loaded(compounds: Array)
signal reactions_loaded(reactions: Array)
signal inventory_loaded(inventory: Dictionary)

# API configuration
var base_url: String = "http://localhost:3000/api"
var player_wallet: String = ""

# Cache
var cached_elements: Array = []
var cached_compounds: Array = []
var cached_reactions: Array = []
var cached_inventory: Dictionary = {"elements": [], "compounds": []}
var cached_energy: Dictionary = {}

# HTTP Request nodes (created dynamically)
var http_pool: Array[HTTPRequest] = []
const MAX_POOL_SIZE = 5

func _ready() -> void:
	# Get player wallet from WalletManager
	if WalletManager:
		player_wallet = WalletManager.get_wallet_address()

	# Load initial data
	fetch_all_elements()
	fetch_all_reactions()

	if player_wallet:
		fetch_player_energy()
		fetch_player_inventory()

## ============================================================================
## ENERGY ENDPOINTS
## ============================================================================

func fetch_player_energy() -> void:
	if not player_wallet:
		push_error("No player wallet set")
		return

	var http = _get_http_request()
	http.request_completed.connect(_on_energy_received)

	var url = base_url + "/player/energy/" + player_wallet
	print("Fetching energy from: ", url)

	var error = http.request(url)
	if error != OK:
		push_error("Failed to request energy: " + str(error))

func _on_energy_received(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		push_error("Energy request failed with code: " + str(response_code))
		return

	var json = JSON.new()
	var error = json.parse(body.get_string_from_utf8())

	if error != OK:
		push_error("Failed to parse energy JSON")
		return

	var response = json.data
	if response.get("success"):
		cached_energy = response.get("data", {})
		energy_updated.emit(cached_energy)
		print("✅ Energy updated: %d⚡ / %d⚡" % [
			cached_energy.get("current_energy", 0),
			cached_energy.get("max_energy", 100)
		])

## ============================================================================
## ELEMENTS ENDPOINTS
## ============================================================================

func fetch_all_elements() -> void:
	var http = _get_http_request()
	http.request_completed.connect(_on_elements_received)

	var url = base_url + "/chemistry/elements"
	http.request(url)

func _on_elements_received(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK:
		var response = json.data
		if response.get("success"):
			cached_elements = response.get("data", [])
			elements_loaded.emit(cached_elements)
			print("✅ Loaded %d elements" % cached_elements.size())

## ============================================================================
## COMPOUNDS ENDPOINTS
## ============================================================================

func fetch_all_compounds() -> void:
	var http = _get_http_request()
	http.request_completed.connect(_on_compounds_received)

	var url = base_url + "/chemistry/compounds"
	http.request(url)

func _on_compounds_received(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK:
		var response = json.data
		if response.get("success"):
			cached_compounds = response.get("data", [])
			compounds_loaded.emit(cached_compounds)
			print("✅ Loaded %d compounds" % cached_compounds.size())

## ============================================================================
## REACTIONS ENDPOINTS
## ============================================================================

func fetch_all_reactions(reaction_type: String = "") -> void:
	var http = _get_http_request()
	http.request_completed.connect(_on_reactions_received)

	var url = base_url + "/chemistry/reactions"
	if reaction_type != "":
		url += "?type=" + reaction_type

	http.request(url)

func _on_reactions_received(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK:
		var response = json.data
		if response.get("success"):
			cached_reactions = response.get("data", [])
			reactions_loaded.emit(cached_reactions)
			print("✅ Loaded %d reactions" % cached_reactions.size())

## ============================================================================
## INVENTORY ENDPOINTS
## ============================================================================

func fetch_player_inventory() -> void:
	if not player_wallet:
		return

	var http = _get_http_request()
	http.request_completed.connect(_on_inventory_received)

	var url = base_url + "/chemistry/inventory/" + player_wallet
	http.request(url)

func _on_inventory_received(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK:
		var response = json.data
		if response.get("success"):
			cached_inventory = response.get("data", {"elements": [], "compounds": []})
			inventory_loaded.emit(cached_inventory)
			print("✅ Loaded inventory with %d items" % (
				cached_inventory.get("elements", []).size() +
				cached_inventory.get("compounds", []).size()
			))

## ============================================================================
## PERFORM REACTION (MAIN FEATURE)
## ============================================================================

func perform_reaction(reaction_id: int) -> void:
	if not player_wallet:
		reaction_failed.emit("No wallet connected")
		return

	var http = _get_http_request()
	http.request_completed.connect(_on_reaction_completed)

	var url = base_url + "/chemistry/react"
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"player_wallet": player_wallet,
		"reaction_id": reaction_id
	})

	print("🧪 Performing reaction %d..." % reaction_id)
	http.request(url, headers, HTTPClient.METHOD_POST, body)

func _on_reaction_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		reaction_failed.emit("Failed to parse response")
		return

	var response = json.data

	# Check for error response (400/500)
	if not response.get("success", false):
		var error_msg = response.get("message", "Unknown error")
		reaction_failed.emit(error_msg)
		print("❌ Reaction failed: ", error_msg)
		return

	# Success - parse reaction result
	var reaction_data = response.get("data", {})

	if reaction_data.get("success", false):
		# Reaction succeeded!
		print("✅ Reaction SUCCESS!")
		print("   Energy spent: %d⚡" % reaction_data.get("energy_spent", 0))
		print("   Outputs: ", reaction_data.get("outputs_created", []))

		# Check for discovery
		if reaction_data.has("discovery"):
			var discovery = reaction_data.get("discovery")
			print("🎉 FIRST DISCOVERY: ", discovery.get("compound_id"))

		reaction_completed.emit(reaction_data)
	else:
		# Reaction failed (but materials/energy consumed)
		print("❌ Reaction FAILED (materials consumed)")
		print("   Energy spent: %d⚡" % reaction_data.get("energy_spent", 0))

		reaction_completed.emit(reaction_data)  # Still emit with success=false

	# Refresh energy and inventory
	fetch_player_energy()
	fetch_player_inventory()

## ============================================================================
## HELPER FUNCTIONS
## ============================================================================

## Get HTTP request node from pool (or create new one)
func _get_http_request() -> HTTPRequest:
	# Reuse existing completed requests
	for http in http_pool:
		if http.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
			return http

	# Create new if pool not full
	if http_pool.size() < MAX_POOL_SIZE:
		var http = HTTPRequest.new()
		add_child(http)
		http_pool.append(http)
		return http

	# Pool full, wait for first one
	return http_pool[0]

## Get element amount from cached inventory
func get_inventory_element_amount(element_id: String) -> int:
	for element in cached_inventory.get("elements", []):
		if element.get("item_id") == element_id:
			return int(element.get("amount", 0))
	return 0

## Get compound amount from cached inventory
func get_inventory_compound_amount(compound_id: String) -> int:
	for compound in cached_inventory.get("compounds", []):
		if compound.get("item_id") == compound_id:
			return int(compound.get("amount", 0))
	return 0

## Check if reaction is nuclear (contains isotopes)
func is_nuclear_reaction(reaction: Dictionary) -> bool:
	var inputs = reaction.get("inputs", [])
	for input in inputs:
		var element_id = input.get("id", "")
		# Check if it's an isotope (contains numbers in name)
		if element_id.contains("14") or element_id.contains("18") or element_id.ends_with("X"):
			return true
	return false

## Get reaction energy cost
func get_reaction_energy_cost(reaction: Dictionary) -> int:
	return reaction.get("energy_cost", 0)

## Get current player energy
func get_current_energy() -> int:
	return cached_energy.get("current_energy", 0)

## Get max player energy
func get_max_energy() -> int:
	return cached_energy.get("max_energy", 100)

## Get energy percentage
func get_energy_percentage() -> int:
	return cached_energy.get("energy_percentage", 0)

## Get time until full energy
func get_time_until_full() -> String:
	return cached_energy.get("time_until_full", "Unknown")

## Set player wallet address
func set_player_wallet(wallet: String) -> void:
	player_wallet = wallet
	fetch_player_energy()
	fetch_player_inventory()
