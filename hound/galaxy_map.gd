extends Node2D

const PLANET_ATLAS := preload("res://sprites/planet_sprites.png")
const COLUMN_COUNTS := [1, 3, 3, 3, 1]

const STAR_REGIONS := {
	"Yellow": Rect2(64, 64, 32, 32),
	"Red": Rect2(96, 64, 32, 32),
	"Blue": Rect2(0, 96, 32, 32)
}

const LOCATION_DATA := {
	"Gas Giant Fueling Station": {
		"region": Rect2(0, 64, 32, 32),
		"objective": "Destroy fueling station",
		"strategic_resource": "fuel",
		"effect": "Fewer enemy patrols and powered defenses"
	},
	"Moon with Space Station": {
		"region": Rect2(32, 64, 32, 32),
		"objective": "Destroy defense platform",
		"strategic_resource": "defense_network",
		"effect": "Fewer defense platforms near the Boss"
	},
	"M-Class Planet": {
		"region": Rect2(32, 32, 32, 32),
		"objective": "Destroy fighter production",
		"strategic_resource": "fighters",
		"effect": "Fewer fighter squadrons and reinforcements"
	},
	"Asteroid Field": {
		"region": Rect2(0, 32, 32, 32),
		"objective": "Destroy mining operation",
		"strategic_resource": "metals",
		"effect": "Fewer armored ships and fortified defenses"
	}
}

var random := RandomNumberGenerator.new()
var map_nodes: Array[Dictionary] = []
var lanes: Array[Vector2i] = []
var background_stars: Array[Dictionary] = []
var start_node_id := 0
var boss_node_id := 0
var current_node_id := 0
var enemy_support_totals: Dictionary = {}
var destroyed_enemy_targets: Dictionary = {}
var map_size := Vector2.ZERO


func _ready() -> void:
	random.randomize()
	%MainMenuButton.pressed.connect(_return_to_main_menu)
	_build_map()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_return_to_main_menu()
		get_viewport().set_input_as_handled()


func _build_map() -> void:
	map_size = get_viewport_rect().size
	_build_background_stars()
	_create_map_nodes()
	_create_hyperspace_lanes()
	_create_node_visuals()
	queue_redraw()


func _build_background_stars() -> void:
	background_stars.clear()
	for index in range(110):
		background_stars.append({
			"position": Vector2(
				random.randf_range(0.0, map_size.x),
				random.randf_range(0.0, map_size.y)
			),
			"radius": random.randf_range(0.5, 1.6),
			"brightness": random.randf_range(0.2, 0.75)
		})


func _create_map_nodes() -> void:
	map_nodes.clear()
	enemy_support_totals.clear()
	destroyed_enemy_targets.clear()
	var left_margin := 115.0
	var right_margin := 115.0
	var top_margin := 165.0
	var bottom_margin := 105.0
	var location_names: Array = LOCATION_DATA.keys()
	location_names.shuffle()
	var regular_node_number := 0

	for column in range(COLUMN_COUNTS.size()):
		var count: int = COLUMN_COUNTS[column]
		var column_x := lerpf(
			left_margin,
			map_size.x - right_margin,
			float(column) / float(COLUMN_COUNTS.size() - 1)
		)
		for row in range(count):
			var node_position := Vector2(
				column_x,
				lerpf(
					top_margin,
					map_size.y - bottom_margin,
					0.5 if count == 1 else float(row) / float(count - 1)
				)
			)
			if count > 1:
				node_position += Vector2(
					random.randf_range(-18.0, 18.0),
					random.randf_range(-18.0, 18.0)
				)

			var is_boss := column == COLUMN_COUNTS.size() - 1
			var location_name := "Boss"
			var star_name := ""
			if not is_boss:
				location_name = location_names[
					regular_node_number % location_names.size()
				]
				star_name = STAR_REGIONS.keys().pick_random()
				var strategic_resource: String = LOCATION_DATA[
					location_name
				]["strategic_resource"]
				enemy_support_totals[strategic_resource] = int(
					enemy_support_totals.get(strategic_resource, 0)
				) + 1
				regular_node_number += 1

			var node_id := map_nodes.size()
			map_nodes.append({
				"id": node_id,
				"column": column,
				"position": node_position,
				"star": star_name,
				"location": location_name,
				"is_boss": is_boss,
				"completed": false
			})

	start_node_id = 0
	boss_node_id = map_nodes.size() - 1
	current_node_id = start_node_id


func _create_hyperspace_lanes() -> void:
	lanes.clear()
	var columns: Array = []
	for column_index in range(COLUMN_COUNTS.size()):
		columns.append([])
	for map_node in map_nodes:
		columns[int(map_node["column"])].append(int(map_node["id"]))

	for column_index in range(columns.size() - 1):
		var from_nodes: Array = columns[column_index]
		var to_nodes: Array = columns[column_index + 1]
		for from_index in range(from_nodes.size()):
			_add_lane(
				int(from_nodes[from_index]),
				int(to_nodes[from_index % to_nodes.size()])
			)
			if to_nodes.size() > 1:
				_add_lane(
					int(from_nodes[from_index]),
					int(to_nodes[(from_index + 1) % to_nodes.size()])
				)
		for to_index in range(to_nodes.size()):
			_add_lane(
				int(from_nodes[to_index % from_nodes.size()]),
				int(to_nodes[to_index])
			)

	# The player can challenge the Boss immediately, but the red direct lane
	# skips every opportunity to disrupt its supplies and reinforcements.
	_add_lane(start_node_id, boss_node_id)


func _add_lane(from_id: int, to_id: int) -> void:
	var lane := Vector2i(from_id, to_id)
	if not lanes.has(lane):
		lanes.append(lane)


func _create_node_visuals() -> void:
	for map_node in map_nodes:
		var node_position: Vector2 = map_node["position"]
		if bool(map_node["is_boss"]):
			_create_boss_label(node_position)
			continue

		var star_sprite := Sprite2D.new()
		star_sprite.name = "Star_%s" % map_node["id"]
		star_sprite.texture = _atlas_texture(STAR_REGIONS[map_node["star"]])
		star_sprite.position = node_position + Vector2(-25.0, -23.0)
		star_sprite.scale = Vector2(0.85, 0.85)
		add_child(star_sprite)

		var location_sprite := Sprite2D.new()
		location_sprite.name = "Location_%s" % map_node["id"]
		location_sprite.texture = _atlas_texture(
			LOCATION_DATA[map_node["location"]]["region"]
		)
		location_sprite.position = node_position
		location_sprite.scale = Vector2(1.35, 1.35)
		add_child(location_sprite)

		var location_label := Label.new()
		location_label.position = node_position + Vector2(-90.0, 28.0)
		location_label.size = Vector2(180.0, 44.0)
		location_label.text = (
			"START\n" if int(map_node["id"]) == start_node_id else ""
		) + str(map_node["location"])
		location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		location_label.add_theme_font_size_override("font_size", 13)
		location_label.add_theme_color_override(
			"font_color",
			Color(0.8, 0.9, 1.0)
		)
		add_child(location_label)


func _create_boss_label(node_position: Vector2) -> void:
	var boss_label := Label.new()
	boss_label.position = node_position + Vector2(-70.0, -24.0)
	boss_label.size = Vector2(140.0, 48.0)
	boss_label.text = "Boss"
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_label.add_theme_font_size_override("font_size", 30)
	boss_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	add_child(boss_label)


func _atlas_texture(region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = PLANET_ATLAS
	texture.region = region
	return texture


func complete_location(node_id: int) -> void:
	if node_id < 0 or node_id >= map_nodes.size():
		return
	var map_node: Dictionary = map_nodes[node_id]
	if bool(map_node["is_boss"]) or bool(map_node["completed"]):
		return
	map_node["completed"] = true
	var location_data: Dictionary = LOCATION_DATA[map_node["location"]]
	var strategic_resource := str(location_data["strategic_resource"])
	destroyed_enemy_targets[strategic_resource] = int(
		destroyed_enemy_targets.get(strategic_resource, 0)
	) + 1


func is_enemy_support_active(strategic_resource: String) -> bool:
	return get_enemy_support_ratio(strategic_resource) > 0.0


func get_enemy_support_ratio(strategic_resource: String) -> float:
	var total := int(enemy_support_totals.get(strategic_resource, 0))
	if total <= 0:
		return 0.0
	var destroyed := int(destroyed_enemy_targets.get(strategic_resource, 0))
	return clampf(float(total - destroyed) / float(total), 0.0, 1.0)


func get_enemy_support_levels() -> Dictionary:
	var support_levels: Dictionary = {}
	for strategic_resource in enemy_support_totals:
		support_levels[strategic_resource] = get_enemy_support_ratio(
			strategic_resource
		)
	return support_levels


func get_adjacent_locations() -> Array[int]:
	var adjacent_locations: Array[int] = []
	for lane in lanes:
		if lane.x == current_node_id:
			adjacent_locations.append(lane.y)
		elif lane.y == current_node_id:
			adjacent_locations.append(lane.x)
	return adjacent_locations


func move_fleet_to(node_id: int) -> bool:
	if not get_adjacent_locations().has(node_id):
		return false
	current_node_id = node_id
	queue_redraw()
	return true


func _draw() -> void:
	# The source atlas has an opaque black background, so matching it here keeps
	# each pixel-art region visually seamless.
	draw_rect(Rect2(Vector2.ZERO, map_size), Color.BLACK)
	for star in background_stars:
		var brightness := float(star["brightness"])
		draw_circle(
			star["position"],
			float(star["radius"]),
			Color(brightness, brightness, brightness * 1.15)
		)

	for lane in lanes:
		var is_accessible := (
			lane.x == current_node_id or lane.y == current_node_id
		)
		if lane.x == start_node_id and lane.y == boss_node_id:
			_draw_direct_boss_lane(is_accessible)
			continue
		var from_position: Vector2 = map_nodes[lane.x]["position"]
		var to_position: Vector2 = map_nodes[lane.y]["position"]
		_draw_hyperspace_lane(from_position, to_position, is_accessible)

	for map_node in map_nodes:
		if bool(map_node["is_boss"]):
			continue
		var node_position: Vector2 = map_node["position"]
		draw_circle(node_position, 28.0, Color(0.08, 0.2, 0.38, 0.8))
		draw_arc(node_position, 29.0, 0.0, TAU, 32, Color(0.3, 0.8, 1.0), 2.0)

	_draw_fleet_marker()


func _draw_hyperspace_lane(
	from_position: Vector2,
	to_position: Vector2,
	is_accessible: bool
) -> void:
	if is_accessible:
		draw_line(
			from_position,
			to_position,
			Color(0.05, 0.35, 0.8, 0.22),
			7.0
		)
		draw_line(
			from_position,
			to_position,
			Color(0.25, 0.75, 1.0, 0.95),
			2.5
		)
		return
	draw_dashed_line(
		from_position,
		to_position,
		Color(0.2, 0.45, 0.65, 0.48),
		2.0,
		8.0
	)


func _draw_direct_boss_lane(is_accessible: bool) -> void:
	var start_position: Vector2 = map_nodes[start_node_id]["position"]
	var boss_position: Vector2 = map_nodes[boss_node_id]["position"]
	var high_route_y := 122.0
	var route := PackedVector2Array([
		start_position,
		Vector2(start_position.x + 75.0, high_route_y),
		Vector2(boss_position.x - 75.0, high_route_y),
		boss_position
	])
	if is_accessible:
		draw_polyline(route, Color(0.9, 0.08, 0.04, 0.25), 8.0)
		draw_polyline(route, Color(1.0, 0.22, 0.12, 0.95), 2.5)
		return
	for point_index in range(route.size() - 1):
		draw_dashed_line(
			route[point_index],
			route[point_index + 1],
			Color(0.65, 0.16, 0.12, 0.48),
			2.0,
			8.0
		)


func _draw_fleet_marker() -> void:
	var fleet_position: Vector2 = map_nodes[current_node_id]["position"]
	fleet_position.y -= 55.0
	var triangle := PackedVector2Array([
		fleet_position + Vector2(0.0, -11.0),
		fleet_position + Vector2(-10.0, 9.0),
		fleet_position + Vector2(10.0, 9.0)
	])
	draw_colored_polygon(triangle, Color(1.0, 1.0, 1.0))
	draw_polyline(
		PackedVector2Array([triangle[0], triangle[1], triangle[2], triangle[0]]),
		Color(0.2, 0.65, 1.0),
		2.0
	)


func _return_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://title.tscn")
