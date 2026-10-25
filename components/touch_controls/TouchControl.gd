class_name TouchControl
extends Control
## Base of the on-screen controls: sends input actions and never leaves one stuck.


func cancel() -> void:
	pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		cancel()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		cancel()


func _set_action(action: StringName, strength: float) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = strength > 0.0
	event.strength = strength
	Input.parse_input_event(event)
