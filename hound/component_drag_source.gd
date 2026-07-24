extends GridContainer

signal component_selected(component_data: Dictionary)

const ICON_SHEET := preload("res://sprites/loadouticons.png")
const DISPLAY_CELL_SIZE := Vector2(32.0, 32.0)

@export_enum("battery", "shield", "laser") var component_type := "battery"
@export var component_size := Vector2i.ONE
@export var atlas_region := Rect2(8.0, 0.0, 16.0, 16.0)


func _ready() -> void:
	add_to_group("component_palette_sources")
	columns = component_size.x
	for child in get_children():
		child.queue_free()
	for cell_index in component_size.x * component_size.y:
		add_child(_create_icon_cell())


func _gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if (
		mouse_event == null
		or mouse_event.button_index != MOUSE_BUTTON_LEFT
		or not mouse_event.pressed
	):
		return
	component_selected.emit(_get_component_data())
	accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	var drag_data := _get_component_data()
	component_selected.emit(drag_data)
	set_drag_preview(_create_drag_preview())
	return drag_data


func _get_component_data() -> Dictionary:
	return {
		"component_type": component_type,
		"size": component_size,
		"atlas_region": atlas_region
	}


func set_selected(is_selected: bool) -> void:
	modulate = Color(1.25, 1.25, 0.75) if is_selected else Color.WHITE


func _create_drag_preview() -> Control:
	var preview := GridContainer.new()
	preview.columns = component_size.x
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for cell_index in component_size.x * component_size.y:
		preview.add_child(_create_icon_cell())
	return preview


func _create_icon_cell() -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = DISPLAY_CELL_SIZE
	icon.texture = _create_icon_texture()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _create_icon_texture() -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = ICON_SHEET
	texture.region = atlas_region
	return texture
