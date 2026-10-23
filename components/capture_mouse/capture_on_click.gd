extends Node


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"exit"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var buttonEvent := event as InputEventMouseButton
		var isFocused := not get_window().has_focus() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
		if buttonEvent.is_pressed() and isFocused:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_window().grab_focus()


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
