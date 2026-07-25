extends Control

@onready var main_menu: VBoxContainer = $Menu
@onready var controls_panel: CenterContainer = $ControlsPanel
@onready var invert_vertical_toggle: CheckButton = %InvertVerticalToggle


func _ready() -> void:
	$Menu/TrainingButton.pressed.connect(_start_training)
	$Menu/ControlsButton.pressed.connect(_show_controls)
	%BackButton.pressed.connect(_hide_controls)
	invert_vertical_toggle.toggled.connect(_set_vertical_inversion)
	invert_vertical_toggle.button_pressed = bool(
		get_node("/root/LoadoutState").get("vertical_controls_inverted")
	)


func _start_training() -> void:
	get_tree().change_scene_to_file("res://loadout.tscn")


func _show_controls() -> void:
	main_menu.hide()
	controls_panel.show()


func _hide_controls() -> void:
	controls_panel.hide()
	main_menu.show()


func _set_vertical_inversion(is_inverted: bool) -> void:
	get_node("/root/LoadoutState").set(
		"vertical_controls_inverted",
		is_inverted
	)
