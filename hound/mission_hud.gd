extends Control

const SHIP_STATUS_TEXTURE := preload("res://sprites/new_status_sprites.png")
const STATUS_REGIONS := {
	"healthy": Rect2(56, 0, 16, 16),
	"left_damaged": Rect2(88, 0, 16, 16),
	"right_damaged": Rect2(104, 0, 16, 16),
	"both_damaged": Rect2(88, 16, 16, 16),
	"destroyed": Rect2(104, 16, 16, 16)
}

@onready var power_label: Label = %PowerLabel
@onready var power_bar: ProgressBar = %PowerBar
@onready var shield_readout: VBoxContainer = %ShieldReadout
@onready var shield_label: Label = %ShieldLabel
@onready var ship_icon: TextureRect = %ShipIcon
@onready var kills_label: Label = %KillsLabel
@onready var metal_label: Label = get_node_or_null("%MetalLabel") as Label

var ship_icon_state := "healthy"
var displayed_ship_icon_state := ""
var kill_count := 0


func _ready() -> void:
	_style_bar(power_bar, Color(0.95, 0.78, 0.12))

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	player.runtime_status_changed.connect(_update_status)
	_update_status(player.call("get_runtime_status"))
	_update_kills_label()
	set_metal_progress(0, 5)


func _process(_delta: float) -> void:
	if ship_icon_state in ["left_damaged", "right_damaged", "both_damaged"]:
		var showing_damage := (
			Time.get_ticks_msec() / 250
		) % 2 == 0
		_set_ship_icon_region(
			ship_icon_state if showing_damage else "healthy"
		)


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
	ship_icon_state = "healthy"
	if bool(status["ship_destroyed"]):
		ship_icon_state = "destroyed"
	elif not bool(status["left_wing_intact"]) and not bool(status["right_wing_intact"]):
		ship_icon_state = "both_damaged"
	elif not bool(status["left_wing_intact"]):
		ship_icon_state = "left_damaged"
	elif not bool(status["right_wing_intact"]):
		ship_icon_state = "right_damaged"
	_set_ship_icon_region(ship_icon_state)


func _set_ship_icon_region(icon_state: String) -> void:
	if displayed_ship_icon_state == icon_state:
		return
	displayed_ship_icon_state = icon_state
	var atlas := AtlasTexture.new()
	atlas.atlas = SHIP_STATUS_TEXTURE
	atlas.region = STATUS_REGIONS[icon_state]
	ship_icon.texture = atlas


func register_player_kill() -> void:
	kill_count += 1
	_update_kills_label()


func _update_kills_label() -> void:
	kills_label.text = "Kills : %d" % kill_count


func set_metal_progress(destroyed_count: int, target_count: int) -> void:
	if metal_label == null:
		return
	metal_label.text = "Metal Harvested: %d / %d" % [
		destroyed_count,
		target_count
	]
