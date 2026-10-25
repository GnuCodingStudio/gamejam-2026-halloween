class_name LabyrinthHud
extends CanvasLayer

const MESSAGE_DURATION := 2.0
const MESSAGE_FADE_DURATION := 0.5

var _message_tween: Tween

@onready var candy_label: Label = %CandyLabel
@onready var bonus_label: Label = %BonusLabel
@onready var time_label: Label = %TimeLabel
@onready var prompt_label: Label = %PromptLabel
@onready var message_label: Label = %MessageLabel


func set_candies(collected: int, total: int) -> void:
	candy_label.text = tr("CREDITS_LABYRINTH_CANDIES") % [collected, total]


func set_bonus_candies(total: int) -> void:
	bonus_label.text = tr("CREDITS_LABYRINTH_BONUS_CANDIES") % total


func set_time(seconds: float) -> void:
	var whole_seconds := ceili(seconds)
	var minutes := floori(whole_seconds / 60.0)
	time_label.text = "%d:%02d" % [minutes, whole_seconds % 60]


func show_prompt(should_show: bool) -> void:
	prompt_label.visible = should_show


func show_message(text: String) -> void:
	if _message_tween:
		_message_tween.kill()
	message_label.text = text
	message_label.modulate.a = 1.0
	message_label.visible = true
	_message_tween = create_tween()
	_message_tween.tween_interval(MESSAGE_DURATION)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, MESSAGE_FADE_DURATION)
	_message_tween.tween_callback(message_label.hide)
