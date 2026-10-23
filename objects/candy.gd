class_name Candy
extends Area3D

signal collected

const SPARKLES_SCENE: PackedScene = preload("res://objects/candy_sparkles.tscn")
const SPARKLES_HEIGHT: float = 1.0

@export var bob_height: float = 0.1
@export var bob_speed: float = 2.0
@export var sparkle_color: Color = Color.WHITE

var _phase: float = randf() * TAU

@onready var _mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(_delta: float) -> void:
	var time := Time.get_ticks_msec() / 1000.0
	_mesh.position.y = sin(time * bob_speed + _phase) * bob_height


func _on_body_entered(_body: Node3D) -> void:
	_spawn_sparkles()
	collected.emit()
	queue_free()


func _spawn_sparkles() -> void:
	var sparkles: CPUParticles3D = SPARKLES_SCENE.instantiate()
	sparkles.color = sparkle_color
	get_parent().add_child(sparkles)
	sparkles.global_position = _mesh.global_position + Vector3.UP * SPARKLES_HEIGHT
