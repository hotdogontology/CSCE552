extends Node

var components_by_bay := {
	"left_wing": [],
	"fuselage": [],
	"right_wing": []
}
var shield_level := 0
var laser_component_count := 0
var battery_area := 0
var has_saved_loadout := false
var saved_loadouts: Array[Dictionary] = []
var active_loadout_index := -1
var using_default_loadout := false
var vertical_controls_inverted := false
var selected_mission_name := "Training"
var selected_mission_scene := "res://main.tscn"


func select_mission(mission_name: String, mission_scene: String) -> void:
	selected_mission_name = mission_name
	selected_mission_scene = mission_scene


func save_loadout(
	slot_index: int,
	new_components_by_bay: Dictionary,
	new_shield_level: int,
	new_laser_component_count: int,
	new_battery_area: int
) -> void:
	var loadout_data := {
		"components_by_bay": new_components_by_bay.duplicate(true),
		"shield_level": new_shield_level,
		"laser_component_count": new_laser_component_count,
		"battery_area": new_battery_area
	}
	if slot_index < saved_loadouts.size():
		saved_loadouts[slot_index] = loadout_data
	else:
		saved_loadouts.append(loadout_data)

	active_loadout_index = slot_index
	using_default_loadout = false
	_apply_active_loadout(loadout_data)
	has_saved_loadout = true


func get_saved_loadouts() -> Array[Dictionary]:
	return saved_loadouts.duplicate(true)


func activate_default_loadout() -> Dictionary:
	var loadout_data := get_default_loadout()
	active_loadout_index = -1
	using_default_loadout = true
	_apply_active_loadout(loadout_data)
	has_saved_loadout = true
	return loadout_data.duplicate(true)


func activate_saved_loadout(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= saved_loadouts.size():
		return {}
	var loadout_data: Dictionary = saved_loadouts[slot_index]
	active_loadout_index = slot_index
	using_default_loadout = false
	_apply_active_loadout(loadout_data)
	has_saved_loadout = true
	return loadout_data.duplicate(true)


func clear_active_loadout() -> void:
	components_by_bay = {
		"left_wing": [],
		"fuselage": [],
		"right_wing": []
	}
	shield_level = 0
	laser_component_count = 0
	battery_area = 0
	has_saved_loadout = false
	active_loadout_index = -1
	using_default_loadout = false


func get_default_loadout() -> Dictionary:
	var default_components := {
		"left_wing": _build_wing_components(3),
		"fuselage": _build_fuselage_components(),
		"right_wing": _build_wing_components(0)
	}
	return {
		"components_by_bay": default_components,
		"shield_level": 2,
		"laser_component_count": 2,
		"battery_area": 32
	}


func _build_wing_components(laser_column: int) -> Array[Dictionary]:
	var components: Array[Dictionary] = [{
		"component_type": "laser",
		"bay": "left_wing" if laser_column == 3 else "right_wing",
		"origin": Vector2i(laser_column, 0),
		"size": Vector2i(1, 4),
		"occupied_cells": [
			laser_column,
			laser_column + 4,
			laser_column + 8,
			laser_column + 12
		]
	}]
	var bay_id := "left_wing" if laser_column == 3 else "right_wing"
	for cell_index in range(16):
		if cell_index % 4 == laser_column:
			continue
		components.append({
			"component_type": "battery",
			"bay": bay_id,
			"origin": Vector2i(cell_index % 4, cell_index / 4),
			"size": Vector2i.ONE,
			"occupied_cells": [cell_index]
		})
	return components


func _build_fuselage_components() -> Array[Dictionary]:
	var components: Array[Dictionary] = [
		{
			"component_type": "shield",
			"bay": "fuselage",
			"origin": Vector2i(0, 0),
			"size": Vector2i(2, 2),
			"occupied_cells": [0, 1, 2, 3]
		},
		{
			"component_type": "shield",
			"bay": "fuselage",
			"origin": Vector2i(0, 2),
			"size": Vector2i(2, 2),
			"occupied_cells": [4, 5, 6, 7]
		}
	]
	for cell_index in range(8, 16):
		components.append({
			"component_type": "battery",
			"bay": "fuselage",
			"origin": Vector2i(cell_index % 2, cell_index / 2),
			"size": Vector2i.ONE,
			"occupied_cells": [cell_index]
		})
	return components


func get_laser_components() -> Array[Dictionary]:
	var laser_components: Array[Dictionary] = []
	for bay_id in ["left_wing", "fuselage", "right_wing"]:
		for component in components_by_bay[bay_id]:
			if component["component_type"] == "laser":
				laser_components.append(component)
	return laser_components


func _apply_active_loadout(loadout_data: Dictionary) -> void:
	components_by_bay = loadout_data["components_by_bay"].duplicate(true)
	shield_level = int(loadout_data["shield_level"])
	laser_component_count = int(loadout_data["laser_component_count"])
	battery_area = int(loadout_data["battery_area"])
