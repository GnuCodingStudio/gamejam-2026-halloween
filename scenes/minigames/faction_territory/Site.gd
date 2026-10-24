class_name Site
extends Node3D

signal owner_changed(site: Site, side: Faction.Side)

const GROUP := &"sites"
const BASE_DARKEN := 0.5

@export_range(0.0, 20.0, 0.5, "suffix:s") var capture_wait_time := 3.0
@export var faction: Faction.Side = Faction.Side.ENEMY:
	set(value):
		faction = value
		if is_node_ready():
			_refresh_color()

@onready var _flag: MeshInstance3D = %Flag
@onready var _base: MeshInstance3D = %Base
@onready var _capture_burst: CPUParticles3D = %CaptureBurst

var _flag_material := StandardMaterial3D.new()
var _base_material := StandardMaterial3D.new()


func _ready() -> void:
	add_to_group(GROUP)
	_flag.material_override = _flag_material
	_base.material_override = _base_material
	_refresh_color()


func flip_to(side: Faction.Side) -> void:
	if side == faction:
		return
	faction = side
	_capture_burst.restart()
	owner_changed.emit(self, side)


func _refresh_color() -> void:
	var color := Faction.color_of(faction)
	_flag_material.albedo_color = color
	_base_material.albedo_color = color.darkened(BASE_DARKEN)
	_capture_burst.color = color
