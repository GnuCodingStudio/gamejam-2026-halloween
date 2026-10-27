class_name TouchControl
extends Control
## Base of the on-screen controls: sends input actions and never leaves one stuck.

static var _claimed_fingers: Dictionary[int, bool] = {}


static func is_finger_claimed(index: int) -> bool:
	return _claimed_fingers.has(index)


func cancel() -> void:
	pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		cancel()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		cancel()


func _claim_finger(index: int) -> void:
	_claimed_fingers[index] = true


func _release_finger(index: int) -> void:
	_claimed_fingers.erase(index)


func _set_action(action: StringName, strength: float) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = strength > 0.0
	event.strength = strength
	Input.parse_input_event(event)
