extends Control
## Profile/Stats screen showing user progress

@onready var wallet_label: Label = $Panel/VBoxContainer/WalletSection/WalletLabel
@onready var world_label: Label = $Panel/VBoxContainer/WalletSection/WorldLabel
@onready var sol_balance_label: Label = $Panel/VBoxContainer/WalletSection/SOLBalanceLabel
@onready var alsol_balance_label: Label = $Panel/VBoxContainer/WalletSection/alSOLBalanceLabel

@onready var gloves_level_label: Label = $Panel/VBoxContainer/GlovesSection/LevelLabel
@onready var gloves_progress_bar: ProgressBar = $Panel/VBoxContainer/GlovesSection/ProgressBar
@onready var gloves_progress_label: Label = $Panel/VBoxContainer/GlovesSection/ProgressBar/Label

@onready var analyses_label: Label = $Panel/VBoxContainer/StatsSection/AnalysesLabel
@onready var distance_label: Label = $Panel/VBoxContainer/StatsSection/DistanceLabel
@onready var collected_label: Label = $Panel/VBoxContainer/StatsSection/CollectedLabel
@onready var isotopes_label: Label = $Panel/VBoxContainer/StatsSection/IsotopesLabel

func _ready() -> void:
	refresh_stats()

	# Connect to wallet balance updates
	WalletManager.balance_updated.connect(_on_balance_updated)

func refresh_stats() -> void:
	# Wallet info
	var wallet_address = WalletManager.wallet_address
	if wallet_address:
		var shortened = wallet_address.substr(0, 4) + "..." + wallet_address.substr(-4)
		wallet_label.text = "👻 " + shortened
	else:
		wallet_label.text = "👻 Not Connected"

	# Balances
	if WalletManager.is_connected:
		sol_balance_label.text = "💎 SOL: %.3f" % WalletManager.sol_balance
		alsol_balance_label.text = "⚡ alSOL: %.3f" % WalletManager.alsol_balance
	else:
		sol_balance_label.text = "💎 SOL: ---"
		alsol_balance_label.text = "⚡ alSOL: ---"

	# World info
	var world_data = WorldManager.get_current_world()
	if not world_data.is_empty():
		var icon = world_data.get("icon", "🌍")
		var name = world_data.get("display_name", "Unknown")
		world_label.text = "%s %s" % [icon, name]
	else:
		world_label.text = "🌍 No World Selected"

	# Gloves info
	var gloves_data = load_gloves_data()
	var level = gloves_data.get("level", 1)
	var analyses_count = gloves_data.get("analyses_count", 0)

	gloves_level_label.text = "Gloves Level: %d" % level

	# Progress to next level
	var level_thresholds = [0, 500, 2000, 5000, 10000]
	if level < 5:
		var current_threshold = level_thresholds[level - 1]
		var next_threshold = level_thresholds[level]
		var progress = float(analyses_count - current_threshold) / float(next_threshold - current_threshold)
		gloves_progress_bar.value = progress * 100.0
		gloves_progress_label.text = "%d / %d analyses" % [analyses_count, next_threshold]
	else:
		gloves_progress_bar.value = 100.0
		gloves_progress_label.text = "MAX LEVEL"

	# Stats
	analyses_label.text = "⚗️ Total Analyses: %s" % format_number(analyses_count)

	# Distance traveled (mock for now)
	var distance_km = analyses_count * 0.05  # Rough estimate
	distance_label.text = "🚶 Distance Traveled: %.2f km" % distance_km

	# Total collected
	var total_raw = InventoryManager.raw_materials.get("lkC", 0)
	var total_clean = InventoryManager.elements.get("lkC", 0)
	collected_label.text = "💰 Total lkC Collected: %s" % format_number(total_raw + total_clean)

	# Isotopes discovered
	var isotope_count = InventoryManager.isotopes.size()
	isotopes_label.text = "💎 Isotopes Discovered: %d" % isotope_count

func load_gloves_data() -> Dictionary:
	var save_path = "user://gloves.save"
	if not FileAccess.file_exists(save_path):
		return {"level": 1, "analyses_count": 0}

	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			return json.data

	return {"level": 1, "analyses_count": 0}

func format_number(num: int) -> String:
	var str_num = str(num)
	var result = ""
	var counter = 0

	for i in range(str_num.length() - 1, -1, -1):
		if counter == 3:
			result = "," + result
			counter = 0
		result = str_num[i] + result
		counter += 1

	return result

## Called when wallet balance is updated
func _on_balance_updated(sol: float, alsol: float) -> void:
	sol_balance_label.text = "💎 SOL: %.3f" % sol
	alsol_balance_label.text = "⚡ alSOL: %.3f" % alsol

func _on_close_button_pressed() -> void:
	queue_free()
