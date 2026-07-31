extends Node3D

@export var speed := 6.0
@export var despawn_z := 10.0


func _process(delta: float) -> void:
	position.z += speed * delta
	if position.z > despawn_z:
		queue_free()
