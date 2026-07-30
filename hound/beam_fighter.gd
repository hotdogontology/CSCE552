extends Area3D

enum BeamState {
	COOLDOWN,
	TELEGRAPHING,
	FIRING
}

@export var speed := 20.0
@export var despawn_z := 15.0
@export_range(1, 20, 1) var maximum_health := 3
@export_range(0.1, 3.0, 0.05) var telegraph_duration := 0.8
@export_range(3.0, 5.0, 0.1) var minimum_beam_duration := 3.0
@export_range(3.0, 5.0, 0.1) var maximum_beam_duration := 5.0
@export_range(0.1, 10.0, 0.1) var minimum_cooldown := 2.0
@export_range(0.1, 10.0, 0.1) var maximum_cooldown := 4.0

@onready var beam_pivot: Node3D = $BeamPivot
@onready var beam_visual: MeshInstance3D = $BeamPivot/BeamVisual
@onready var beam_area: Area3D = $BeamPivot/BeamArea
@onready var beam_collision: CollisionShape3D = (
	$BeamPivot/BeamArea/CollisionShape3D
)

var health := 3
var beam_state := BeamState.COOLDOWN
var state_time_remaining := 0.0
var damaged_player_this_burst := false
var has_been_destroyed := false


func _ready() -> void:
	health = maximum_health
	beam_area.area_entered.connect(_on_beam_area_entered)
	_enter_cooldown(true)


func _physics_process(delta: float) -> void:
	position.z += speed * delta
	if position.z > despawn_z:
		queue_free()
		return

	state_time_remaining -= delta
	match beam_state:
		BeamState.COOLDOWN:
			if state_time_remaining <= 0.0:
				_begin_telegraph()
		BeamState.TELEGRAPHING:
			_aim_at_player()
			if state_time_remaining <= 0.0:
				_begin_firing()
		BeamState.FIRING:
			if state_time_remaining <= 0.0:
				_enter_cooldown()


func take_damage(amount: int = 1) -> void:
	if has_been_destroyed:
		return
	health -= maxi(amount, 1)
	if health <= 0:
		has_been_destroyed = true
		get_tree().call_group(
			"player_kill_counter",
			"register_player_kill"
		)
		queue_free()


func _begin_telegraph() -> void:
	beam_state = BeamState.TELEGRAPHING
	state_time_remaining = telegraph_duration
	beam_visual.show()
	beam_visual.scale = Vector3(0.25, 1.0, 0.25)
	beam_collision.set_deferred("disabled", true)
	_aim_at_player()


func _begin_firing() -> void:
	beam_state = BeamState.FIRING
	state_time_remaining = randf_range(
		minf(minimum_beam_duration, maximum_beam_duration),
		maxf(minimum_beam_duration, maximum_beam_duration)
	)
	damaged_player_this_burst = false
	beam_visual.scale = Vector3.ONE
	beam_collision.set_deferred("disabled", false)


func _enter_cooldown(is_initial_cooldown: bool = false) -> void:
	beam_state = BeamState.COOLDOWN
	beam_visual.hide()
	beam_collision.set_deferred("disabled", true)
	var cooldown := randf_range(
		minf(minimum_cooldown, maximum_cooldown),
		maxf(minimum_cooldown, maximum_cooldown)
	)
	state_time_remaining = cooldown * (0.5 if is_initial_cooldown else 1.0)


func _aim_at_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Area3D
	if player == null:
		return
	if beam_pivot.global_position.is_equal_approx(player.global_position):
		return
	beam_pivot.look_at(player.global_position, Vector3.UP)


func _on_beam_area_entered(area: Area3D) -> void:
	if beam_state != BeamState.FIRING or damaged_player_this_burst:
		return
	if not area.is_in_group("player"):
		return
	damaged_player_this_burst = true
	if area.has_method("receive_enemy_hit"):
		area.call("receive_enemy_hit", beam_area.global_position)
