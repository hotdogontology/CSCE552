extends Area3D

@export var speed := 18.0
@export var lifetime := 2.0


func _process(delta: float) -> void:
	position.z -= speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
