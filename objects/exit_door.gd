class_name ExitDoor
extends Node3D

signal player_near(is_near: bool)
signal use_requested

var _is_player_near := false

@onready var interact_zone: Area3D = %InteractZone


func _ready() -> void:
	interact_zone.body_entered.connect(_set_player_near.bind(true))
	interact_zone.body_exited.connect(_set_player_near.bind(false))


func _unhandled_input(event: InputEvent) -> void:
	if _is_player_near and event.is_action_pressed("action_activate"):
		use_requested.emit()


func _set_player_near(_body: Node3D, is_near: bool) -> void:
	_is_player_near = is_near
	player_near.emit(is_near)
