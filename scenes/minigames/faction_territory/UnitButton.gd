class_name UnitButton
extends Button

signal unit_requested(stats: UnitStats)

@onready var _cooldown_bar: ProgressBar = %CooldownBar

var _stats: UnitStats
var _spawner: UnitSpawner


func setup(stats: UnitStats, spawner: UnitSpawner) -> void:
	_stats = stats
	_spawner = spawner
	text = stats.display_name


func _ready() -> void:
	pressed.connect(_on_pressed)


func _process(_delta: float) -> void:
	visible = _spawner.is_unlocked(_stats)
	var remaining := _spawner.remaining_cooldown(_stats)
	disabled = remaining > 0.0 or _spawner.is_at_max_alive()
	_cooldown_bar.value = remaining / _stats.cooldown * 100.0
	text = _label(remaining)


func _label(remaining: float) -> String:
	if remaining > 0.0:
		return "%s\n%.1fs" % [_stats.display_name, remaining]
	return _stats.display_name


func _on_pressed() -> void:
	unit_requested.emit(_stats)
