extends Area3D

# speed at which buildings move towards player
@export var speed := 25.0
@export var despawn_z := 15.0

func _process(delta: float) -> void:
	position.z += speed * delta

	if position.z > despawn_z:
		queue_free()
