extends Node
## Central game manager handling app lifecycle and scene transitions

signal offline_rewards_calculated(rewards: Dictionary)
signal scene_transition_requested(scene_path: String)

var last_close_time: int = 0
var is_first_launch: bool = true

func _ready() -> void:
	# Load saved data
	load_game_data()

	# Check if returning from background
	if not is_first_launch:
		calculate_offline_rewards()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Android back button
			handle_back_button()
		NOTIFICATION_APPLICATION_PAUSED:
			# App going to background
			save_close_time()
		NOTIFICATION_APPLICATION_RESUMED:
			# App returning from background
			calculate_offline_rewards()

func save_close_time() -> void:
	last_close_time = Time.get_unix_time_from_system()
	save_game_data()

func calculate_offline_rewards() -> void:
	if last_close_time == 0:
		return

	# Get movement data from HealthManager
	var distance_traveled = await HealthManager.get_distance_since(last_close_time)
	var avg_efficiency = await HealthManager.calculate_efficiency(last_close_time)

	# Calculate chunks (50m per chunk)
	var chunks_collected = floor(distance_traveled / 50.0)

	if chunks_collected > 0:
		var rewards = generate_raw_chunks(chunks_collected, avg_efficiency)
		offline_rewards_calculated.emit(rewards)

func generate_raw_chunks(count: int, efficiency: float) -> Dictionary:
	var total_raw_lkc = 0
	var chunks = []

	for i in range(count):
		var base_amount = randi_range(12, 20)
		var final_amount = floor(base_amount * efficiency)
		total_raw_lkc += final_amount

		chunks.append({
			"id": "chunk_%d_%d" % [Time.get_unix_time_from_system(), i],
			"element": "lkC",
			"base_amount": base_amount,
			"efficiency": efficiency,
			"final_amount": final_amount,
			"analyzed": false
		})

	return {
		"chunks": chunks,
		"total_raw_lkc": total_raw_lkc,
		"chunk_count": count,
		"avg_per_chunk": total_raw_lkc / float(count)
	}

func save_game_data() -> void:
	var save_data = {
		"last_close_time": last_close_time,
		"is_first_launch": false
	}

	var file = FileAccess.open("user://game_data.save", FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()

func load_game_data() -> void:
	if not FileAccess.file_exists("user://game_data.save"):
		is_first_launch = true
		return

	var file = FileAccess.open("user://game_data.save", FileAccess.READ)
	if file:
		var save_data = file.get_var()
		last_close_time = save_data.get("last_close_time", 0)
		is_first_launch = save_data.get("is_first_launch", true)
		file.close()

func handle_back_button() -> void:
	# Handle navigation back
	get_tree().quit()

func transition_to_scene(scene_path: String) -> void:
	scene_transition_requested.emit(scene_path)
	get_tree().change_scene_to_file(scene_path)
