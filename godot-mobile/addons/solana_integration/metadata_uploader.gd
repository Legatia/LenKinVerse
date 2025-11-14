extends Node
## Metadata Uploader - Upload NFT metadata to decentralized storage

# Upload services
enum UploadService {
	ARWEAVE,      # Permanent storage, costs AR tokens
	IPFS,         # IPFS via NFT.Storage (free)
	PINATA,       # IPFS via Pinata
	MOCK          # Mock mode for testing
}

var current_service: UploadService = UploadService.MOCK
var http_client: HTTPRequest

# API keys (set these from environment or config)
var nft_storage_api_key: String = ""
var pinata_api_key: String = ""
var pinata_secret_key: String = ""

signal upload_completed(metadata_uri: String)
signal upload_failed(error: String)

func _ready() -> void:
	http_client = HTTPRequest.new()
	add_child(http_client)
	http_client.request_completed.connect(_on_upload_completed)

## Upload element NFT metadata
func upload_element_metadata(element_data: Dictionary) -> void:
	"""
	Upload metadata for element NFT

	element_data structure:
	{
		"element_id": "lkC",
		"element_name": "Lennard-Kinsium Carbon",
		"symbol": "lkC",
		"rarity": 0,
		"amount": 10,
		"generation_method": "walk_mining",
		"discovered_at": 1234567890,
		"decay_time": null,  # Optional
		"volume": null  # Optional (for isotopes)
	}
	"""
	var metadata = _build_nft_metadata(element_data)

	match current_service:
		UploadService.ARWEAVE:
			_upload_to_arweave(metadata)
		UploadService.IPFS, UploadService.PINATA:
			_upload_to_ipfs(metadata)
		UploadService.MOCK:
			_upload_mock(metadata)

## Build Metaplex-compatible metadata
func _build_nft_metadata(element_data: Dictionary) -> Dictionary:
	"""
	Build metadata following Metaplex standard
	https://docs.metaplex.com/programs/token-metadata/token-standard
	"""
	var element_id = element_data.get("element_id", "Unknown")
	var element_name = element_data.get("element_name", "Unknown Element")
	var symbol = element_data.get("symbol", "???")
	var rarity = element_data.get("rarity", 0)
	var amount = element_data.get("amount", 1)
	var generation_method = element_data.get("generation_method", "unknown")
	var discovered_at = element_data.get("discovered_at", Time.get_unix_time_from_system())

	# Rarity mapping
	var rarity_name = ["Common", "Uncommon", "Rare", "Legendary"][rarity] if rarity < 4 else "Unknown"

	# Build attributes array
	var attributes = [
		{"trait_type": "Element ID", "value": element_id},
		{"trait_type": "Symbol", "value": symbol},
		{"trait_type": "Rarity", "value": rarity_name},
		{"trait_type": "Amount", "value": amount, "display_type": "number"},
		{"trait_type": "Generation Method", "value": generation_method},
		{"trait_type": "Discovered At", "value": discovered_at, "display_type": "date"},
	]

	# Add isotope-specific attributes
	if element_data.has("decay_time") and element_data["decay_time"] != null:
		attributes.append({
			"trait_type": "Decay Time",
			"value": element_data["decay_time"],
			"display_type": "date"
		})

	if element_data.has("volume") and element_data["volume"] != null:
		attributes.append({
			"trait_type": "Volume",
			"value": "%.1f units" % element_data["volume"],
		})

	# Build Metaplex metadata JSON
	return {
		"name": "%s (%s)" % [element_name, symbol],
		"symbol": symbol,
		"description": "Element discovered in LenKinVerse through %s. Rarity: %s. Amount: %d." % [
			generation_method,
			rarity_name,
			amount
		],
		"image": _get_element_image_url(element_id, rarity),
		"attributes": attributes,
		"properties": {
			"category": "element",
			"creators": [
				{
					"address": "LenKinVerse_Authority_Address",  # Replace with actual
					"share": 100
				}
			],
			"files": [
				{
					"uri": _get_element_image_url(element_id, rarity),
					"type": "image/png"
				}
			]
		},
		"collection": {
			"name": "LenKinVerse Elements",
			"family": "LenKinVerse"
		},
		"external_url": "https://lenkinverse.com/elements/%s" % element_id
	}

## Get element image URL (placeholder)
func _get_element_image_url(element_id: String, rarity: int) -> String:
	# In production, these would be actual hosted images or generated on-the-fly
	return "https://lenkinverse.com/images/elements/%s_rarity%d.png" % [element_id, rarity]

## Upload to Arweave
func _upload_to_arweave(metadata: Dictionary) -> void:
	# Arweave upload requires AR wallet and tokens
	# For now, show error - implement later with Bundlr or ArDrive API

	push_error("Arweave upload not implemented yet. Use IPFS or MOCK mode.")
	upload_failed.emit("Arweave upload not implemented")

## Upload to IPFS via NFT.Storage (free)
func _upload_to_ipfs(metadata: Dictionary) -> void:
	if nft_storage_api_key.is_empty():
		upload_failed.emit("NFT.Storage API key not configured")
		return

	var url = "https://api.nft.storage/upload"
	var headers = [
		"Authorization: Bearer " + nft_storage_api_key,
		"Content-Type: application/json"
	]
	var body = JSON.stringify(metadata)

	var error = http_client.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		upload_failed.emit("HTTP request failed: %s" % error_string(error))

## Upload mock (for testing)
func _upload_mock(metadata: Dictionary) -> void:
	# Simulate upload delay
	await get_tree().create_timer(0.5).timeout

	# Generate mock IPFS URI
	var mock_hash = "Qm" + str(metadata.hash()).md5_text().substr(0, 44)
	var metadata_uri = "https://ipfs.io/ipfs/" + mock_hash

	print("📦 Mock metadata uploaded:")
	print("  Name: %s" % metadata.get("name"))
	print("  URI: %s" % metadata_uri)

	upload_completed.emit(metadata_uri)

## Handle upload response
func _on_upload_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200 and response_code != 201:
		upload_failed.emit("Upload failed with HTTP %d" % response_code)
		return

	var json = JSON.new()
	var parse_error = json.parse(body.get_string_from_utf8())

	if parse_error != OK:
		upload_failed.emit("Failed to parse upload response")
		return

	var response = json.data

	# NFT.Storage response format
	if response.has("value") and response["value"].has("cid"):
		var cid = response["value"]["cid"]
		var metadata_uri = "https://ipfs.io/ipfs/" + cid
		upload_completed.emit(metadata_uri)
		return

	# Pinata response format
	if response.has("IpfsHash"):
		var ipfs_hash = response["IpfsHash"]
		var metadata_uri = "https://ipfs.io/ipfs/" + ipfs_hash
		upload_completed.emit(metadata_uri)
		return

	upload_failed.emit("Unknown upload response format")

## Set NFT.Storage API key
func set_nft_storage_key(api_key: String) -> void:
	nft_storage_api_key = api_key

## Set upload service
func set_upload_service(service: UploadService) -> void:
	current_service = service

## Quick upload with automatic service selection
func quick_upload(element_data: Dictionary) -> void:
	# Use IPFS if API key available, otherwise use mock
	if not nft_storage_api_key.is_empty():
		set_upload_service(UploadService.IPFS)
	else:
		set_upload_service(UploadService.MOCK)

	upload_element_metadata(element_data)
