extends Control

signal transition_finished()


@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var fade_screen: ColorRect = %FadeScreen

var _transition_active: bool = false


## Starts a protected scene change. The optional block runs on a fully black screen.
func change_scene(scene_path: String, at_black: Callable = Callable()) -> bool:
	if not _begin_transition():
		return false

	_change_scene_after_fade(scene_path, at_black)
	return true


## Runs an in-scene transition. Both callbacks run while the screen is black.
func run_fade(at_black: Callable, on_reveal: Callable = Callable()) -> bool:
	if not _begin_transition():
		return false

	_run_fade_sequence(at_black, on_reveal)
	return true


func is_transition_active() -> bool:
	return _transition_active


func _begin_transition() -> bool:
	if _transition_active:
		return false

	_transition_active = true
	fade_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	return true


func _change_scene_after_fade(scene_path: String, at_black: Callable) -> void:
	animation_player.play("fade_out")
	await animation_player.animation_finished
	_call_if_valid(at_black)

	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Unable to change scene to %s: %s" % [scene_path, error_string(error)])
		_finish_transition()
		return

	await get_tree().process_frame
	animation_player.play("fade_in")
	await animation_player.animation_finished
	_finish_transition()


func _run_fade_sequence(at_black: Callable, on_reveal: Callable) -> void:
	animation_player.play("fade_out")
	await animation_player.animation_finished
	_call_if_valid(at_black)
	await get_tree().process_frame
	_call_if_valid(on_reveal)
	animation_player.play("fade_in")
	await animation_player.animation_finished
	_finish_transition()


func _call_if_valid(callback: Callable) -> void:
	if callback.is_valid():
		callback.call()


func _finish_transition() -> void:
	_transition_active = false
	fade_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_finished.emit()
