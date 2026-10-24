extends SceneTree

const SCENE_PATH := "res://scenes/minigames/faction_fight/FactionFight.tscn"
const PresentationScript := preload("res://scenes/minigames/faction_fight/gameplay/ChaseweenItemPresentation.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_model_catalog()
	await _test_faction_fight_scene()
	_finish()


func _test_model_catalog() -> void:
	_check(PresentationScript.MODELS.size() == 13, "Les treize GLB sont référencés")
	for presentation_id: StringName in PresentationScript.MODELS:
		var presentation := PresentationScript.new() as PresentationScript
		root.add_child(presentation)
		presentation.configure(presentation_id)
		var model := presentation.get_node_or_null("VisualPivot/GLBInstance") as Node3D
		_check(model != null, "%s instancie son GLB" % presentation_id)
		_check(model != null and not model.find_children("*", "GeometryInstance3D", true, false).is_empty(), "%s contient une géométrie visible" % presentation_id)
		presentation.queue_free()


func _test_faction_fight_scene() -> void:
	var packed_scene := load(SCENE_PATH) as PackedScene
	_check(packed_scene != null, "La scène FactionFight charge avec les nouveaux assets")
	if packed_scene == null:
		return
	var scene := packed_scene.instantiate() as Node3D
	root.add_child(scene)
	await process_frame
	await process_frame
	var gameplay := scene.get_node_or_null("FactionFightGameplay") as FactionFightGameplay
	_check(gameplay != null, "Le gameplay FactionFight est instancié")
	if gameplay == null:
		scene.queue_free()
		return
	var presentation_ids: Dictionary[StringName, bool] = {}
	var presentation_count: int = 0
	var polished_title_count: int = 0
	for pickup: FactionFightPickup in gameplay._pickups:
		if pickup.kind == FactionFightPickup.Kind.CANDY:
			continue
		_check(is_instance_valid(pickup._presentation), "%s utilise une présentation GLB" % pickup.display_name)
		if is_instance_valid(pickup._presentation):
			presentation_count += 1
			presentation_ids[pickup._presentation.presentation_id] = true
			_check(pickup._presentation.get_node_or_null("InnerHalo") != null, "%s possède un double halo" % pickup.display_name)
			_check(pickup._presentation.get_node_or_null("RuneCrown") != null, "%s possède des accents runiques" % pickup.display_name)
			_test_effect_alignment(pickup)
		if pickup.get_node_or_null("WorldTitle/TitleBackdrop") != null:
			polished_title_count += 1
	_check(presentation_count == 15, "Les quinze objets de gameplay utilisent les nouveaux visuels")
	_check(polished_title_count == 15, "Les quinze objets interactifs utilisent un cartouche world-space")
	_check(gameplay._objective_marker.get_node_or_null("GroundSigil") != null, "Le marqueur d’objectif possède un sceau au sol")
	_check(gameplay._objective_marker.get_node_or_null("SpectralBeacon") != null, "Le marqueur d’objectif possède un faisceau spectral composite")
	_check(gameplay._objective_marker.get_node_or_null("RisingSugarMotes") != null, "Le marqueur d’objectif possède des particules verticales")
	_check(gameplay._objective_marker.get_node_or_null("ObjectiveTitle") != null, "Le marqueur d’objectif possède un titre intégré")
	gameplay._hud.set_prompt("E  •  TEST D’INTERACTION")
	_check(gameplay._hud._prompt_key_panel.visible, "Le prompt distingue la touche d’interaction")
	_check(gameplay._hud._prompt_action_label.text == "TEST D’INTERACTION", "Le prompt hiérarchise le libellé d’action")
	_check(gameplay._hud._help_label.text.contains("Clic gauche utiliser"), "Le HUD annonce le clic gauche pour utiliser l’outil")
	_check(not gameplay._hud._help_label.text.contains("R ") and not gameplay._hud._help_label.text.contains("F "), "Le HUD ne mentionne plus les anciennes commandes R/F")
	var toast_style := gameplay._hud._toast_panel.get_theme_stylebox("panel")
	_check(toast_style is StyleBoxEmpty, "Les consignes temporaires n’ont plus de carte ni de bordure")
	_test_message_categories(gameplay._hud)
	_check(is_instance_valid(gameplay._heart), "Le Cœur de CHEWINGLAND utilise son GLB")
	_check(gameplay._heart._presentation.presentation_id == &"chewingland_heart", "Le cœur conserve sa présentation dédiée")
	_test_heart_collection(gameplay)
	gameplay._equip_tool(&"ghost_lamp", 4)
	await process_frame
	_check(is_instance_valid(gameplay._held_tool_visual), "La lampe fantôme apparaît une fois équipée")
	_check(gameplay._held_tool_visual.presentation_id == &"ghost_lamp", "Le modèle tenu correspond à la lampe fantôme")
	_test_spectral_preview(gameplay)
	_check(presentation_ids.has(&"haunted_locker"), "Le casier hanté remplace le dispositif provisoire")
	_check(presentation_ids.has(&"magic_dispenser"), "Le distributeur magique remplace le dispositif provisoire")
	_check(presentation_ids.has(&"magic_altar"), "L’autel magique remplace les socles provisoires")
	scene.queue_free()
	await process_frame
	await physics_frame


func _test_heart_collection(gameplay: FactionFightGameplay) -> void:
	var heart := gameplay._heart
	_check(heart.global_position.is_equal_approx(FactionFightGameplay.HEART_POSITION), "Le cœur et ses effets partagent leur nouvelle position")
	_check(heart.global_position.distance_to(gameplay._portal_interaction_position()) > FactionFightGameplay.PORTAL_INTERACTION_RADIUS + 4.0, "Le cœur est hors de la zone de sortie")
	gameplay._player.global_position = heart.get_interaction_position()
	gameplay._update_interaction_prompt()
	_check(gameplay._nearest_interactive == heart and gameplay._hud._prompt_action_label.text == "CŒUR DE CHEWINGLAND", "Le prompt E cible le cœur")
	gameplay._interact()
	_check(heart.collected and gameplay._inventory.get(&"chewingland_heart", false), "Le cœur est collecté avec le système existant")
	_check(gameplay._collect_audio_player.playing, "La collecte du cœur conserve le bruitage")
	_check(not heart.collect_once(), "Le cœur ne peut être collecté qu’une fois")
	_check(not gameplay._completed, "La collecte du cœur ne déclenche pas le portail")


func _test_message_categories(hud: FactionFightHUD) -> void:
	_check(hud._toast_label.get_theme_color("font_color").is_equal_approx(Color.WHITE), "La teinte des messages n’est pas altérée par une couleur de base")
	var categories: Array[int] = [
		FactionFightHUD.MessageCategory.OBJECTIVE,
		FactionFightHUD.MessageCategory.INFORMATION,
		FactionFightHUD.MessageCategory.SUCCESS,
		FactionFightHUD.MessageCategory.DANGER,
	]
	var names: Array[String] = ["doré", "turquoise", "vert", "rouge"]
	for index: int in categories.size():
		var category := categories[index]
		hud.show_gameplay_message("CATÉGORIE TEST", category)
		_check(hud._toast_label.modulate.is_equal_approx(FactionFightHUD.message_color(category)), "La catégorie %s utilise sa couleur centralisée" % names[index])
	hud.show_gameplay_message("OBJECTIF EN ATTENTE", FactionFightHUD.MessageCategory.OBJECTIVE)
	_check(hud._toast_label.text == "CATÉGORIE TEST", "Un objectif ne remplace pas une alerte prioritaire")


func _test_spectral_preview(gameplay: FactionFightGameplay) -> void:
	var preview := gameplay._aim_preview
	var beam := preview.get_node_or_null("SpectralBeam") as MeshInstance3D if preview != null else null
	var particles := preview.get_node_or_null("SpectralMotes") as GPUParticles3D if preview != null else null
	var light := preview.get_node_or_null("SpectralSourceLight") as OmniLight3D if preview != null else null
	var mesh := beam.mesh as CylinderMesh if beam != null else null
	_check(beam != null and beam.get_active_material(0) is ShaderMaterial, "La lampe utilise un faisceau spectral shader")
	_check(mesh != null and is_equal_approx(mesh.height, FactionFightVFX.GHOST_BEAM_DISTANCE), "Le faisceau conserve exactement la portée réelle de 8 m")
	_check(mesh != null and is_equal_approx(mesh.top_radius, tan(FactionFightVFX.GHOST_BEAM_HALF_ANGLE) * FactionFightVFX.GHOST_BEAM_DISTANCE), "L’ouverture visuelle conserve exactement l’angle réel")
	_check(particles != null and particles.amount == 14, "Le faisceau utilise un nombre limité de particules spectrales")
	_check(light != null and not light.shadow_enabled, "La lumière locale spectrale reste unique et sans ombres")


func _test_effect_alignment(pickup: FactionFightPickup) -> void:
	var center := pickup._presentation.get_effect_center()
	var halo := pickup._presentation.get_node_or_null("PresentationHalo") as Node3D
	var title := pickup.get_node_or_null("WorldTitle") as Node3D
	_check(halo != null and Vector2(halo.position.x, halo.position.z).is_equal_approx(Vector2(center.x, center.z)), "%s centre son halo sur le GLB visible" % pickup.display_name)
	_check(title != null and Vector2(title.position.x, title.position.z).is_equal_approx(Vector2(center.x, center.z)), "%s centre son titre sur le GLB visible" % pickup.display_name)
	if pickup.kind != FactionFightPickup.Kind.CHEST and pickup.kind != FactionFightPickup.Kind.DEVICE:
		return
	var body := pickup.get_node_or_null("PhysicalCollision") as StaticBody3D
	_check(body != null and Vector2(body.position.x, body.position.z).is_equal_approx(Vector2(center.x, center.z)), "%s centre sa collision sur le GLB visible" % pickup.display_name)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("FACTION_FIGHT_ASSET_INTEGRATION_TESTS_OK")
		quit(0)
		return
	print("FACTION_FIGHT_ASSET_INTEGRATION_TESTS_FAILED: %d" % _failures.size())
	quit(1)
