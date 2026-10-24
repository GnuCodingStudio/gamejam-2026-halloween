class_name UnitSpawner
extends Node

signal unit_spawned(unit: Unit)

const UNIT_SCENE := preload("res://scenes/minigames/territory/Unit.tscn")

@export var faction: Faction.Side
@export var units_root: Node3D
@export var home_x := 0.0
@export var spawn_at_rearmost_site := false

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


func start_cooldowns(all_stats: Array[UnitStats]) -> void:
	for stats in all_stats:
		if not _cooldowns.has(stats):
			_cooldowns[stats] = stats.cooldown


func spawn(stats: UnitStats) -> Unit:
	if remaining_cooldown(stats) > 0.0:
		return null
	_cooldowns[stats] = stats.cooldown
	return spawn_free(stats)


func spawn_free(stats: UnitStats) -> Unit:
	var unit: Unit = UNIT_SCENE.instantiate()
	unit.setup(stats, faction)
	units_root.add_child(unit)
	unit.position = Vector3(_spawn_x(), 0.0, 0.0)
	unit_spawned.emit(unit)
	return unit


func _spawn_x() -> float:
	var owned_xs := _owned_site_xs()
	if owned_xs.is_empty():
		return home_x
	var wants_highest_x := (faction == Faction.Side.PLAYER) != spawn_at_rearmost_site
	var x: float = owned_xs.max() if wants_highest_x else owned_xs.min()
	return x


func _owned_site_xs() -> Array[float]:
	var xs: Array[float] = []
	for node in get_tree().get_nodes_in_group(Site.GROUP):
		var site := node as Site
		if site.faction == faction:
			xs.append(site.global_position.x)
	return xs
