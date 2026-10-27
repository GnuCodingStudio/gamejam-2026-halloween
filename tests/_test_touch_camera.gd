extends Node

var _failures: Array[String] = []


func _ready() -> void:
	_test_reserved_finger_is_ignored()
	_test_second_finger_rotates_camera()
	_test_release_restores_camera_drag()
	await _test_action_button_keeps_multitouch_independent()
	_test_mouse_filtering()
	_finish()


func _test_reserved_finger_is_ignored() -> void:
	var joystick := TouchJoystick.new()
	var camera_pivot := CameraPivot.new()
	joystick._claim_finger(4)
	var initial_rotation := camera_pivot.rotation
	camera_pivot._unhandled_input(_screen_drag(4, Vector2(30.0, 15.0)))
	_check(camera_pivot.rotation.is_equal_approx(initial_rotation), "Le doigt du joystick ne tourne pas la caméra")
	joystick._release_finger(4)
	joystick.free()
	camera_pivot.free()


func _test_second_finger_rotates_camera() -> void:
	var joystick := TouchJoystick.new()
	var camera_pivot := CameraPivot.new()
	joystick._claim_finger(1)
	var initial_rotation := camera_pivot.rotation
	camera_pivot._unhandled_input(_screen_drag(2, Vector2(30.0, 15.0)))
	_check(not camera_pivot.rotation.is_equal_approx(initial_rotation), "Un second doigt conserve la rotation tactile volontaire")
	joystick._release_finger(1)
	joystick.free()
	camera_pivot.free()


func _test_release_restores_camera_drag() -> void:
	var joystick := TouchJoystick.new()
	var camera_pivot := CameraPivot.new()
	joystick._claim_finger(7)
	joystick._release_finger(7)
	var initial_rotation := camera_pivot.rotation
	camera_pivot._unhandled_input(_screen_drag(7, Vector2(30.0, 15.0)))
	_check(not camera_pivot.rotation.is_equal_approx(initial_rotation), "Le relâchement libère immédiatement l'index tactile")
	joystick.free()
	camera_pivot.free()


func _test_action_button_keeps_multitouch_independent() -> void:
	var joystick := TouchJoystick.new()
	var jump_button := TouchActionButton.new()
	jump_button.action = &"move_jump"
	joystick._claim_finger(10)
	jump_button._finger = 11
	jump_button._claim_finger(11)
	jump_button._set_action(jump_button.action, 1.0)
	await get_tree().process_frame
	_check(Input.is_action_pressed(&"move_jump"), "Le saut peut être pressé pendant le déplacement")
	jump_button.cancel()
	await get_tree().process_frame
	_check(not Input.is_action_pressed(&"move_jump"), "Le relâchement du saut libère son action")
	_check(TouchControl.is_finger_claimed(10), "Le relâchement du saut ne libère pas le doigt du joystick")
	joystick._release_finger(10)
	joystick.free()
	jump_button.free()


func _test_mouse_filtering() -> void:
	var camera_pivot := CameraPivot.new()
	var emulated_motion := InputEventMouseMotion.new()
	emulated_motion.device = InputEvent.DEVICE_ID_EMULATION
	emulated_motion.screen_relative = Vector2(30.0, 15.0)
	var initial_rotation := camera_pivot.rotation
	camera_pivot._unhandled_input(emulated_motion)
	_check(camera_pivot.rotation.is_equal_approx(initial_rotation), "La souris émulée par le toucher est ignorée")

	var physical_motion := InputEventMouseMotion.new()
	physical_motion.device = InputEvent.DEVICE_ID_MOUSE
	physical_motion.screen_relative = Vector2(30.0, 15.0)
	camera_pivot._unhandled_input(physical_motion)
	_check(not camera_pivot.rotation.is_equal_approx(initial_rotation), "La souris physique conserve le contrôle de caméra")
	camera_pivot.free()


func _screen_drag(index: int, relative_motion: Vector2) -> InputEventScreenDrag:
	var drag := InputEventScreenDrag.new()
	drag.index = index
	drag.screen_relative = relative_motion
	return drag


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("TOUCH_CAMERA_TESTS_OK")
		get_tree().quit(0)
		return
	push_error("TOUCH_CAMERA_TESTS_FAILED: %d" % _failures.size())
	get_tree().quit(1)
