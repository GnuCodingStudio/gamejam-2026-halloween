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
	var remaining := _spawner.remaining_cooldown(_stats)
	disabled = remaining > 0.0
	_cooldown_bar.value = remaining / _stats.cooldown * 100.0
	text = _stats.display_name if remaining <= 0.0 else "%s\n%.1fs" % [_stats.display_name, remaining]


func _on_pressed() -> void:
	unit_requested.emit(_stats)
