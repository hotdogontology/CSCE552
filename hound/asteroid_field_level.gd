extends Node3D

const ROCK_ASTEROID_SCENE := preload("res://asteroid.tscn")
const METAL_ASTEROID_SCENE := preload("res://metal_rich_asteroid.tscn")
const ENEMY_FIGHTER_SCENE := preload("res://enemy_fighter.tscn")
const DESTROYER_SCENE := preload("res://destroyer.tscn")
const METAL_ASTEROID_GOAL := 5

@export var scroll_speed := 12.0
@export var boost_scroll_speed := 18.0
@export var brake_scroll_speed := 4.0
@export var scroll_speed_acceleration := 20.0
@export var asteroid_spawn_z := -100.0
@export var horizontal_spawn_limit := 2.4
@export var vertical_spawn_minimum := -2.0
@export var vertical_spawn_maximum := 2.0
@export var enemy_spawn_z := -2.5
@export var enemy_side_spawn_x := 5.0
@export var enemy_attack_horizontal_limit := 1.6
@export var enemy_attack_vertical_minimum := -1.5
@export var enemy_attack_vertical_maximum := 1.5
@export_range(0.0, 1.0, 0.05) var destroyer_spawn_chance := 0.25
@export var destroyer_spawn_z := -42.0
@export var destroyer_horizontal_limit := 1.25
@export var destroyer_vertical_minimum := -1.25
@export var destroyer_vertical_maximum := 0.5
@export var minimum_spawn_delay := 2.2
@export var maximum_spawn_delay := 3.6

@onready var player: Area3D = $Player
@onready var asteroid_timer: Timer = $AsteroidTimer
@onready var status_hud: Control = $HUD/StatusHUD
@onready var result_overlay: Control = $HUD/MissionResultOverlay
@onready var result_title: Label = %MissionResultTitle
@onready var select_loadout_button: Button = %SelectLoadoutButton

var current_scroll_speed := 0.0
var encounter_step := 0
var asteroid_spawn_count := 0
var metal_asteroids_destroyed := 0
var mission_ended := false


func _ready() -> void:
	current_scroll_speed = scroll_speed
	player.area_entered.connect(_on_player_area_entered)
	player.connect("destroyed", _show_mission_failed)
	asteroid_timer.timeout.connect(_spawn_next_encounter)
	%ResultGalaxyMapButton.pressed.connect(_return_to_galaxy_map)
	select_loadout_button.pressed.connect(_select_loadout_for_new_fighter)
	status_hud.call(
		"set_metal_progress",
		metal_asteroids_destroyed,
		METAL_ASTEROID_GOAL
	)
	_schedule_next_encounter()


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
	asteroid_spawn_count += 1
	var asteroid_scene := (
		METAL_ASTEROID_SCENE
		if asteroid_spawn_count % 3 == 0
		else ROCK_ASTEROID_SCENE
	)
	var asteroid := asteroid_scene.instantiate() as Area3D
	add_child(asteroid)
	asteroid.connect("destroyed", _on_asteroid_destroyed)
	asteroid.position = Vector3(
		randf_range(-horizontal_spawn_limit, horizontal_spawn_limit),
		randf_range(
			minf(vertical_spawn_minimum, vertical_spawn_maximum),
			maxf(vertical_spawn_minimum, vertical_spawn_maximum)
		),
		asteroid_spawn_z
	)
	asteroid.set("speed", current_scroll_speed)


func _spawn_enemy_fighter() -> void:
	var enemy := ENEMY_FIGHTER_SCENE.instantiate() as Area3D
	add_child(enemy)
	enemy.add_to_group("active_enemy_encounter")
	var entry_side := -1.0 if randf() < 0.5 else 1.0
	var side_spawn_x := _get_enemy_side_spawn_x()
	enemy.position = Vector3(
		entry_side * side_spawn_x,
		randf_range(
			minf(
				enemy_attack_vertical_minimum,
				enemy_attack_vertical_maximum
			),
			maxf(
				enemy_attack_vertical_minimum,
				enemy_attack_vertical_maximum
			)
		),
		enemy_spawn_z
	)
	enemy.call(
		"begin_side_attack",
		entry_side,
		randf_range(
			-absf(enemy_attack_horizontal_limit),
			absf(enemy_attack_horizontal_limit)
		),
		side_spawn_x
	)


func _spawn_destroyer() -> void:
	var destroyer := DESTROYER_SCENE.instantiate() as Node3D
	add_child(destroyer)
	destroyer.position = Vector3(
		randf_range(
			-absf(destroyer_horizontal_limit),
			absf(destroyer_horizontal_limit)
		),
		randf_range(
			minf(destroyer_vertical_minimum, destroyer_vertical_maximum),
			maxf(destroyer_vertical_minimum, destroyer_vertical_maximum)
		),
		destroyer_spawn_z
	)


func _spawn_next_encounter() -> void:
	if mission_ended:
		return
	if encounter_step == 2:
		if get_tree().get_first_node_in_group("active_enemy_encounter") != null:
			_schedule_next_encounter()
			return
		if randf() < destroyer_spawn_chance:
			_spawn_destroyer()
		else:
			_spawn_enemy_fighter()
	else:
		_spawn_asteroid()
	encounter_step = (encounter_step + 1) % 3
	_schedule_next_encounter()


func _on_asteroid_destroyed(composition: int, was_large: bool) -> void:
	if mission_ended or composition != 1 or not was_large:
		return
	metal_asteroids_destroyed += 1
	status_hud.call(
		"set_metal_progress",
		metal_asteroids_destroyed,
		METAL_ASTEROID_GOAL
	)
	if metal_asteroids_destroyed >= METAL_ASTEROID_GOAL:
		_show_mission_success()


func _show_mission_success() -> void:
	_show_mission_result("Mission Success", false)


func _show_mission_failed() -> void:
	_show_mission_result("Mission Failed", true)


func _show_mission_result(title: String, allow_new_fighter: bool) -> void:
	if mission_ended:
		return
	mission_ended = true
	asteroid_timer.stop()
	result_title.text = title
	select_loadout_button.visible = allow_new_fighter
	result_overlay.show()
	$HUD/PauseMenu.set_process_unhandled_input(false)
	get_viewport().gui_release_focus()
	get_tree().paused = true


func _return_to_galaxy_map() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://galaxy_map.tscn")


func _select_loadout_for_new_fighter() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://loadout.tscn")


func _get_enemy_side_spawn_x() -> float:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return enemy_side_spawn_x
	var screen_edge := Vector2(
		0.0,
		get_viewport().get_visible_rect().size.y * 0.5
	)
	var ray_origin := camera.project_ray_origin(screen_edge)
	var ray_direction := camera.project_ray_normal(screen_edge)
	if is_zero_approx(ray_direction.z):
		return enemy_side_spawn_x
	var distance := (enemy_spawn_z - ray_origin.z) / ray_direction.z
	var edge_position := ray_origin + ray_direction * distance
	return maxf(enemy_side_spawn_x, absf(edge_position.x) + 1.0)


func _schedule_next_encounter() -> void:
	var low_delay := minf(minimum_spawn_delay, maximum_spawn_delay)
	var high_delay := maxf(minimum_spawn_delay, maximum_spawn_delay)
	asteroid_timer.start(randf_range(low_delay, high_delay))


func _on_player_area_entered(area: Area3D) -> void:
	if mission_ended or not area.is_in_group("asteroid"):
		return
	player.call("destroy_ship")
