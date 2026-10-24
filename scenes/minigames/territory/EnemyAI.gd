class_name EnemyAI
extends Node

@export var spawner: UnitSpawner
@export_range(1.0, 20.0, 0.5) var spawn_interval := 4.0

var _all_stats: Array[UnitStats] = []
var _has_spawned := false

@onready var _timer: Timer = %SpawnTimer


func _ready() -> void:
	_timer.timeout.connect(_on_spawn_timer_timeout)


func start(all_stats: Array[UnitStats]) -> void:
	_all_stats = all_stats
	_has_spawned = false
	_timer.start(spawn_interval)


func _on_spawn_timer_timeout() -> void:
	if not _has_spawned:
		_has_spawned = true
		spawner.spawn(_all_stats[0])
		return
	var candidates := _ready_stats()
	if candidates.is_empty():
		return
	spawner.spawn(candidates.pick_random())


func _ready_stats() -> Array[UnitStats]:
	var ready_stats: Array[UnitStats] = []
	for stats in _all_stats:
		if spawner.remaining_cooldown(stats) <= 0.0:
			ready_stats.append(stats)
	return ready_stats
