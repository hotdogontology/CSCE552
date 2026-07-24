extends GridContainer

signal loadout_changed

const ICON_SHEET := preload("res://sprites/loadouticons.png")

@export_enum("left_wing", "fuselage", "right_wing") var bay_id := "left_wing"

var occupancy: Array[int] = []
var placed_components: Array[Dictionary] = []
var cells: Array[Control] = []
var selected_component: Dictionary = {}


func _ready() -> void:
	for child in get_children():
		var cell := child as Control
		if cell != null:
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cells.append(cell)
	occupancy.resize(cells.size())
	occupancy.fill(-1)


func _gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed:
		return

	var cell_index := _cell_index_at_position(mouse_event.position)
	if cell_index < 0:
		return
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		if occupancy[cell_index] >= 0:
			_remove_component(occupancy[cell_index])
			accept_event()
		return
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		if selected_component.is_empty():
			return
		var origin_index := _placement_origin_index(
			mouse_event.position,
			selected_component["size"]
		)
		if (
			origin_index >= 0
			and _can_place(origin_index, selected_component["size"])
		):
			_place_component(origin_index, selected_component)
			accept_event()


func set_selected_component(component_data: Dictionary) -> void:
	selected_component = component_data.duplicate(true)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not _is_component_data(data):
		return false
	var origin_index := _placement_origin_index(at_position, data["size"])
	if origin_index < 0:
		return false
	return _can_place(origin_index, data["size"])


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var origin_index := _placement_origin_index(at_position, data["size"])
	if origin_index < 0 or not _can_place(origin_index, data["size"]):
		return
	_place_component(origin_index, data)


func get_component_counts() -> Dictionary:
	var counts := {
		"battery": 0,
		"shield": 0,
		"laser": 0
	}
	for component in placed_components:
		if component.get("removed", false):
			continue
		var component_type: String = component["component_type"]
		counts[component_type] += 1
	return counts


func get_saved_components() -> Array[Dictionary]:
	var saved_components: Array[Dictionary] = []
	for component in placed_components:
		if component.get("removed", false):
			continue
		var saved_component := component.duplicate(true)
		saved_component.erase("removed")
		saved_components.append(saved_component)
	return saved_components


func _is_component_data(data: Variant) -> bool:
	return (
		data is Dictionary
		and data.has("component_type")
		and data.has("size")
		and data.has("atlas_region")
	)


func _cell_index_at_position(at_position: Vector2) -> int:
	var closest_index := -1
	var closest_distance := INF
	for index in cells.size():
		var cell := cells[index]
		var cell_rect := Rect2(cell.position, cell.size).grow(6.0)
		if not cell_rect.has_point(at_position):
			continue
		var distance := at_position.distance_squared_to(
			cell.position + cell.size * 0.5
		)
		if distance < closest_distance:
			closest_distance = distance
			closest_index = index
	return closest_index


func _placement_origin_index(
	at_position: Vector2,
	component_size: Vector2i
) -> int:
	var hovered_index := _cell_index_at_position(at_position)
	if hovered_index < 0:
		return -1

	var row_count := ceili(float(cells.size()) / float(columns))
	var hovered_column := hovered_index % columns
	var hovered_row := floori(float(hovered_index) / float(columns))
	var origin_column := mini(
		hovered_column,
		columns - component_size.x
	)
	var origin_row := mini(
		hovered_row,
		row_count - component_size.y
	)
	if origin_column < 0 or origin_row < 0:
		return -1
	return origin_row * columns + origin_column


func _can_place(origin_index: int, component_size: Vector2i) -> bool:
	var row_count := ceili(float(cells.size()) / float(columns))
	var origin_column := origin_index % columns
	var origin_row := floori(float(origin_index) / float(columns))
	if (
		origin_column + component_size.x > columns
		or origin_row + component_size.y > row_count
	):
		return false

	for y_offset in component_size.y:
		for x_offset in component_size.x:
			var cell_index := (
				(origin_row + y_offset) * columns
				+ origin_column
				+ x_offset
			)
			if occupancy[cell_index] != -1:
				return false
	return true


func _place_component(origin_index: int, data: Dictionary) -> void:
	var component_size: Vector2i = data["size"]
	var component_id := placed_components.size()
	var origin_column := origin_index % columns
	var origin_row := floori(float(origin_index) / float(columns))
	var occupied_cells: Array[int] = []

	for y_offset in component_size.y:
		for x_offset in component_size.x:
			var cell_index := (
				(origin_row + y_offset) * columns
				+ origin_column
				+ x_offset
			)
			occupancy[cell_index] = component_id
			occupied_cells.append(cell_index)
			_set_cell_icon(cells[cell_index], data["atlas_region"])

	placed_components.append({
		"component_type": data["component_type"],
		"bay": bay_id,
		"origin": Vector2i(origin_column, origin_row),
		"size": component_size,
		"occupied_cells": occupied_cells,
		"removed": false
	})
	loadout_changed.emit()


func _remove_component(component_id: int) -> void:
	if (
		component_id < 0
		or component_id >= placed_components.size()
		or placed_components[component_id].get("removed", false)
	):
		return

	var component := placed_components[component_id]
	for cell_index in component["occupied_cells"]:
		occupancy[cell_index] = -1
		_clear_cell_icon(cells[cell_index])
	component["removed"] = true
	loadout_changed.emit()


func _clear_cell_icon(cell: Control) -> void:
	for child in cell.get_children():
		child.queue_free()


func _set_cell_icon(cell: Control, atlas_region: Rect2) -> void:
	var texture := AtlasTexture.new()
	texture.atlas = ICON_SHEET
	texture.region = atlas_region

	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(icon)
