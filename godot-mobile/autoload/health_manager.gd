extends Node
## Manages movement tracking via iOS HealthKit / Android Google Fit
## Requires native plugin for iOS/Android

signal health_data_received(distance: float, steps: int)
signal permissions_granted()
signal permissions_denied()

var has_permissions: bool = false
var native_plugin = null

func _ready() -> void:
	# Try to load native health plugin
	if OS.get_name() == "iOS":
		if Engine.has_singleton("HealthKit"):
			native_plugin = Engine.get_singleton("HealthKit")
			print("HealthKit plugin loaded")
	elif OS.get_name() == "Android":
		if Engine.has_singleton("GoogleFit"):
			native_plugin = Engine.get_singleton("GoogleFit")
			print("Google Fit plugin loaded")

	if not native_plugin:
		push_warning("Health plugin not found - using mock mode")

## Request permissions to access health data
func request_permissions() -> bool:
	if native_plugin:
		var result = await native_plugin.request_authorization([
			"distance_walking_running",
			"step_count"
		])

		has_permissions = result.granted
		if has_permissions:
			permissions_granted.emit()
		else:
			permissions_denied.emit()

		return has_permissions
	else:
		# Mock permissions granted
		await get_tree().create_timer(0.5).timeout
		has_permissions = true
		permissions_granted.emit()
		return true

## Get distance traveled since timestamp
func get_distance_since(timestamp: int) -> float:
	if not has_permissions:
		push_warning("Health permissions not granted")
		return 0.0

	if native_plugin:
		var start_date = Time.get_datetime_dict_from_unix_time(timestamp)
		var end_date = Time.get_datetime_dict_from_system()

		var result = await native_plugin.get_distance({
			"start_date": start_date,
			"end_date": end_date
		})

		return result.distance if result.success else 0.0
	else:
		# Mock distance based on time passed
		return _mock_distance(timestamp)

## Get step count since timestamp
func get_steps_since(timestamp: int) -> int:
	if not has_permissions:
		push_warning("Health permissions not granted")
		return 0

	if native_plugin:
		var start_date = Time.get_datetime_dict_from_unix_time(timestamp)
		var end_date = Time.get_datetime_dict_from_system()

		var result = await native_plugin.get_steps({
			"start_date": start_date,
			"end_date": end_date
		})

		return result.steps if result.success else 0
	else:
		# Mock steps
		return _mock_steps(timestamp)

## Calculate average movement efficiency based on distance and steps
func calculate_efficiency(timestamp: int) -> float:
	var distance = await get_distance_since(timestamp)
	var steps = await get_steps_since(timestamp)

	if distance == 0 or steps == 0:
		return 0.95  # Default to walking efficiency

	# Calculate average stride length
	var avg_stride = distance / float(steps)

	# Determine efficiency based on stride length
	# Walking: ~0.7-0.8m per step = 95%
	# Jogging: ~1.0-1.2m per step = 85%
	# Running: ~1.2-1.5m per step = 70%
	# Vehicle: very few steps for distance = 50%

	if avg_stride < 0.85:
		return 0.95  # Walking
	elif avg_stride < 1.2:
		return 0.85  # Jogging
	elif steps > distance * 0.3:
		return 0.70  # Running
	else:
		return 0.50  # Vehicle (few steps, large distance)

## Mock distance calculation for testing
func _mock_distance(since_timestamp: int) -> float:
	var hours_elapsed = (Time.get_unix_time_from_system() - since_timestamp) / 3600.0
	# Assume average 1 km per hour walked
	var distance = hours_elapsed * 1000.0  # meters
	# Add some randomness
	distance *= randf_range(0.8, 1.2)
	return min(distance, 50000.0)  # Cap at 50km

## Mock steps calculation
func _mock_steps(since_timestamp: int) -> int:
	var distance = _mock_distance(since_timestamp)
	# Average stride ~0.75m
	return int(distance / 0.75)

## Get today's stats
func get_today_stats() -> Dictionary:
	var today_start = Time.get_unix_time_from_system()
	today_start = today_start - (today_start % 86400)  # Start of day

	var distance = await get_distance_since(today_start)
	var steps = await get_steps_since(today_start)

	return {
		"distance": distance,
		"steps": steps,
		"distance_km": distance / 1000.0
	}
