extends Area3D

enum AsteroidComposition {
	ROCK,
	METAL
}

const ROCK_ASTEROID_PATH := "res://asteroid.tscn"
const METAL_ASTEROID_PATH := "res://metal_rich_asteroid.tscn"

@export var speed := 25.0
@export var despawn_z := 15.0
@export var composition: AsteroidComposition = AsteroidComposition.ROCK
@export var is_large := true
@export_range(1, 20, 1) var large_hit_points := 4
@export_range(0.0, 1.0, 0.05) var break_apart_chance := 0.65
@export_range(0.5, 3.0, 0.05) var minimum_large_size := 0.9
@export_range(0.5, 3.0, 0.05) var maximum_large_size := 1.3
@export_range(0.1, 1.5, 0.05) var minimum_small_size := 0.4
@export_range(0.1, 1.5, 0.05) var maximum_small_size := 0.6
@export_range(0.0, 4.0, 0.05) var maximum_tumble_speed := 1.2
@export_range(0.0, 8.0, 0.1) var fragment_spread_speed := 2.5

var tumble_speed := Vector3.ZERO
var drift_velocity := Vector3.ZERO
var health := 1
var has_been_destroyed := false


func _ready() -> void:
	health = _get_maximum_health()
	rotation = Vector3(
		randf_range(0.0, TAU),
		randf_range(0.0, TAU),
		randf_range(0.0, TAU)
	)
	var minimum_size := (
		minimum_large_size if is_large else minimum_small_size
	)
	var maximum_size := (
		maximum_large_size if is_large else maximum_small_size
	)
	var asteroid_size := randf_range(
		minf(minimum_size, maximum_size),
		maxf(minimum_size, maximum_size)
	)
	scale *= asteroid_size
	tumble_speed = Vector3(
		randf_range(-maximum_tumble_speed, maximum_tumble_speed),
		randf_range(-maximum_tumble_speed, maximum_tumble_speed),
		randf_range(-maximum_tumble_speed, maximum_tumble_speed)
	)


func _process(delta: float) -> void:
	position += drift_velocity * delta
	position.z += speed * delta
	rotation += tumble_speed * delta
	if position.z > despawn_z:
		queue_free()


func take_damage(amount: int = 1) -> void:
	if has_been_destroyed:
		return
	health -= maxi(amount, 1)
	if health > 0:
		return
	has_been_destroyed = true
	if is_large and randf() <= break_apart_chance:
		_spawn_fragments()
	queue_free()


func _get_maximum_health() -> int:
	if is_large:
		return large_hit_points
	return maxi(ceili(float(large_hit_points) / 2.0), 1)


func _spawn_fragments() -> void:
	var fragment_count := randi_range(1, 3)
	for fragment_index in range(fragment_count):
		var fragment_composition := AsteroidComposition.ROCK
		if composition == AsteroidComposition.METAL and randf() < 0.5:
			fragment_composition = AsteroidComposition.METAL
		_spawn_fragment(fragment_composition, fragment_index, fragment_count)


func _spawn_fragment(
	fragment_composition: AsteroidComposition,
	fragment_index: int,
	fragment_count: int
) -> void:
	var scene_path := (
		METAL_ASTEROID_PATH
		if fragment_composition == AsteroidComposition.METAL
		else ROCK_ASTEROID_PATH
	)
	var fragment_scene := load(scene_path) as PackedScene
	if fragment_scene == null:
		return
	var fragment := fragment_scene.instantiate() as Area3D
	fragment.set("is_large", false)
	fragment.set("speed", speed)
	fragment.set("despawn_z", despawn_z)
	var spread_angle := (
		TAU * float(fragment_index) / float(fragment_count)
		+ randf_range(-0.45, 0.45)
	)
	var spread_direction := Vector3(
		cos(spread_angle),
		sin(spread_angle),
		randf_range(-0.35, 0.35)
	).normalized()
	fragment.set("drift_velocity", spread_direction * fragment_spread_speed)
	get_tree().current_scene.add_child(fragment)
	fragment.global_position = global_position + spread_direction * 0.6
