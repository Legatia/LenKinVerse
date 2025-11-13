extends StaticBody2D
## Base class for interactable furniture in the room

@export var zone_name: String = "Interactable"
@export var scene_to_open: String = ""  # Path to UI scene

@onready var interaction_area: Area2D = $InteractionArea

var current_ui_instance: Node = null

func _ready() -> void:
	# Add to interactable group
	interaction_area.add_to_group("interactable")

func interact() -> void:
	print("Interacting with: ", zone_name)

	# Don't open if already open
	if current_ui_instance != null and is_instance_valid(current_ui_instance):
		print("UI already open for: ", zone_name)
		return

	if scene_to_open != "":
		open_ui_scene()
	else:
		push_warning("No scene assigned to: " + zone_name)

func open_ui_scene() -> void:
	# Load and show UI scene
	var ui_scene = load(scene_to_open)
	if ui_scene:
		var ui_instance = ui_scene.instantiate()
		current_ui_instance = ui_instance
		get_tree().root.add_child(ui_instance)

		# Connect to the instance's tree_exiting signal to clean up reference
		ui_instance.tree_exiting.connect(_on_ui_closed)
	else:
		push_error("Failed to load scene: " + scene_to_open)

func _on_ui_closed() -> void:
	current_ui_instance = null
