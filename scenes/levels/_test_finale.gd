extends Node


const LOBBY_SCENE_PATH: String = "res://scenes/levels/main.tscn"
const FINALE_MUSIC_PATH: String = "res://assets/audio/bilan_final.mp3"
const CHURCH_DOOR_PATH: NodePath = NodePath("CSGCombiner3D/church/door")
const COMPLETED_WORLDS: Array[StringName] = [&"candy_bucket", &"labyrinth", &"chaseween"]

var _failures: Array[String] = []
var _original_progression: Progression


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred(&"_run")


func _run() -> void:
	_original_progression = ProgressionService.data
	ProgressionService.data = Progression.new(0, 247, COMPLETED_WORLDS, false, "Jyjio")

	var packed_scene: PackedScene = load(LOBBY_SCENE_PATH) as PackedScene
	_check(packed_scene != null, "Le lobby et son bilan se chargent")
	if packed_scene == null:
		_finish()
		return

	var lobby: Node = packed_scene.instantiate()
	get_tree().root.add_child(lobby)
	await get_tree().process_frame
	await get_tree().process_frame

	var hud: LobbyCandyHud = lobby.get_node_or_null("CandyHUD") as LobbyCandyHud
	var interactor: ChurchFinaleInteractor = lobby.get_node_or_null("ChurchFinaleInteractor") as ChurchFinaleInteractor
	var player: CharacterBody3D = lobby.get_node_or_null("Player") as CharacterBody3D
	var church_door: Node3D = lobby.get_node_or_null(CHURCH_DOOR_PATH) as Node3D
	_check(hud != null, "Le HUD final existe")
	_check(interactor != null, "La porte de l'église possède une interaction dédiée")
	_check(player != null and church_door != null, "Le joueur et la porte visible sont résolus")
	if hud == null or interactor == null or player == null or church_door == null:
		lobby.queue_free()
		_finish()
		return

	_check(not hud.finale_overlay.visible, "Le bilan ne s'ouvre pas automatiquement")
	_check(interactor._available and interactor.light.visible, "L'église s'active après les trois mondes")
	var horizontal_distance := Vector2(
		interactor.global_position.x - church_door.global_position.x,
		interactor.global_position.z - church_door.global_position.z
	).length()
	_check(horizontal_distance < 1.3, "La zone d'interaction est centrée devant la porte visible")
	_check(interactor.global_position.z > church_door.global_position.z, "La zone reste du côté accessible de la façade")

	interactor._on_body_entered(player)
	_check(interactor.prompt.visible, "Le prompt apparaît à proximité")
	_check(interactor.prompt_label.text == ChurchFinaleInteractor.PROMPT_TEXT, "Le prompt propose de consulter le bilan")

	var score_before: int = ProgressionService.get_total_candy()
	var previous_mouse_mode: Input.MouseMode = Input.mouse_mode
	_check(hud.open_finale(), "E peut ouvrir une première instance du bilan")
	_check(not hud.open_finale(), "Une seconde ouverture simultanée est refusée")
	await SceneTransition.transition_finished
	await get_tree().process_frame
	_check(hud.finale_overlay.visible, "Le bilan est visible après le fondu")
	_check(get_tree().paused, "Le déplacement est suspendu pendant le bilan")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Le curseur est libéré pour la saisie")
	_check(hud.name_input.text == "Jyjio", "Le pseudo sauvegardé est reproposé")
	_check(hud.name_input.max_length == ProgressionService.MAX_PLAYER_NAME_LENGTH, "Le pseudo est limité à 20 caractères")
	_check(ResourceLoader.exists(FINALE_MUSIC_PATH) and hud.finale_audio.stream is AudioStreamMP3, "bilan_final.mp3 accompagne le bilan")
	_check(hud.finale_audio.playing, "La musique finale démarre une seule fois")
	_check(ProgressionService.get_total_candy() == score_before, "L'ouverture ne modifie pas les CANDY")

	_test_pseudo_serialization()
	var sanitized_name: String = ProgressionService.call(
		&"_sanitize_player_name",
		"  Joueur%s%sHalloween avec un pseudo trop long  " % [String.chr(7), String.chr(130)]
	)
	_check(String.chr(7) not in sanitized_name and String.chr(130) not in sanitized_name, "Les caractères de contrôle sont supprimés")
	_check(sanitized_name.length() <= 20 and not sanitized_name.begins_with(" "), "Le pseudo est rogné et nettoyé")

	hud._show_final_result("<b>Jyjio</b>")
	await get_tree().create_timer(0.55, true).timeout
	_check(hud.player_name_label.get_class() == "Label", "Le pseudo reste du texte simple sans BBCode")
	_check(hud.player_name_label.text == "<b>Jyjio</b>", "Les caractères usuels sont affichés littéralement")
	_check(hud.final_score_label.text == "247 CANDY", "Le bilan reprend exactement le total global")
	_check(hud.result_step.visible and hud.save_button.visible, "Le résultat et l'export PNG apparaissent après validation")
	hud.player_name_label.text = "Jyjio"

	await hud._save_finale_capture()
	if DisplayServer.get_name() == "headless":
		_check("affichage graphique" in hud.save_status.text, "L'export PNG échoue explicitement en mode headless")
	else:
		var capture_path: String = hud.save_status.text.trim_prefix("Image enregistrée :\n")
		var capture_exists: bool = FileAccess.file_exists(capture_path)
		_check(capture_exists, "L'export PNG crée une image lisible")
		if capture_exists:
			var captured_image: Image = Image.load_from_file(capture_path)
			_check(not captured_image.is_empty(), "La capture PNG possède des dimensions valides")
			DirAccess.remove_absolute(capture_path)

	await hud._dismiss_finale()
	_check(not hud.finale_overlay.visible, "Le bilan se ferme")
	_check(not get_tree().paused, "Le joueur retrouve le contrôle du lobby")
	_check(Input.mouse_mode == previous_mouse_mode, "Le mode souris précédent est restauré")
	_check(not hud.finale_audio.playing, "La musique finale s'arrête au retour")
	_check(ProgressionService.get_total_candy() == score_before, "La fermeture ne modifie pas les CANDY")
	_check(interactor.prompt.visible, "Le bilan peut être consulté à nouveau depuis l'église")

	lobby.queue_free()
	await get_tree().process_frame
	_finish()


func _test_pseudo_serialization() -> void:
	var service_script: Script = load("res://services/save/ProgressionService.gd") as Script
	var isolated_service: Node = service_script.new() as Node
	var serialized: String = isolated_service.call(
		&"_serialize",
		Progression.new(0, 42, [&"labyrinth"], false, "Éva 42")
	)
	var parsed: Progression = isolated_service.call(&"_parse", serialized) as Progression
	_check(parsed.player_name == "Éva 42", "Le pseudo est conservé dans la sauvegarde existante")
	_check(parsed.total_candy == 42, "L'ajout du pseudo préserve le score sauvegardé")
	isolated_service.free()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	ProgressionService.data = _original_progression
	if _failures.is_empty():
		print("LOBBY_FINALE_TESTS_OK")
		get_tree().quit(0)
		return
	print("LOBBY_FINALE_TESTS_FAILED: %d" % _failures.size())
	get_tree().quit(1)
