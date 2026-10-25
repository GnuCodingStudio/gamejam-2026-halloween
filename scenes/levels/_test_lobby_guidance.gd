extends Node


const LOBBY_SCENE_PATH: String = "res://scenes/levels/main.tscn"
const PORTAL_PATHS: Dictionary[StringName, NodePath] = {
	&"candy_bucket": NodePath("CandyBucketPortal"),
	&"labyrinth": NodePath("LabyrinthPortal"),
	&"chaseween": NodePath("ChaseweenPortal"),
	&"faction_territory": NodePath("FactionTerritoryPortal"),
}
const INITIAL_SCORE: int = 73

var _failures: Array[String] = []
var _original_progression: Progression
var _lobby: Node


func _ready() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_original_progression = ProgressionService.data
	ProgressionService.data = Progression.new(0, INITIAL_SCORE, [], false, "Guide")
	await _load_lobby()
	_test_initial_state()

	_complete_in_memory(&"candy_bucket")
	_test_partial_state([&"candy_bucket"])
	_complete_in_memory(&"labyrinth")
	_complete_in_memory(&"chaseween")
	_test_partial_state([&"candy_bucket", &"labyrinth", &"chaseween"])
	_complete_in_memory(&"faction_territory")
	await _test_completed_state()
	await _test_restored_state()
	_finish()


func _load_lobby() -> void:
	var packed_scene: PackedScene = load(LOBBY_SCENE_PATH) as PackedScene
	_check(packed_scene != null, "Le lobby se charge pour le test de guidage")
	if packed_scene == null:
		return
	_lobby = packed_scene.instantiate()
	get_tree().root.add_child(_lobby)
	await get_tree().process_frame
	await get_tree().process_frame


func _test_initial_state() -> void:
	for world_id: StringName in PORTAL_PATHS:
		var portal: LevelPortal = _get_portal(world_id)
		_check(portal != null and portal.light.visible, "%s reste éclairé au départ" % world_id)
		_check(portal != null and portal._light_tween != null, "%s conserve sa pulsation disponible" % world_id)
	var church: ChurchFinaleInteractor = _get_church()
	_check(church != null and not church._available, "L'église reste indisponible au départ")
	_check(church != null and not church.light.visible, "La lumière finale est éteinte au départ")
	_check(_score_is_unchanged(), "L'état initial ne modifie pas les CANDY")


func _test_partial_state(completed_worlds: Array[StringName]) -> void:
	for world_id: StringName in PORTAL_PATHS:
		var portal: LevelPortal = _get_portal(world_id)
		var should_be_completed: bool = completed_worlds.has(world_id)
		_check(
			portal != null and portal.light.visible != should_be_completed,
			"%s possède le bon état lumineux partiel" % world_id
		)
		if should_be_completed:
			_check(portal._light_tween == null, "%s arrête son tween après validation" % world_id)
	var church: ChurchFinaleInteractor = _get_church()
	_check(church != null and not church.light.visible, "L'église reste normale pendant la progression partielle")
	_check(_score_is_unchanged(), "Le guidage partiel ne modifie pas les CANDY")


func _test_completed_state() -> void:
	for world_id: StringName in PORTAL_PATHS:
		var portal: LevelPortal = _get_portal(world_id)
		_check(portal != null and not portal.light.visible, "%s s'éteint après les quatre mondes" % world_id)

	var church: ChurchFinaleInteractor = _get_church()
	_check(church != null and church._available and church.light.visible, "L'église s'illumine après les quatre mondes")
	_check(
		ChurchFinaleInteractor.LIGHT_MIN_ENERGY > LevelPortal.PULSE_MAX_ENERGY,
		"L'intensité minimale de l'église dépasse le pic d'une porte ordinaire"
	)
	_check(
		is_equal_approx(ChurchFinaleInteractor.LIGHT_MAX_ENERGY / ChurchFinaleInteractor.LIGHT_MIN_ENERGY, 2.5),
		"Le pic lumineux atteint deux fois et demie l'intensité minimale"
	)
	_check(
		is_equal_approx(ChurchFinaleInteractor.LIGHT_PULSE_DURATION * 2.0, 4.0),
		"Le cycle lumineux complet dure quatre secondes"
	)
	_check(not church.light.shadow_enabled, "La lumière finale n'ajoute aucune ombre dynamique")
	_check(church.light.omni_range <= 8.0, "La lumière finale reste localisée autour de l'église")
	_check(
		church.light.light_color.r > church.light.light_color.g
		and church.light.light_color.g > church.light.light_color.b,
		"La lumière finale conserve sa teinte chaude orangée"
	)
	var minimum_energy: float = church.light.light_energy
	await get_tree().create_timer(1.0).timeout
	var rising_energy: float = church.light.light_energy
	_check(rising_energy > minimum_energy, "La pulsation augmente progressivement l'intensité")
	await get_tree().create_timer(1.05).timeout
	var peak_energy: float = church.light.light_energy
	_check(peak_energy > rising_energy, "Le pic lumineux est nettement distinct de la montée")
	await get_tree().create_timer(1.0).timeout
	var falling_energy: float = church.light.light_energy
	_check(falling_energy < peak_energy, "La pulsation redescend progressivement après le pic")
	_check(
		falling_energy >= ChurchFinaleInteractor.LIGHT_MIN_ENERGY
		and falling_energy <= ChurchFinaleInteractor.LIGHT_MAX_ENERGY,
		"La pulsation reste entre ses limites sans extinction"
	)
	await get_tree().create_timer(2.0).timeout
	_check(church.light.light_energy > ChurchFinaleInteractor.LIGHT_MIN_ENERGY, "La respiration continue sur un second cycle")

	var player: CharacterBody3D = _lobby.get_node("Player") as CharacterBody3D
	church._on_body_entered(player)
	_check(church.prompt.visible, "Le prompt du bilan reste disponible près de l'église")
	_check(church.prompt_label.text == ChurchFinaleInteractor.PROMPT_TEXT, "Le message d'interaction existant est conservé")
	var tween_id: int = church._light_tween.get_instance_id()
	church._on_finale_closed()
	_check(church._light_tween.get_instance_id() == tween_id, "La fermeture du bilan ne duplique pas la pulsation")
	_check(_score_is_unchanged(), "Le guidage final ne modifie pas les CANDY")


func _test_restored_state() -> void:
	_lobby.queue_free()
	await get_tree().process_frame
	ProgressionService.data = Progression.new(
		0,
		INITIAL_SCORE,
		ProgressionService.AVAILABLE_WORLD_IDS.duplicate(),
		false,
		"Guide"
	)
	await _load_lobby()
	for world_id: StringName in PORTAL_PATHS:
		var portal: LevelPortal = _get_portal(world_id)
		_check(portal != null and not portal.light.visible, "%s restaure son état terminé" % world_id)
	var church: ChurchFinaleInteractor = _get_church()
	_check(church != null and church.light.visible and church._available, "La sauvegarde complète restaure le guidage de l'église")
	_check(_score_is_unchanged(), "La restauration lumineuse ne modifie pas les CANDY")


func _complete_in_memory(world_id: StringName) -> void:
	ProgressionService.data.completed_worlds.append(world_id)
	ProgressionService.world_completed.emit(world_id, 0)
	ProgressionService.world_progress_changed.emit(
		ProgressionService.get_completed_world_count(),
		ProgressionService.get_available_world_count()
	)


func _get_portal(world_id: StringName) -> LevelPortal:
	return _lobby.get_node_or_null(PORTAL_PATHS[world_id]) as LevelPortal


func _get_church() -> ChurchFinaleInteractor:
	return _lobby.get_node_or_null("ChurchFinaleInteractor") as ChurchFinaleInteractor


func _score_is_unchanged() -> bool:
	return ProgressionService.get_total_candy() == INITIAL_SCORE


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if is_instance_valid(_lobby):
		_lobby.queue_free()
	ProgressionService.data = _original_progression
	if _failures.is_empty():
		print("LOBBY_GUIDANCE_TESTS_OK")
		get_tree().quit(0)
		return
	print("LOBBY_GUIDANCE_TESTS_FAILED: %d" % _failures.size())
	get_tree().quit(1)
