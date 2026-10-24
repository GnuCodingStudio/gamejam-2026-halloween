class_name Territory
extends Node3D

const ALL_STATS: Array[UnitStats] = [
	preload("res://scenes/minigames/territory/units/rogue.tres"),
	preload("res://scenes/minigames/territory/units/ranger.tres"),
	preload("res://scenes/minigames/territory/units/mage.tres"),
]

@onready var _player_spawner: UnitSpawner = %PlayerSpawner
@onready var _hud: TerritoryHud = %Hud


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hud.setup(ALL_STATS, _player_spawner)
	_hud.unit_requested.connect(_on_unit_requested)


func _on_unit_requested(stats: UnitStats) -> void:
	_player_spawner.spawn(stats)
