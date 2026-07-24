extends Control

const SHIP_STATUS_TEXTURE := preload("res://sprites/shipstatus.png")
const STATUS_REGIONS := {
	"healthy": Rect2(8, 0, 16, 16),
	"left_damaged": Rect2(40, 0, 16, 16),
	"right_damaged": Rect2(56, 0, 16, 16),
	"both_damaged": Rect2(8, 16, 16, 16),
	"destroyed": Rect2(56, 16, 16, 16)
}

@onready var power_label: Label = %PowerLabel
@onready var power_bar: ProgressBar = %PowerBar
@onready var shield_readout: VBoxContainer = %ShieldReadout
@onready var shield_label: Label = %ShieldLabel
@onready var ship_icon: TextureRect = %ShipIcon


func _ready() -> void:
	_style_bar(power_bar, Color(0.95, 0.78, 0.12))

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	player.runtime_status_changed.connect(_update_status)
	_update_status(player.call("get_runtime_status"))


func _style_bar(bar: ProgressBar, fill_color: Color) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.035, 0.045, 0.07, 0.9)
	background.border_color = Color(0.7, 0.75, 0.8, 0.8)
	background.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)


func _update_status(status: Dictionary) -> void:
	var current_power := float(status["current_power"])
	var maximum_power := float(status["maximum_power"])
	power_bar.max_value = maxf(maximum_power, 1.0)
	power_bar.value = current_power
	power_label.text = "POWER"

	var shield_count := int(status["shield_count"])
	shield_readout.visible = true
	shield_label.text = (
		"SHIELDS UP"
		if shield_count > 0 and bool(status["shields_active"])
		else "SHIELDS DOWN"
	)
	_update_ship_icon(status)


func _update_ship_icon(status: Dictionary) -> void:
	var icon_state := "healthy"
	if bool(status["ship_destroyed"]):
		icon_state = "destroyed"
	elif not bool(status["left_wing_intact"]) and not bool(status["right_wing_intact"]):
		icon_state = "both_damaged"
	elif not bool(status["left_wing_intact"]):
		icon_state = "left_damaged"
	elif not bool(status["right_wing_intact"]):
		icon_state = "right_damaged"

	var atlas := AtlasTexture.new()
	atlas.atlas = SHIP_STATUS_TEXTURE
	atlas.region = STATUS_REGIONS[icon_state]
	ship_icon.texture = atlas
