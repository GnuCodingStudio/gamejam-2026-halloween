extends SceneTree

const FallProtectionScript := preload("res://scenes/minigames/faction_fight/gameplay/FallProtection.gd")

const SCENE_PATH := "res://scenes/minigames/faction_fight/Chaseween.tscn"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load(SCENE_PATH) as PackedScene
	_check(packed_scene != null, "La scène FactionFight charge avec ses collisions")
	if packed_scene == null:
		_finish()
		return
	var scene := packed_scene.instantiate() as Node3D
	root.add_child(scene)
	for _frame: int in 6:
		await physics_frame
	_test_ground_and_boundaries(scene)
	_test_environment_obstacles(scene)
	var gameplay := scene.get_node_or_null("FactionFightGameplay") as FactionFightGameplay
	_check(gameplay != null, "Le gameplay local est disponible")
	if gameplay != null:
		_test_interactive_collisions(gameplay)
		_test_route_and_patrol_clearance(gameplay)
		await _test_fall_protection(scene, gameplay)
	scene.queue_free()
	await process_frame
	await physics_frame
	_finish()


func _test_ground_and_boundaries(scene: Node3D) -> void:
	var ground := scene.get_node_or_null("Ground/GroundCollision") as StaticBody3D
	_check(ground != null and ground.collision_layer == 2, "Le terrain conserve sa couche Floor")
	_check(ground != null and ground.get_child_count() == 5, "Les cinq surfaces jouables ont une collision")
	var boundaries := scene.get_node_or_null("Ground/MapBoundaries") as StaticBody3D
	_check(boundaries != null and boundaries.collision_layer == 4, "MapBoundaries utilise la couche Wall")
	_check(boundaries != null and boundaries.get_child_count() >= 19, "La frontière suit les cinq sections, les ponts et leurs raccords")
	if boundaries == null:
		return
	for child: Node in boundaries.get_children():
		var collision := child as CollisionShape3D
		var box := collision.shape as BoxShape3D if collision != null else null
		_check(box != null and box.size.y >= 6.0, "%s empêche le franchissement par saut" % child.name)
	var entry_left := boundaries.get_node("BridgeEntryLeft") as CollisionShape3D
	var entry_right := boundaries.get_node("BridgeEntryRight") as CollisionShape3D
	var left_box := entry_left.shape as BoxShape3D
	var right_box := entry_right.shape as BoxShape3D
	var gap_start: float = entry_left.position.x + left_box.size.x * entry_left.scale.x * 0.5
	var gap_end: float = entry_right.position.x - right_box.size.x * entry_right.scale.x * 0.5
	_check(gap_end - gap_start >= 7.0, "L’entrée du pont principal reste ouverte")


func _test_environment_obstacles(scene: Node3D) -> void:
	_check(scene.has_node("Zone1_LeJardinOublie/Tree01/Collision"), "Les arbres morts restent solides")
	_check(scene.has_node("Zone1_LeJardinOublie/ElderTree/Collision"), "Les arbres anciens restent solides")
	_check(scene.has_node("Zone2_LaForetDesRacines/Rock01/Collision"), "Les rochers restent solides")
	_check(scene.has_node("Zone2_LaForetDesRacines/Root01/Collision"), "Les racines volumineuses sont solides")
	_check(scene.has_node("Zone3_LesPontsDeSirop/MainBridge/FloorCollision"), "Le pont principal possède un plancher physique")
	_check(scene.has_node("Zone3_LesPontsDeSirop/MainBridge/RailCollisions"), "Le pont principal possède des garde-corps physiques")
	var sanctuary := scene.get_node_or_null("Zone4_LeSanctuaireCorrompu/Sanctuary") as Node3D
	_check(sanctuary != null and sanctuary.has_node("WalkableCollision/DaisShape"), "Le socle du sanctuaire reste praticable")
	var structures := sanctuary.get_node_or_null("StructureCollision") as StaticBody3D if sanctuary != null else null
	_check(structures != null and structures.collision_layer == 4, "Les structures du sanctuaire sont des obstacles")
	_check(structures != null and structures.get_child_count() == 5, "Mur, piliers et tours du sanctuaire sont couverts")


func _test_interactive_collisions(gameplay: FactionFightGameplay) -> void:
	var solid_count: int = 0
	var syrup_capsule: FactionFightPickup
	var spectral_altar: FactionFightPickup
	for pickup: FactionFightPickup in gameplay._pickups:
		if pickup.item_id == &"syrup_capsule":
			syrup_capsule = pickup
		if pickup.required_item_id == &"spectral_badge":
			spectral_altar = pickup
		var body := pickup.get_node_or_null("PhysicalCollision") as StaticBody3D
		if pickup.kind == FactionFightPickup.Kind.CHEST or pickup.kind == FactionFightPickup.Kind.DEVICE:
			_check(body != null and body.collision_layer == 4, "%s possède une collision physique locale" % pickup.display_name)
			solid_count += 1
		else:
			_check(body == null, "%s reste collectable sans obstacle solide" % pickup.display_name)
	_check(solid_count == 7, "Les trois coffres et quatre mécanismes sont solides")
	var supports := get_nodes_in_group(&"faction_fight_support")
	_check(supports.size() == 7, "Les sept supports existants sont conservés")
	for support: Node in supports:
		var collision := support.get_node_or_null("SupportCollision") as StaticBody3D
		_check(collision != null and collision.collision_layer == 4, "%s possède une collision simple" % support.name)
	_check(syrup_capsule != null, "La capsule de sirop est présente")
	if syrup_capsule != null:
		_check(syrup_capsule.global_position.is_equal_approx(Vector3(-5.0, 0.45, -148.0)), "La capsule de sirop repose au centre du pont praticable")
	_check(spectral_altar != null, "L’autel spectral est présent")
	if spectral_altar != null:
		var portal_distance := spectral_altar.global_position.distance_to(gameplay._portal.global_position)
		_check(portal_distance > FactionFightGameplay.PORTAL_INTERACTION_RADIUS + 4.0, "L’autel spectral ne concurrence plus la zone de sortie")


func _test_route_and_patrol_clearance(gameplay: FactionFightGameplay) -> void:
	var probe := SphereShape3D.new()
	probe.radius = 0.45
	var main_route: Array[Vector3] = [
		Vector3(0.0, 0.75, 8.0),
		Vector3(0.0, 0.75, -18.0),
		Vector3(0.0, 0.75, -38.0),
		Vector3(7.0, 0.75, -58.0),
		Vector3(8.0, 0.75, -82.0),
		Vector3(8.0, 0.75, -108.0),
		Vector3(-5.0, 0.75, -126.0),
		Vector3(-5.0, 0.75, -154.0),
		Vector3(-5.0, 0.75, -181.0),
		Vector3(4.0, 0.75, -205.0),
		Vector3(8.0, 0.75, -233.5),
	]
	for point: Vector3 in main_route:
		_check(_position_is_clear(gameplay, probe, point), "Le chemin principal reste libre près de %s" % point)
	for monster: FactionFightMonster in gameplay._monsters:
		var patrol_is_clear: bool = true
		var obstacle_name := ""
		for point: Vector3 in monster._patrol_points:
			var obstacle := _obstacle_at(gameplay, probe, point + Vector3.UP * 0.75)
			if obstacle != null and obstacle.name != &"MapBoundaries":
				patrol_is_clear = false
				obstacle_name = "%s près de %s" % [obstacle.get_path(), point]
				break
		_check(patrol_is_clear, "%s conserve une ronde sans obstacle%s" % [monster.display_name, "" if obstacle_name.is_empty() else " (%s)" % obstacle_name])


func _position_is_clear(gameplay: FactionFightGameplay, probe: Shape3D, point: Vector3) -> bool:
	return _obstacle_at(gameplay, probe, point) == null


func _obstacle_at(gameplay: FactionFightGameplay, probe: Shape3D, point: Vector3) -> Node:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.transform = Transform3D(Basis.IDENTITY, point)
	query.collision_mask = 4
	query.collide_with_areas = false
	var hits := gameplay.get_world_3d().direct_space_state.intersect_shape(query, 1)
	return null if hits.is_empty() else hits[0].get("collider") as Node


func _test_fall_protection(scene: Node3D, gameplay: FactionFightGameplay) -> void:
	var player := scene.get_node_or_null("Player") as CharacterBody3D
	var protection := gameplay.get_node_or_null("FallProtection") as FallProtectionScript
	_check(player != null and protection != null, "La protection anti-chute locale est active")
	if player == null or protection == null:
		return
	var safe_position := protection.get_last_safe_position()
	var candy_before: int = gameplay._candy
	var mission_before: int = gameplay._mission_index
	var inventory_before: Dictionary[StringName, bool] = gameplay._inventory.duplicate()
	var session_before: float = gameplay._session_time
	player.global_position = Vector3(safe_position.x, -10.0, safe_position.z)
	player.velocity = Vector3(2.0, -20.0, 1.0)
	await physics_frame
	await physics_frame
	_check(protection.recovery_count == 1, "Une chute sous la carte déclenche un seul sauvetage")
	_check(player.global_position.y >= safe_position.y - 0.1, "Le joueur revient sur sa dernière position stable")
	_check(player.velocity.length() < 1.0, "La vitesse de chute est réinitialisée")
	_check(gameplay._candy == candy_before, "Le sauvetage conserve les CANDY")
	_check(gameplay._mission_index == mission_before, "Le sauvetage conserve la mission")
	_check(gameplay._inventory == inventory_before, "Le sauvetage conserve l’inventaire")
	_check(gameplay._session_time >= session_before, "Le sauvetage ne réinitialise pas la corruption")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("FACTION_FIGHT_COLLISION_TESTS_OK")
		quit(0)
		return
	print("FACTION_FIGHT_COLLISION_TESTS_FAILED: %d" % _failures.size())
	quit(1)
