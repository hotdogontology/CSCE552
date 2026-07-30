extends Area3D

@export var speed := 20.0
@export var despawn_z := 15.0
@export_range(1, 20, 1) var maximum_health := 3

var health := 3
var has_been_destroyed := false


func _ready() -> void:
	health = maximum_health


func _process(delta: float) -> void:
	position.z += speed * delta
	if position.z > despawn_z:
		queue_free()


func take_damage(amount: int = 1) -> void:
	if has_been_destroyed:
		return
	health -= maxi(amount, 1)
	if health > 0:
		return
	has_been_destroyed = true
	get_tree().call_group(
		"player_kill_counter",
		"register_player_kill"
	)
	queue_free()
