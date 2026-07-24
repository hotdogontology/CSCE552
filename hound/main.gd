extends Node3D

const TRENCH_SEGMENT_SCENE := preload("res://trench_segment.tscn")
const TRENCH_SCRAPER_SCENE := preload("res://trench_scraper.tscn")
const TURRET_SCENE := preload("res://turret.tscn")
const TRENCH_SCRAPER_BASE_HEIGHT := 5.0

@export var scroll_speed := 20.0
@export var boost_scroll_speed := 30.0
@export var brake_scroll_speed := 10.0
@export var scroll_speed_acceleration := 60.0
@export_range(2, 10, 1) var trench_segment_count := 3
@export var trench_segment_length := 200.0
@export var obstacle_spawn_z := -120.0
@export var obstacle_ground_y := -4.5
@export var obstacle_horizontal_limit := 8.5
@export_range(0.0, 1.0, 0.05) var turret_spawn_chance := 0.25
@export var turret_horizontal_limit := 2.0
@export_range(0.5, 1.1, 0.05) var turret_building_height_scale := 0.8
@export var minimum_obstacle_height_scale := 0.5
@export var maximum_obstacle_height_scale := 2.0
@export var minimum_spawn_delay := 0.45
@export var maximum_spawn_delay := 0.9
@export var restart_on_collision := true

@onready var player: Area3D = $Player
@onready var first_trench_segment: Node3D = $TutorialTrench
@onready var obstacle_timer: Timer = $BuildingTimer

var trench_segments: Array[Node3D] = []
var current_scroll_speed := 0.0


func _ready() -> void:
	current_scroll_speed = scroll_speed
	_setup_trench()
	player.area_entered.connect(_on_player_area_entered)
	obstacle_timer.timeout.connect(_spawn_obstacle)
	_schedule_next_obstacle()


func _process(delta: float) -> void:
	_update_scroll_speed(delta)
	_move_trench(delta)
	_update_obstacle_speeds()


func _update_scroll_speed(delta: float) -> void:
	var target_speed := scroll_speed
	var boosting := Input.is_action_pressed("boost")
	var braking := Input.is_action_pressed("brake")
	if boosting and not braking:
		target_speed = boost_scroll_speed
	elif braking and not boosting:
		target_speed = brake_scroll_speed

	current_scroll_speed = move_toward(
		current_scroll_speed,
		target_speed,
		scroll_speed_acceleration * delta
	)


func _update_obstacle_speeds() -> void:
	for obstacle in get_tree().get_nodes_in_group("obstacle"):
		obstacle.set("speed", current_scroll_speed)


func _setup_trench() -> void:
	trench_segments.append(first_trench_segment)
	first_trench_segment.position.z = 0.0

	for index in range(1, trench_segment_count):
		var segment := TRENCH_SEGMENT_SCENE.instantiate() as Node3D
		add_child(segment)
		segment.position.z = -trench_segment_length * index
		trench_segments.append(segment)


func _move_trench(delta: float) -> void:
	for segment in trench_segments:
		segment.position.z += current_scroll_speed * delta

	for segment in trench_segments:
		if segment.position.z >= trench_segment_length:
			segment.position.z = _furthest_segment_z() - trench_segment_length


func _furthest_segment_z() -> float:
	var furthest_z := trench_segments[0].position.z
	for segment in trench_segments:
		furthest_z = minf(furthest_z, segment.position.z)
	return furthest_z


func _spawn_obstacle() -> void:
	var spawning_turret := randf() < turret_spawn_chance
	var building := TRENCH_SCRAPER_SCENE.instantiate() as Area3D
	add_child(building)
	var building_height_scale := turret_building_height_scale
	if not spawning_turret:
		var minimum_height := minf(
			minimum_obstacle_height_scale,
			maximum_obstacle_height_scale
		)
		var maximum_height := maxf(
			minimum_obstacle_height_scale,
			maximum_obstacle_height_scale
		)
		building_height_scale = randf_range(minimum_height, maximum_height)
	building.scale.y = building_height_scale
	var horizontal_spawn_limit := (
		turret_horizontal_limit
		if spawning_turret
		else obstacle_horizontal_limit
	)
	var spawn_position := Vector3(
		randf_range(-horizontal_spawn_limit, horizontal_spawn_limit),
		obstacle_ground_y,
		obstacle_spawn_z
	)
	building.position = spawn_position
	building.set("speed", current_scroll_speed)

	if spawning_turret:
		var turret := TURRET_SCENE.instantiate() as Area3D
		add_child(turret)
		turret.position = spawn_position + Vector3(
			0.0,
			TRENCH_SCRAPER_BASE_HEIGHT * building_height_scale,
			0.0
		)
		turret.set("speed", current_scroll_speed)

	_schedule_next_obstacle()


func _schedule_next_obstacle() -> void:
	var low_delay := minf(minimum_spawn_delay, maximum_spawn_delay)
	var high_delay := maxf(minimum_spawn_delay, maximum_spawn_delay)
	obstacle_timer.start(randf_range(low_delay, high_delay))


func _on_player_area_entered(area: Area3D) -> void:
	if not area.is_in_group("obstacle"):
		return

	print("Player collided with obstacle: ", area.name)
	if restart_on_collision:
		get_tree().call_deferred("reload_current_scene")
	else:
		area.queue_free()
