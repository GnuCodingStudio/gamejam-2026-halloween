extends Node3D


const LOBBY_SCENE_PATH: String = "res://scenes/levels/main.tscn"


func debug_finish() -> void:
	if SceneTransition.is_transition_active():
		return

	for world_id: StringName in ProgressionService.AVAILABLE_WORLD_IDS:
		ProgressionService.complete_world(world_id, 0)

	SceneTransition.change_scene(LOBBY_SCENE_PATH)
