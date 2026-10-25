extends Node

const LOBBY_SCENE_PATH: String = "res://scenes/levels/main.tscn"
const CHASEWEEN_SCENE_PATH: String = "res://scenes/minigames/faction_fight/Chaseween.tscn"
const CHASEWEEN_WORLD_ID: StringName = &"chaseween"
const CHASEWEEN_PORTAL_POSITION: Vector3 = Vector3(-6.483225, 0.3572799, 20.4333)
const RESULT_OVERLAY_PATH: String = "res://scenes/minigames/labyrinth/ResultOverlay.tscn"
const HUD_SCRIPT: Script = preload("res://scenes/minigames/faction_fight/gameplay/FactionFightHUD.gd")

var _failures: Array[String] = []
var _progression_service: Node
var _original_progression: Progression


func _ready() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_progression_service = get_tree().root.get_node_or_null("ProgressionService")
	_check(_progression_service != null, "ProgressionService est disponible")
	if _progression_service == null:
		_finish()
		return
	_original_progression = _progression_service.get("data") as Progression
	_progression_service.set("data", Progression.new())
	await _test_lobby_portal()
	await _test_completed_portal_and_hud()
	await _test_shared_results_and_audio()
	_test_single_score_credit()
	await _test_summary_button_geometry()
	_progression_service.set("data", _original_progression)
	_finish()


func _test_lobby_portal() -> void:
	var packed := load(LOBBY_SCENE_PATH) as PackedScene
	_check(packed != null, "Le lobby charge avec la porte CHASEWEEN")
	if packed == null:
		return
	var lobby := packed.instantiate()
	get_tree().root.add_child(lobby)
	await get_tree().process_frame
	var portal := lobby.get_node_or_null("ChaseweenPortal") as LevelPortal
	_check(portal != null, "La porte libre de house2 est attribuée à CHASEWEEN")
	if portal != null:
		_check(portal.target_scene_path == CHASEWEEN_SCENE_PATH, "La porte charge la scène CHASEWEEN officielle")
		_check(portal.prompt_text == "E - CHASEWEEN", "Le nom CHASEWEEN est affiché par le prompt existant")
		_check(portal.world_id == CHASEWEEN_WORLD_ID, "La porte utilise l’identifiant de progression CHASEWEEN")
		_check(portal.return_meta == &"chaseween_return_to_door", "Le retour cible la même porte du lobby")
		_check(portal.light.visible, "La lumière existante signale le monde disponible")
		_check(portal.global_position.is_equal_approx(CHASEWEEN_PORTAL_POSITION), "Le portail interactif est aligné devant house2/door")
		_check(portal.global_basis.z.dot(Vector3.BACK) < -0.99, "Le retour CHASEWEEN est orienté vers la rue")
		var house_door := lobby.get_node_or_null("CSGCombiner3D/house2/door") as Node3D
		var church_door := lobby.get_node_or_null("CSGCombiner3D/church/door") as Node3D
		_check(house_door != null and Vector2(house_door.global_position.x, house_door.global_position.z).distance_to(Vector2(portal.global_position.x, portal.global_position.z)) < 0.4, "La nouvelle porte physique et son interaction coïncident")
		_check(church_door != null and church_door.global_position.distance_to(portal.global_position) > 20.0, "La porte de l’église est libérée de CHASEWEEN")
	var service_constants: Dictionary = _progression_service.get_script().get_script_constant_map()
	var world_ids: Array = service_constants.get("AVAILABLE_WORLD_IDS", [])
	_check(world_ids.has(CHASEWEEN_WORLD_ID), "ProgressionService connaît CHASEWEEN")
	_check(load(CHASEWEEN_SCENE_PATH) is PackedScene, "La scène CHASEWEEN ciblée est chargeable")
	_check(load("res://scenes/minigames/candy_bucket/CandyBucket.tscn") is PackedScene, "Candy Bucket reste chargeable")
	_check(load("res://scenes/minigames/labyrinth/Level01.tscn") is PackedScene, "Labyrinth reste chargeable")
	lobby.queue_free()
	await get_tree().process_frame


func _test_completed_portal_and_hud() -> void:
	var completed_worlds: Array[StringName] = [CHASEWEEN_WORLD_ID]
	_progression_service.set("data", Progression.new(0, 77, completed_worlds, false))
	var lobby := (load(LOBBY_SCENE_PATH) as PackedScene).instantiate()
	get_tree().root.add_child(lobby)
	await get_tree().process_frame
	var portal := lobby.get_node_or_null("ChaseweenPortal") as LevelPortal
	var candy_label := lobby.get_node_or_null("CandyHUD/CandyMargin/Stats/CandyLabel") as Label
	_check(portal != null and not portal.light.visible, "La porte CHASEWEEN éteint sa lumière après complétion")
	_check(portal != null and portal.prompt_label.text == LevelPortal.COMPLETED_TEXT, "La porte CHASEWEEN reprend l’état MONDE TERMINÉ")
	_check(candy_label != null and "77" in candy_label.text, "Le HUD du lobby lit immédiatement le total global actualisé")
	lobby.queue_free()
	await get_tree().process_frame
	_progression_service.set("data", Progression.new())


func _test_shared_results_and_audio() -> void:
	var labyrinth := (load("res://scenes/minigames/labyrinth/Labyrinth.tscn") as PackedScene).instantiate() as Labyrinth
	get_tree().root.add_child(labyrinth)
	await get_tree().process_frame
	_check(labyrinth.collect_audio_player.stream.resource_path == "res://assets/audio/collect.wav", "Le Labyrinthe conserve collect.wav sur le bus SFX")
	_check(labyrinth.collect_audio_player.bus == &"SFX", "Le son du Labyrinthe conserve son bus SFX")
	_check(labyrinth.result_overlay.scene_file_path == RESULT_OVERLAY_PATH, "Le Labyrinthe conserve sa carte de résultat officielle")
	labyrinth.queue_free()
	await get_tree().process_frame

	var candy_bucket := (load("res://scenes/minigames/candy_bucket/CandyBucket.tscn") as PackedScene).instantiate() as CandyBucketGame
	get_tree().root.add_child(candy_bucket)
	await get_tree().process_frame
	_check(candy_bucket.collect_sfx_player.stream.resource_path == "res://assets/audio/collect.wav", "Candy Bucket réutilise exactement collect.wav")
	_check(candy_bucket.collect_sfx_player.bus == &"SFX", "Candy Bucket utilise le même bus SFX")
	_check(candy_bucket.result_overlay.scene_file_path == RESULT_OVERLAY_PATH, "Candy Bucket instancie la carte de résultat du Labyrinthe")
	candy_bucket._round_active = true
	var healthy_candy := (load("res://scenes/minigames/candy_bucket/FallingCandy.tscn") as PackedScene).instantiate() as CandyBucketFallingCandy
	candy_bucket.candies.add_child(healthy_candy)
	candy_bucket.collect_sfx_player.stop()
	candy_bucket._on_player_candy_entered(healthy_candy)
	_check(candy_bucket._collected_candies == 1, "Candy Bucket valide le CANDY sain une seule fois")
	_check(candy_bucket.collect_sfx_player.playing, "Candy Bucket joue collect.wav lors du gain réel")
	var toxic_candy := (load("res://scenes/minigames/candy_bucket/FallingCandy.tscn") as PackedScene).instantiate() as CandyBucketFallingCandy
	candy_bucket.candies.add_child(toxic_candy)
	toxic_candy.is_poison = true
	candy_bucket.collect_sfx_player.stop()
	candy_bucket._on_player_candy_entered(toxic_candy)
	_check(candy_bucket._collected_candies == 1, "Un bonbon toxique ne modifie pas le score")
	_check(not candy_bucket.collect_sfx_player.playing, "Un bonbon toxique ne joue pas le son officiel de collecte")
	candy_bucket.result_overlay.show_result("TEST", 17)
	_check(candy_bucket.result_overlay.candy_score_label.text == "CANDY : 17", "Candy Bucket affiche le vrai score local")
	_check(candy_bucket.result_overlay.continue_button.text == ResultOverlay.EXIT_TEXT, "Candy Bucket utilise le bouton Sortir dans la rue")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "La carte commune libère et affiche la souris")
	candy_bucket.queue_free()
	await get_tree().process_frame


func _test_single_score_credit() -> void:
	_progression_service.set("data", Progression.new())
	var first_credit := bool(_progression_service.call(&"complete_world", CHASEWEEN_WORLD_ID, 20))
	var second_credit := bool(_progression_service.call(&"complete_world", CHASEWEEN_WORLD_ID, 20))
	_check(first_credit and not second_credit, "CHASEWEEN ne peut créditer le score global qu’une fois")
	_check(int(_progression_service.call(&"get_total_candy")) == 20, "Un second clic de retour ne double pas les CANDY")
	_progression_service.set("data", Progression.new())


func _test_summary_button_geometry() -> void:
	var viewport_sizes: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
	for viewport_size: Vector2i in viewport_sizes:
		await _test_summary_button_at_size(viewport_size)


func _test_summary_button_at_size(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	get_tree().root.add_child(viewport)
	var hud := HUD_SCRIPT.new() as FactionFightHUD
	viewport.add_child(hud)
	await get_tree().process_frame
	hud.show_summary(42, 0, 4, 5, "PORTAIL")
	await get_tree().process_frame
	var button := hud._summary_button
	_check(hud._summary_overlay.scene_file_path == RESULT_OVERLAY_PATH, "CHASEWEEN instancie la carte de résultat du Labyrinthe")
	_check(button != null and button.text == ResultOverlay.EXIT_TEXT, "Le bouton commun affiche exactement Sortir dans la rue")
	_check(button != null and button.visible, "Le bouton est visible en %s" % viewport_size)
	if button != null:
		_test_button_hit_rect(button, viewport_size)
		button.mouse_entered.emit()
		button.pressed.emit()
		_check(not hud.summary_visible, "Un clic sur toute la carte ferme le résultat en %s" % viewport_size)
	viewport.queue_free()
	await get_tree().process_frame


func _test_button_hit_rect(button: Button, viewport_size: Vector2i) -> void:
	var rect := button.get_global_rect()
	_check(rect.size.x >= 300.0 and rect.size.y >= 54.0, "Le bouton conserve les dimensions minimales de la référence en %s" % viewport_size)
	_check(rect.size.is_equal_approx(button.size), "La zone cliquable correspond à toute la surface visible en %s" % viewport_size)
	var samples: Array[Vector2] = [
		Vector2(rect.size.x * 0.5, rect.size.y * 0.5),
		Vector2(rect.size.x * 0.5, 2.0),
		Vector2(rect.size.x * 0.5, rect.size.y - 2.0),
		Vector2(2.0, rect.size.y * 0.5),
		Vector2(rect.size.x - 2.0, rect.size.y * 0.5),
	]
	for sample: Vector2 in samples:
		_check(Rect2(Vector2.ZERO, button.size).has_point(sample), "Le clic touche le bouton en %s au point %s" % [viewport_size, sample])
	_check(button.scale.is_equal_approx(Vector2.ONE), "Le bouton ne subit aucune mise à l’échelle en %s" % viewport_size)
	_check(button.get_global_transform().get_scale().is_equal_approx(Vector2.ONE), "La transformation UI reste unitaire en %s" % viewport_size)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("CHASEWEEN_LOBBY_INTEGRATION_TESTS_OK")
		get_tree().quit(0)
		return
	print("CHASEWEEN_LOBBY_INTEGRATION_TESTS_FAILED: %d" % _failures.size())
	get_tree().quit(1)
