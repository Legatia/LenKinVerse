extends Node2D
## Base Planet placeholder - Ethereum Layer 2 gameplay (coming soon)

func _ready() -> void:
	print("Base Planet - Coming Soon!")

func _on_back_button_pressed() -> void:
	# Reset world selection and go back
	WorldManager.reset_world_selection()
	get_tree().change_scene_to_file("res://scenes/ui/world_selection.tscn")
