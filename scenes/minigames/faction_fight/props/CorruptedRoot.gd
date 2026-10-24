extends Node3D

@export var collision_enabled: bool = true

@onready var collision_shape: CollisionShape3D = $Collision/MainRootShape


func _ready() -> void:
	collision_shape.disabled = not collision_enabled
