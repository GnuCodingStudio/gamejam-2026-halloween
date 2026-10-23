extends Node

const TOTAL_TIME := 600.0
const TIME_UP_SCENE := "res://scenes/levels/main.tscn"

var bonus_candies := 0

var _timer := Timer.new()


func _ready() -> void:
	_timer.one_shot = true
	_timer.timeout.connect(_on_time_up)
	add_child(_timer)


#region logic

func reset() -> void:
	_timer.stop()
	_timer.paused = false
	bonus_candies = 0


func resume() -> void:
	if _timer.is_stopped():
		_timer.start(TOTAL_TIME)
	else:
		_timer.paused = false


func pause() -> void:
	_timer.paused = true


func remaining_time() -> float:
	if _timer.is_stopped():
		return TOTAL_TIME
	return _timer.time_left


func add_bonus_candies(amount: int) -> void:
	bonus_candies += amount

#endregion logic


func _on_time_up() -> void:
	SceneTransition.change_scene(TIME_UP_SCENE)
