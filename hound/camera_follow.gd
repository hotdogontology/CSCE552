extends Camera3D

@export var target_path: NodePath = NodePath("../Player")
@export_range(0.0, 1.0, 0.05) var horizontal_follow_amount := 0.3
@export_range(0.0, 1.0, 0.05) var vertical_follow_amount := 0.2
@export var follow_smoothing := 7.0

@onready var target: Node3D = get_node(target_path) as Node3D

var starting_position := Vector3.ZERO
var target_starting_position := Vector3.ZERO


func _ready() -> void:
	starting_position = position
	target_starting_position = target.position


func _process(delta: float) -> void:
	var target_offset := target.position - target_starting_position
	var desired_position := starting_position + Vector3(
		target_offset.x * horizontal_follow_amount,
		target_offset.y * vertical_follow_amount,
		0.0
	)
	var follow_weight := 1.0 - exp(-follow_smoothing * delta)
	position = position.lerp(desired_position, follow_weight)
