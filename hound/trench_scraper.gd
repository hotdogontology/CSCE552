extends Area3D

# speed at which buildings move towards player
@export var speed := 25.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position.z += speed * delta 
	
	if position.z > 15.0: 
		queue_free()
