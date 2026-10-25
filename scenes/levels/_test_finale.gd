extends Node


const LOBBY_SCENE_PATH: String = "res://scenes/levels/main.tscn"
const FINALE_MUSIC_PATH: String = "res://assets/audio/bilan_final.mp3"
const CHURCH_DOOR_PATH: NodePath = NodePath("CSGCombiner3D/church/door")
const COMPLETED_WORLDS: Array[StringName] = [
	&"candy_bucket",
	&"labyrinth",
	&"chaseween",
	&"faction_territory",
]

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
	var lobby_music: AudioStreamPlayer = lobby.get_node_or_null("LobbyMusic") as AudioStreamPlayer
	_check(hud != null, "Le HUD final existe")
	_check(interactor != null, "La porte de l'église possède une interaction dédiée")
	_check(player != null and church_door != null, "Le joueur et la porte visible sont résolus")
	if hud == null or interactor == null or player == null or church_door == null:
		lobby.queue_free()
		_finish()
		return

	_check(not hud.finale_overlay.visible, "Le bilan ne s'ouvre pas automatiquement")
	_check(interactor._available and interactor.light.visible, "L'église s'active après tous les mondes")
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
	_check(
		_is_horizontally_aligned(hud.name_input, hud.validate_button)
		and _is_horizontally_aligned(hud.validate_button, hud.return_button),
		"Le champ pseudo, la validation et le retour partagent le même axe central"
	)
	_check(
		hud.validate_button.size.x == 410.0 and hud.return_button.size.x == 350.0,
		"Les largeurs de la validation et du retour restent cohérentes"
	)
	_check(ResourceLoader.exists(FINALE_MUSIC_PATH) and hud.finale_audio.stream is AudioStreamMP3, "bilan_final.mp3 accompagne le bilan")
	_check(hud.finale_audio.playing, "La musique finale démarre une seule fois")
	_check(lobby_music != null and lobby_music.stream_paused, "La musique du lobby est suspendue pendant le bilan")
	_check(is_equal_approx(LobbyCandyHud.FINALE_VOLUME_DB, -10.0), "Le gain mesuré du bilan est appliqué")
	_check(ProgressionService.get_total_candy() == score_before, "L'ouverture ne modifie pas les CANDY")

	_test_pseudo_serialization()
	var sanitized_name: String = ProgressionService.call(
		&"_sanitize_player_name",
		"  Joueur%s%sHalloween avec un pseudo trop long  " % [String.chr(7), String.chr(130)]
	)
	_check(String.chr(7) not in sanitized_name and String.chr(130) not in sanitized_name, "Les caractères de contrôle sont supprimés")
	_check(sanitized_name.length() <= 20 and not sanitized_name.begins_with(" "), "Le pseudo est rogné et nettoyé")

	hud.player_name_label.text = "<b>Jyjio</b>"
	_check(hud.player_name_label.get_class() == "Label", "Le pseudo reste du texte simple sans BBCode")
	_check(hud.player_name_label.text == "<b>Jyjio</b>", "Les caractères usuels sont affichés littéralement")
	hud._show_final_result("Jyjio")
	await get_tree().create_timer(0.55, true).timeout
	_check(hud.final_score_label.text == "247 CANDY", "Le bilan reprend exactement le total global")
	_check(hud.result_step.visible and hud.save_button.visible, "Le résultat et l'export PNG apparaissent après validation")
	_check(hud.find_child("ShareButton", true, false) == null, "Le bouton de partage est absent du bilan")
	_check(
		hud.open_folder_button.visible == FinaleSharePlatform.is_desktop(),
		"L'ouverture du dossier est réservée aux plateformes desktop"
	)
	_check(hud.open_folder_button.disabled, "Le dossier reste désactivé avant le premier PNG")
	var action_buttons: VBoxContainer = hud.actions.get_node("ActionCenter/ActionButtons") as VBoxContainer
	_check(hud.actions is VBoxContainer, "Le bloc d'actions utilise une disposition verticale")
	_check(
		action_buttons.get_theme_constant("separation") == 12,
		"La colonne conserve un espacement régulier entre les boutons"
	)
	_check(
		action_buttons != null and _is_horizontally_aligned(action_buttons, hud.finale_card),
		"La colonne d'actions partage l'axe central de la carte"
	)
	_check(
		hud.save_button.size == Vector2(350.0, 64.0)
		and hud.open_folder_button.size == Vector2(350.0, 64.0)
		and hud.return_button.size == Vector2(350.0, 64.0),
		"Les trois actions conservent des dimensions cohérentes"
	)
	var folder_was_visible: bool = hud.open_folder_button.visible
	hud.open_folder_button.hide()
	await get_tree().process_frame
	_check(
		_is_horizontally_aligned(hud.return_button, hud.finale_card),
		"Le retour reste centré quand l'ouverture du dossier est masquée"
	)
	_check(
		is_equal_approx(
			hud.return_button.global_position.y - hud.save_button.get_global_rect().end.y,
			12.0
		),
		"Masquer l'ouverture du dossier ne laisse aucun espace vide"
	)
	hud.open_folder_button.visible = folder_was_visible
	await get_tree().process_frame
	var card_rect: Rect2 = hud.finale_card.get_global_rect()
	var viewport_size: Vector2 = hud.get_viewport().get_visible_rect().size
	_check(
		card_rect.position.x >= 0.0
		and card_rect.position.y >= 0.0
		and card_rect.end.x <= viewport_size.x
		and card_rect.end.y <= viewport_size.y,
		"La grille complète reste dans la fenêtre"
	)
	_check(
		hud._build_capture_file_name(" Ludo / Test:*? ") == "halloween2026_bilan_ludo_test.png",
		"Le nom du PNG est explicite et nettoyé"
	)
	var tested_names: Array[String] = ["Jyjio", "Chasseur2026", "WWWWWWWWWWWWWWWWWWWW"]
	var all_names_fit: bool = true
	for tested_name: String in tested_names:
		hud._fit_player_name(tested_name)
		var tested_font_size: int = hud.player_name_label.get_theme_font_size("font_size")
		var tested_width: float = hud.player_name_label.get_theme_font("font").get_string_size(
			tested_name,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			tested_font_size
		).x
		all_names_fit = all_names_fit and tested_width <= LobbyCandyHud.PLAYER_NAME_MAX_WIDTH
	_check(all_names_fit, "Les pseudos courts, moyens et proches de 20 caractères restent sur une ligne")
	_check(
		hud.player_name_label.get_theme_font_size("font_size") < LobbyCandyHud.PLAYER_NAME_MAX_FONT_SIZE,
		"Un pseudo très large est réduit pour rester sur une ligne"
	)
	hud.player_name_label.text = "Jyjio"
	hud._fit_player_name("Jyjio")

	await hud._save_finale_capture()
	if DisplayServer.get_name() == "headless":
		_check("affichage graphique" in hud.save_status.text, "L'export PNG échoue explicitement en mode headless")
	else:
		var capture_path: String = hud.save_status.text.trim_prefix("Image enregistrée :\n")
		var capture_exists: bool = FileAccess.file_exists(capture_path)
		_check(capture_exists, "L'export PNG crée une image lisible")
		_check(
			capture_path.get_file().begins_with("halloween2026_bilan_jyjio"),
			"Le fichier exporté porte un nom explicite"
		)
		_check(not hud.open_folder_button.disabled, "L'ouverture du dossier s'active après l'export")
		if capture_exists:
			var captured_image: Image = Image.load_from_file(capture_path)
			_check(not captured_image.is_empty(), "La capture PNG possède des dimensions valides")
			if OS.get_environment("KEEP_FINALE_TEST_CAPTURE") == "1":
				print("FINALE_CAPTURE_PATH: %s" % capture_path)
			else:
				DirAccess.remove_absolute(capture_path)

	await hud._dismiss_finale()
	_check(not hud.finale_overlay.visible, "Le bilan se ferme")
	_check(not get_tree().paused, "Le joueur retrouve le contrôle du lobby")
	_check(Input.mouse_mode == previous_mouse_mode, "Le mode souris précédent est restauré")
	_check(not hud.finale_audio.playing, "La musique finale s'arrête au retour")
	_check(lobby_music != null and not lobby_music.stream_paused and lobby_music.playing, "La musique du lobby reprend sans doublon")
	await get_tree().create_timer(0.9, true).timeout
	_check(is_equal_approx(lobby_music.volume_db, 5.0), "Le lobby retrouve progressivement son gain mesuré")
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


func _is_horizontally_aligned(first: Control, second: Control) -> bool:
	var first_center: float = first.get_global_rect().get_center().x
	var second_center: float = second.get_global_rect().get_center().x
	return is_equal_approx(first_center, second_center)


func _finish() -> void:
	ProgressionService.data = _original_progression
	if _failures.is_empty():
		print("LOBBY_FINALE_TESTS_OK")
		get_tree().quit(0)
		return
	print("LOBBY_FINALE_TESTS_FAILED: %d" % _failures.size())
	get_tree().quit(1)
