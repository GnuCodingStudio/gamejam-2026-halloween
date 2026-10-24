class_name UnitSpawner
extends Node

signal unit_spawned(unit: Unit)

const UNIT_SCENE := preload("res://scenes/minigames/territory/Unit.tscn")

@export var faction: Faction.Side
@export var units_root: Node3D
@export var home_x := 0.0

var _cooldowns: Dictionary[UnitStats, float] = {}


func _process(delta: float) -> void:
	for stats in _cooldowns.keys():
		var remaining := _cooldowns[stats] - delta
		if remaining > 0.0:
			_cooldowns[stats] = remaining
		else:
			_cooldowns.erase(stats)


func remaining_cooldown(stats: UnitStats) -> float:
	return _cooldowns.get(stats, 0.0)


func spawn(stats: UnitStats) -> Unit:
	if remaining_cooldown(stats) > 0.0:
		return null
	_cooldowns[stats] = stats.cooldown
	var unit: Unit = UNIT_SCENE.instantiate()
	unit.setup(stats, faction)
	units_root.add_child(unit)
	unit.position = Vector3(_spawn_x(), 0.0, 0.0)
	unit_spawned.emit(unit)
	return unit


func _spawn_x() -> float:
	var x := home_x
	for node in get_tree().get_nodes_in_group(Site.GROUP):
		var site := node as Site
		if site.faction == faction and _is_more_forward(site.global_position.x, x):
			x = site.global_position.x
	return x


func _is_more_forward(candidate_x: float, current_x: float) -> bool:
	if faction == Faction.Side.PLAYER:
		return candidate_x > current_x
	return candidate_x < current_x
