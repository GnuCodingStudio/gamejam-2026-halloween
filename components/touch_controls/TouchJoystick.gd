class_name TouchJoystick
extends TouchControl
## Floating joystick: appears where the thumb lands in the left part of the screen.

const REST_POSITION := Vector2(260.0, 820.0)
const RING_COLOR := Color(1.0, 1.0, 1.0, 0.35)
const KNOB_COLOR := Color(1.0, 1.0, 1.0, 0.45)
const HINT_COLOR := Color(1.0, 1.0, 1.0, 0.15)

@export_range(0.1, 1.0) var zone_width_ratio: float = 0.5
@export var radius: float = 110.0

var _finger: int = -1
var _origin: Vector2 = REST_POSITION
var _knob: Vector2 = REST_POSITION


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)


func cancel() -> void:
	if _finger == -1:
		return
	_finger = -1
	_send_direction(Vector2.ZERO)
	_origin = REST_POSITION
	_knob = REST_POSITION
	queue_redraw()


func _draw() -> void:
	if _finger == -1:
		draw_arc(_origin, radius, 0.0, TAU, 48, HINT_COLOR, 6.0)
		return
	draw_arc(_origin, radius, 0.0, TAU, 48, RING_COLOR, 6.0)
	draw_circle(_knob, radius * 0.4, KNOB_COLOR)


func _on_touch(touch: InputEventScreenTouch) -> void:
	if touch.pressed and _finger == -1 and _is_in_zone(touch.position):
		_finger = touch.index
		_origin = touch.position
		_knob = touch.position
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif not touch.pressed and touch.index == _finger:
		cancel()
		get_viewport().set_input_as_handled()


func _on_drag(drag: InputEventScreenDrag) -> void:
	if drag.index != _finger:
		return
	var offset := (drag.position - _origin).limit_length(radius)
	_knob = _origin + offset
	_send_direction(offset / radius)
	queue_redraw()
	get_viewport().set_input_as_handled()


func _is_in_zone(position_on_screen: Vector2) -> bool:
	return position_on_screen.x < get_viewport_rect().size.x * zone_width_ratio


func _send_direction(direction: Vector2) -> void:
	_update_action(&"move_left", maxf(-direction.x, 0.0))
	_update_action(&"move_right", maxf(direction.x, 0.0))
	_update_action(&"move_up", maxf(-direction.y, 0.0))
	_update_action(&"move_down", maxf(direction.y, 0.0))


func _update_action(action: StringName, strength: float) -> void:
	if not is_equal_approx(Input.get_action_raw_strength(action), strength):
		_set_action(action, strength)
