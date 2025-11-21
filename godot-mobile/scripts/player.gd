extends CharacterBody2D
## Player character with top-down movement and interaction system

@export var move_speed: float = 100.0

@onready var sprite_node: Node = null  # Will be set to either ColorRect or Sprite2D
@onready var interaction_area: Area2D = $InteractionArea

var current_direction: String = "down"
var is_moving: bool = false
var nearby_interactable: Node2D = null
var interaction_prompt: Label = null

func _ready() -> void:
	# Setup player sprite programmatically
	_setup_player_sprite()

	# Connect interaction area signals
	interaction_area.area_entered.connect(_on_interaction_area_entered)
	interaction_area.area_exited.connect(_on_interaction_area_exited)

	# Get reference to HUD prompt
	interaction_prompt = get_node("/root/Main/HUD/InteractionPrompt")

func _setup_player_sprite() -> void:
	"""Programmatically load and setup player sprite from asset_config.json"""
	var player_texture = AssetManager.get_player_sprite()

	if player_texture is Texture2D:
		# Remove old ColorRect if it exists
		var old_color_rect = get_node_or_null("ColorRect")
		if old_color_rect:
			old_color_rect.queue_free()

		# Create new Sprite2D with player texture
		var sprite = Sprite2D.new()
		sprite.name = "PlayerSprite"
		sprite.texture = player_texture
		sprite.centered = true

		# Scale down the 1024x1024 image to ~32x32 for game
		var scale_factor = 32.0 / 1024.0
		sprite.scale = Vector2(scale_factor, scale_factor)

		# Add as child
		add_child(sprite)
		sprite_node = sprite

		print("Player: Loaded player.JPG sprite from asset_config.json")
	else:
		# Fallback: Use existing ColorRect if sprite loading fails
		sprite_node = get_node_or_null("ColorRect")
		if sprite_node:
			print("Player: Using fallback ColorRect (sprite loading failed)")
		else:
			# Create fallback ColorRect if nothing exists
			var color_rect = ColorRect.new()
			color_rect.name = "ColorRect"
			color_rect.size = Vector2(32, 32)
			color_rect.position = Vector2(-16, -16)
			color_rect.color = Color(0.4, 0.8, 0.4, 1)
			add_child(color_rect)
			sprite_node = color_rect
			print("Player: Created fallback ColorRect")

func _physics_process(_delta: float) -> void:
	# Get input direction
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")

	# Normalize to prevent faster diagonal movement
	input_vector = input_vector.normalized()

	# Update velocity
	velocity = input_vector * move_speed

	# Update visual (movement state)
	if input_vector.length() > 0:
		is_moving = true
		# For Sprite2D: Could add modulate or animation
		# For ColorRect: Change color
		if sprite_node is ColorRect:
			sprite_node.color = Color(0.3, 0.7, 0.3, 1)
		elif sprite_node is Sprite2D:
			# Slightly darken when moving (optional visual feedback)
			sprite_node.modulate = Color(0.9, 0.9, 0.9, 1)
	else:
		is_moving = false
		# Reset to normal appearance
		if sprite_node is ColorRect:
			sprite_node.color = Color(0.4, 0.8, 0.4, 1)
		elif sprite_node is Sprite2D:
			sprite_node.modulate = Color(1, 1, 1, 1)

	# Move character
	move_and_slide()

	# NOTE: Interaction is now handled by direct clicks on furniture
	# Proximity-based interaction disabled for mobile
	# if Input.is_action_just_pressed("ui_interact") and nearby_interactable:
	#	interact_with_nearby()

func _on_interaction_area_entered(area: Area2D) -> void:
	if area.is_in_group("interactable"):
		nearby_interactable = area.get_parent()
		# Disabled: Direct click interaction is used instead
		# show_interaction_prompt()

func _on_interaction_area_exited(area: Area2D) -> void:
	if area.is_in_group("interactable") and area.get_parent() == nearby_interactable:
		nearby_interactable = null
		# Disabled: Direct click interaction is used instead
		# hide_interaction_prompt()

func interact_with_nearby() -> void:
	if nearby_interactable and nearby_interactable.has_method("interact"):
		nearby_interactable.interact()

func show_interaction_prompt() -> void:
	if interaction_prompt and nearby_interactable:
		interaction_prompt.text = "[E] %s" % nearby_interactable.zone_name
		interaction_prompt.visible = true

func hide_interaction_prompt() -> void:
	if interaction_prompt:
		interaction_prompt.visible = false
