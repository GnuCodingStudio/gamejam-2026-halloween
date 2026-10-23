extends SceneTree

const SCENE_PATH := "res://scenes/minigames/faction_fight/FactionFight.tscn"

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

	_test_population(gameplay)
	_test_obstacle_detection(gameplay)
	_test_random_roll(gameplay)
	_test_theft_rules(gameplay)
	_test_protections(gameplay)
	_test_exit_guarantee(gameplay)

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
	_check(model_counts.get(FactionFightGameplay.GOBLIN_MODEL, 0) == 4, "Quatre Peppermint Goblin")
	_check(model_counts.get(FactionFightGameplay.PALADIN_MODEL, 0) == 4, "Quatre Pumpkin Paladin")
	_check(model_counts.get(FactionFightGameplay.CONQUEROR_MODEL, 0) == 4, "Quatre Candy Corn Conqueror")
	_check(zone_counts == [2, 3, 3, 4], "Répartition 2 / 3 / 3 / 4 dans les zones")


func _test_obstacle_detection(gameplay: FactionFightGameplay) -> void:
	var monster: FactionFightMonster = gameplay._monsters[0]
	var original_position := monster.global_position
	monster.global_position = Vector3(-20.8, 0.02, -18.0)
	_check(monster._has_obstacle(Vector3.LEFT, 1.0), "Les monstres détectent les collisions du décor")
	monster.global_position = original_position


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
	var stolen := gameplay._steal_candy(monster)
	_check(stolen >= 1 and stolen <= 2, "Le vol réel est limité au score disponible")
	_check(gameplay._candy >= 0, "Le score ne devient pas négatif")
	gameplay._candy = 20
	gameplay._theft_immunity_time = 0.0
	gameplay._on_player_bumped(gameplay._monsters[0], Vector3.RIGHT, 0.0)
	var after_first_contact := gameplay._candy
	gameplay._on_player_bumped(gameplay._monsters[1], Vector3.LEFT, 0.0)
	_check(gameplay._candy == after_first_contact, "Deux contacts simultanés ne provoquent qu'un vol")
	_check(is_equal_approx(gameplay._theft_immunity_time, 3.0), "L'immunité globale dure trois secondes")
	_check(gameplay._hud._candy_label.text == "CANDY  %d" % gameplay._candy, "Le HUD est actualisé immédiatement")


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
	gameplay._complete_world()
	_check(gameplay._candy == 20, "La sortie garantit vingt CANDY")
	_check(int(gameplay.result_data.candy_amount) == 20, "Le résultat local contient le minimum garanti")
	_check("GARANTIE DE SORTIE : +20 CANDY" in gameplay._hud._summary_candy.text, "Le complément est expliqué dans le résumé")
	gameplay._complete_world()
	_check(gameplay._candy == 20, "La garantie de sortie ne peut pas être réappliquée")
	_check(gameplay._completed, "Les interactions locales sont arrêtées après la sortie")
	for monster: FactionFightMonster in gameplay._monsters:
		_check(not monster.is_physics_processing(), "%s s’arrête à la fin" % monster.display_name)


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
