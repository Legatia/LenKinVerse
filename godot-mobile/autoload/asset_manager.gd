extends Node
## Manages all game assets (textures, sprites, icons) with fallback support
## Loads from assets/asset_config.json

var asset_config: Dictionary = {}
var loaded_textures: Dictionary = {}

func _ready() -> void:
	load_asset_config()

## Load asset configuration from JSON
func load_asset_config() -> void:
	var config_path = "res://assets/asset_config.json"

	if not FileAccess.file_exists(config_path):
		push_warning("Asset config not found: %s - using fallbacks" % config_path)
		return

	var file = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		push_error("Failed to open asset config: %s" % config_path)
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)

	if error != OK:
		push_error("Failed to parse asset config JSON: %s at line %d" % [json.get_error_message(), json.get_error_line()])
		return

	asset_config = json.data
	print("✅ Asset config loaded: %d categories" % asset_config.size())

## Get furniture asset with fallback to emoji
func get_furniture_icon(furniture_id: String) -> Variant:
	return _get_asset(["furniture", furniture_id, "icon"],
		asset_config.get("furniture", {}).get(furniture_id, {}).get("fallback_emoji", "❓"))

## Get furniture sprite with fallback
func get_furniture_sprite(furniture_id: String) -> Variant:
	return _get_asset(["furniture", furniture_id, "sprite"],
		asset_config.get("furniture", {}).get(furniture_id, {}).get("fallback_emoji", "❓"))

## Get UI icon with fallback to emoji
func get_ui_icon(ui_id: String) -> Variant:
	return _get_asset(["ui", ui_id, "icon"],
		asset_config.get("ui", {}).get(ui_id, {}).get("fallback_emoji", "❓"))

## Get player sprite texture
func get_player_sprite() -> Texture2D:
	var player_path = "res://assets/ui/player.JPG"
	if ResourceLoader.exists(player_path):
		return load(player_path)
	else:
		push_warning("Player sprite not found at: %s" % player_path)
		return null

## Get element icon with fallback to emoji
func get_element_icon(element_id: String, rarity: int = -1) -> Variant:
	# Try rarity-specific icon first
	if rarity >= 0:
		var rarity_key = "rarity_%d" % rarity
		var rarity_icon = _get_asset(["elements", element_id, rarity_key], null)
		if rarity_icon != null:
			return rarity_icon

	# Fall back to base icon
	return _get_asset(["elements", element_id, "icon"],
		asset_config.get("elements", {}).get(element_id, {}).get("fallback_emoji", "❓"))

## Get element card image (for NFT metadata)
func get_element_image(element_id: String, rarity: int = -1) -> Variant:
	# Try rarity-specific image first
	if rarity >= 0:
		var rarity_key = "rarity_%d" % rarity
		var rarity_image = _get_asset(["elements", element_id, rarity_key], null)
		if rarity_image != null:
			return rarity_image

	# Fall back to base image
	return _get_asset(["elements", element_id, "image"],
		asset_config.get("elements", {}).get(element_id, {}).get("fallback_emoji", "❓"))

## Get element image URL for metadata (converts res:// to https://)
func get_element_image_url(element_id: String, rarity: int = 0) -> String:
	var image = get_element_image(element_id, rarity)

	if image is String:
		# If it's a resource path, convert to web URL
		if image.begins_with("res://"):
			# Replace with your actual CDN/hosting URL
			var web_path = image.replace("res://assets/", "https://lenkinverse.com/assets/")
			return web_path
		return image

	# Fallback: return placeholder URL
	return "https://lenkinverse.com/assets/elements/placeholder.png"

## Get planet background
func get_planet_background(planet_id: String) -> Variant:
	return _get_asset(["planets", planet_id, "background"],
		asset_config.get("planets", {}).get(planet_id, {}).get("fallback_color", "#2c212b"))

## Get planet floor texture
func get_planet_floor(planet_id: String) -> Variant:
	return _get_asset(["planets", planet_id, "floor"], null)

## Get planet icon
func get_planet_icon(planet_id: String) -> Variant:
	return _get_asset(["planets", planet_id, "icon"], planet_id)

## Get reaction icon with fallback to emoji
func get_reaction_icon(reaction_type: String) -> Variant:
	return _get_asset(["reactions", reaction_type, "icon"],
		asset_config.get("reactions", {}).get(reaction_type, {}).get("fallback_emoji", "⚛️"))

## Get effect particle
func get_effect(effect_id: String) -> Variant:
	return _get_asset(["effects", effect_id], null)

## Get tutorial asset
func get_tutorial_asset(asset_id: String) -> Variant:
	return _get_asset(["tutorial", asset_id], null)

## Internal: Get asset from config path with fallback
func _get_asset(path: Array, fallback: Variant) -> Variant:
	# Navigate config path
	var current = asset_config
	for key in path:
		if current is Dictionary and current.has(key):
			current = current[key]
		else:
			return fallback

	# If we have a resource path, try to load it
	if current is String and current.begins_with("res://"):
		return _load_texture(current, fallback)

	return current

## Internal: Load texture with caching and fallback
func _load_texture(path: String, fallback: Variant) -> Variant:
	# Check cache first
	if loaded_textures.has(path):
		return loaded_textures[path]

	# Try to load resource
	if ResourceLoader.exists(path):
		var texture = load(path)
		if texture:
			loaded_textures[path] = texture
			return texture
		else:
			push_warning("Failed to load texture: %s - using fallback" % path)
	else:
		# File doesn't exist yet - this is expected during development
		# Don't log warning, just use fallback
		pass

	return fallback

## Clear texture cache (useful for hot-reloading)
func clear_cache() -> void:
	loaded_textures.clear()
	print("🗑️ Asset cache cleared")

## Reload config and clear cache
func reload() -> void:
	clear_cache()
	load_asset_config()
	print("🔄 Assets reloaded")

## Get fallback emoji for element
func get_element_emoji(element_id: String) -> String:
	return asset_config.get("elements", {}).get(element_id, {}).get("fallback_emoji", "❓")

## Get fallback emoji for UI element
func get_ui_emoji(ui_id: String) -> String:
	return asset_config.get("ui", {}).get(ui_id, {}).get("fallback_emoji", "❓")

## Alias for consistency with get_ui_emoji
func get_ui_fallback(ui_id: String) -> String:
	return get_ui_emoji(ui_id)

## Check if asset exists
func has_asset(category: String, asset_id: String, property: String = "icon") -> bool:
	if not asset_config.has(category):
		return false

	var category_data = asset_config[category]
	if not category_data.has(asset_id):
		return false

	var asset_data = category_data[asset_id]
	if not asset_data.has(property):
		return false

	var path = asset_data[property]
	if path is String and path.begins_with("res://"):
		return ResourceLoader.exists(path)

	return true

## Get asset size from config
func get_asset_size(category: String, asset_id: String) -> Vector2:
	var category_data = asset_config.get(category, {})
	var asset_data = category_data.get(asset_id, {})
	var size_array = asset_data.get("size", [64, 64])

	if size_array is Array and size_array.size() >= 2:
		return Vector2(size_array[0], size_array[1])

	return Vector2(64, 64)
