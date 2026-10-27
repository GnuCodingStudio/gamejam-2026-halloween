class_name CameraPivot
extends Node3D

@export_range(0.0, 1.0) var mouse_sensitivity: float = 0.01
@export_range(0.0, 1.0) var touch_sensitivity: float = 0.005
@export var tilt_limit: float = deg_to_rad(75)

@onready var camera: Camera3D = %Camera


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		_rotate_by((event as InputEventMouseMotion).screen_relative * mouse_sensitivity)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if not TouchControl.is_finger_claimed(drag.index) and not _is_in_joystick_zone(drag.position):
			_rotate_by(drag.screen_relative * touch_sensitivity)


func _is_in_joystick_zone(position_on_screen: Vector2) -> bool:
	if not is_inside_tree():
		return false
	var screen_width := get_viewport().get_visible_rect().size.x
	return position_on_screen.x < screen_width * TouchJoystick.DEFAULT_ZONE_WIDTH_RATIO


func _rotate_by(angles: Vector2) -> void:
	self.rotation.x = clampf(self.rotation.x - angles.y, -tilt_limit, tilt_limit)
	self.rotation.y -= angles.x
