class_name FactionTerritoryResultOverlay
extends CanvasLayer

signal continue_pressed

@onready var _candies_label: Label = %CandiesLabel
@onready var _continue_button: Button = %ContinueButton


func _ready() -> void:
	_continue_button.pressed.connect(continue_pressed.emit)


func show_result(candies: int) -> void:
	_candies_label.text = "Candies: %d" % candies
	visible = true
	_continue_button.grab_focus()
