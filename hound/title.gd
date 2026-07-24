extends Control


func _ready() -> void:
	$Menu/TrainingButton.pressed.connect(_start_training)


func _start_training() -> void:
	get_tree().change_scene_to_file("res://loadout.tscn")
