extends SceneTree

const SCENE_PATH := "res://scenes/minigames/faction_fight/Chaseween.tscn"
const MODEL_PATHS: Array[String] = [
	"res://assets/chaseween/objets/Chaseween_Candy_Tree.glb",
	"res://assets/chaseween/objets/Chaseween_Haunted_Lamppost.glb",
	"res://assets/chaseween/objets/Chaseween_Crystal_Mushrooms.glb",
]
const MAIN_ROUTE: Array[Vector3] = [
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

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_model_resources()
	var scene := (load(SCENE_PATH) as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	for _frame: int in 6:
		await physics_frame
	var decorations := scene.get_node_or_null("ChaseweenDecorations") as Node3D
	_check(decorations != null, "Le parent ChaseweenDecorations existe")
	if decorations != null:
		_test_instances(decorations)
		_test_lighting(decorations)
		_test_ground_support(decorations)
		_test_navigation_clearance(scene, decorations)
	_test_gameplay_references(scene)
	scene.queue_free()
	await process_frame
	await physics_frame
	_finish()


func _test_model_resources() -> void:
	for path: String in MODEL_PATHS:
		var packed := load(path) as PackedScene
		_check(packed != null, "%s se charge" % path.get_file())
		if packed == null:
			continue
		var instance := packed.instantiate()
		_check(not instance.find_children("*", "MeshInstance3D", true, false).is_empty(), "%s contient une géométrie visible" % path.get_file())
		_check(instance.find_children("*", "AnimationPlayer", true, false).is_empty(), "%s ne simule pas d’animation absente du GLB" % path.get_file())
		instance.free()


func _test_instances(decorations: Node3D) -> void:
	var groups: Array[Node] = [
		decorations.get_node("CandyTrees"),
		decorations.get_node("HauntedLampposts"),
		decorations.get_node("CrystalMushrooms"),
	]
	var expected_counts: Array[int] = [5, 4, 8]
	for index: int in groups.size():
		_check(groups[index].get_child_count() == expected_counts[index], "%s contient %d instances" % [groups[index].name, expected_counts[index]])
	for decoration: Node in decorations.find_children("*", "ChaseweenDecoration", true, false):
		var visual := decoration as ChaseweenDecoration
		var collision := visual.get_node_or_null("Collision") as StaticBody3D
		var shape := collision.get_child(0) as CollisionShape3D if collision != null and collision.get_child_count() > 0 else null
		_check(collision != null and collision.collision_layer == 4 and collision.collision_mask == 0, "%s possède une collision décorative isolée" % visual.name)
		_check(collision != null and collision.top_level and collision.global_basis.get_scale().is_equal_approx(Vector3.ONE), "%s garde une collision physique non déformée" % visual.name)
		_check(shape != null and not shape.disabled, "%s active réellement sa collision" % visual.name)
		_check(shape != null and (shape.shape is CylinderShape3D or shape.shape is BoxShape3D), "%s utilise une collision primitive" % visual.name)
		_check(_collision_fits_asset(visual, shape), "%s couvre le volume solide utile du modèle" % visual.name)
		_check(_collision_is_queryable(visual, collision), "%s bloque un volume de joueur" % visual.name)
		_check(visual.find_children("*", "Area3D", true, false).is_empty(), "%s n’est ni récoltable ni interactif" % visual.name)
		_check(visual.find_children("*", "Label3D", true, false).is_empty(), "%s n’ajoute aucun texte de gameplay" % visual.name)
		for mesh_node: Node in visual.find_children("*", "MeshInstance3D", true, false):
			var mesh := mesh_node as MeshInstance3D
			var bounds := mesh.global_transform * mesh.get_aabb()
			_check(bounds.position.y >= -0.06 and bounds.position.y <= 0.12, "%s repose au niveau du sol" % visual.name)
			_check(mesh.visibility_range_end > 0.0 and mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s utilise le culling et ne projette pas d’ombre" % visual.name)


func _test_lighting(decorations: Node3D) -> void:
	var lights := decorations.get_node("AccentLights").get_children()
	_check(lights.size() == 4, "Quatre lumières d’accent seulement sont ajoutées")
	for child: Node in lights:
		var light := child as OmniLight3D
		_check(light != null and light.light_energy <= 0.32, "%s reste une lumière subtile" % child.name)
		_check(light != null and not light.shadow_enabled, "%s ne calcule pas d’ombres dynamiques" % child.name)


func _collision_is_queryable(visual: ChaseweenDecoration, expected_body: StaticBody3D) -> bool:
	var probe := CapsuleShape3D.new()
	probe.radius = 0.375
	probe.height = 1.5
	var shape := expected_body.get_child(0) as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.transform = Transform3D(Basis.IDENTITY, shape.global_position)
	query.collision_mask = 4
	query.collide_with_areas = false
	for hit: Dictionary in visual.get_world_3d().direct_space_state.intersect_shape(query, 16):
		if hit.get("collider") == expected_body:
			return true
	return false


func _collision_fits_asset(visual: ChaseweenDecoration, collision: CollisionShape3D) -> bool:
	var instance_scale := visual.global_basis.get_scale().abs()
	match visual.asset_key:
		&"candy_tree":
			var tree_shape := collision.shape as CylinderShape3D
			return tree_shape != null and tree_shape.radius / maxf(instance_scale.x, instance_scale.z) >= 0.8
		&"haunted_lamppost":
			var lamp_shape := collision.shape as CylinderShape3D
			return lamp_shape != null and lamp_shape.radius / maxf(instance_scale.x, instance_scale.z) >= 0.49
		&"crystal_mushrooms":
			var crystal_shape := collision.shape as BoxShape3D
			return crystal_shape != null and crystal_shape.size.x / instance_scale.x >= 3.1 and crystal_shape.size.z / instance_scale.z >= 2.7
		_:
			return false


func _test_ground_support(decorations: Node3D) -> void:
	var space := decorations.get_world_3d().direct_space_state
	for decoration: Node in decorations.find_children("*", "ChaseweenDecoration", true, false):
		var visual := decoration as ChaseweenDecoration
		var query := PhysicsRayQueryParameters3D.create(visual.global_position + Vector3.UP * 2.0, visual.global_position + Vector3.DOWN * 2.0, 2)
		query.collide_with_areas = false
		_check(not space.intersect_ray(query).is_empty(), "%s est posé sur une surface de sol" % visual.name)


func _test_navigation_clearance(scene: Node3D, decorations: Node3D) -> void:
	var gameplay := scene.get_node("FactionFightGameplay") as FactionFightGameplay
	var probe := SphereShape3D.new()
	probe.radius = 0.55
	for point: Vector3 in MAIN_ROUTE:
		_check(not _hits_new_decoration(gameplay, probe, point), "Le chemin principal reste libre près de %s" % point)
	for monster: FactionFightMonster in gameplay._monsters:
		for point: Vector3 in monster._patrol_points:
			var obstacle := _new_decoration_at(gameplay, probe, point + Vector3.UP * 0.75)
			_check(obstacle == null, "%s ne rencontre aucun nouveau décor sur sa ronde%s" % [monster.display_name, "" if obstacle == null else " (%s)" % obstacle.get_parent().name])
	for pickup: FactionFightPickup in gameplay._pickups:
		var nearest_distance := 999.0
		for decoration: Node in decorations.find_children("*", "ChaseweenDecoration", true, false):
			nearest_distance = minf(nearest_distance, pickup.global_position.distance_to((decoration as Node3D).global_position))
		_check(nearest_distance >= 4.0, "%s conserve son espace d’accès" % pickup.display_name)


func _hits_new_decoration(gameplay: FactionFightGameplay, shape: Shape3D, point: Vector3) -> bool:
	return _new_decoration_at(gameplay, shape, point) != null


func _new_decoration_at(gameplay: FactionFightGameplay, shape: Shape3D, point: Vector3) -> Node:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, point)
	query.collision_mask = 4
	query.collide_with_areas = false
	for hit: Dictionary in gameplay.get_world_3d().direct_space_state.intersect_shape(query, 16):
		var collider := hit.get("collider") as Node
		if collider != null and "ChaseweenDecorations" in str(collider.get_path()):
			return collider
	return null


func _test_gameplay_references(scene: Node3D) -> void:
	var gameplay := scene.get_node_or_null("FactionFightGameplay") as FactionFightGameplay
	_check(gameplay != null and gameplay._monsters.size() == 12, "Les douze monstres de gameplay sont conservés")
	_check(gameplay != null and gameplay._pickups.size() == 24, "Les objets et récompenses de gameplay sont conservés")
	_check(gameplay != null and is_instance_valid(gameplay._portal), "Le portail final reste disponible")
	_check(gameplay != null and is_equal_approx(gameplay.SESSION_DURATION, 240.0), "La corruption dure quatre minutes")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("FACTION_FIGHT_DECORATION_TESTS_OK")
		quit(0)
		return
	print("FACTION_FIGHT_DECORATION_TESTS_FAILED: %d" % _failures.size())
	quit(1)
