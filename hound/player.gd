extends Area3D

@export var speed := 4.0
@export var horizontal_limit := 4.0
@export var vertical_minimum := -2.0
@export var vertical_maximum := 2.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	var input_direction := Input.get_vector( "move_left", "move_right", "move_up", "move_down" )
	
	position.x += input_direction.x * speed * delta
	position.y -= input_direction.y * speed * delta
	
	position.x = clampf( position.x, -horizontal_limit, horizontal_limit )
	position.y = clampf( position.y, vertical_minimum, vertical_maximum )
	
