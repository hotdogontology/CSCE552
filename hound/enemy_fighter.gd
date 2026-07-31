extends Area3D

const ENEMY_LASER_SCENE := preload("res://enemy_laser.tscn")

enum FlightState {
	ENTERING,
	ATTACKING,
	EXITING
}

@export var entry_speed := 12.0
@export var exit_speed := 12.0
@export var attack_duration := 5.0
@export var fire_interval := 1.1
@export var exit_x := 4.5
@export_range(1, 20, 1) var maximum_health := 1

var health := 1
var has_been_destroyed := false
var flight_state := FlightState.ENTERING
var entry_side := 1.0
var attack_position := Vector3.ZERO
var attack_time_remaining := 0.0
var fire_cooldown := 0.0
var hover_time := 0.0


func _ready() -> void:
	health = maximum_health


func begin_side_attack(
	new_entry_side: float,
	target_x: float,
	new_exit_x: float
) -> void:
	entry_side = signf(new_entry_side)
	if is_zero_approx(entry_side):
		entry_side = 1.0
	attack_position = Vector3(target_x, position.y, position.z)
	exit_x = maxf(new_exit_x, absf(target_x) + 1.0)
	rotation.y = PI


func _process(delta: float) -> void:
	match flight_state:
		FlightState.ENTERING:
			position = position.move_toward(attack_position, entry_speed * delta)
			if position.is_equal_approx(attack_position):
				flight_state = FlightState.ATTACKING
				attack_time_remaining = attack_duration
				fire_cooldown = 0.35
		FlightState.ATTACKING:
			_update_attack(delta)
		FlightState.EXITING:
			position.x = move_toward(
				position.x,
				-entry_side * exit_x,
				exit_speed * delta
			)
			if is_equal_approx(position.x, -entry_side * exit_x):
				queue_free()


func _update_attack(delta: float) -> void:
	attack_time_remaining -= delta
	fire_cooldown -= delta
	hover_time += delta
	position.y = attack_position.y + sin(hover_time * 1.8) * 0.25
	if fire_cooldown <= 0.0:
		_fire_at_player()
		fire_cooldown = fire_interval
	if attack_time_remaining <= 0.0:
		flight_state = FlightState.EXITING


func _fire_at_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Area3D
	if player == null:
		return
	var enemy_laser := ENEMY_LASER_SCENE.instantiate() as Area3D
	get_tree().current_scene.add_child(enemy_laser)
	enemy_laser.global_position = global_position + Vector3(0.0, 0.0, 0.35)
	enemy_laser.call(
		"set_direction",
		enemy_laser.global_position.direction_to(player.global_position)
	)


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
