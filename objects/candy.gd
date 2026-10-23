class_name Candy
extends Area3D

signal collected

@export var bob_height: float = 0.1
@export var bob_speed: float = 2.0

var _phase: float = randf() * TAU

@onready var _mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(_delta: float) -> void:
	var time := Time.get_ticks_msec() / 1000.0
	_mesh.position.y = sin(time * bob_speed + _phase) * bob_height


func _on_body_entered(_body: Node3D) -> void:
	collected.emit()
	queue_free()
