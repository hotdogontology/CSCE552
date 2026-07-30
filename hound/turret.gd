extends Area3D

const ENEMY_LASER_SCENE := preload("res://enemy_laser.tscn")

@export var speed := 30.0
@export var despawn_z := 15.0
@export var maximum_health := 3
@export var fire_interval := 1.5
@export var minimum_firing_distance := 2.0
@export var maximum_firing_distance := 100.0

var health := 3
var fire_cooldown := 0.0
var has_been_destroyed := false


func _ready() -> void:
	health = maximum_health
	fire_cooldown = randf_range(0.35, fire_interval)


func _physics_process(delta: float) -> void:
	position.z += speed * delta
	if position.z > despawn_z:
		queue_free()
		return

	fire_cooldown = maxf(fire_cooldown - delta, 0.0)
	if fire_cooldown <= 0.0:
		_try_to_fire()


func take_damage(amount: int = 1) -> void:
	if has_been_destroyed:
		return
	health -= amount
	if health <= 0:
		has_been_destroyed = true
		get_tree().call_group(
			"player_kill_counter",
			"register_player_kill"
		)
		queue_free()


func _try_to_fire() -> void:
	var player := get_tree().get_first_node_in_group("player") as Area3D
	if player == null:
		return

	var distance_ahead := player.global_position.z - global_position.z
	if (
		distance_ahead < minimum_firing_distance
		or distance_ahead > maximum_firing_distance
	):
		return

	var enemy_laser := ENEMY_LASER_SCENE.instantiate() as Area3D
	get_tree().current_scene.add_child(enemy_laser)
	enemy_laser.global_position = global_position + Vector3(0.0, 2.5, 0.0)
	enemy_laser.call(
		"set_direction",
		enemy_laser.global_position.direction_to(player.global_position)
	)
	fire_cooldown = fire_interval
