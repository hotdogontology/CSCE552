extends Area3D

signal runtime_status_changed(status: Dictionary)

const LASER_SCENE := preload("res://laser.tscn")
const BAY_ORDER := ["left_wing", "fuselage", "right_wing"]

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
@export var barrel_roll_lateral_speed := 3.2
@export var barrel_roll_acceleration := 18.0
@export_range(0.05, 1.0, 0.05) var fire_interval := 0.2
@export_range(0.0, 20.0, 0.1) var power_recharge_per_second := 2.0
@export_range(0.0, 10.0, 0.1) var power_cost_per_laser_component := 1.0
@export_range(0.0, 20.0, 0.1) var maneuver_power_cost_per_second := 3.0

@onready var ship_model: MeshInstance3D = $ShipModel
@onready var hitbox: CollisionShape3D = $CockpitHitBox
@onready var wing_damage_sound: AudioStreamPlayer = $WingDamageSound

var velocity := Vector2.ZERO
var model_rest_rotation := Vector3.ZERO
var visual_roll := 0.0
var barrel_roll_direction := 0.0
var barrel_roll_time := 0.0
var last_left_tap := -10.0
var last_right_tap := -10.0
var fire_cooldown := 0.0
var runtime_components_by_bay: Dictionary = {}
var laser_mounts: Array[Dictionary] = []
var left_wing_intact := true
var right_wing_intact := true
var shield_component_count := 0
var maximum_power := 0.0
var current_power := 0.0
var ship_destroyed := false
var vertical_controls_inverted := false

func _ready() -> void:
	model_rest_rotation = ship_model.rotation
	visual_roll = model_rest_rotation.z
	wing_damage_sound.finished.connect(_repeat_wing_damage_sound)
	var state := get_node_or_null("/root/LoadoutState")
	if state != null:
		vertical_controls_inverted = bool(
			state.get("vertical_controls_inverted")
		)
	_apply_saved_loadout()


func _process(delta: float) -> void:
	_update_continuous_power(delta)
	_handle_maneuver_input()
	_handle_firing(delta)
	if Input.is_action_just_pressed("invert_vertical"):
		vertical_controls_inverted = not vertical_controls_inverted
		var state := get_node_or_null("/root/LoadoutState")
		if state != null:
			state.set(
				"vertical_controls_inverted",
				vertical_controls_inverted
			)

	var input_direction := Input.get_vector(
		"move_left", "move_right", "move_up", "move_down"
	)
	# Input.get_vector returns negative Y for up, matching world-space Y here.
	input_direction.y *= -1.0
	if vertical_controls_inverted:
		input_direction.y *= -1.0

	var target_velocity := input_direction * speed
	var barrel_roll_movement := _get_barrel_roll_movement_direction()
	if barrel_roll_movement != 0.0:
		target_velocity.x = barrel_roll_movement * barrel_roll_lateral_speed
	var response := acceleration if input_direction != Vector2.ZERO else deceleration
	if barrel_roll_movement != 0.0:
		response = barrel_roll_acceleration
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


func _update_continuous_power(delta: float) -> void:
	if ship_destroyed:
		return
	var using_maneuver_power := (
		Input.is_action_pressed("boost")
		!= Input.is_action_pressed("brake")
		and current_power > 0.0
	)
	if using_maneuver_power:
		current_power = maxf(
			current_power - maneuver_power_cost_per_second * delta,
			0.0
		)
	elif current_power < maximum_power:
		current_power = minf(
			current_power + power_recharge_per_second * delta,
			maximum_power
		)
	else:
		return
	_emit_runtime_status()


func can_use_maneuver_power() -> bool:
	return not ship_destroyed and current_power > 0.0


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

	var firing_cost := (
		float(_get_total_laser_component_count())
		* power_cost_per_laser_component
	)
	if laser_mounts.is_empty() or current_power < firing_cost:
		return

	current_power = maxf(current_power - firing_cost, 0.0)
	for laser_mount in laser_mounts:
		_fire_laser(laser_mount)
	fire_cooldown = fire_interval
	_emit_runtime_status()


func _fire_laser(laser_mount: Dictionary) -> void:
	var laser := LASER_SCENE.instantiate() as Area3D
	$LaserSound.play()
	get_tree().current_scene.add_child(laser)
	var muzzle_offset: Vector3 = laser_mount["muzzle_offset"]
	laser.global_position = ship_model.to_global(muzzle_offset)
	laser.call("set_direction", get_aim_direction())
	laser.call("set_damage", int(laser_mount["level"]))


func get_aim_direction() -> Vector3:
	return -ship_model.global_transform.basis.z.normalized()


func _apply_saved_loadout() -> void:
	var state := get_node_or_null("/root/LoadoutState")
	if state == null or not state.get("has_saved_loadout"):
		_apply_default_runtime_loadout()
		return

	runtime_components_by_bay = state.get(
		"components_by_bay"
	).duplicate(true)
	_recalculate_runtime_loadout(false)


func _apply_default_runtime_loadout() -> void:
	runtime_components_by_bay = {
		"left_wing": [
			{"component_type": "laser", "occupied_cells": [0, 4, 8, 12]}
		],
		"fuselage": [],
		"right_wing": [
			{"component_type": "laser", "occupied_cells": [3, 7, 11, 15]}
		]
	}
	for bay_id in ["left_wing", "right_wing"]:
		for cell_index in range(16):
			if cell_index % 4 == (0 if bay_id == "left_wing" else 3):
				continue
			runtime_components_by_bay[bay_id].append({
				"component_type": "battery",
				"occupied_cells": [cell_index]
			})
	_recalculate_runtime_loadout(false)


func _recalculate_runtime_loadout(preserve_current_power: bool = true) -> void:
	var previous_power := current_power
	maximum_power = 0.0
	shield_component_count = 0
	laser_mounts.clear()

	for bay_id in BAY_ORDER:
		if not _is_bay_intact(bay_id):
			continue
		var components: Array = runtime_components_by_bay.get(bay_id, [])
		maximum_power += _calculate_bay_power(bay_id, components)
		var bay_laser_count := 0
		for component in components:
			match component["component_type"]:
				"shield":
					shield_component_count += 1
				"laser":
					bay_laser_count += 1
		if bay_laser_count > 0:
			laser_mounts.append({
				"bay": bay_id,
				"level": bay_laser_count,
				"muzzle_offset": _get_bay_muzzle_offset(bay_id)
			})

	current_power = (
		minf(previous_power, maximum_power)
		if preserve_current_power
		else maximum_power
	)
	_emit_runtime_status()


func _calculate_bay_power(bay_id: String, components: Array) -> float:
	var battery_cells: Dictionary = {}
	for component in components:
		if component["component_type"] != "battery":
			continue
		for cell_index in component["occupied_cells"]:
			battery_cells[int(cell_index)] = true

	var battery_count := battery_cells.size()
	if battery_count <= 1:
		return float(battery_count)

	var group_count := _count_battery_groups(
		battery_cells,
		2 if bay_id == "fuselage" else 4
	)
	var multiplier := (
		2.0
		- float(group_count - 1) / float(battery_count - 1)
	)
	return float(battery_count) * multiplier


func _count_battery_groups(
	battery_cells: Dictionary,
	column_count: int
) -> int:
	var unvisited := battery_cells.duplicate()
	var group_count := 0
	while not unvisited.is_empty():
		group_count += 1
		var starting_cell := int(unvisited.keys()[0])
		var pending_cells: Array[int] = [starting_cell]
		unvisited.erase(starting_cell)

		while not pending_cells.is_empty():
			var cell_index: int = int(pending_cells.pop_back())
			var column: int = cell_index % column_count
			var neighbors: Array[int] = [
				cell_index - column_count,
				cell_index + column_count
			]
			if column > 0:
				neighbors.append(cell_index - 1)
			if column < column_count - 1:
				neighbors.append(cell_index + 1)

			for neighbor in neighbors:
				if not unvisited.has(neighbor):
					continue
				unvisited.erase(neighbor)
				pending_cells.append(neighbor)
	return group_count


func _get_total_laser_component_count() -> int:
	var total := 0
	for bay_id in BAY_ORDER:
		if not _is_bay_intact(bay_id):
			continue
		for component in runtime_components_by_bay.get(bay_id, []):
			if component["component_type"] == "laser":
				total += 1
	return total


func _get_bay_muzzle_offset(bay_id: String) -> Vector3:
	match bay_id:
		"left_wing":
			return Vector3(-0.12, 0.0, -0.25)
		"right_wing":
			return Vector3(0.12, 0.0, -0.25)
		_:
			return Vector3(0.0, 0.0, -0.25)


func _is_bay_intact(bay_id: String) -> bool:
	if bay_id == "left_wing":
		return left_wing_intact
	if bay_id == "right_wing":
		return right_wing_intact
	return true


func receive_enemy_hit(hit_position: Vector3) -> void:
	if ship_destroyed:
		return
	if barrel_roll_direction != 0.0:
		return

	var shield_hit_cost := _get_shield_hit_cost()
	if shield_component_count > 0 and current_power >= shield_hit_cost:
		current_power = maxf(current_power - shield_hit_cost, 0.0)
		_emit_runtime_status()
		return

	if not left_wing_intact and not right_wing_intact:
		_destroy_ship()
		return

	var hit_left_side := hit_position.x < global_position.x
	if hit_left_side and left_wing_intact:
		left_wing_intact = false
	elif not hit_left_side and right_wing_intact:
		right_wing_intact = false
	elif left_wing_intact:
		left_wing_intact = false
	else:
		right_wing_intact = false
	_recalculate_runtime_loadout()
	_update_wing_damage_sound()


func _get_shield_hit_cost() -> float:
	if shield_component_count <= 0:
		return INF
	return 4.0 / float(shield_component_count)


func _destroy_ship() -> void:
	ship_destroyed = true
	wing_damage_sound.stop()
	_emit_runtime_status()
	get_tree().call_deferred("reload_current_scene")


func _update_wing_damage_sound() -> void:
	var wing_is_damaged := not left_wing_intact or not right_wing_intact
	if wing_is_damaged and not ship_destroyed:
		if not wing_damage_sound.playing:
			wing_damage_sound.play()
	else:
		wing_damage_sound.stop()


func _repeat_wing_damage_sound() -> void:
	if (
		not ship_destroyed
		and (not left_wing_intact or not right_wing_intact)
	):
		wing_damage_sound.play()


func get_runtime_status() -> Dictionary:
	var laser_levels := {
		"left_wing": 0,
		"fuselage": 0,
		"right_wing": 0
	}
	for laser_mount in laser_mounts:
		laser_levels[laser_mount["bay"]] = int(laser_mount["level"])

	var shield_hit_cost := _get_shield_hit_cost()
	var shield_capacity := 0.0
	var shield_remaining := 0.0
	if shield_component_count > 0:
		shield_capacity = maximum_power / shield_hit_cost
		shield_remaining = current_power / shield_hit_cost
	return {
		"current_power": current_power,
		"maximum_power": maximum_power,
		"shield_count": shield_component_count,
		"shield_capacity": shield_capacity,
		"shield_remaining": shield_remaining,
		"shields_active": (
			shield_component_count > 0
			and current_power >= shield_hit_cost
		),
		"laser_count": laser_mounts.size(),
		"laser_levels": laser_levels,
		"left_wing_intact": left_wing_intact,
		"right_wing_intact": right_wing_intact,
		"ship_destroyed": ship_destroyed
	}


func _emit_runtime_status() -> void:
	runtime_status_changed.emit(get_runtime_status())


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


func _get_barrel_roll_movement_direction() -> float:
	if (
		barrel_roll_direction > 0.0
		and Input.is_action_pressed("knife_left")
	):
		return -1.0
	if (
		barrel_roll_direction < 0.0
		and Input.is_action_pressed("knife_right")
	):
		return 1.0
	return 0.0


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
	
