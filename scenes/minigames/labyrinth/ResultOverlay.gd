class_name ResultOverlay
extends CanvasLayer

signal continue_pressed

const NEXT_LEVEL_TEXT := "Prochain labyrinthe"
const EXIT_TEXT := "Sortir dans la rue"

@onready var title_label: Label = %TitleLabel
@onready var candy_score_label: Label = %CandyScoreLabel
@onready var details_label: Label = %DetailsLabel
@onready var continue_button: Button = %ContinueButton


func _ready() -> void:
	continue_button.pressed.connect(continue_pressed.emit)


func show_win(extra_candies: int, is_last_level: bool, candy_amount: int = 0) -> void:
	var details := "+%d candies!" % extra_candies if extra_candies > 0 else ""
	show_result(
		"You escaped!",
		candy_amount,
		details,
		EXIT_TEXT if is_last_level else NEXT_LEVEL_TEXT
	)


func show_time_up(candy_amount: int = 0) -> void:
	show_result("Time's up!", candy_amount)


func show_result(
	title: String,
	candy_amount: int,
	details: String = "",
	button_text: String = EXIT_TEXT
) -> void:
	title_label.text = title
	candy_score_label.text = "CANDY : %d" % candy_amount
	details_label.text = details
	details_label.visible = not details.is_empty()
	continue_button.text = button_text
	_show()


func _show() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	continue_button.grab_focus()
