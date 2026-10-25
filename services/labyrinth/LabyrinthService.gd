extends Node

signal time_up

const TOTAL_TIME: float = 600.0
const INTRO_TRACK: AudioStream = preload("res://assets/audio/labyrinthe01.mp3")
const ROTATION_TRACKS: Array[AudioStream] = [
	preload("res://assets/audio/labyrinthe02.mp3"),
	preload("res://assets/audio/labyrinthe03.mp3"),
	preload("res://assets/audio/labyrinthe04.mp3"),
	preload("res://assets/audio/labyrinthe05.mp3"),
]
const INTRO_VOLUME_DB: float = -14.0
const ROTATION_VOLUMES_DB: Array[float] = [-10.0, -14.0, -10.0, -11.0]

var bonus_candies: int = 0
var collected_candies: int = 0

var _timer: Timer = Timer.new()
var _music_player: AudioStreamPlayer = AudioStreamPlayer.new()
var _music_order: Array[int] = []
var _last_rotation_index: int = -1
var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_timer.one_shot = true
	_timer.timeout.connect(_on_time_up)
	add_child(_timer)
	_music_player.name = "LabyrinthMusic"
	_music_player.bus = &"Music"
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)
	_random.randomize()


#region logic

func reset() -> void:
	_timer.stop()
	_timer.paused = false
	bonus_candies = 0
	collected_candies = 0
	stop_music_session()


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


func add_collected_candies(amount: int) -> void:
	collected_candies += amount


func start_music_session() -> void:
	_music_order.clear()
	_last_rotation_index = -1
	_play_music(INTRO_TRACK, INTRO_VOLUME_DB)


func stop_music_session() -> void:
	_music_player.stop()
	_music_player.stream = null
	_music_order.clear()
	_last_rotation_index = -1


func is_music_playing() -> bool:
	return _music_player.playing


func current_music_path() -> String:
	if _music_player.stream == null:
		return ""
	return _music_player.stream.resource_path

#endregion logic


func _on_time_up() -> void:
	time_up.emit()


func _on_music_finished() -> void:
	if _music_order.is_empty():
		_refill_music_order()
	var track_index: int = _music_order.pop_back()
	_last_rotation_index = track_index
	_play_music(ROTATION_TRACKS[track_index], ROTATION_VOLUMES_DB[track_index])


func _refill_music_order() -> void:
	_music_order.assign(range(ROTATION_TRACKS.size()))
	for index: int in range(_music_order.size() - 1, 0, -1):
		var swap_index: int = _random.randi_range(0, index)
		var value: int = _music_order[index]
		_music_order[index] = _music_order[swap_index]
		_music_order[swap_index] = value
	if _last_rotation_index >= 0 and _music_order.back() == _last_rotation_index:
		var first_index: int = _music_order[0]
		_music_order[0] = _music_order.back()
		_music_order[_music_order.size() - 1] = first_index


func _play_music(stream: AudioStream, volume_db: float) -> void:
	_music_player.stream = stream
	_music_player.volume_db = volume_db
	_music_player.play()
