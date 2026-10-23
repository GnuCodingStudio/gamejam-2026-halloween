class_name ResultOverlay
extends CanvasLayer

signal continue_pressed

@onready var extra_candies_label: Label = %ExtraCandiesLabel
@onready var continue_button: Button = %ContinueButton


func _ready() -> void:
	continue_button.pressed.connect(continue_pressed.emit)


func show_win(extra_candies: int) -> void:
	extra_candies_label.text = "+%d candies!" % extra_candies
	extra_candies_label.visible = extra_candies > 0
	visible = true
	continue_button.grab_focus()
