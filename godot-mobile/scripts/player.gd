extends CharacterBody2D
## Player character with top-down movement and interaction system

@export var move_speed: float = 100.0

@onready var sprite: ColorRect = $ColorRect
@onready var interaction_area: Area2D = $InteractionArea

var current_direction: String = "down"
var is_moving: bool = false
var nearby_interactable: Node2D = null
var interaction_prompt: Label = null

func _ready() -> void:
	# Connect interaction area signals
	interaction_area.area_entered.connect(_on_interaction_area_entered)
	interaction_area.area_exited.connect(_on_interaction_area_exited)

	# Get reference to HUD prompt
	interaction_prompt = get_node("/root/Main/HUD/InteractionPrompt")

func _physics_process(_delta: float) -> void:
	# Get input direction
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")

	# Normalize to prevent faster diagonal movement
	input_vector = input_vector.normalized()

	# Update velocity
	velocity = input_vector * move_speed

	# Update visual (simple color change for now)
	if input_vector.length() > 0:
		is_moving = true
		sprite.color = Color(0.3, 0.7, 0.3, 1)
	else:
		is_moving = false
		sprite.color = Color(0.4, 0.8, 0.4, 1)

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
