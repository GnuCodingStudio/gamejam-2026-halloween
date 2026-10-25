class_name LevelPortal
extends Node3D


const COMPLETED_TEXT: String = "LOBBY_PORTAL_COMPLETED"
const PULSE_MIN_ENERGY: float = 1.0
const PULSE_MAX_ENERGY: float = 3.0
const PULSE_DURATION: float = 1.0


@export_file("*.tscn") var target_scene_path: String
@export var prompt_text: String = "LOBBY_PORTAL_ENTER"
## Leave empty for a level that is never "completed" (it can be entered again and again).
@export var world_id: StringName = &""
## Leave empty if the player does not need to be placed at `ReturnSpawn` when coming back.
@export var return_meta: StringName = &""
@export_node_path("CharacterBody3D") var player_path: NodePath

var _player_is_near: bool = false
var _transition_started: bool = false
var _world_completed: bool = false
var _player: CharacterBody3D
var _light_tween: Tween

@onready var interaction_area: Area3D = %InteractionArea
@onready var light: OmniLight3D = %Light
@onready var prompt: Control = %Prompt
@onready var prompt_label: Label = %PromptLabel
@onready var return_spawn: Marker3D = %ReturnSpawn


func _ready() -> void:
    interaction_area.body_entered.connect(_on_body_entered)
    interaction_area.body_exited.connect(_on_body_exited)
    ProgressionService.world_progress_changed.connect(_on_world_progress_changed)
    prompt.hide()
    _refresh_progress_state()
    _resolve_player()
    _restore_player_after_return()


func _unhandled_input(event: InputEvent) -> void:
    if _transition_started or _world_completed or not _player_is_near:
        return
    if not event.is_action_pressed(&"action_activate"):
        return

    get_viewport().set_input_as_handled()
    _enter_level()


func _update_light() -> void:
    _stop_light_pulse()
    light.visible = not _world_completed
    if _world_completed:
        return

    _light_tween = create_tween().set_loops()
    _light_tween.tween_property(light, "light_energy", PULSE_MAX_ENERGY, PULSE_DURATION)
    _light_tween.tween_property(light, "light_energy", PULSE_MIN_ENERGY, PULSE_DURATION)


func _stop_light_pulse() -> void:
    if _light_tween != null and _light_tween.is_valid():
        _light_tween.kill()
    _light_tween = null


func _refresh_progress_state() -> void:
    var was_completed: bool = _world_completed
    _world_completed = ProgressionService.is_world_completed(world_id)
    prompt_label.text = tr(COMPLETED_TEXT if _world_completed else prompt_text)
    if _light_tween == null or _world_completed != was_completed:
        _update_light()


func _on_world_progress_changed(_completed_worlds: int, _available_worlds: int) -> void:
    _refresh_progress_state()


func _resolve_player() -> void:
    var player_node := get_node_or_null(player_path)
    if player_node is CharacterBody3D:
        _player = player_node as CharacterBody3D
        return

    push_error("Level portal could not resolve its CharacterBody3D player.")
    set_process_unhandled_input(false)


func _restore_player_after_return() -> void:
    if _player == null or return_meta.is_empty() or not get_tree().has_meta(return_meta):
        return

    _player.global_position = return_spawn.global_position
    _player.velocity = Vector3.ZERO
    get_tree().remove_meta(return_meta)


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


func _enter_level() -> void:
    if ProgressionService.is_world_completed(world_id):
        _refresh_progress_state()
        return

    if not SceneTransition.change_scene(target_scene_path):
        return

    _transition_started = true
    prompt.hide()
