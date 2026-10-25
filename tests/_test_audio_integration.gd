extends Node

const INTRO_PATH: String = "res://assets/audio/labyrinthe01.mp3"
const ROTATION_PATHS: Array[String] = [
	"res://assets/audio/labyrinthe02.mp3",
	"res://assets/audio/labyrinthe03.mp3",
	"res://assets/audio/labyrinthe04.mp3",
	"res://assets/audio/labyrinthe05.mp3",
]
const FACTION_SCENE_PATH: String = (
	"res://scenes/minigames/faction_territory/FactionTerritory.tscn"
)

var _failures: Array[String] = []


func _ready() -> void:
	await _run()


func _run() -> void:
	_test_audio_files()
	_test_labyrinth_playlist()
	await _test_faction_music()
	_test_scene_audio_configuration()
	_finish()


func _test_audio_files() -> void:
	for path: String in [INTRO_PATH] + ROTATION_PATHS + ["res://assets/audio/faction.mp3"]:
		_check(FileAccess.file_exists(path), "%s existe" % path.get_file())


func _test_labyrinth_playlist() -> void:
	var service: Node = get_tree().root.get_node("LabyrinthService")
	service.call(&"start_music_session")
	_check(service.call(&"current_music_path") == INTRO_PATH, "Le Labyrinthe commence par 01")
	var music_player: AudioStreamPlayer = service.get("_music_player") as AudioStreamPlayer
	_check(music_player.bus == &"Music", "La playlist utilise le bus Music")

	var first_cycle: Array[String] = []
	for _track: int in ROTATION_PATHS.size():
		service.call(&"_on_music_finished")
		first_cycle.append(service.call(&"current_music_path") as String)
	_check(_all_unique(first_cycle), "Le premier cycle 02-05 ne contient aucun doublon")
	_check(_same_members(first_cycle, ROTATION_PATHS), "Le premier cycle contient exactement 02-05")

	var last_path: String = first_cycle.back()
	service.call(&"_on_music_finished")
	_check(service.call(&"current_music_path") != last_path, "Deux cycles ne répètent pas immédiatement le même morceau")
	_check(service.call(&"current_music_path") != INTRO_PATH, "01 ne revient pas dans la rotation")

	service.call(&"stop_music_session")
	_check(not service.call(&"is_music_playing"), "La sortie arrête la playlist")
	_check((service.call(&"current_music_path") as String).is_empty(), "La sortie libère le flux du lecteur")
	service.call(&"start_music_session")
	_check(service.call(&"current_music_path") == INTRO_PATH, "Une nouvelle session revient à 01")
	service.call(&"stop_music_session")


func _test_faction_music() -> void:
	var packed_scene: PackedScene = load(FACTION_SCENE_PATH) as PackedScene
	_check(packed_scene != null, "Faction Territory reste chargeable")
	if packed_scene == null:
		return
	var scene: FactionTerritory = packed_scene.instantiate() as FactionTerritory
	var music: AudioStreamPlayer = scene.get_node("FactionMusic") as AudioStreamPlayer
	_check(music.stream.resource_path == "res://assets/audio/faction.mp3", "Faction Territory utilise faction.mp3")
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(music.bus == &"Music" and music.playing, "La musique de faction démarre sur Music")
	_check(music.stream is AudioStreamMP3 and (music.stream as AudioStreamMP3).loop, "La musique de faction boucle")
	_check(is_equal_approx(music.volume_db, -8.0), "Le gain mesuré de faction est appliqué")
	scene._exit_tree()
	_check(not music.playing, "La musique de faction s'arrête à la sortie")
	scene.queue_free()
	await get_tree().process_frame


func _test_scene_audio_configuration() -> void:
	var lobby: Node = _instantiate("res://scenes/levels/main.tscn")
	if lobby != null:
		var lobby_music: AudioStreamPlayer = lobby.get_node("LobbyMusic") as AudioStreamPlayer
		var finale_music: AudioStreamPlayer = lobby.get_node("CandyHUD/FinaleAudio") as AudioStreamPlayer
		_check(lobby_music.stream.resource_path.ends_with("music_lobby.mp3"), "Le lobby conserve music_lobby.mp3")
		_check(is_equal_approx(lobby_music.volume_db, 5.0), "Le gain mesuré du lobby est appliqué")
		_check(finale_music.stream.resource_path.ends_with("bilan_final.mp3"), "Le bilan conserve bilan_final.mp3")
		_check(is_equal_approx(finale_music.volume_db, -10.0), "Le gain mesuré du bilan est appliqué")
		lobby.free()

	var chaseween: Node = _instantiate("res://scenes/minigames/chaseween/Chaseween.tscn")
	if chaseween != null:
		var chaseween_music: AudioStreamPlayer = chaseween.get_node("ChaseweenMusic") as AudioStreamPlayer
		_check(chaseween_music.stream.resource_path.ends_with("fantasy_V2.mp3"), "Chaseween conserve fantasy_V2.mp3")
		_check(is_equal_approx(chaseween_music.volume_db, -12.0), "Le gain validé de Chaseween est conservé")
		chaseween.free()

	var labyrinth: Node = _instantiate("res://scenes/minigames/labyrinth/Labyrinth.tscn")
	var candy_bucket: Node = _instantiate("res://scenes/minigames/candy_bucket/CandyBucket.tscn")
	if labyrinth != null and candy_bucket != null:
		var labyrinth_collect: AudioStreamPlayer = labyrinth.get_node("CollectAudioPlayer") as AudioStreamPlayer
		var bucket_collect: AudioStreamPlayer = candy_bucket.get_node("CollectSfxPlayer") as AudioStreamPlayer
		_check(labyrinth_collect.stream.resource_path.ends_with("collect.wav"), "Le Labyrinthe conserve collect.wav")
		_check(bucket_collect.stream.resource_path == labyrinth_collect.stream.resource_path, "Candy Bucket partage le même collect.wav")
	if labyrinth != null:
		labyrinth.free()
	if candy_bucket != null:
		candy_bucket.free()


func _instantiate(path: String) -> Node:
	var packed_scene: PackedScene = load(path) as PackedScene
	_check(packed_scene != null, "%s charge" % path.get_file())
	if packed_scene == null:
		return null
	return packed_scene.instantiate()


func _all_unique(paths: Array[String]) -> bool:
	var seen: Dictionary[String, bool] = {}
	for path: String in paths:
		if seen.has(path):
			return false
		seen[path] = true
	return true


func _same_members(first: Array[String], second: Array[String]) -> bool:
	if first.size() != second.size():
		return false
	for path: String in first:
		if not second.has(path):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("Audio integration test passed.")
		get_tree().quit(0)
		return
	push_error("Audio integration test failed: %s" % ", ".join(_failures))
	get_tree().quit(1)
