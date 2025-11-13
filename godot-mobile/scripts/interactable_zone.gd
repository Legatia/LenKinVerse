extends StaticBody2D
## Base class for interactable furniture in the room

@export var zone_name: String = "Interactable"
@export var scene_to_open: String = ""  # Path to UI scene

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: Area2D = $InteractionArea

func _ready() -> void:
	# Add to interactable group
	interaction_area.add_to_group("interactable")

func interact() -> void:
	print("Interacting with: ", zone_name)

	if scene_to_open != "":
		open_ui_scene()
	else:
		push_warning("No scene assigned to: " + zone_name)

func open_ui_scene() -> void:
	# Load and show UI scene
	var ui_scene = load(scene_to_open)
	if ui_scene:
		var ui_instance = ui_scene.instantiate()
		get_tree().root.add_child(ui_instance)
	else:
		push_error("Failed to load scene: " + scene_to_open)
