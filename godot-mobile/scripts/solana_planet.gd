extends Node2D
## Solana Planet scene - room-based gameplay for Solana blockchain
##
## This scene is specifically for the Solana ecosystem and integrates with:
## - Solana smart contracts (marketplace, element-nft, registry)
## - Solana Mobile Wallet Adapter (via WalletManager)
## - alSOL token economy (1:1 SOL-backed in-game currency)
##
## Players can:
## - Collect raw materials through movement
## - Analyze materials with Alchemy Gloves
## - Perform reactions to create compounds
## - Mint discoveries as NFTs on Solana
## - Trade elements on decentralized marketplace
## - Swap SOL/LKC for alSOL currency
##
## Smart Contracts:
## - Marketplace: MKTPLCExxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
## - Element NFT: ELeMNFTxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
## - Registry: (TBD)
##
## See: SOLANA_PLANET_TODO.md for integration status

func _ready() -> void:
	# Create room boundaries to keep player inside brown floor area
	_create_room_boundaries()

	# Setup furniture icons from asset_config.json
	_setup_furniture_icons()

	# Show tutorial overlay if needed
	if TutorialManager.should_show_tutorial():
		call_deferred("show_tutorial")

func _create_room_boundaries() -> void:
	"""Create invisible collision walls to keep player in the brown room area"""
	# Brown room bounds from FloorTiles: x: 20-340, y: 80-600
	var room_left = 20.0
	var room_right = 340.0
	var room_top = 80.0
	var room_bottom = 600.0
	var wall_thickness = 10.0

	# Create walls as StaticBody2D nodes
	var walls = [
		{"pos": Vector2(room_left - wall_thickness/2, (room_top + room_bottom)/2), "size": Vector2(wall_thickness, room_bottom - room_top)},  # Left wall
		{"pos": Vector2(room_right + wall_thickness/2, (room_top + room_bottom)/2), "size": Vector2(wall_thickness, room_bottom - room_top)},  # Right wall
		{"pos": Vector2((room_left + room_right)/2, room_top - wall_thickness/2), "size": Vector2(room_right - room_left, wall_thickness)},  # Top wall
		{"pos": Vector2((room_left + room_right)/2, room_bottom + wall_thickness/2), "size": Vector2(room_right - room_left, wall_thickness)}  # Bottom wall
	]

	for wall_data in walls:
		var wall = StaticBody2D.new()
		wall.position = wall_data["pos"]

		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = wall_data["size"]
		collision.shape = shape

		wall.add_child(collision)
		add_child(wall)

	print("Room boundaries created: (%d, %d) to (%d, %d)" % [room_left, room_top, room_right, room_bottom])

func show_tutorial() -> void:
	var tutorial_scene = load("res://scenes/ui/tutorial_overlay.tscn")
	if tutorial_scene:
		var tutorial_instance = tutorial_scene.instantiate()
		get_tree().root.add_child(tutorial_instance)
	else:
		push_error("Failed to load tutorial overlay scene")

func _setup_furniture_icons() -> void:
	"""Load and apply furniture icons from asset_config.json"""
	# Setup Storage Box icon
	var storage_node = get_node_or_null("StorageBox")
	if storage_node:
		_apply_furniture_icon(storage_node, "storage_box")

	# Setup Marketplace icon
	var marketplace_node = get_node_or_null("Marketplace")
	if marketplace_node:
		_apply_furniture_icon(marketplace_node, "marketplace")

func _apply_furniture_icon(furniture_node: Node2D, furniture_id: String) -> void:
	"""Apply icon texture to furniture node, replacing emoji label"""
	var icon_texture = AssetManager.get_furniture_icon(furniture_id)

	print("DEBUG: Attempting to load furniture icon for: %s" % furniture_id)
	print("DEBUG: Icon texture type: %s" % type_string(typeof(icon_texture)))
	print("DEBUG: Icon texture value: %s" % str(icon_texture))

	if icon_texture is Texture2D:
		# Remove the emoji label
		var label = furniture_node.get_node_or_null("ColorRect/Label")
		if label:
			label.queue_free()

		# Create a Sprite2D to display the icon
		var sprite = Sprite2D.new()
		sprite.texture = icon_texture
		sprite.name = "IconSprite"

		# Scale to fit the furniture size (80x80 area)
		var image = icon_texture.get_image()
		var icon_size = image.get_size()
		var target_size = 60.0  # Slightly smaller than 80x80 to add padding
		var scale_factor = target_size / max(icon_size.x, icon_size.y)
		sprite.scale = Vector2(scale_factor, scale_factor)

		# Add sprite to ColorRect
		var color_rect = furniture_node.get_node_or_null("ColorRect")
		if color_rect:
			color_rect.add_child(sprite)
			# Center the sprite
			sprite.position = Vector2(40, 40)  # Center of 80x80 rect

		print("Solana Planet: Loaded %s furniture icon" % furniture_id)
	else:
		print("Solana Planet: Using fallback emoji for %s" % furniture_id)
