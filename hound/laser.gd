extends Area3D

@export var speed := 18.0
@export var lifetime := 2.0
@export var damage := 1

@onready var laser_mesh: MeshInstance3D = $Mesh
@onready var hitbox: CollisionShape3D = $CollisionShape3D
@onready var explosion_sound: AudioStreamPlayer3D = $Explosion

var has_hit := false
var direction := Vector3.FORWARD


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func set_direction(new_direction: Vector3) -> void:
	direction = new_direction.normalized()
	look_at(global_position + direction, Vector3.UP)


func set_damage(new_damage: int) -> void:
	damage = maxi(new_damage, 1)


func _physics_process(delta: float) -> void:
	if has_hit:
		return

	var movement := direction * speed * delta
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = hitbox.shape
	query.transform = hitbox.global_transform
	query.motion = movement
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var collision_fractions := (
		get_world_3d().direct_space_state.cast_motion(query)
	)
	if collision_fractions[0] < 1.0:
		global_position += movement * collision_fractions[0]
		_damage_colliders_at_impact(query, movement, collision_fractions[1])
		_play_impact()
		return

	global_position += movement
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_area_entered(area: Area3D) -> void:
	if has_hit:
		return

	if area.is_in_group("obstacle"):
		_damage_target(area)
		_play_impact()


func _damage_colliders_at_impact(
	query: PhysicsShapeQueryParameters3D,
	movement: Vector3,
	unsafe_fraction: float
) -> void:
	var impact_transform := query.transform
	impact_transform.origin += movement * minf(unsafe_fraction + 0.01, 1.0)
	query.transform = impact_transform
	query.motion = Vector3.ZERO
	var collisions := (
		get_world_3d().direct_space_state.intersect_shape(query, 8)
	)
	for collision in collisions:
		var collider := collision.get("collider") as Node
		if collider != null and collider.is_in_group("obstacle"):
			_damage_target(collider)
			return


func _damage_target(target: Node) -> void:
	if target.has_method("take_damage"):
		target.call("take_damage", damage)


func _play_impact() -> void:
	if has_hit:
		return

	has_hit = true
	laser_mesh.hide()
	hitbox.set_deferred("disabled", true)
	set_deferred("monitoring", false)
	set_physics_process(false)
	explosion_sound.play()
	await explosion_sound.finished
	queue_free()
