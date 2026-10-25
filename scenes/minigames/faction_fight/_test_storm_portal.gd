extends SceneTree

const SCENE_PATH := "res://scenes/minigames/faction_fight/Chaseween.tscn"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "FactionFight.tscn charge avec le portail et l’orage")
	if packed == null:
		_finish()
		return
	var scene := packed.instantiate() as FactionFightEnvironment
	root.add_child(scene)
	await process_frame
	await process_frame
	var gameplay := scene.get_node("FactionFightGameplay") as FactionFightGameplay
	gameplay.set_process(false)
	_test_portal_alignment(gameplay)
	_test_audio(scene)
	await _test_storm_phases(scene)
	_test_fog_and_timing(gameplay)
	scene.queue_free()
	await process_frame
	await physics_frame
	_finish()


func _test_portal_alignment(gameplay: FactionFightGameplay) -> void:
	var objective_point := gameplay._portal.get_node_or_null("ObjectivePoint") as Marker3D
	var interaction_point := gameplay._portal.get_node_or_null("InteractionPoint") as Marker3D
	_check(objective_point != null, "Le portail possède un ancrage visuel explicite")
	_check(interaction_point != null, "Le portail possède un point d’interaction explicite")
	if objective_point == null or interaction_point == null:
		return
	_check(objective_point.global_position.is_equal_approx(gameplay._portal.global_position), "Le repère visuel est centré au sol sous le portail")
	_check(interaction_point.position.is_equal_approx(Vector3(0.0, 0.5, 2.4)), "La zone interactive est centrée devant la façade du portail")
	gameplay._mission_index = FactionFightGameplay.MISSIONS.size()
	gameplay._refresh_mission()
	_check(gameplay._mission_target().is_equal_approx(objective_point.global_position), "Le guidage final vise le portail visible")
	_check(gameplay._objective_marker.global_position.is_equal_approx(objective_point.global_position), "Le halo final est placé sous le portail visible")
	gameplay._player.global_position = interaction_point.global_position
	gameplay._update_interaction_prompt()
	_check(gameplay._is_player_near_portal(), "Le joueur peut interagir devant le portail")
	_check(gameplay._hud._prompt_action_label.text == "QUITTER CHASEWEEN", "Le message E est affiché devant le portail")
	_check(not gameplay._completed, "La proximité seule ne termine pas la partie")
	gameplay._player.global_position = gameplay._portal.global_position
	gameplay._update_interaction_prompt()
	_check(not gameplay._is_player_near_portal(), "Le pivot situé derrière le plan visible n’active plus la sortie")
	gameplay._player.global_position = gameplay._portal.to_global(Vector3(3.2, 0.5, 2.4))
	_check(not gameplay._is_player_near_portal(), "Un décalage latéral incohérent n’active pas la sortie")
	gameplay._player.global_position = gameplay._portal.to_global(Vector3(0.0, 0.5, -1.0))
	_check(not gameplay._is_player_near_portal(), "Le portail ne peut pas être activé depuis l’arrière")


func _test_audio(environment: FactionFightEnvironment) -> void:
	var storm_players := environment.find_children("ChaseweenStormAudio", "AudioStreamPlayer", true, false)
	_check(storm_players.size() == 1, "Un seul lecteur d’orage local existe")
	_check(environment.storm_audio != null and environment.storm_audio.bus == &"SFX", "Le tonnerre utilise le bus SFX")
	var stream := environment.storm_audio.stream as AudioStreamMP3
	_check(stream != null and stream.get_length() >= 14.0 and stream.get_length() <= 16.0, "orage.mp3 est un effet court d’environ quinze secondes")
	_check(stream != null and not stream.loop, "Le tonnerre ponctuel n’est pas bouclé")
	_check(environment.music != null and environment.music.bus == &"Music" and environment.music.playing, "fantasy_V2.mp3 continue sur le bus Music")


func _test_storm_phases(environment: FactionFightEnvironment) -> void:
	var intensities: Array[float] = [0.0, 0.34, 0.68, 1.0]
	var minimum_delays: Array[float] = [22.0, 13.0, 7.0, 3.8]
	var maximum_delays: Array[float] = [32.0, 21.0, 12.0, 7.0]
	var volumes: Array[float] = [-80.0, -22.0, -15.0, -11.0]
	for phase: int in 4:
		environment.set_storm_phase(phase)
		_check(is_equal_approx(environment._storm_intensity, intensities[phase]), "La phase %d applique son intensité d’éclair" % (phase + 1))
		_check(is_equal_approx(environment.lightning_delay_min, minimum_delays[phase]) and is_equal_approx(environment.lightning_delay_max, maximum_delays[phase]), "La phase %d applique sa cadence irrégulière" % (phase + 1))
		_check(is_equal_approx(environment._storm_volume_db, volumes[phase]), "La phase %d applique son niveau de tonnerre" % (phase + 1))
	_check(environment._lightning_visuals.get_child_count() == 2, "Deux silhouettes d’éclairs légères sont réutilisées")
	for child: Node in environment._lightning_visuals.get_children():
		var bolt := child as MeshInstance3D
		_check(bolt != null and bolt.mesh.get_surface_count() == 1, "%s tient dans une seule surface" % child.name)
		_check(bolt != null and bolt.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s ne projette pas d’ombre" % child.name)
	environment.set_storm_phase(0)
	environment._flash_lightning()
	_check(not environment._lightning_visuals.visible, "La phase calme ne produit aucun flash")
	environment.set_storm_phase(3)
	environment._flash_lightning()
	_check(environment._lightning_visuals.visible, "La phase finale affiche les silhouettes d’éclair")
	var maximum_energy := environment.lightning.light_energy
	for sample: int in 18:
		await process_frame
		maximum_energy = maxf(maximum_energy, environment.lightning.light_energy)
	_check(maximum_energy > 3.0, "Le flash final éclaire nettement l’environnement")
	await create_timer(0.5).timeout
	_check(not environment._lightning_visuals.visible and environment.lightning.light_energy < 0.05, "L’éclairage normal est restauré après deux pulsations courtes")
	environment.stop_storm()
	_check(not environment.storm_audio.playing and is_equal_approx(environment.storm_audio.volume_db, -80.0), "Le son d’orage s’arrête proprement à la fin")


func _test_fog_and_timing(gameplay: FactionFightGameplay) -> void:
	var environment := gameplay._world_environment.environment
	var initial_density := gameplay._base_fog_density
	gameplay._session_time = 119.9
	gameplay._update_corruption(0.1)
	_check(environment.fog_enabled and environment.fog_density >= initial_density, "Le brouillard est conservé pendant l’orage")
	_check(is_equal_approx(FactionFightGameplay.SESSION_DURATION, 240.0), "La durée maximale est fixée à 240 secondes")
	_check(gameplay._corruption_phase_name(0.0) != gameplay._corruption_phase_name(60.0) and gameplay._corruption_phase_name(120.0) != gameplay._corruption_phase_name(180.0), "Les quatre phases de soixante secondes sont conservées")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("FACTION_FIGHT_STORM_PORTAL_TESTS_OK")
		quit(0)
		return
	print("FACTION_FIGHT_STORM_PORTAL_TESTS_FAILED: %d" % _failures.size())
	quit(1)
