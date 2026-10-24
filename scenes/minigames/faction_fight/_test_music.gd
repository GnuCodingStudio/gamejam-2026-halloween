extends SceneTree

const SCENE_PATH := "res://scenes/minigames/faction_fight/FactionFight.tscn"
const MUSIC_PATH := "res://assets/audio/fantasy_V2.mp3"
const OLD_MUSIC_PATH := "res://assets/audio/fantasy-ambient_chaseween.mp3"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load(SCENE_PATH) as PackedScene
	_check(packed_scene != null, "La scène FactionFight se charge")
	if packed_scene == null:
		_finish()
		return

	var scene := packed_scene.instantiate() as Node3D
	var music := scene.get_node_or_null("ChaseweenMusic") as AudioStreamPlayer
	_check(music != null, "Le lecteur ChaseweenMusic existe")
	_check(music != null and music.stream != null and music.stream.resource_path == MUSIC_PATH, "Le lecteur référence fantasy_V2.mp3")
	root.add_child(scene)
	await process_frame
	await process_frame

	var local_music_players: Array[AudioStreamPlayer] = []
	for node: Node in scene.find_children("*", "AudioStreamPlayer", true, false):
		var player := node as AudioStreamPlayer
		if player != null and player.bus == &"Music":
			local_music_players.append(player)
	_check(local_music_players.size() == 1, "Un seul lecteur local utilise le bus Music")
	_check(music.playing, "La musique démarre automatiquement")
	_check(music.stream is AudioStreamMP3 and (music.stream as AudioStreamMP3).loop, "La boucle MP3 est active pendant l’exécution")
	_check(music.bus == &"Music" and is_equal_approx(music.volume_db, -12.0), "Le bus Music et le volume existant sont conservés")

	var runtime_stream_id := music.stream.get_instance_id()
	var gameplay := scene.get_node_or_null("FactionFightGameplay") as FactionFightGameplay
	gameplay._complete_mission(&"garden_reserve")
	await process_frame
	_check(music.playing and music.stream.get_instance_id() == runtime_stream_id, "Un changement de mission ne relance pas la musique")

	var scene_source := FileAccess.get_file_as_string(SCENE_PATH)
	_check(OLD_MUSIC_PATH not in scene_source, "L’ancienne musique n’est plus référencée dans la scène")
	scene.queue_free()
	await process_frame
	_check(not is_instance_valid(music), "Le lecteur est libéré avec la scène")
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failed = true
	push_error("FAIL: " + message)


func _finish() -> void:
	print("FACTION_FIGHT_MUSIC_TESTS_FAILED" if _failed else "FACTION_FIGHT_MUSIC_TESTS_OK")
	quit(1 if _failed else 0)
