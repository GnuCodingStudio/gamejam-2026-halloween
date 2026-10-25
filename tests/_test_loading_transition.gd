extends Node


const TARGET_SCENE_PATH: String = "res://scenes/menus/main/MainMenu.tscn"
const INVALID_SCENE_PATH: String = "res://tests/scene_that_does_not_exist.tscn"
const TIMEOUT_SECONDS: float = 8.0

var _failed: bool = false


func _ready() -> void:
	_move_to_autoload_and_run.call_deferred()


func _move_to_autoload_and_run() -> void:
	# Keep the test alive when SceneTree replaces the current scene.
	reparent(SceneTransition)
	_run()


func _run() -> void:
	if SceneTransition.is_transition_active():
		await SceneTransition.transition_finished

	var started: bool = SceneTransition.change_scene(TARGET_SCENE_PATH)
	_check(started, "La transition asynchrone démarre")
	if not started:
		_finish()
		return

	var completed: bool = await _wait_for_transition()
	_check(completed, "La transition se termine avant le délai")
	_check(
		get_tree().current_scene != null
		and get_tree().current_scene.scene_file_path == TARGET_SCENE_PATH,
		"La scène chargée devient la scène courante"
	)
	_check(not SceneTransition.loading_screen.visible, "L'écran de chargement est masqué")

	var valid_scene: Node = get_tree().current_scene
	started = SceneTransition.change_scene(INVALID_SCENE_PATH)
	_check(started, "Une destination invalide déclenche la gestion d'erreur")
	completed = await _wait_for_transition()
	_check(completed, "La gestion d'erreur se termine avant le délai")
	_check(get_tree().current_scene == valid_scene, "La dernière scène valide est conservée")
	_check(not SceneTransition.loading_screen.visible, "L'erreur ne laisse pas l'écran bloqué")
	_finish()


func _wait_for_transition() -> bool:
	var timeout: SceneTreeTimer = get_tree().create_timer(TIMEOUT_SECONDS, true)
	while SceneTransition.is_transition_active() and timeout.time_left > 0.0:
		await get_tree().process_frame
	return not SceneTransition.is_transition_active()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failed = true
	push_error("FAIL: %s" % description)


func _finish() -> void:
	get_tree().quit(1 if _failed else 0)
