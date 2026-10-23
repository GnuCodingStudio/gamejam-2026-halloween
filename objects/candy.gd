class_name Candy
extends Area3D

signal collected


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(_body: Node3D) -> void:
	collected.emit()
	queue_free()
