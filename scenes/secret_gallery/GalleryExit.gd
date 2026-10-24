class_name GalleryExit
extends Node3D


const LOBBY_SCENE_PATH: String = "res://scenes/levels/main.tscn"
const LOBBY_RETURN_META: StringName = &"secret_gallery_return_to_lamp"
const PROMPT_TEXT: String = "E — RETOUR AU LOBBY"

@export_node_path("CharacterBody3D") var player_path: NodePath

@onready var interaction_area: Area3D = %InteractionArea
@onready var prompt: Control = %Prompt
@onready var prompt_label: Label = %PromptLabel

var _player: CharacterBody3D
var _player_is_near: bool = false
var _transition_started: bool = false


func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	prompt_label.text = PROMPT_TEXT
	prompt.hide()
	_resolve_player()


func _unhandled_input(event: InputEvent) -> void:
	if _transition_started or not _player_is_near or _text_field_has_focus():
		return
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	if not event.is_action_pressed(&"action_activate"):
		return

	get_viewport().set_input_as_handled()
	_return_to_lobby()


func _text_field_has_focus() -> bool:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	return focus_owner is LineEdit or focus_owner is TextEdit


func _return_to_lobby() -> void:
	if not SceneTransition.change_scene(LOBBY_SCENE_PATH, _mark_lobby_return):
		return
	_transition_started = true
	prompt.hide()


func _mark_lobby_return() -> void:
	get_tree().set_meta(LOBBY_RETURN_META, true)


func _resolve_player() -> void:
	var player_node: Node = get_node_or_null(player_path)
	if player_node is CharacterBody3D:
		_player = player_node as CharacterBody3D
		return
	push_error("Secret gallery exit could not resolve its player.")
	set_process_unhandled_input(false)


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
