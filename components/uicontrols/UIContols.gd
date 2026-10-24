extends Node

const UI_CLICK = preload("res://components/uicontrols/UI_Click.wav")
const UI_HOVER = preload("res://components/uicontrols/UI_Hover.wav")


func _ready() -> void:
	for child in get_parent().get_children():
		_bind_node(child)


func _bind_node(node: Node) -> void:
	if node is Button:
		_bind_button(node)
	elif node is CheckBox:
		_bind_checkbox(node)

	for child in node.get_children():
		_bind_node(child)


func _bind_button(button: Button) -> void:
	var ui_audio: Node = get_node_or_null("/root/UiAudio")
	if ui_audio == null:
		return
	var play_ui: Callable = Callable(ui_audio, &"play_ui")
	button.mouse_entered.connect(play_ui.bind(UI_HOVER))
	button.pressed.connect(play_ui.bind(UI_CLICK))


func _bind_checkbox(checkbox: CheckBox) -> void:
	var ui_audio: Node = get_node_or_null("/root/UiAudio")
	if ui_audio == null:
		return
	var play_ui: Callable = Callable(ui_audio, &"play_ui")
	checkbox.mouse_entered.connect(play_ui.bind(UI_HOVER))
	checkbox.pressed.connect(play_ui.bind(UI_CLICK))
