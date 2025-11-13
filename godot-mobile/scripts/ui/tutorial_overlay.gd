extends CanvasLayer
## Tutorial overlay that displays step-by-step instructions

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var message_label: Label = $Panel/VBoxContainer/MessageLabel
@onready var step_label: Label = $Panel/VBoxContainer/StepLabel
@onready var next_button: Button = $Panel/VBoxContainer/ButtonContainer/NextButton
@onready var skip_button: Button = $Panel/VBoxContainer/ButtonContainer/SkipButton

@onready var highlight_arrow: Control = $HighlightArrow

func _ready() -> void:
	# Connect signals
	next_button.pressed.connect(_on_next_pressed)
	skip_button.pressed.connect(_on_skip_pressed)

	# Show first step if tutorial not completed
	if TutorialManager.should_show_tutorial():
		show_current_step()
	else:
		queue_free()

func show_current_step() -> void:
	var step = TutorialManager.get_current_step()
	if step.is_empty():
		# Tutorial complete
		queue_free()
		return

	title_label.text = step.get("title", "")
	message_label.text = step.get("message", "")

	# Update step counter
	var total_steps = TutorialManager.tutorial_steps.size()
	var current = TutorialManager.current_step + 1
	step_label.text = "Step %d / %d" % [current, total_steps]

	# Update button text
	if current >= total_steps:
		next_button.text = "FINISH"
	else:
		next_button.text = "NEXT"

	# Show highlight if needed
	var highlight_target = step.get("highlight", "")
	if highlight_target != "":
		show_highlight(highlight_target)
	else:
		hide_highlight()

func show_highlight(target_name: String) -> void:
	# Find the target node in the scene
	var main_scene = get_tree().root.get_node("Main")
	if main_scene:
		var target = main_scene.get_node_or_null(target_name)
		if target and target is Node2D:
			# Position arrow near the target
			highlight_arrow.visible = true
			var target_pos = target.global_position
			# Position arrow above the target
			highlight_arrow.position = Vector2(target_pos.x - 20, target_pos.y - 80)
		else:
			hide_highlight()
	else:
		hide_highlight()

func hide_highlight() -> void:
	highlight_arrow.visible = false

func _on_next_pressed() -> void:
	TutorialManager.advance_tutorial()
	show_current_step()

func _on_skip_pressed() -> void:
	TutorialManager.mark_completed()
	queue_free()
