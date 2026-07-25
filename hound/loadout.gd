extends Control

@onready var left_wing_grid: Node = $Layout/Body/Bays/LeftWingBay/Grid
@onready var fuselage_grid: Node = $Layout/Body/Bays/FuselageBay/Grid
@onready var right_wing_grid: Node = $Layout/Body/Bays/RightWingBay/Grid
@onready var shield_level_label: Label = $Layout/Summary/ShieldLevel
@onready var laser_count_label: Label = $Layout/Summary/LaserCount
@onready var power_label: Label = $Layout/Summary/Power
@onready var validation_message: Label = $Layout/ValidationMessage
@onready var save_button: Button = $Layout/SaveButton
@onready var launch_button: Button = $Layout/LaunchButton
@onready var loadout_slot_1: Button = $Layout/Body/SavedLoadouts/LoadoutSlot1
@onready var loadout_slot_2: Button = $Layout/Body/SavedLoadouts/LoadoutSlot2
@onready var overwrite_dialog: ConfirmationDialog = $OverwriteDialog
@onready var directions_popup: Control = $DirectionsPopup

var grids: Array[Node] = []
var loadout_slots: Array[Button] = []
var pending_loadout_data: Dictionary = {}
var pending_overwrite_slot := -1


func _ready() -> void:
	grids = [left_wing_grid, fuselage_grid, right_wing_grid]
	loadout_slots = [loadout_slot_1, loadout_slot_2]
	for grid in grids:
		grid.connect("loadout_changed", _update_summary)
	for source in get_tree().get_nodes_in_group("component_palette_sources"):
		source.component_selected.connect(_select_component.bind(source))
	save_button.pressed.connect(_save_loadout)
	launch_button.pressed.connect(_launch_mission)
	loadout_slot_1.pressed.connect(_request_overwrite.bind(0))
	loadout_slot_2.pressed.connect(_request_overwrite.bind(1))
	overwrite_dialog.confirmed.connect(_confirm_overwrite)
	$Layout/DirectionsButton.pressed.connect(_show_directions)
	%DirectionsBackButton.pressed.connect(_hide_directions)
	_update_summary()
	_refresh_saved_loadout_slots()


func _unhandled_input(event: InputEvent) -> void:
	if directions_popup.visible and event.is_action_pressed("ui_cancel"):
		_hide_directions()
		get_viewport().set_input_as_handled()


func _show_directions() -> void:
	directions_popup.show()
	%DirectionsBackButton.grab_focus()


func _hide_directions() -> void:
	directions_popup.hide()
	$Layout/DirectionsButton.grab_focus()


func _launch_mission() -> void:
	var state := get_node("/root/LoadoutState")
	if not bool(state.get("has_saved_loadout")):
		validation_message.text = "Save a valid loadout before launching."
		return
	get_tree().change_scene_to_file("res://main.tscn")


func _select_component(component_data: Dictionary, selected_source: Node) -> void:
	for grid in grids:
		grid.call("set_selected_component", component_data)
	for source in get_tree().get_nodes_in_group("component_palette_sources"):
		source.call("set_selected", source == selected_source)


func _update_summary() -> void:
	pending_loadout_data.clear()
	pending_overwrite_slot = -1
	var totals := _get_total_counts()
	var shield_count := int(totals["shield"])
	var laser_count := int(totals["laser"])
	var battery_count := int(totals["battery"])
	var required_battery_area: int = 4 * (shield_count + laser_count)
	shield_level_label.text = "Shield Level: %d" % shield_count
	laser_count_label.text = "Lasers: %d" % laser_count
	power_label.text = "Battery Area: %d / %d required" % [
		battery_count,
		required_battery_area
	]
	validation_message.text = ""
	_refresh_saved_loadout_slots()


func _save_loadout() -> void:
	var totals := _get_total_counts()
	var shield_count := int(totals["shield"])
	var laser_count := int(totals["laser"])
	var battery_count := int(totals["battery"])
	var required_battery_area: int = 4 * (shield_count + laser_count)
	if laser_count < 1:
		validation_message.text = "At least one laser component is required."
		return
	if battery_count < required_battery_area:
		validation_message.text = (
			"Not enough battery area. Add %d more battery cells."
			% (required_battery_area - battery_count)
		)
		return

	var loadout_data := {
		"components_by_bay": {
			"left_wing": left_wing_grid.call("get_saved_components"),
			"fuselage": fuselage_grid.call("get_saved_components"),
			"right_wing": right_wing_grid.call("get_saved_components")
		},
		"shield_level": shield_count,
		"laser_component_count": laser_count,
		"battery_area": battery_count
	}
	var state := get_node("/root/LoadoutState")
	var saved_loadouts: Array[Dictionary] = state.call("get_saved_loadouts")
	if saved_loadouts.size() < 2:
		_commit_save(saved_loadouts.size(), loadout_data)
		return

	pending_loadout_data = loadout_data
	validation_message.text = (
		"Both slots are full. Select a loadout on the right to overwrite."
	)
	_refresh_saved_loadout_slots()


func _request_overwrite(slot_index: int) -> void:
	if pending_loadout_data.is_empty():
		return
	pending_overwrite_slot = slot_index
	overwrite_dialog.dialog_text = (
		"Overwrite Loadout %d?" % (slot_index + 1)
	)
	overwrite_dialog.popup_centered()


func _confirm_overwrite() -> void:
	if pending_overwrite_slot < 0 or pending_loadout_data.is_empty():
		return
	_commit_save(pending_overwrite_slot, pending_loadout_data)


func _commit_save(slot_index: int, loadout_data: Dictionary) -> void:
	var state := get_node("/root/LoadoutState")
	state.call(
		"save_loadout",
		slot_index,
		loadout_data["components_by_bay"],
		int(loadout_data["shield_level"]),
		int(loadout_data["laser_component_count"]),
		int(loadout_data["battery_area"])
	)
	pending_loadout_data.clear()
	pending_overwrite_slot = -1
	validation_message.text = "Loadout %d saved." % (slot_index + 1)
	_refresh_saved_loadout_slots()


func _refresh_saved_loadout_slots() -> void:
	if loadout_slots.is_empty():
		return
	var state := get_node("/root/LoadoutState")
	var saved_loadouts: Array[Dictionary] = state.call("get_saved_loadouts")
	var active_slot := int(state.get("active_loadout_index"))
	launch_button.disabled = not bool(state.get("has_saved_loadout"))
	for slot_index in loadout_slots.size():
		var slot := loadout_slots[slot_index]
		if slot_index >= saved_loadouts.size():
			slot.text = "Loadout %d\nEmpty" % (slot_index + 1)
			continue

		var saved_loadout := saved_loadouts[slot_index]
		var active_marker := " *" if slot_index == active_slot else ""
		slot.text = (
			"Loadout %d%s\nShields: %d\nLasers: %d\nBattery: %d"
			% [
				slot_index + 1,
				active_marker,
				int(saved_loadout["shield_level"]),
				int(saved_loadout["laser_component_count"]),
				int(saved_loadout["battery_area"])
			]
		)
		if not pending_loadout_data.is_empty():
			slot.text += "\nClick to overwrite"


func _get_total_counts() -> Dictionary:
	var totals := {
		"battery": 0,
		"shield": 0,
		"laser": 0
	}
	for grid in grids:
		var counts: Dictionary = grid.call("get_component_counts")
		totals["battery"] += int(counts["battery"])
		totals["shield"] += int(counts["shield"])
		totals["laser"] += int(counts["laser"])
	return totals
