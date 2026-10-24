class_name Territory
extends Node3D

const UNIT_SCENE := preload("res://scenes/minigames/territory/Unit.tscn")
const ALL_STATS: Array[UnitStats] = [
	preload("res://scenes/minigames/territory/units/rogue.tres"),
	preload("res://scenes/minigames/territory/units/ranger.tres"),
	preload("res://scenes/minigames/territory/units/mage.tres"),
]
const HOME_X := 22.0
const TEST_SPACING := 2.0

@onready var _units: Node3D = %Units


func _ready() -> void:
	_spawn_test_units()


func _spawn_test_units() -> void:
	for index in ALL_STATS.size():
		var offset := index * TEST_SPACING
		_spawn(ALL_STATS[index], Faction.Side.PLAYER, -HOME_X - offset)
		_spawn(ALL_STATS[index], Faction.Side.ENEMY, HOME_X + offset)


func _spawn(stats: UnitStats, side: Faction.Side, x: float) -> void:
	var unit: Unit = UNIT_SCENE.instantiate()
	unit.setup(stats, side)
	_units.add_child(unit)
	unit.position = Vector3(x, 0.0, 0.0)
