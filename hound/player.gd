extends Area3D

const LASER_SCENE := preload("res://laser.tscn")

@export var speed := 2.3
@export var acceleration := 10.0
@export var deceleration := 14.0
@export var horizontal_limit := 2.0
@export var vertical_minimum := -2.0
@export var vertical_maximum := 2.0
@export_range(0.0, 200.0, 1.0) var screen_edge_margin := 48.0
@export_range(0.0, 90.0, 1.0) var maximum_bank_degrees := 35.0
@export_range(0.0, 90.0, 1.0) var maximum_pitch_degrees := 20.0
@export var rotation_speed := 8.0
@export_range(0.1, 1.0, 0.05) var double_tap_window := 0.3
@export_range(0.1, 2.0, 0.05) var barrel_roll_duration := 0.6
@export_range(0.05, 1.0, 0.05) var fire_interval := 0.2

@onready var ship_model: MeshInstance3D = $ShipModel
@onready var hitbox: CollisionShape3D = $CockpitHitBox

var velocity := Vector2.ZERO
var model_rest_rotation := Vector3.ZERO
var visual_roll := 0.0
var barrel_roll_direction := 0.0
var barrel_roll_time := 0.0
var last_left_tap := -10.0
var last_right_tap := -10.0
var fire_cooldown := 0.0

func _ready() -> void:
	model_rest_rotation = ship_model.rotation
	visual_roll = model_rest_rotation.z


func _process(delta: float) -> void:
	_handle_maneuver_input()
	_handle_firing(delta)

	var input_direction := Input.get_vector(
		"move_left", "move_right", "move_up", "move_down"
	)
	# Input.get_vector returns negative Y for up, matching world-space Y here.
	input_direction.y *= -1.0

	var target_velocity := input_direction * speed
	var response := acceleration if input_direction != Vector2.ZERO else deceleration
	velocity = velocity.move_toward(target_velocity, response * delta)

	position.x = clampf(
		position.x + velocity.x * delta,
		-horizontal_limit,
		horizontal_limit
	)
	position.y = clampf(
		position.y + velocity.y * delta,
		vertical_minimum,
		vertical_maximum
	)
	_keep_player_on_screen()

	# Stop pushing against an edge so the ship responds immediately when turning away.
	if is_equal_approx(absf(position.x), horizontal_limit):
		velocity.x = 0.0
	if is_equal_approx(position.y, vertical_minimum) or is_equal_approx(position.y, vertical_maximum):
		velocity.y = 0.0

	var rotation_weight := 1.0 - exp(-rotation_speed * delta)
	var target_pitch := model_rest_rotation.x \
		+ deg_to_rad(maximum_pitch_degrees) * input_direction.y
	ship_model.rotation.x = lerp_angle(
		ship_model.rotation.x, target_pitch, rotation_weight
	)
	ship_model.rotation.y = lerp_angle(
		ship_model.rotation.y, model_rest_rotation.y, rotation_weight
	)

	_update_roll(delta, input_direction.x, rotation_weight)
	ship_model.rotation.z = visual_roll
	# Rotate the thin collider with the ship. At knife edge its narrow vertical
	# dimension becomes its screen-space width instead of leaving a wide box behind.
	hitbox.rotation.x = ship_model.rotation.x
	hitbox.rotation.z = visual_roll


func _keep_player_on_screen() -> void:
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d()
	if camera == null or camera.is_position_behind(global_position):
		return

	var viewport_size := viewport.get_visible_rect().size
	var usable_margin := minf(
		screen_edge_margin,
		minf(viewport_size.x, viewport_size.y) * 0.45
	)
	var screen_position := camera.unproject_position(global_position)
	var clamped_screen_position := Vector2(
		clampf(screen_position.x, usable_margin, viewport_size.x - usable_margin),
		clampf(screen_position.y, usable_margin, viewport_size.y - usable_margin)
	)
	if screen_position.is_equal_approx(clamped_screen_position):
		return

	var ray_origin := camera.project_ray_origin(clamped_screen_position)
	var ray_direction := camera.project_ray_normal(clamped_screen_position)
	if is_zero_approx(ray_direction.z):
		return

	var distance_to_movement_plane := (
		global_position.z - ray_origin.z
	) / ray_direction.z
	var corrected_position := (
		ray_origin + ray_direction * distance_to_movement_plane
	)
	if not is_equal_approx(screen_position.x, clamped_screen_position.x):
		velocity.x = 0.0
	if not is_equal_approx(screen_position.y, clamped_screen_position.y):
		velocity.y = 0.0
	global_position = Vector3(
		corrected_position.x,
		corrected_position.y,
		global_position.z
	)


func _handle_firing(delta: float) -> void:
	fire_cooldown = maxf(fire_cooldown - delta, 0.0)
	if not Input.is_action_pressed("fire") or fire_cooldown > 0.0:
		return

	_fire_laser(Vector3(-0.1, 0.0, -0.25))
	_fire_laser(Vector3(0.1, 0.0, -0.25))
	fire_cooldown = fire_interval


func _fire_laser(muzzle_offset: Vector3) -> void:
	var laser := LASER_SCENE.instantiate() as Area3D
	$LaserSound.play()
	get_tree().current_scene.add_child(laser)
	laser.global_position = ship_model.to_global(muzzle_offset)


func _handle_maneuver_input() -> void:
	var now := Time.get_ticks_msec() / 1000.0

	if Input.is_action_just_pressed("knife_left"):
		if now - last_left_tap <= double_tap_window:
			_start_barrel_roll(1.0)
			last_left_tap = -10.0
		else:
			last_left_tap = now

	if Input.is_action_just_pressed("knife_right"):
		if now - last_right_tap <= double_tap_window:
			_start_barrel_roll(-1.0)
			last_right_tap = -10.0
		else:
			last_right_tap = now


func _start_barrel_roll(direction: float) -> void:
	barrel_roll_direction = direction
	barrel_roll_time = 0.0


func _update_roll(delta: float, horizontal_input: float, rotation_weight: float) -> void:
	if barrel_roll_direction != 0.0:
		var remaining_time := barrel_roll_duration - barrel_roll_time
		var roll_delta := minf(delta, remaining_time)
		visual_roll += barrel_roll_direction * TAU * roll_delta / barrel_roll_duration
		barrel_roll_time += roll_delta

		if barrel_roll_time >= barrel_roll_duration:
			visual_roll = wrapf(visual_roll, -PI, PI)
			barrel_roll_direction = 0.0
		return

	var target_roll := model_rest_rotation.z \
		- deg_to_rad(maximum_bank_degrees) * horizontal_input
	if Input.is_action_pressed("knife_left"):
		target_roll = model_rest_rotation.z + PI / 2.0
	elif Input.is_action_pressed("knife_right"):
		target_roll = model_rest_rotation.z - PI / 2.0

	visual_roll = lerp_angle(visual_roll, target_roll, rotation_weight)
	
