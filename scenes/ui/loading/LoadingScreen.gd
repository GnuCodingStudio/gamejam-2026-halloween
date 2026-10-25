class_name LoadingScreen
extends Control


const MESSAGE_COLOR: Color = Color("f4efe8")
const ERROR_COLOR: Color = Color("ff9b73")
const DOT_SPEED: float = 3.2
const DOT_PHASE_OFFSET: float = 0.75

@onready var progress_bar: ProgressBar = %ProgressBar
@onready var message_label: Label = %MessageLabel
@onready var dots: Array[Control] = [%DotOrange, %DotViolet, %DotCream]

var _elapsed: float = 0.0


func _ready() -> void:
	hide_loading()


func _process(delta: float) -> void:
	_elapsed += delta
	for index: int in range(dots.size()):
		var wave: float = sin(_elapsed * DOT_SPEED - float(index) * DOT_PHASE_OFFSET)
		var opacity: float = remap(wave, -1.0, 1.0, 0.28, 1.0)
		dots[index].modulate.a = opacity


func show_loading(message: String) -> void:
	message_label.text = message
	message_label.add_theme_color_override(&"font_color", MESSAGE_COLOR)
	progress_bar.show()
	progress_bar.indeterminate = true
	progress_bar.value = 0.0
	_elapsed = 0.0
	_reset_dots()
	mouse_filter = Control.MOUSE_FILTER_STOP
	show()
	set_process(true)


func set_progress(ratio: float) -> void:
	progress_bar.show()
	progress_bar.indeterminate = false
	progress_bar.value = clampf(ratio, 0.0, 1.0) * progress_bar.max_value


func set_indeterminate() -> void:
	progress_bar.show()
	progress_bar.indeterminate = true


func show_error(message: String) -> void:
	message_label.text = message
	message_label.add_theme_color_override(&"font_color", ERROR_COLOR)
	progress_bar.hide()
	set_process(false)
	for dot: Control in dots:
		dot.modulate.a = 0.35


func hide_loading() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func _reset_dots() -> void:
	for dot: Control in dots:
		dot.modulate.a = 1.0
