class_name SecretGalleryEntrance
extends Node3D


const REQUIRED_PRESS_COUNT: int = 5
const LOBBY_RETURN_META: StringName = &"secret_gallery_return_to_lamp"
const PULSE_DURATION: float = 0.18

@export_file("*.tscn") var target_scene_path: String = "res://scenes/secret_gallery/SecretGallery.tscn"
@export_node_path("CharacterBody3D") var player_path: NodePath

@onready var interaction_area: Area3D = %InteractionArea
@onready var secret_light: OmniLight3D = %SecretLight
@onready var return_spawn: Marker3D = %ReturnSpawn

var _player: CharacterBody3D
var _player_is_near: bool = false
var _accepting_input: bool = true
var _transition_started: bool = false
var _press_count: int = 0
var _pulse_tween: Tween


func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	secret_light.light_energy = 0.0
	_resolve_player()
	_restore_player_after_gallery()


func _process(_delta: float) -> void:
	if not _transition_started and _press_count > 0 and _text_field_has_focus():
		_reset_sequence()
	if not _accepting_input and not Input.is_action_pressed(&"action_activate"):
		_accepting_input = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and not _transition_started and _press_count > 0:
		_reset_sequence()


func _unhandled_input(event: InputEvent) -> void:
	if not _can_count_press(event):
		return

	get_viewport().set_input_as_handled()
	_count_press()


func _can_count_press(event: InputEvent) -> bool:
	if not _accepting_input or _transition_started or not _player_is_near:
		return false
	if _text_field_has_focus():
		return false
	if event is InputEventKey and (event as InputEventKey).echo:
		return false
	return event.is_action_pressed(&"action_activate")


func _text_field_has_focus() -> bool:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	return focus_owner is LineEdit or focus_owner is TextEdit


func _count_press() -> void:
	_press_count += 1
	if _press_count < REQUIRED_PRESS_COUNT:
		_play_secret_pulse(_press_count)
		return
	_open_gallery()


func _play_secret_pulse(press_count: int) -> void:
	_stop_pulse()
	var peak_energy: float = lerpf(0.55, 1.35, float(press_count) / REQUIRED_PRESS_COUNT)
	secret_light.light_energy = 0.0
	_pulse_tween = create_tween()
	_pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(secret_light, "light_energy", peak_energy, PULSE_DURATION * 0.45)
	_pulse_tween.tween_property(secret_light, "light_energy", 0.0, PULSE_DURATION)


func _open_gallery() -> void:
	_transition_started = true
	_stop_pulse()
	secret_light.light_energy = 0.0
	_pulse_tween = create_tween()
	_pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(secret_light, "light_energy", 3.0, 0.12)
	_pulse_tween.tween_property(secret_light, "light_energy", 0.0, 0.20)
	await _pulse_tween.finished
	if not SceneTransition.change_scene(target_scene_path):
		_transition_started = false
		_reset_sequence()


func _stop_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null


func _reset_sequence() -> void:
	_press_count = 0
	_stop_pulse()
	secret_light.light_energy = 0.0


func _resolve_player() -> void:
	var player_node: Node = get_node_or_null(player_path)
	if player_node is CharacterBody3D:
		_player = player_node as CharacterBody3D
		return
	push_error("Secret gallery entrance could not resolve its player.")
	set_process_unhandled_input(false)


func _restore_player_after_gallery() -> void:
	if _player == null or not get_tree().has_meta(LOBBY_RETURN_META):
		return
	_player.global_position = return_spawn.global_position
	_player.rotation.y = return_spawn.global_rotation.y
	_player.velocity = Vector3.ZERO
	get_tree().remove_meta(LOBBY_RETURN_META)
	_accepting_input = false
	_reset_sequence()


func _on_body_entered(body: Node3D) -> void:
	if body != _player or _transition_started:
		return
	_player_is_near = true


func _on_body_exited(body: Node3D) -> void:
	if body != _player:
		return
	_player_is_near = false
	if _transition_started:
		return
	_reset_sequence()
