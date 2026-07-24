extends Control

@export var aim_distance := 30.0
@export var box_half_size := 24.0
@export var corner_length := 9.0
@export var line_width := 2.0
@export var reticle_color := Color(0.1, 1.0, 0.25, 0.95)

var player: Area3D
var reticle_center := Vector2.ZERO


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Area3D


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if player == null or camera == null:
		visible = false
		return

	var aim_direction: Vector3 = player.call("get_aim_direction")
	var aim_position := player.global_position + aim_direction * aim_distance
	visible = not camera.is_position_behind(aim_position)
	if visible:
		reticle_center = camera.unproject_position(aim_position)
		queue_redraw()


func _draw() -> void:
	var left := reticle_center.x - box_half_size
	var right := reticle_center.x + box_half_size
	var top := reticle_center.y - box_half_size
	var bottom := reticle_center.y + box_half_size

	_draw_corner(Vector2(left, top), Vector2.RIGHT, Vector2.DOWN)
	_draw_corner(Vector2(right, top), Vector2.LEFT, Vector2.DOWN)
	_draw_corner(Vector2(left, bottom), Vector2.RIGHT, Vector2.UP)
	_draw_corner(Vector2(right, bottom), Vector2.LEFT, Vector2.UP)


func _draw_corner(
	corner: Vector2,
	horizontal_direction: Vector2,
	vertical_direction: Vector2
) -> void:
	draw_line(
		corner,
		corner + horizontal_direction * corner_length,
		reticle_color,
		line_width
	)
	draw_line(
		corner,
		corner + vertical_direction * corner_length,
		reticle_color,
		line_width
	)
