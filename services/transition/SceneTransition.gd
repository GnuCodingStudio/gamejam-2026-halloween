extends Control

signal transition_finished()


const STARTUP_MESSAGE: String = "Préparation de l'aventure…"
const LOAD_ERROR_MESSAGE: String = "Le chargement a rencontré un problème."
const ERROR_NOTICE_DURATION: float = 1.8
const DESTINATION_MESSAGES: Dictionary[String, String] = {
	"res://scenes/menus/main/MainMenu.tscn": "Préparation de l'aventure…",
	"res://scenes/levels/main.tscn": "Retour dans le village…",
	"res://scenes/minigames/candy_bucket/CandyBucket.tscn": "Les bonbons arrivent…",
	"res://scenes/minigames/labyrinth/Level01.tscn": "Ouverture du labyrinthe…",
	"res://scenes/minigames/labyrinth/Level02.tscn": "Ouverture du labyrinthe…",
	"res://scenes/minigames/labyrinth/Level03.tscn": "Ouverture du labyrinthe…",
	"res://scenes/minigames/faction_fight/Chaseween.tscn": "Le royaume des sucreries vous attend…",
	"res://scenes/minigames/faction_territory/FactionTerritory.tscn": "Préparation du prochain défi…",
	"res://scenes/secret_gallery/SecretGallery.tscn": "Ouverture des souvenirs…",
}


@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var fade_screen: ColorRect = %FadeScreen
@onready var loading_screen: LoadingScreen = %LoadingScreen

var _transition_active: bool = false
var _startup_visible: bool = true


func _ready() -> void:
	fade_screen.color = Color.BLACK
	loading_screen.show_loading(STARTUP_MESSAGE)
	_reveal_initial_scene.call_deferred()


## Starts a protected scene change. The optional block runs on a fully black screen.
func change_scene(scene_path: String, at_black: Callable = Callable()) -> bool:
	if not _begin_transition():
		return false

	_change_scene_after_fade(scene_path, at_black)
	return true


## Runs an in-scene transition. Both callbacks run while the screen is black.
func run_fade(at_black: Callable, on_reveal: Callable = Callable()) -> bool:
	if not _begin_transition():
		return false

	_run_fade_sequence(at_black, on_reveal)
	return true


func is_transition_active() -> bool:
	return _transition_active


func _begin_transition() -> bool:
	if _transition_active:
		return false

	_dismiss_startup_screen()
	_transition_active = true
	fade_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	return true


func _change_scene_after_fade(scene_path: String, at_black: Callable) -> void:
	animation_player.play("fade_out")
	await animation_player.animation_finished
	_call_if_valid(at_black)
	loading_screen.show_loading(_message_for(scene_path))

	var request_error: Error = ResourceLoader.load_threaded_request(scene_path, "PackedScene")
	if request_error != OK:
		await _recover_from_load_error(scene_path, request_error)
		return

	await get_tree().process_frame
	await _wait_for_scene(scene_path)


func _wait_for_scene(scene_path: String) -> void:
	var progress: Array = []
	while true:
		progress.clear()
		var status: int = ResourceLoader.load_threaded_get_status(scene_path, progress)
		match status:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				_update_progress(progress)
				await get_tree().process_frame
			ResourceLoader.THREAD_LOAD_LOADED:
				await _activate_loaded_scene(scene_path)
				return
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				await _recover_from_load_error(scene_path, ERR_CANT_ACQUIRE_RESOURCE)
				return
			_:
				await _recover_from_load_error(scene_path, ERR_BUG)
				return


func _update_progress(progress: Array) -> void:
	if progress.is_empty():
		loading_screen.set_indeterminate()
		return

	var ratio: float = clampf(float(progress[0]), 0.0, 0.99)
	loading_screen.set_progress(ratio)


func _activate_loaded_scene(scene_path: String) -> void:
	var resource: Resource = ResourceLoader.load_threaded_get(scene_path)
	if not resource is PackedScene:
		await _recover_from_load_error(scene_path, ERR_FILE_CORRUPT)
		return

	loading_screen.set_progress(1.0)
	var packed_scene: PackedScene = resource as PackedScene
	var error: Error = get_tree().change_scene_to_packed(packed_scene)
	if error != OK:
		await _recover_from_load_error(scene_path, error)
		return

	await get_tree().process_frame
	loading_screen.hide_loading()
	animation_player.play("fade_in")
	await animation_player.animation_finished
	_finish_transition()


func _recover_from_load_error(scene_path: String, error: Error) -> void:
	push_error("Unable to load scene %s: %s" % [scene_path, error_string(error)])
	loading_screen.show_error(LOAD_ERROR_MESSAGE)
	await get_tree().create_timer(ERROR_NOTICE_DURATION, true).timeout
	loading_screen.hide_loading()
	animation_player.play("fade_in")
	await animation_player.animation_finished
	_finish_transition()


func _reveal_initial_scene() -> void:
	await get_tree().process_frame
	_dismiss_startup_screen()


func _dismiss_startup_screen() -> void:
	if not _startup_visible:
		return
	_startup_visible = false
	loading_screen.hide_loading()
	fade_screen.color = Color(0.0, 0.0, 0.0, 0.0)


func _run_fade_sequence(at_black: Callable, on_reveal: Callable) -> void:
	animation_player.play("fade_out")
	await animation_player.animation_finished
	_call_if_valid(at_black)
	await get_tree().process_frame
	_call_if_valid(on_reveal)
	animation_player.play("fade_in")
	await animation_player.animation_finished
	_finish_transition()


func _call_if_valid(callback: Callable) -> void:
	if callback.is_valid():
		callback.call()


func _message_for(scene_path: String) -> String:
	return DESTINATION_MESSAGES.get(scene_path, STARTUP_MESSAGE)


func _finish_transition() -> void:
	_transition_active = false
	fade_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_finished.emit()
