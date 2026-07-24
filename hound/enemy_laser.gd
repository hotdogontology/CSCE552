extends Area3D

@export var speed := 25.0
@export var lifetime := 5.0

@onready var hitbox: CollisionShape3D = $CollisionShape3D

var direction := Vector3.BACK
var has_hit := false


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func set_direction(new_direction: Vector3) -> void:
	direction = new_direction.normalized()
	look_at(global_position + direction, Vector3.UP)


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
		_hit_player()
		return

	global_position += movement
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("player"):
		_hit_player()


func _hit_player() -> void:
	if has_hit:
		return

	has_hit = true
	set_physics_process(false)
	set_deferred("monitoring", false)
	hitbox.set_deferred("disabled", true)
	queue_free()
	get_tree().call_deferred("reload_current_scene")
