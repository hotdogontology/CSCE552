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
var vertical_controls_inverted := false


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
	_apply_active_loadout(loadout_data)
	has_saved_loadout = true


func get_saved_loadouts() -> Array[Dictionary]:
	return saved_loadouts.duplicate(true)


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
