extends Control

@onready var main_menu: VBoxContainer = $Menu
@onready var controls_panel: CenterContainer = $ControlsPanel
@onready var exit_menu: Control = $ExitMenu
@onready var invert_vertical_toggle: CheckButton = %InvertVerticalToggle


func _ready() -> void:
	$Menu/NewGameButton.pressed.connect(_start_new_game)
	$Menu/TrainingButton.pressed.connect(_start_training)
	$Menu/ControlsButton.pressed.connect(_show_controls)
	%BackButton.pressed.connect(_hide_controls)
	%ReturnToMainMenuButton.pressed.connect(_hide_exit_menu)
	%QuitGameButton.pressed.connect(_quit_game)
	invert_vertical_toggle.toggled.connect(_set_vertical_inversion)
	invert_vertical_toggle.button_pressed = bool(
		get_node("/root/LoadoutState").get("vertical_controls_inverted")
	)
	$Menu/NewGameButton.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if controls_panel.visible:
			_hide_controls()
		elif exit_menu.visible:
			_hide_exit_menu()
		else:
			_show_exit_menu()
		get_viewport().set_input_as_handled()


func _start_training() -> void:
	get_tree().change_scene_to_file("res://loadout.tscn")


func _start_new_game() -> void:
	get_tree().change_scene_to_file("res://galaxy_map.tscn")


func _show_controls() -> void:
	main_menu.hide()
	controls_panel.show()


func _hide_controls() -> void:
	controls_panel.hide()
	main_menu.show()
	$Menu/NewGameButton.grab_focus()


func _show_exit_menu() -> void:
	exit_menu.show()
	%ReturnToMainMenuButton.grab_focus()


func _hide_exit_menu() -> void:
	exit_menu.hide()
	$Menu/NewGameButton.grab_focus()


func _quit_game() -> void:
	get_tree().quit()


func _set_vertical_inversion(is_inverted: bool) -> void:
	get_node("/root/LoadoutState").set(
		"vertical_controls_inverted",
		is_inverted
	)
