extends Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	%ResumeButton.pressed.connect(_resume_game)
	%MainMenuButton.pressed.connect(_return_to_main_menu)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			_resume_game()
		else:
			_pause_game()
		get_viewport().set_input_as_handled()


func _pause_game() -> void:
	show()
	get_tree().paused = true


func _resume_game() -> void:
	get_tree().paused = false
	hide()


func _return_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://title.tscn")
