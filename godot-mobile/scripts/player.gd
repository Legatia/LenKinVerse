extends CharacterBody2D
## Player character with top-down movement and interaction system

@export var move_speed: float = 100.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $InteractionArea

var current_direction: String = "down"
var is_moving: bool = false
var nearby_interactable: Node2D = null

func _ready() -> void:
	# Connect interaction area signals
	interaction_area.area_entered.connect(_on_interaction_area_entered)
	interaction_area.area_exited.connect(_on_interaction_area_exited)

func _physics_process(_delta: float) -> void:
	# Get input direction
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")

	# Normalize to prevent faster diagonal movement
	input_vector = input_vector.normalized()

	# Update velocity
	velocity = input_vector * move_speed

	# Update animation
	if input_vector.length() > 0:
		is_moving = true
		update_direction(input_vector)
		play_walk_animation()
	else:
		is_moving = false
		play_idle_animation()

	# Move character
	move_and_slide()

	# Check for interaction input
	if Input.is_action_just_pressed("ui_interact") and nearby_interactable:
		interact_with_nearby()

func update_direction(input: Vector2) -> void:
	# Determine primary direction
	if abs(input.x) > abs(input.y):
		current_direction = "right" if input.x > 0 else "left"
	else:
		current_direction = "down" if input.y > 0 else "up"

func play_walk_animation() -> void:
	match current_direction:
		"down":
			sprite.play("walk_down")
		"up":
			sprite.play("walk_up")
		"left":
			sprite.play("walk_left")
		"right":
			sprite.play("walk_right")

func play_idle_animation() -> void:
	match current_direction:
		"down":
			sprite.play("idle_down")
		"up":
			sprite.play("idle_up")
		"left":
			sprite.play("idle_left")
		"right":
			sprite.play("idle_right")

func _on_interaction_area_entered(area: Area2D) -> void:
	if area.is_in_group("interactable"):
		nearby_interactable = area.get_parent()
		show_interaction_prompt()

func _on_interaction_area_exited(area: Area2D) -> void:
	if area.is_in_group("interactable") and area.get_parent() == nearby_interactable:
		nearby_interactable = null
		hide_interaction_prompt()

func interact_with_nearby() -> void:
	if nearby_interactable and nearby_interactable.has_method("interact"):
		nearby_interactable.interact()

func show_interaction_prompt() -> void:
	# TODO: Show [E] prompt UI
	pass

func hide_interaction_prompt() -> void:
	# TODO: Hide prompt UI
	pass
