extends Node


const LOBBY_SCENE_PATH: String = "res://scenes/levels/main.tscn"
const GALLERY_SCENE_PATH: String = "res://scenes/secret_gallery/SecretGallery.tscn"
const SECRET_LAMP_PATH: NodePath = NodePath("CSGCombiner3D/light18")

var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred(&"_run")


func _run() -> void:
	var candy_before: int = ProgressionService.get_total_candy()
	var worlds_before: int = ProgressionService.get_completed_world_count()
	var name_before: String = ProgressionService.get_player_name()

	await _test_lobby_entrance()
	await _test_gallery_scene()
	await _test_lobby_return()

	_check(ProgressionService.get_total_candy() == candy_before, "La visite ne modifie aucun CANDY")
	_check(ProgressionService.get_completed_world_count() == worlds_before, "La visite ne modifie aucun monde")
	_check(ProgressionService.get_player_name() == name_before, "La visite ne modifie pas le pseudo")
	_finish()


func _test_lobby_entrance() -> void:
	var lobby: Node3D = await _instantiate_scene(LOBBY_SCENE_PATH) as Node3D
	_check(lobby != null, "Le lobby chargé contient l'accès secret")
	if lobby == null:
		return

	var entrance: SecretGalleryEntrance = lobby.get_node_or_null("SecretGalleryEntrance") as SecretGalleryEntrance
	var player: CharacterBody3D = lobby.get_node_or_null("Player") as CharacterBody3D
	var lamp: Node3D = lobby.get_node_or_null(SECRET_LAMP_PATH) as Node3D
	_check(entrance != null and player != null and lamp != null, "Le lampadaire light18, le joueur et l'interaction sont résolus")
	if entrance == null or player == null or lamp == null:
		lobby.queue_free()
		await get_tree().process_frame
		return

	var horizontal_distance: float = Vector2(
		entrance.global_position.x - lamp.global_position.x,
		entrance.global_position.z - lamp.global_position.z
	).length()
	_check(horizontal_distance < 0.1, "L'interaction est centrée sur le lampadaire light18")
	_check(
		entrance.global_position.distance_to(lobby.get_node("ChaseweenPortal").global_position) > 10.0
		and entrance.global_position.distance_to(lobby.get_node("CandyBucketPortal").global_position) > 10.0
		and entrance.global_position.distance_to(lobby.get_node("LabyrinthPortal").global_position) > 10.0,
		"Le lampadaire secret ne chevauche aucun portail"
	)
	var church: Node3D = lobby.get_node_or_null("CSGCombiner3D/church") as Node3D
	if church != null:
		_check(entrance.global_position.distance_to(church.global_position) > 10.0, "Le lampadaire secret reste à l'écart de l'église")

	entrance._on_body_entered(player)
	var echo_event := InputEventKey.new()
	echo_event.physical_keycode = KEY_E
	echo_event.pressed = true
	echo_event.echo = true
	_check(not entrance._can_count_press(echo_event), "Une répétition automatique de E est ignorée")

	for _press: int in range(4):
		entrance._count_press()
	_check(entrance._press_count == 4 and not entrance._transition_started, "Quatre pressions ne déclenchent aucune transition")
	entrance._on_body_exited(player)
	_check(entrance._press_count == 0, "S'éloigner réinitialise le code secret")
	entrance._on_body_entered(player)
	entrance._count_press()
	entrance._count_press()
	var console: CanvasLayer = lobby.get_node_or_null("GameConsole") as CanvasLayer
	var console_input: LineEdit = lobby.get_node_or_null("GameConsole/Panel/GlobalMargin/VBoxContainer/HBoxContainer/Input") as LineEdit
	if console != null and console_input != null:
		console.show()
		console_input.grab_focus()
		await get_tree().process_frame
		_check(entrance._press_count == 0, "Une interface active interrompt et réinitialise le code")
		console_input.release_focus()
		console.hide()
	entrance._on_body_exited(player)
	var action_event := InputEventAction.new()
	action_event.action = &"action_activate"
	action_event.pressed = true
	_check(not entrance._can_count_press(action_event), "Une pression hors de portée n'est pas comptée")
	entrance._on_body_entered(player)
	for _press: int in range(5):
		entrance._count_press()
	_check(entrance._press_count == 5 and entrance._transition_started, "La cinquième pression arme une seule transition")
	entrance._on_body_exited(player)
	_check(entrance._transition_started, "S'éloigner pendant l'effet final n'annule pas l'ouverture")

	lobby.queue_free()
	await get_tree().process_frame


func _test_gallery_scene() -> void:
	var gallery: Node3D = await _instantiate_scene(GALLERY_SCENE_PATH) as Node3D
	_check(gallery != null, "SecretGallery.tscn se charge")
	if gallery == null:
		return

	var player: Player = gallery.get_node_or_null("Player") as Player
	var exit: GalleryExit = gallery.get_node_or_null("GalleryExit") as GalleryExit
	var frames: Node3D = gallery.get_node_or_null("Frames") as Node3D
	_check(player != null and player.get_node_or_null("CameraPivot/SpringArm/Camera") is Camera3D, "Le contrôleur et la caméra partagés sont réutilisés")
	_check(exit != null and exit.prompt_label.text == GalleryExit.PROMPT_TEXT, "La sortie propose un retour au lobby en une pression")
	_check(frames != null and frames.get_child_count() == 7, "Les sept emplacements d'archives sont présents")

	var portrait_count: int = 0
	var landscape_count: int = 0
	var frames_are_empty: bool = true
	if frames != null:
		for index: int in range(frames.get_child_count()):
			var frame: GalleryFrame = frames.get_child(index) as GalleryFrame
			_check(frame != null and frame.name == "ArchiveFrame_%02d" % (index + 1), "Le cadre %02d possède un nom explicite" % (index + 1))
			if frame == null:
				continue
			frames_are_empty = frames_are_empty and frame.archive_texture == null
			if frame.frame_size.x > frame.frame_size.y:
				landscape_count += 1
			else:
				portrait_count += 1
	_check(frames_are_empty, "Les cadres restent neutres et sans archive inventée")
	_check(portrait_count == 4 and landscape_count == 3, "La galerie prévoit quatre portraits et trois paysages")

	await get_tree().physics_frame
	var space_state: PhysicsDirectSpaceState3D = gallery.get_world_3d().direct_space_state
	var floor_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3(0, 2, 0), Vector3(0, -2, 0), 2
	)
	var wall_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3.ZERO, Vector3(12, 0, 0), 4
	)
	_check(not space_state.intersect_ray(floor_query).is_empty(), "Le sol possède une collision")
	_check(not space_state.intersect_ray(wall_query).is_empty(), "Les murs empêchent de sortir de la galerie")
	var door_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3(0, 1.5, 13.5), Vector3(0, 1.5, 15.5), 4
	)
	_check(not space_state.intersect_ray(door_query).is_empty(), "La porte de sortie possède une collision")
	if DisplayServer.get_name() != "headless":
		_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Le curseur est capturé pendant l'exploration")

	if player != null:
		var start_position: Vector3 = player.global_position
		Input.action_press(&"move_up")
		for _frame: int in range(8):
			await get_tree().physics_frame
		Input.action_release(&"move_up")
		_check(player.global_position.distance_to(start_position) > 0.1, "Le contrôleur partagé permet d'explorer la galerie")
		_check(player.global_position.y > 0.2, "Le joueur reste porté par le sol")

	if exit != null and player != null:
		exit._on_body_entered(player)
		_check(exit.prompt.visible, "Le message de sortie apparaît à proximité")
		exit._on_body_exited(player)
		_check(not exit.prompt.visible, "Le message disparaît hors de portée")

	if OS.get_environment("KEEP_SECRET_GALLERY_SCREEN") == "1" and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var screenshot_path: String = ProjectSettings.globalize_path("user://secret_gallery_test.png")
		gallery.get_viewport().get_texture().get_image().save_png(screenshot_path)
		print("SECRET_GALLERY_SCREEN: %s" % screenshot_path)

	gallery.queue_free()
	await get_tree().process_frame


func _test_lobby_return() -> void:
	Input.action_press(&"action_activate")
	get_tree().set_meta(SecretGalleryEntrance.LOBBY_RETURN_META, true)
	var lobby: Node3D = await _instantiate_scene(LOBBY_SCENE_PATH) as Node3D
	if lobby == null:
		Input.action_release(&"action_activate")
		_check(false, "Le lobby se recharge pour le retour")
		return

	var entrance: SecretGalleryEntrance = lobby.get_node_or_null("SecretGalleryEntrance") as SecretGalleryEntrance
	var player: CharacterBody3D = lobby.get_node_or_null("Player") as CharacterBody3D
	_check(entrance != null and player != null, "Le retour retrouve le lampadaire et le joueur")
	if entrance != null and player != null:
		var return_distance: float = Vector2(
			player.global_position.x - entrance.return_spawn.global_position.x,
			player.global_position.z - entrance.return_spawn.global_position.z
		).length()
		_check(return_distance < 0.05, "Le joueur réapparaît au point sûr près du lampadaire")
		_check(not entrance._accepting_input and entrance._press_count == 0, "Le E de sortie ne rouvre pas immédiatement la galerie")
	Input.action_release(&"action_activate")
	_check(not get_tree().has_meta(SecretGalleryEntrance.LOBBY_RETURN_META), "Le point de retour ne perturbe pas les entrées suivantes")
	lobby.queue_free()
	await get_tree().process_frame


func _instantiate_scene(scene_path: String) -> Node:
	var packed_scene: PackedScene = load(scene_path) as PackedScene
	if packed_scene == null:
		return null
	var instance: Node = packed_scene.instantiate()
	get_tree().root.add_child(instance)
	await get_tree().process_frame
	await get_tree().process_frame
	return instance


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("SECRET_GALLERY_TESTS_OK")
		get_tree().quit(0)
		return
	print("SECRET_GALLERY_TESTS_FAILED: %d" % _failures.size())
	get_tree().quit(1)
