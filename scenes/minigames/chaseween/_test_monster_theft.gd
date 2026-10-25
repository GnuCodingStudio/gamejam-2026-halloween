extends SceneTree

const SCENE_PATH := "res://scenes/minigames/chaseween/Chaseween.tscn"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load(SCENE_PATH) as PackedScene
	_check(packed_scene != null, "La scène FactionFight charge")
	if packed_scene == null:
		_finish()
		return
	var scene := packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var gameplay := scene.get_node_or_null("FactionFightGameplay") as FactionFightGameplay
	_check(gameplay != null, "Le gestionnaire de gameplay existe")
	if gameplay == null:
		_finish()
		return
	_check(
		DisplayServer.get_name() == "headless" or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"CHASEWEEN demande la capture de la souris dès le début du gameplay"
	)

	_test_population(gameplay)
	_test_shared_candies(gameplay)
	_test_affinity_matrix(gameplay)
	_test_action_vfx(gameplay)
	_test_mission_start(gameplay)
	_test_unlock_chains(gameplay)
	_test_mission_finish(gameplay)
	_test_tool_slots(gameplay)
	_test_corruption_phases(gameplay)
	_test_obstacle_detection(gameplay)
	_test_voluntary_exit_prompt(gameplay)
	_test_random_roll(gameplay)
	_test_theft_rules(gameplay)
	_test_protections(gameplay)
	_test_exit_guarantee(gameplay)
	await _test_ghost_lamp_impacts()
	await _test_auto_finish()

	scene.queue_free()
	await process_frame
	await create_timer(1.3).timeout
	_finish()


func _test_population(gameplay: FactionFightGameplay) -> void:
	_check(gameplay._monsters.size() == 12, "Douze monstres sont instanciés")
	var model_counts: Dictionary[String, int] = {}
	var zone_counts: Array[int] = [0, 0, 0, 0]
	for monster: FactionFightMonster in gameplay._monsters:
		model_counts[monster.model_resource_path] = model_counts.get(monster.model_resource_path, 0) + 1
		zone_counts[_zone_for_z(monster.global_position.z)] += 1
		_check(monster._animation_player != null, "%s possède ses animations" % monster.display_name)
		var monster_node: Node = monster
		_check(not (monster_node is CollisionObject3D), "%s ne bloque pas physiquement le passage" % monster.display_name)
		for animation_name: StringName in monster._animation_names.values():
			_check(
				monster._animation_player != null and monster._animation_player.has_animation(animation_name),
				"%s peut jouer l’animation %s" % [monster.display_name, animation_name]
			)
		_check(monster._patrol_points.size() >= 3, "%s suit une ronde à plusieurs points" % monster.display_name)
		_check(monster._model_pivot != null and is_equal_approx(monster._model_pivot.rotation.y, PI), "%s aligne son +Z visuel sur l’avant -Z de l’acteur" % monster.display_name)
	var facing_monster: FactionFightMonster = gameplay._monsters[0]
	facing_monster._face_position(facing_monster.global_position + Vector3.RIGHT * 5.0, 1.0)
	_check((-facing_monster.global_basis.z).dot(Vector3.RIGHT) > 0.99, "Le monstre oriente bien son avant -Z vers son déplacement")
	_check(model_counts.get(FactionFightGameplay.GOBLIN_MODEL, 0) == 4, "Quatre Peppermint Goblin")
	_check(model_counts.get(FactionFightGameplay.PALADIN_MODEL, 0) == 4, "Quatre Pumpkin Paladin")
	_check(model_counts.get(FactionFightGameplay.CONQUEROR_MODEL, 0) == 4, "Quatre Candy Corn Conqueror")
	_check(zone_counts == [2, 3, 3, 4], "Répartition 2 / 3 / 3 / 4 dans les zones")


func _test_shared_candies(gameplay: FactionFightGameplay) -> void:
	var candies: Array[FactionFightPickup] = []
	var scene_counts: Dictionary[String, int] = {}
	for pickup: FactionFightPickup in gameplay._pickups:
		if pickup.kind != FactionFightPickup.Kind.CANDY:
			continue
		candies.append(pickup)
		scene_counts[pickup.shared_candy_scene_path] = scene_counts.get(pickup.shared_candy_scene_path, 0) + 1
		_check(is_instance_valid(pickup._shared_candy), "%s instancie un Candy partagé" % pickup.display_name)
		var mesh := pickup._shared_candy.get_node_or_null("MeshInstance3D") as MeshInstance3D
		var light := pickup._shared_candy.get_node_or_null("OmniLight3D") as OmniLight3D
		_check(mesh != null and mesh.scale.is_equal_approx(Vector3.ONE * 0.5), "Le mesh partagé conserve son échelle")
		_check(light != null and is_equal_approx(light.light_energy, 1.0), "La lumière locale du Candy est conservée")
		_check(pickup._shared_candy.bob_height == 0.1 and pickup._shared_candy.bob_speed == 2.0, "Le flottement Labyrinth est conservé")
	_check(candies.size() == 9, "Les neuf récompenses CANDY existantes sont préservées")
	_check(scene_counts.get("res://objects/candy_crystalberry.tscn", 0) == 5, "Cinq Crystalberry sont répartis dans CHASEWEEN")
	_check(scene_counts.get("res://objects/candy_pumpkin.tscn", 0) == 4, "Quatre Pumpkin Wrapper sont répartis dans CHASEWEEN")

	var first_candy := candies[0]
	var expected_score := gameplay._candy + first_candy.candy_value
	first_candy._shared_candy._on_body_entered(gameplay._player)
	_check(gameplay._candy == expected_score, "Le signal partagé ajoute la valeur prévue au score local")
	_check(gameplay._hud._candy_label.text == tr("CHASE_HUD_CANDY") % expected_score, "Le HUD est actualisé après collecte")
	_check(gameplay._collect_audio_player.playing, "Le bruitage collect.wav est déclenché")
	_check(_has_sparkles(first_candy), "Les particules Labyrinth sont déclenchées")
	first_candy._shared_candy._on_body_entered(gameplay._player)
	_check(gameplay._candy == expected_score, "Un même Candy ne peut créditer le score deux fois")


func _has_sparkles(pickup: FactionFightPickup) -> bool:
	for child: Node in pickup.get_children():
		if child is CPUParticles3D:
			return true
	return false


func _test_affinity_matrix(gameplay: FactionFightGameplay) -> void:
	var effective := FactionFightAffinityRules.Reaction.EFFECTIVE
	var weak := FactionFightAffinityRules.Reaction.WEAK
	var inverse := FactionFightAffinityRules.Reaction.INVERSE
	var expected: Dictionary = {
		&"sugar_spray": {&"goblin": effective, &"paladin": weak, &"conqueror": inverse},
		&"candy_cane": {&"goblin": effective, &"paladin": weak, &"conqueror": effective},
		&"caramel_shield": {&"goblin": effective, &"paladin": effective, &"conqueror": inverse},
		&"ghost_lamp": {&"goblin": effective, &"paladin": effective, &"conqueror": weak},
	}
	for item_id: StringName in expected:
		for monster_type: StringName in expected[item_id]:
			_check(FactionFightAffinityRules.reaction(item_id, monster_type) == expected[item_id][monster_type], "Affinité %s / %s correcte" % [item_id, monster_type])
	var conqueror: FactionFightMonster = gameplay._monsters[1]
	conqueror.apply_enrage(5.0)
	conqueror.apply_enrage(5.0)
	_check(is_equal_approx(conqueror._enrage_time, 5.0), "Le renforcement inverse ne se cumule pas")
	conqueror._physics_process(5.1)
	_check(conqueror._enrage_time == 0.0, "Le renforcement inverse expire automatiquement")
	gameplay._apply_affinity(&"sugar_spray", conqueror)
	_check(gameplay._discoveries.size() == 1, "Une affinité testée est ajoutée au carnet")


func _test_action_vfx(gameplay: FactionFightGameplay) -> void:
	var cone := FactionFightVFX.spawn_cone(gameplay, gameplay._player.global_transform, 7.0, deg_to_rad(30.0), Color.MAGENTA)
	var cone_visual := cone.get_child(0) as MeshInstance3D
	var cone_mesh := cone_visual.mesh as CylinderMesh
	_check(is_equal_approx(cone_mesh.height, 7.0), "Le VFX du spray correspond à sa portée de 7 m")
	var arc := FactionFightVFX.spawn_arc(gameplay, gameplay._player.global_transform, 2.6, Color.ORANGE_RED)
	_check(arc.get_child_count() == 7, "L’arc lumineux du bâton est généré")
	var dome := FactionFightVFX.spawn_dome(gameplay, gameplay._player.global_position, 1.65, Color.GOLD, 0.2)
	_check(dome is MeshInstance3D, "Le dôme du bouclier est généré")
	var spray_preview := FactionFightVFX.create_preview(&"sugar_spray", gameplay)
	var preview_mesh := (spray_preview.get_child(0) as MeshInstance3D).mesh as CylinderMesh
	_check(is_equal_approx(preview_mesh.height, 7.0), "La prévisualisation du spray reprend exactement sa portée")
	var cane_preview := FactionFightVFX.create_preview(&"candy_cane", gameplay)
	_check(cane_preview.get_child_count() == 8, "La prévisualisation du bâton dessine tout son secteur et sa limite")
	var ghost_preview := FactionFightVFX.create_preview(&"ghost_lamp", gameplay)
	var ghost_beam := ghost_preview.get_node_or_null("SpectralBeam") as MeshInstance3D
	var ghost_mesh := ghost_beam.mesh as CylinderMesh if ghost_beam != null else null
	_check(ghost_mesh != null and is_equal_approx(ghost_mesh.height, 8.0), "La prévisualisation spectrale conserve la portée réelle de la lampe")
	_check(ghost_preview.get_node_or_null("SpectralMotes") != null, "La lampe possède des poussières spectrales discrètes")
	FactionFightVFX.pulse_spectral_beam(ghost_preview)
	var ghost_material := ghost_beam.get_active_material(0) as ShaderMaterial if ghost_beam != null else null
	_check(ghost_material != null and is_equal_approx(float(ghost_material.get_shader_parameter(&"impulse")), 1.0), "Le clic peut intensifier le faisceau existant sans en créer un second")
	spray_preview.queue_free()
	cane_preview.queue_free()
	ghost_preview.queue_free()


func _test_mission_start(gameplay: FactionFightGameplay) -> void:
	_check(FactionFightGameplay.MISSIONS.size() == 4, "Quatre missions explicites sont configurées")
	_check(gameplay._mission_index == 0, "La mission du Jardin est active immédiatement")
	_check(gameplay._objective_marker != null and gameplay._objective_marker.name == "UniqueMissionMarker", "Un unique marqueur de mission existe")
	var mission_pickups := 0
	for pickup: FactionFightPickup in gameplay._pickups:
		if pickup.mission_id != &"":
			mission_pickups += 1
	_check(mission_pickups == 4, "Chaque mission possède exactement un objectif interactif")
	gameplay._complete_mission(&"syrup_cache")
	_check(gameplay._mission_index == 0, "Une mission future ne peut pas être validée hors séquence")
	var garden_chest := _mission_pickup(gameplay, &"garden_reserve")
	var score_before := gameplay._candy
	gameplay._collect_pickup(garden_chest)
	_check(gameplay._mission_index == 0 and gameplay._candy == score_before, "La réserve reste fermée avant l’action tutorielle")
	gameplay._tool_slots.clear()
	gameplay._sync_active_tool()
	gameplay._mission_elapsed = 40.0
	gameplay._update_mission(0.0)
	_check(gameplay._mission_hint_shown, "L’indice de secours apparaît après 40 secondes")
	_check(gameplay._tool_has_charges(&"candy_cane"), "Le secours restaure l’outil indispensable s’il a été perdu")
	gameplay._apply_affinity(&"candy_cane", gameplay._monsters[0])
	gameplay._collect_pickup(garden_chest)
	_check(gameplay._mission_index == 1, "La mission du Jardin ouvre celle de la Forêt")
	var score_after := gameplay._candy
	gameplay._collect_pickup(garden_chest)
	_check(gameplay._candy == score_after, "Un coffre de mission ne peut jamais créditer deux fois")


func _test_unlock_chains(gameplay: FactionFightGameplay) -> void:
	var key_items: Dictionary[StringName, FactionFightPickup] = {}
	var devices: Dictionary[StringName, FactionFightPickup] = {}
	for pickup: FactionFightPickup in gameplay._pickups:
		if pickup.kind == FactionFightPickup.Kind.KEY_ITEM:
			key_items[pickup.item_id] = pickup
		elif pickup.kind == FactionFightPickup.Kind.DEVICE:
			devices[pickup.required_item_id] = pickup
	_check(key_items.size() == 5 and key_items.has(&"chewingland_heart") and devices.size() == 4, "Le cœur, quatre objets de déblocage et quatre dispositifs existent")
	var unlock_order: Array[StringName] = [&"caramel_key", &"sugar_crystal", &"syrup_capsule", &"spectral_badge"]
	for item_id: StringName in unlock_order:
		gameplay._collect_pickup(key_items[item_id])
		_check(gameplay._inventory.get(item_id, false), "%s entre dans les trouvailles" % item_id)
		gameplay._collect_pickup(devices[item_id])
		_check(not gameplay._inventory.get(item_id, false), "%s est consommé par son dispositif" % item_id)
	_check(gameplay._active_item == &"ghost_lamp" or gameplay._active_item == &"sugar_spray", "Les chaînes débloquent un équipement tactique")
	_check(gameplay._mission_index == 2, "Le casier hanté valide la mission de la Forêt")


func _test_mission_finish(gameplay: FactionFightGameplay) -> void:
	var syrup_chest := _mission_pickup(gameplay, &"syrup_cache")
	gameplay._collect_pickup(syrup_chest)
	_check(gameplay._mission_index == 2, "La cache de sirop exige d’abord un essai d’affinité")
	gameplay._apply_affinity(&"candy_cane", gameplay._monsters[7])
	gameplay._collect_pickup(syrup_chest)
	_check(gameplay._mission_index == 3, "La cache de sirop ouvre la mission du Sanctuaire")
	gameplay._collect_pickup(_mission_pickup(gameplay, &"sanctuary_treasure"))
	_check(gameplay._mission_index == 4, "Les quatre missions se terminent dans l’ordre")
	_check(gameplay._objective_marker.global_position.is_equal_approx(gameplay._portal_objective_position()), "Le marqueur final est centré sous le portail")


func _mission_pickup(gameplay: FactionFightGameplay, mission_id: StringName) -> FactionFightPickup:
	for pickup: FactionFightPickup in gameplay._pickups:
		if pickup.mission_id == mission_id:
			return pickup
	return null


func _test_tool_slots(gameplay: FactionFightGameplay) -> void:
	gameplay._tool_slots.clear()
	gameplay._equip_tool(&"candy_cane", 3)
	gameplay._equip_tool(&"sugar_spray", 3)
	gameplay._equip_tool(&"caramel_shield", 1)
	_check(gameplay._tool_slots.size() == 2, "Le joueur ne transporte jamais plus de deux outils d’action")
	_check(gameplay._aim_preview != null, "La zone d’action apparaît automatiquement avec l’outil")
	var first_tool := gameplay._active_item
	gameplay._switch_tool()
	_check(gameplay._active_item != first_tool, "Q alterne entre les deux outils")
	_check(gameplay._aim_preview != null, "La zone permanente suit le nouvel outil actif")
	var charges_before_old_keys := gameplay._item_charges
	var old_key := InputEventKey.new()
	old_key.pressed = true
	old_key.physical_keycode = KEY_F
	gameplay._unhandled_input(old_key)
	_check(gameplay._item_charges == charges_before_old_keys, "F ne déclenche plus l’outil")
	old_key.physical_keycode = KEY_R
	gameplay._unhandled_input(old_key)
	_check(gameplay._aim_preview != null, "R n’est plus nécessaire à la prévisualisation")
	gameplay._switch_tool()
	var mouse_event := InputEventMouseButton.new()
	mouse_event.pressed = true
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	gameplay._mouse_was_captured = false
	gameplay._unhandled_input(mouse_event)
	_check(gameplay._tool_has_charges(&"caramel_shield"), "Le clic qui capture la souris ne déclenche pas l’outil")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	gameplay._mouse_was_captured = true
	gameplay._unhandled_input(mouse_event)
	_check(gameplay._shield_time > 0.0 and not gameplay._tool_has_charges(&"caramel_shield"), "Le clic gauche utilise l’outil actif avec la souris capturée")
	_check(gameplay._active_item == &"candy_cane" and gameplay._aim_preview != null, "La zone permanente passe à l’outil utilisable suivant")
	gameplay._shield_time = 0.0


func _test_corruption_phases(gameplay: FactionFightGameplay) -> void:
	_check(gameplay._corruption_phase_name(0.0) == tr("CHASE_GAME_PHASE_1"), "Phase climatique 1")
	_check(gameplay._corruption_phase_name(60.0) == tr("CHASE_GAME_PHASE_2"), "Phase climatique 2 à 60 secondes")
	_check(gameplay._corruption_phase_name(120.0) == tr("CHASE_GAME_PHASE_3"), "Phase climatique 3 à 120 secondes")
	_check(gameplay._corruption_phase_name(180.0) == tr("CHASE_GAME_PHASE_4"), "Phase climatique 4 à 180 secondes")
	gameplay._session_time = 120.0
	gameplay._update_corruption(0.0)
	_check(is_equal_approx(gameplay._hud._corruption_bar.value, 50.0), "La jauge affiche la corruption sans secondes")
	gameplay._session_time = 0.0


func _test_obstacle_detection(gameplay: FactionFightGameplay) -> void:
	var monster: FactionFightMonster = gameplay._monsters[0]
	var original_position := monster.global_position
	var original_rotation := monster.rotation
	monster.global_position = Vector3(-20.8, 0.02, -18.0)
	_check(monster._has_obstacle(Vector3.LEFT, 1.0), "Les monstres détectent les collisions du décor")
	monster._move_in_direction(Vector3.LEFT, 3.0)
	_check(monster.global_position.x > -21.5, "Le recul ne traverse pas la limite de la carte")
	monster.global_position = Vector3(0.0, 0.02, -18.0)
	monster.rotation.y = 0.0
	var movement_start := monster.global_position
	for _step: int in 12:
		monster._move_toward(Vector3(5.0, 0.02, -18.0), 2.0, 0.1)
	var displacement := monster.global_position - movement_start
	var visual_forward := -monster.global_basis.z
	visual_forward.y = 0.0
	_check(displacement.length() > 0.2 and displacement.normalized().dot(visual_forward.normalized()) > 0.98, "Le monstre avance dans la direction de son corps")
	monster.global_position = Vector3(0.0, 0.02, -18.0)
	monster.apply_repel(Vector3(0.0, 0.02, -17.0), 1.5, 8.0)
	var repel_start := monster.global_position
	for _step: int in 16:
		monster._physics_process(0.1)
	_check(monster.global_position.distance_to(repel_start) >= 5.0, "Un repoussement efficace crée une vraie fenêtre d’action")
	_check(monster.get_state_name() == "RECOVERING", "Le monstre récupère brièvement après le recul")
	monster.global_position = original_position
	monster.rotation = original_rotation
	monster._repel_velocity = Vector3.ZERO
	monster._set_state(FactionFightMonster.State.IDLE, 0.1)


func _test_voluntary_exit_prompt(gameplay: FactionFightGameplay) -> void:
	var original_position := gameplay._player.global_position
	gameplay._mission_index = FactionFightGameplay.MISSIONS.size()
	gameplay._player.global_position = gameplay._portal_interaction_position()
	gameplay._update_interaction_prompt()
	_check(not gameplay._completed, "Approcher le portail ne termine pas la partie")
	_check(gameplay._hud._prompt_action_label.text == "QUITTER CHASEWEEN", "Le portail annonce une sortie volontaire avec E")
	gameplay._player.global_position = original_position


func _test_random_roll(gameplay: FactionFightGameplay) -> void:
	gameplay._random.seed = 20261024
	var seen: Dictionary[int, bool] = {}
	var all_rolls_valid := true
	for index: int in 500:
		var amount := gameplay._roll_theft_amount()
		all_rolls_valid = all_rolls_valid and amount >= 1 and amount <= 5
		seen[amount] = true
	_check(all_rolls_valid, "Tous les tirages restent entre 1 et 5")
	_check(seen.size() == 5, "Les cinq résultats de vol sont atteignables")


func _test_theft_rules(gameplay: FactionFightGameplay) -> void:
	var monster: FactionFightMonster = gameplay._monsters[0]
	gameplay._candy = 2
	gameplay._collect_audio_player.stop()
	var stolen := gameplay._steal_candy(monster)
	_check(stolen >= 1 and stolen <= 2, "Le vol réel est limité au score disponible")
	_check(gameplay._candy >= 0, "Le score ne devient pas négatif")
	_check(not gameplay._collect_audio_player.playing, "Un vol ennemi ne joue pas le son officiel de collecte")
	gameplay._candy = 20
	gameplay._theft_immunity_time = 0.0
	gameplay._on_player_bumped(gameplay._monsters[0], Vector3.RIGHT, 0.0)
	var after_first_contact := gameplay._candy
	gameplay._on_player_bumped(gameplay._monsters[1], Vector3.LEFT, 0.0)
	_check(gameplay._candy == after_first_contact, "Deux contacts simultanés ne provoquent qu'un vol")
	_check(is_equal_approx(gameplay._theft_immunity_time, 3.0), "L'immunité globale dure trois secondes")
	_check(gameplay._hud._candy_label.text == tr("CHASE_HUD_CANDY") % gameplay._candy, "Le HUD est actualisé immédiatement")


func _test_protections(gameplay: FactionFightGameplay) -> void:
	var monster: FactionFightMonster = gameplay._monsters[2]
	gameplay._candy = 20
	gameplay._theft_immunity_time = 0.0
	gameplay._shield_time = 8.0
	gameplay._on_player_bumped(monster, Vector3.RIGHT, 0.0)
	_check(gameplay._candy == 20, "Le bouclier empêche le vol")
	gameplay._shield_time = 0.0
	gameplay._theft_immunity_time = 0.0
	monster.apply_stun(2.0)
	gameplay._on_player_bumped(monster, Vector3.RIGHT, 0.0)
	_check(gameplay._candy == 20, "Un monstre neutralisé ne vole pas")
	_check(gameplay._theft_immunity_time == 0.0, "Un contact neutralisé ne consomme pas l'immunité")


func _test_exit_guarantee(gameplay: FactionFightGameplay) -> void:
	gameplay._candy = 0
	gameplay._zones_completed = 4
	gameplay._mission_index = FactionFightGameplay.MISSIONS.size()
	gameplay._player.global_position = gameplay._portal_interaction_position()
	var interact_event := InputEventKey.new()
	interact_event.pressed = true
	interact_event.physical_keycode = KEY_E
	gameplay._unhandled_input(interact_event)
	_check(gameplay._completed, "E déclenche la sortie volontaire au portail")
	_check(gameplay._candy == 20, "La sortie garantit vingt CANDY")
	_check(int(gameplay.result_data.candy_amount) == 20, "Le résultat local contient le minimum garanti")
	_check(gameplay._hud._summary_overlay.candy_score_label.text == "CANDY : 20", "La carte commune affiche le score local CHASEWEEN")
	_check((tr("CHASE_HUD_SUMMARY_BONUS") % 20) in gameplay._hud._summary_candy.text, "Le complément est expliqué dans le résumé")
	_check((tr("CHASE_HUD_SUMMARY_EXIT") % "PORTAIL") in gameplay._hud._summary_candy.text, "La sortie volontaire est indiquée")
	_check(gameplay._hud._summary_button.text == ResultOverlay.EXIT_TEXT, "CHASEWEEN affiche Sortir dans la rue")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Le résumé de sortie volontaire libère et affiche la souris")
	gameplay._complete_world()
	_check(gameplay._candy == 20, "La garantie de sortie ne peut pas être réappliquée")
	_check(gameplay._completed, "Les interactions locales sont arrêtées après la sortie")
	for monster: FactionFightMonster in gameplay._monsters:
		_check(not monster.is_physics_processing(), "%s s’arrête à la fin" % monster.display_name)


func _test_auto_finish() -> void:
	var packed_scene := load(SCENE_PATH) as PackedScene
	var scene := packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var gameplay := scene.get_node("FactionFightGameplay") as FactionFightGameplay
	gameplay._candy = 12
	gameplay._session_time = 239.9
	gameplay._update_corruption(0.1)
	_check(gameplay._finishing, "La fin automatique démarre à 240 secondes")
	_check(gameplay._hud._cinematic_overlay.visible, "Le message du Dernier Sort est affiché")
	gameplay._finish_final_spell()
	_check(gameplay._completed, "Le Dernier Sort termine le mini-jeu sans défaite")
	_check(gameplay._candy == 20, "La fin automatique applique aussi le minimum garanti")
	_check((tr("CHASE_HUD_SUMMARY_EXIT") % "DERNIER SORT") in gameplay._hud._summary_candy.text, "Le résumé distingue la fin automatique")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Le résumé de fin automatique libère et affiche la souris")
	scene.queue_free()
	await process_frame


func _test_ghost_lamp_impacts() -> void:
	var packed_scene := load(SCENE_PATH) as PackedScene
	var scene := packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var gameplay := scene.get_node("FactionFightGameplay") as FactionFightGameplay
	gameplay._tool_slots.clear()
	gameplay._equip_tool(&"ghost_lamp", 4)
	for monster: FactionFightMonster in gameplay._monsters:
		monster.global_position = Vector3(100.0, 0.02, 100.0)
	var beam := gameplay._aim_preview.get_node_or_null("SpectralBeam") as MeshInstance3D
	var beam_material := beam.get_active_material(0) as ShaderMaterial if beam != null else null
	gameplay._use_ghost_lamp()
	_check(gameplay.find_children("SpectralImpact", "Node3D", true, false).is_empty(), "La lampe ne crée aucun impact sans cible réellement touchée")
	_check(beam_material != null and is_equal_approx(float(beam_material.get_shader_parameter(&"impulse")), 1.0), "Le clic produit une impulsion visuelle même sans cible")
	_check(gameplay._item_charges == 4, "Une utilisation sans cible ne modifie pas les charges")
	var target: FactionFightMonster = gameplay._monsters[0]
	var forward := -gameplay._player.global_basis.z
	forward.y = 0.0
	target.global_position = gameplay._player.global_position + forward.normalized() * 3.0
	var beam_before := gameplay._aim_preview.get_node_or_null("SpectralBeam")
	gameplay._use_ghost_lamp()
	_check(gameplay.find_children("SpectralImpact", "Node3D", true, false).size() == 1, "Un impact spectral apparaît uniquement sur le monstre touché")
	_check(gameplay._aim_preview.get_node_or_null("SpectralBeam") == beam_before, "L’impulsion réutilise le faisceau permanent sans superposition")
	_check(gameplay._item_charges == 3, "La lampe conserve sa consommation normale d’une charge")
	scene.queue_free()
	await process_frame


func _zone_for_z(z_position: float) -> int:
	if z_position > -49.0:
		return 0
	if z_position > -113.0:
		return 1
	if z_position > -195.0:
		return 2
	return 3


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("FACTION_FIGHT_THEFT_TESTS_OK")
		quit(0)
	else:
		print("FACTION_FIGHT_THEFT_TESTS_FAILED: ", _failures)
		quit(1)
