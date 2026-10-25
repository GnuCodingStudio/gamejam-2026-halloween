class_name ChurchFinaleInteractor
extends Node3D


const PROMPT_TEXT: String = "E — CONSULTER MON BILAN"
const LIGHT_MIN_ENERGY: float = 5.0
const LIGHT_MAX_ENERGY: float = 12.5
const LIGHT_PULSE_DURATION: float = 2.0

@export_node_path("CharacterBody3D") var player_path: NodePath
@export_node_path("CanvasLayer") var hud_path: NodePath

@onready var interaction_area: Area3D = %InteractionArea
@onready var light: OmniLight3D = %Light
@onready var prompt: Control = %Prompt
@onready var prompt_label: Label = %PromptLabel

var _available: bool = false
var _opening: bool = false
var _player_is_near: bool = false
var _player: CharacterBody3D
var _hud: LobbyCandyHud
var _light_tween: Tween


func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	ProgressionService.world_progress_changed.connect(_on_world_progress_changed)
	prompt_label.text = PROMPT_TEXT
	prompt.hide()
	_resolve_dependencies()
	_update_availability()


func _unhandled_input(event: InputEvent) -> void:
	if not _available or not _player_is_near or _opening:
		return
	if not event.is_action_pressed(&"action_activate"):
		return

	get_viewport().set_input_as_handled()
	_opening = _hud != null and _hud.open_finale()
	if _opening:
		prompt.hide()


func _resolve_dependencies() -> void:
	var player_node: Node = get_node_or_null(player_path)
	if player_node is CharacterBody3D:
		_player = player_node as CharacterBody3D
	else:
		push_error("Church finale interaction could not resolve its player.")
		set_process_unhandled_input(false)

	var hud_node: Node = get_node_or_null(hud_path)
	if hud_node is LobbyCandyHud:
		_hud = hud_node as LobbyCandyHud
		_hud.finale_closed.connect(_on_finale_closed)
	else:
		push_error("Church finale interaction could not resolve LobbyCandyHud.")
		set_process_unhandled_input(false)


func _update_availability() -> void:
	_available = ProgressionService.are_all_worlds_completed()
	light.visible = _available
	if _available:
		_start_light_pulse()
	else:
		_stop_light_pulse()
	prompt.visible = _available and _player_is_near and not _opening


func _start_light_pulse() -> void:
	if _light_tween != null and _light_tween.is_valid():
		return
	light.light_energy = LIGHT_MIN_ENERGY
	_light_tween = create_tween().set_loops()
	_light_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_light_tween.tween_property(light, "light_energy", LIGHT_MAX_ENERGY, LIGHT_PULSE_DURATION)
	_light_tween.tween_property(light, "light_energy", LIGHT_MIN_ENERGY, LIGHT_PULSE_DURATION)


func _stop_light_pulse() -> void:
	if _light_tween != null and _light_tween.is_valid():
		_light_tween.kill()
	_light_tween = null
	light.light_energy = LIGHT_MIN_ENERGY


func _on_world_progress_changed(_completed_worlds: int, _available_worlds: int) -> void:
	_update_availability()


func _on_body_entered(body: Node3D) -> void:
	if body != _player:
		return
	_player_is_near = true
	prompt.visible = _available and not _opening


func _on_body_exited(body: Node3D) -> void:
	if body != _player:
		return
	_player_is_near = false
	prompt.hide()


func _on_finale_closed() -> void:
	_opening = false
	prompt.visible = _available and _player_is_near
