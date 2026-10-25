class_name TouchActionButton
extends TouchControl
## Round on-screen button which presses an input action while a finger is on it.
## It tracks its own finger, so it works together with the joystick (multi-touch).

enum Icon { TEXT, CHEVRON_UP }

const FILL_COLOR := Color(1.0, 1.0, 1.0, 0.18)
const PRESSED_FILL_COLOR := Color(1.0, 1.0, 1.0, 0.45)
const OUTLINE_COLOR := Color(1.0, 1.0, 1.0, 0.6)

@export var action: StringName
@export var label_text: String = ""
@export var icon: Icon = Icon.TEXT

var _finger: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _finger:
		get_viewport().set_input_as_handled()


func cancel() -> void:
	if _finger == -1:
		return
	_finger = -1
	_set_action(action, 0.0)
	queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var radius := size.x / 2.0
	draw_circle(center, radius, PRESSED_FILL_COLOR if _finger != -1 else FILL_COLOR)
	draw_arc(center, radius - 2.0, 0.0, TAU, 48, OUTLINE_COLOR, 4.0)
	if icon == Icon.CHEVRON_UP:
		_draw_chevron(center, radius * 0.4)
	else:
		_draw_label(center, radius)


func _on_touch(touch: InputEventScreenTouch) -> void:
	if touch.pressed and _finger == -1 and _contains(touch.position):
		_finger = touch.index
		_set_action(action, 1.0)
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif not touch.pressed and touch.index == _finger:
		cancel()
		get_viewport().set_input_as_handled()


func _contains(position_on_screen: Vector2) -> bool:
	var center := get_global_rect().get_center()
	return position_on_screen.distance_to(center) <= size.x / 2.0


func _draw_chevron(center: Vector2, half_width: float) -> void:
	var points := PackedVector2Array([
		center + Vector2(-half_width, half_width * 0.5),
		center + Vector2(0.0, -half_width * 0.5),
		center + Vector2(half_width, half_width * 0.5),
	])
	draw_polyline(points, Color.WHITE, 10.0)


func _draw_label(center: Vector2, radius: float) -> void:
	var font := get_theme_default_font()
	var font_size := int(radius * 0.8)
	var baseline := center + Vector2(-radius, font_size * 0.35)
	draw_string(font, baseline, label_text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size)
