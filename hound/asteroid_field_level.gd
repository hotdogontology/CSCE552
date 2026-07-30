extends Node3D

const ROCK_ASTEROID_SCENE := preload("res://asteroid.tscn")
const METAL_ASTEROID_SCENE := preload("res://metal_rich_asteroid.tscn")

@export var scroll_speed := 7.0
@export var boost_scroll_speed := 11.0
@export var brake_scroll_speed := 4.0
@export var scroll_speed_acceleration := 20.0
@export var asteroid_spawn_z := -100.0
@export var horizontal_spawn_limit := 2.4
@export var vertical_spawn_minimum := -2.0
@export var vertical_spawn_maximum := 2.0
@export_range(0.0, 1.0, 0.05) var metal_spawn_chance := 0.3
@export var minimum_spawn_delay := 1.2
@export var maximum_spawn_delay := 2.2

@onready var player: Area3D = $Player
@onready var asteroid_timer: Timer = $AsteroidTimer

var current_scroll_speed := 0.0
var level_restarting := false


func _ready() -> void:
	current_scroll_speed = scroll_speed
	player.area_entered.connect(_on_player_area_entered)
	asteroid_timer.timeout.connect(_spawn_asteroid)
	_schedule_next_asteroid()


func _process(delta: float) -> void:
	_update_scroll_speed(delta)
	for asteroid in get_tree().get_nodes_in_group("asteroid"):
		asteroid.set("speed", current_scroll_speed)


func _update_scroll_speed(delta: float) -> void:
	var target_speed := scroll_speed
	var maneuver_power_available := (
		player.has_method("can_use_maneuver_power")
		and bool(player.call("can_use_maneuver_power"))
	)
	var boosting := (
		Input.is_action_pressed("boost")
		and maneuver_power_available
	)
	var braking := (
		Input.is_action_pressed("brake")
		and maneuver_power_available
	)
	if boosting and not braking:
		target_speed = boost_scroll_speed
	elif braking and not boosting:
		target_speed = brake_scroll_speed
	current_scroll_speed = move_toward(
		current_scroll_speed,
		target_speed,
		scroll_speed_acceleration * delta
	)


func _spawn_asteroid() -> void:
	var asteroid_scene := (
		METAL_ASTEROID_SCENE
		if randf() < metal_spawn_chance
		else ROCK_ASTEROID_SCENE
	)
	var asteroid := asteroid_scene.instantiate() as Area3D
	add_child(asteroid)
	asteroid.position = Vector3(
		randf_range(-horizontal_spawn_limit, horizontal_spawn_limit),
		randf_range(
			minf(vertical_spawn_minimum, vertical_spawn_maximum),
			maxf(vertical_spawn_minimum, vertical_spawn_maximum)
		),
		asteroid_spawn_z
	)
	asteroid.set("speed", current_scroll_speed)
	_schedule_next_asteroid()


func _schedule_next_asteroid() -> void:
	var low_delay := minf(minimum_spawn_delay, maximum_spawn_delay)
	var high_delay := maxf(minimum_spawn_delay, maximum_spawn_delay)
	asteroid_timer.start(randf_range(low_delay, high_delay))


func _on_player_area_entered(area: Area3D) -> void:
	if level_restarting or not area.is_in_group("asteroid"):
		return
	level_restarting = true
	get_tree().call_deferred("reload_current_scene")
