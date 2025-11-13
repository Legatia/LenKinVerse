extends Control
## Offline rewards modal - shown when returning to app

@onready var distance_label: Label = $Panel/VBoxContainer/DistanceLabel
@onready var progress_bar: ProgressBar = $Panel/VBoxContainer/ProgressBar
@onready var progress_label: Label = $Panel/VBoxContainer/ProgressLabel
@onready var results_panel: Panel = $Panel/VBoxContainer/ResultsPanel
@onready var chunks_label: Label = $Panel/VBoxContainer/ResultsPanel/VBoxContainer/ChunksLabel
@onready var details_label: RichTextLabel = $Panel/VBoxContainer/ResultsPanel/VBoxContainer/DetailsLabel

var rewards: Dictionary = {}

func _ready() -> void:
	# Start calculating rewards
	calculate_rewards()

func calculate_rewards() -> void:
	# Animate progress bar
	var tween = create_tween()
	tween.tween_property(progress_bar, "value", 1.0, 2.0)

	# Wait for GameManager to calculate
	GameManager.offline_rewards_calculated.connect(_on_rewards_calculated)

	# Trigger calculation
	await get_tree().create_timer(0.5).timeout
	GameManager.calculate_offline_rewards()

func _on_rewards_calculated(reward_data: Dictionary) -> void:
	rewards = reward_data

	# Update distance
	var distance_km = rewards.get("distance", 0) / 1000.0
	distance_label.text = "🚶 %.2f km" % distance_km

	# Wait for progress bar to finish
	await get_tree().create_timer(1.5).timeout

	# Show results
	progress_label.text = "Complete!"
	results_panel.visible = true

	# Update results
	var chunk_count = rewards.get("chunk_count", 0)
	var total_raw_lkc = rewards.get("total_raw_lkc", 0)
	var avg_per_chunk = rewards.get("avg_per_chunk", 0.0)

	chunks_label.text = "📦 × %d chunks" % chunk_count

	if chunk_count > 0:
		var base_total = int(total_raw_lkc / 0.87)  # Assuming ~87% avg efficiency
		details_label.text = "[center]Base: %d × %.1f avg = %d
Efficiency: 87%%
────────────
Final: [color=#F59E0B]+%d raw lkC[/color][/center]" % [
			chunk_count,
			avg_per_chunk,
			base_total,
			total_raw_lkc
		]

		# Add chunks to inventory
		var chunks = rewards.get("chunks", [])
		InventoryManager.add_raw_chunks(chunks)
	else:
		details_label.text = "[center]No movement detected
────────────
Final: 0 raw lkC[/center]"

func _on_analyze_button_pressed() -> void:
	# Go to main scene and open gloves UI
	get_tree().change_scene_to_file("res://scenes/main.tscn")

	# Open gloves UI after scene loads
	await get_tree().create_timer(0.5).timeout
	var gloves_ui = load("res://scenes/ui/gloves_ui.tscn").instantiate()
	get_tree().root.add_child(gloves_ui)

func _on_continue_button_pressed() -> void:
	# Go to main scene
	get_tree().change_scene_to_file("res://scenes/main.tscn")
