class_name Site
extends Node3D

signal owner_changed(site: Site, side: Faction.Side)

@export var faction: Faction.Side = Faction.Side.ENEMY:
	set(value):
		faction = value
		if is_node_ready():
			_refresh_flag()

@onready var _flag: MeshInstance3D = %Flag

var _flag_material := StandardMaterial3D.new()


func _ready() -> void:
	_flag.material_override = _flag_material
	_refresh_flag()


func flip_to(side: Faction.Side) -> void:
	if side == faction:
		return
	faction = side
	owner_changed.emit(self, side)


func _refresh_flag() -> void:
	_flag_material.albedo_color = Faction.color_of(faction)
