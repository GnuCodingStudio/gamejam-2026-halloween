class_name Door5CandyBucketPortal
extends Node3D


const CANDY_BUCKET_SCENE_PATH: String = (
    "res://scenes/minigames/candy_bucket/CandyBucket.tscn"
)
const LOBBY_RETURN_META: StringName = &"candy_bucket_return_to_door5"
const MINIGAME_ID: StringName = &"candy_bucket"


@export_node_path("CharacterBody3D") var player_path: NodePath

var _player_is_near: bool = false
var _transition_started: bool = false
var _world_completed: bool = false
var _player: CharacterBody3D

@onready var interaction_area: Area3D = %InteractionArea
@onready var prompt: Control = %Prompt
@onready var prompt_label: Label = %PromptLabel
@onready var return_spawn: Marker3D = %ReturnSpawn


func _ready() -> void:
    interaction_area.body_entered.connect(_on_body_entered)
    interaction_area.body_exited.connect(_on_body_exited)
    _world_completed = ProgressionService.is_world_completed(MINIGAME_ID)
    prompt_label.text = "MONDE TERMINÉ" if _world_completed else "E — Candy Bucket"
    prompt.hide()
    _resolve_player()
    _restore_player_after_minigame()


func _unhandled_input(event: InputEvent) -> void:
    if _transition_started or _world_completed or not _player_is_near:
        return
    if not event.is_action_pressed(&"action_activate"):
        return

    get_viewport().set_input_as_handled()
    _enter_candy_bucket()


func _resolve_player() -> void:
    var player_node := get_node_or_null(player_path)
    if player_node is CharacterBody3D:
        _player = player_node as CharacterBody3D
        return

    push_error("Door5 portal could not resolve its CharacterBody3D player.")
    set_process_unhandled_input(false)


func _restore_player_after_minigame() -> void:
    if _player == null or not get_tree().has_meta(LOBBY_RETURN_META):
        return

    _player.global_position = return_spawn.global_position
    _player.velocity = Vector3.ZERO
    get_tree().remove_meta(LOBBY_RETURN_META)


func _on_body_entered(body: Node3D) -> void:
    if body != _player or _transition_started:
        return

    _player_is_near = true
    prompt.show()


func _on_body_exited(body: Node3D) -> void:
    if body != _player:
        return

    _player_is_near = false
    prompt.hide()


func _enter_candy_bucket() -> void:
    if ProgressionService.is_world_completed(MINIGAME_ID):
        _world_completed = true
        prompt_label.text = "MONDE TERMINÉ"
        return

    _transition_started = true
    prompt.hide()
    var error := get_tree().change_scene_to_file(CANDY_BUCKET_SCENE_PATH)
    if error != OK:
        _transition_started = false
        push_error("Unable to enter Candy Bucket: %s" % error_string(error))
