class_name Labyrinth
extends Node3D

@export var extra_candies: int = 0
@export var next_level: PackedScene

var _total_candies := 0
var _collected_candies := 0

@onready var player: Player = %Player
@onready var exit_door: ExitDoor = %ExitDoor
@onready var hud: LabyrinthHud = %Hud
@onready var result_overlay: ResultOverlay = %ResultOverlay


func _ready() -> void:
	_connect_candies()
	_connect_signals()
	hud.set_candies(_collected_candies, _total_candies)
	hud.set_bonus_candies(RunService.bonus_candies)
	hud.set_time(RunService.remaining_time())


func _process(_delta: float) -> void:
	hud.set_time(RunService.remaining_time())


#region setup

func _connect_candies() -> void:
	for node in get_tree().get_nodes_in_group("candy"):
		var candy := node as Candy
		candy.collected.connect(_on_candy_collected)
		_total_candies += 1


func _connect_signals() -> void:
	player.started_moving.connect(RunService.resume)
	exit_door.player_near.connect(hud.show_prompt)
	exit_door.use_requested.connect(_on_door_use_requested)
	result_overlay.continue_pressed.connect(_go_to_next_level)

#endregion setup

#region round

func _on_candy_collected() -> void:
	_collected_candies += 1
	hud.set_candies(_collected_candies, _total_candies)


func _on_door_use_requested() -> void:
	var missing_candies := _total_candies - _collected_candies
	if missing_candies > 0:
		hud.show_message("Candies missing: %d" % missing_candies)
	else:
		_win()


func _win() -> void:
	RunService.pause()
	RunService.add_bonus_candies(extra_candies)
	hud.set_bonus_candies(RunService.bonus_candies)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	result_overlay.show_win(extra_candies)

#endregion round

#region navigation

func _go_to_next_level() -> void:
	if next_level == null:
		print("Last labyrinth finished")
		return
	get_tree().paused = false
	SceneTransition.change_scene(next_level.resource_path)

#endregion navigation
