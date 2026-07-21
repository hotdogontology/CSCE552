extends Node3D

const TRENCH_SEGMENT_SCENE := preload("res://trench_segment.tscn")
const TRENCH_SCRAPER_SCENE := preload("res://trench_scraper.tscn")

@export var scroll_speed := 40.0
@export_range(2, 10, 1) var trench_segment_count := 3
@export var trench_segment_length := 200.0
@export var obstacle_spawn_z := -120.0
@export var obstacle_ground_y := -4.5
@export var obstacle_horizontal_limit := 8.5
@export var minimum_spawn_delay := 0.45
@export var maximum_spawn_delay := 0.9
@export var restart_on_collision := true

@onready var player: Area3D = $Player
@onready var first_trench_segment: Node3D = $TutorialTrench
@onready var obstacle_timer: Timer = $BuildingTimer

var trench_segments: Array[Node3D] = []


func _ready() -> void:
	_setup_trench()
	player.area_entered.connect(_on_player_area_entered)
	obstacle_timer.timeout.connect(_spawn_obstacle)
	_schedule_next_obstacle()


func _process(delta: float) -> void:
	_move_trench(delta)


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
		segment.position.z += scroll_speed * delta

	for segment in trench_segments:
		if segment.position.z >= trench_segment_length:
			segment.position.z = _furthest_segment_z() - trench_segment_length


func _furthest_segment_z() -> float:
	var furthest_z := trench_segments[0].position.z
	for segment in trench_segments:
		furthest_z = minf(furthest_z, segment.position.z)
	return furthest_z


func _spawn_obstacle() -> void:
	var obstacle := TRENCH_SCRAPER_SCENE.instantiate() as Area3D
	add_child(obstacle)
	obstacle.position = Vector3(
		randf_range(-obstacle_horizontal_limit, obstacle_horizontal_limit),
		obstacle_ground_y,
		obstacle_spawn_z
	)
	obstacle.set("speed", scroll_speed)
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
