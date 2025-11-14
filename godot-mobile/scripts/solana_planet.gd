extends Node2D
## Solana Planet scene - room-based gameplay for Solana blockchain

func _ready() -> void:
	# Show tutorial overlay if needed
	if TutorialManager.should_show_tutorial():
		call_deferred("show_tutorial")

func show_tutorial() -> void:
	var tutorial_scene = load("res://scenes/ui/tutorial_overlay.tscn")
	if tutorial_scene:
		var tutorial_instance = tutorial_scene.instantiate()
		get_tree().root.add_child(tutorial_instance)
	else:
		push_error("Failed to load tutorial overlay scene")
