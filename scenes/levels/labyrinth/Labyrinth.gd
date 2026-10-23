class_name Labyrinth
extends Node3D

const LOBBY_SCENE_PATH := "res://scenes/levels/main.tscn"
const LABYRINTH_WORLD_ID: StringName = &"labyrinth"

@export var extra_candies: int = 0
@export var next_level: PackedScene

var _total_candies := 0
var _collected_candies := 0

@onready var player: Player = %Player
@onready var exit_door: ExitDoor = %ExitDoor
@onready var hud: LabyrinthHud = %Hud
@onready var result_overlay: ResultOverlay = %ResultOverlay
@onready var collect_audio_player: AudioStreamPlayer = %CollectAudioPlayer


func _ready() -> void:
	_connect_candies()
	_connect_signals()
	hud.set_candies(_collected_candies, _total_candies)
	hud.set_bonus_candies(LabyrinthService.bonus_candies)
	hud.set_time(LabyrinthService.remaining_time())


func _process(_delta: float) -> void:
	hud.set_time(LabyrinthService.remaining_time())


#region setup

func _connect_candies() -> void:
	for node in get_tree().get_nodes_in_group("candy"):
		var candy := node as Candy
		candy.collected.connect(_on_candy_collected)
		_total_candies += 1


func _connect_signals() -> void:
	player.started_moving.connect(LabyrinthService.resume)
	exit_door.player_near.connect(hud.show_prompt)
	exit_door.use_requested.connect(_on_door_use_requested)
	result_overlay.continue_pressed.connect(_go_to_next_level)

#endregion setup

#region round

func _on_candy_collected() -> void:
	_collected_candies += 1
	collect_audio_player.play()
	hud.set_candies(_collected_candies, _total_candies)


func _on_door_use_requested() -> void:
	var missing_candies := _total_candies - _collected_candies
	if missing_candies > 0:
		hud.show_message("Candies missing: %d" % missing_candies)
	else:
		_win()


func _win() -> void:
	LabyrinthService.pause()
	LabyrinthService.add_bonus_candies(extra_candies)
	LabyrinthService.add_collected_candies(_collected_candies)
	hud.set_bonus_candies(LabyrinthService.bonus_candies)
	if next_level == null:
		var total_candies := LabyrinthService.collected_candies + LabyrinthService.bonus_candies
		ProgressionService.complete_world(LABYRINTH_WORLD_ID, total_candies)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	result_overlay.show_win(extra_candies)

#endregion round

#region navigation

func _go_to_next_level() -> void:
	get_tree().paused = false
	if next_level == null:
		SceneTransition.change_scene(LOBBY_SCENE_PATH)
	else:
		SceneTransition.change_scene(next_level.resource_path)

#endregion navigation
