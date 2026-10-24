class_name FactionFightGameplay
extends Node3D

const MonsterScript := preload("res://scenes/minigames/faction_fight/gameplay/MonsterAgent.gd")
const PickupScript := preload("res://scenes/minigames/faction_fight/gameplay/GameplayPickup.gd")
const HUDScript := preload("res://scenes/minigames/faction_fight/gameplay/FactionFightHUD.gd")
const VFX := preload("res://scenes/minigames/faction_fight/gameplay/FactionFightVFX.gd")
const PresentationScript := preload("res://scenes/minigames/faction_fight/gameplay/ChaseweenItemPresentation.gd")
const FallProtectionScript := preload("res://scenes/minigames/faction_fight/gameplay/FallProtection.gd")
const MissionMarkerScript := preload("res://scenes/minigames/faction_fight/gameplay/MissionMarker.gd")
const COLLECT_SOUND: AudioStream = preload("res://assets/audio/collect.wav")
const CRYSTALBERRY_SCENE: PackedScene = preload("res://objects/candy_crystalberry.tscn")
const PUMPKIN_SCENE: PackedScene = preload("res://objects/candy_pumpkin.tscn")

const GOBLIN_MODEL := "res://assets/chaseween/Meshy_AI_Peppermint_Goblin_All_Animations.glb"
const PALADIN_MODEL := "res://assets/chaseween/Meshy_AI_Pumpkin_Paladin_All_Animations.glb"
const CONQUEROR_MODEL := "res://assets/chaseween/Meshy_AI_Candy_Corn_Conqueror_All_Animations.glb"
const ZONE_THRESHOLDS: Array[float] = [-45.0, -112.0, -195.0, -230.0]
const THEFT_IMMUNITY_DURATION: float = 3.0
const MINIMUM_EXIT_CANDY: int = 20
const SESSION_DURATION: float = 240.0
const RESCUE_HINT_DELAY: float = 40.0
const PORTAL_INTERACTION_RADIUS: float = 2.4
const PORTAL_MIN_FRONT_DISTANCE: float = 0.6
const PORTAL_MAX_SIDE_DISTANCE: float = 2.8
const HEART_POSITION: Vector3 = Vector3(2.0, 1.05, -238.0)
const WORLD_ID: StringName = &"chaseween"
const LOBBY_SCENE_PATH: String = "res://scenes/levels/main.tscn"
const LOBBY_RETURN_META: StringName = &"chaseween_return_to_door"
const MISSIONS: Array[Dictionary] = [
	{
		"id": &"garden_reserve",
		"title": "MISSION 1 / 4 — LE VOLEUR DE BONBONS",
		"objective": "Prends le bâton, repousse le Gobelin et ouvre la réserve.",
		"hint": "La réserve brille près du Gobelin du Jardin.",
		"target": Vector3(7.0, 0.05, -38.0),
	},
	{
		"id": &"forest_locker",
		"title": "MISSION 2 / 4 — LE CASIER HANTÉ",
		"objective": "Trouve la clé caramel puis ouvre le casier gardé par le Paladin.",
		"hint": "La clé est au bord du chemin avant le Paladin.",
		"target": Vector3(-11.0, 0.05, -92.0),
	},
	{
		"id": &"syrup_cache",
		"title": "MISSION 3 / 4 — LE CONQUÉRANT DU SIROP",
		"objective": "Teste une affinité sur le Conquérant puis ouvre la cache de sirop.",
		"hint": "Le coffre est sur le pont, tout près du Conquérant.",
		"target": Vector3(4.0, 0.05, -176.0),
	},
	{
		"id": &"sanctuary_treasure",
		"title": "MISSION 4 / 4 — LE TRÉSOR DU SANCTUAIRE",
		"objective": "Atteins le sanctuaire et ouvre son dernier coffre.",
		"hint": "Suis le faisceau doré au fond du sanctuaire.",
		"target": Vector3(-8.0, 0.05, -233.0),
	},
]
const ITEM_NAMES: Dictionary = {
	&"candy_cane": "BÂTON BONBON",
	&"sugar_spray": "SPRAY SUCRÉ",
	&"caramel_shield": "BOUCLIER CARAMEL",
	&"ghost_lamp": "LAMPE FANTÔME",
}
const KEY_ITEM_NAMES: Dictionary = {
	&"caramel_key": "CLÉ CARAMEL",
	&"sugar_crystal": "CRISTAL SUCRÉ",
	&"syrup_capsule": "CAPSULE DE SIROP",
	&"spectral_badge": "INSIGNE SPECTRAL",
	&"chewingland_heart": "CŒUR DE CHEWINGLAND",
}

var result_data: Dictionary = {
	"world_id": "chaseween",
	"candy_amount": 0,
	"completed": false,
}

var _player: CharacterBody3D
var _portal: Node3D
var _hud: FactionFightHUD
var _monsters: Array[FactionFightMonster] = []
var _pickups: Array[FactionFightPickup] = []
var _candy: int = 0
var _zones_completed: int = 0
var _active_item: StringName = &""
var _item_charges: int = 0
var _shield_time: float = 0.0
var _theft_immunity_time: float = 0.0
var _nearest_interactive: FactionFightPickup
var _random := RandomNumberGenerator.new()
var _completed: bool = false
var _next_candy_variant: int = 0
var _collect_audio_player: AudioStreamPlayer
var _inventory: Dictionary[StringName, bool] = {}
var _discoveries: Dictionary[String, int] = {}
var _session_time: float = 0.0
var _finishing: bool = false
var _world_environment: WorldEnvironment
var _moon_light: DirectionalLight3D
var _base_fog_density: float = 0.0
var _base_fog_color: Color
var _base_moon_color: Color
var _base_moon_energy: float = 0.0
var _heart: FactionFightPickup
var _held_tool_visual: PresentationScript
var _fall_protection: FallProtectionScript
var _environment_controller: FactionFightEnvironment
var _portal_light: OmniLight3D
var _base_portal_energy: float = 0.0
var _corruption_particles: GPUParticles3D
var _last_corruption_phase: int = -1
var _tool_slots: Array[Dictionary] = []
var _active_tool_index: int = 0
var _aiming: bool = false
var _aim_preview: Node3D
var _aim_preview_tool_id: StringName = &""
var _mission_index: int = 0
var _mission_elapsed: float = 0.0
var _mission_hint_shown: bool = false
var _objective_marker: Node3D
var _mission_tactical_done: Dictionary[StringName, bool] = {}
var _mouse_was_captured: bool = false
var _return_transition_started: bool = false


func _ready() -> void:
	_player = get_node_or_null("../Player") as CharacterBody3D
	_portal = get_node_or_null("../Zone4_LeSanctuaireCorrompu/ExitPortal") as Node3D
	if _player == null:
		push_error("FactionFight: Player introuvable, gameplay local désactivé.")
		set_process(false)
		set_physics_process(false)
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_create_fall_protection()
	_random.randomize()
	_create_hud()
	_hud.summary_closed.connect(_on_summary_closed)
	_create_collect_audio_player()
	_setup_corruption()
	_create_chewingland_heart()
	_spawn_monsters()
	_spawn_rewards()
	_spawn_unlock_chains()
	_create_objective_marker()
	_refresh_mission()
	_refresh_journal()
	_update_hud()
	_hud.show_gameplay_message("RÉCUPÈRE LE BÂTON BONBON POUR REPOUSSER LE GOBELIN", FactionFightHUD.MessageCategory.OBJECTIVE)


func _process(delta: float) -> void:
	_mouse_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _hud == null or _completed or _finishing:
		return
	_shield_time = maxf(_shield_time - delta, 0.0)
	_theft_immunity_time = maxf(_theft_immunity_time - delta, 0.0)
	_update_corruption(delta)
	_update_heart()
	_update_mission(delta)
	_update_aim_preview()
	_update_zone_progress()
	_update_interaction_prompt()
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if _hud == null or _completed or _finishing or _hud.summary_visible:
		return
	if _hud.is_journal_visible():
		if event is InputEventKey:
			var journal_key := event as InputEventKey
			if journal_key.pressed and not journal_key.echo and journal_key.physical_keycode == KEY_J:
				_hud.toggle_journal()
				_player.process_mode = Node.PROCESS_MODE_INHERIT
				get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"action_activate"):
		_interact()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT and _mouse_was_captured:
			_use_active_item()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_Q:
			_switch_tool()
			get_viewport().set_input_as_handled()
		elif key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_J:
			_hud.toggle_journal()
			_player.process_mode = Node.PROCESS_MODE_DISABLED if _hud.is_journal_visible() else Node.PROCESS_MODE_INHERIT
			get_viewport().set_input_as_handled()


func _create_hud() -> void:
	_hud = HUDScript.new() as FactionFightHUD
	add_child(_hud)


func _create_collect_audio_player() -> void:
	_collect_audio_player = AudioStreamPlayer.new()
	_collect_audio_player.stream = COLLECT_SOUND
	_collect_audio_player.bus = &"SFX"
	add_child(_collect_audio_player)


func _spawn_monsters() -> void:
	# Zone 1 — Jardin oublié : deux rencontres, dont une hors du chemin direct.
	_spawn_goblin("Gobelin du Jardin", Vector3(7.0, 0.02, -42.0), Vector3(5.0, 0.0, -8.0))
	_spawn_conqueror("Conquérant des Ronces", Vector3(-11.0, 0.02, -26.0), Vector3(5.0, 0.0, 1.0))

	# Zone 2 — Forêt des racines : trois gardiens répartis entre chemin et cachettes.
	_spawn_goblin("Gobelin des Racines", Vector3(13.0, 0.02, -72.0), Vector3(6.0, 0.0, -4.0))
	_spawn_paladin("Paladin du Coffre", Vector3(-11.0, 0.02, -91.0), Vector3(5.0, 0.0, 0.0))
	_spawn_conqueror("Conquérant de la Forêt", Vector3(25.0, 0.02, -102.0), Vector3(-5.0, 0.0, 3.0))

	# Zone 3 — Ponts de sirop : trois patrouilles courtes pour préserver les passages.
	_spawn_goblin("Gobelin du Sirop", Vector3(-12.0, 0.02, -126.0), Vector3(5.0, 0.0, 0.0))
	_spawn_paladin("Paladin du Pont", Vector3(-5.0, 0.02, -178.0), Vector3(5.0, 0.0, 0.0))
	_spawn_conqueror("Conquérant du Pont", Vector3(4.0, 0.02, -169.0), Vector3(-4.0, 0.0, 0.0))

	# Zone 4 — Sanctuaire corrompu : quatre gardiens, sans collision bloquante.
	_spawn_goblin("Gobelin du Sanctuaire", Vector3(-8.0, 0.02, -208.0), Vector3(5.0, 0.0, 0.0))
	_spawn_paladin("Paladin Corrompu", Vector3(8.0, 0.02, -217.0), Vector3(7.0, 0.0, 0.0))
	_spawn_paladin("Paladin du Trésor", Vector3(-8.0, 0.02, -233.0), Vector3(5.0, 0.0, 0.0))
	_spawn_conqueror("Conquérant du Portail", Vector3(22.0, 0.02, -226.0), Vector3(0.0, 0.0, 6.0))


func _spawn_goblin(monster_name: String, spawn_position: Vector3, patrol_offset: Vector3) -> void:
	_spawn_monster(
		monster_name,
		GOBLIN_MODEL,
		spawn_position,
		patrol_offset,
		{"monster_type": &"goblin", "patrol_speed": 1.75, "chase_speed": 3.25, "detection_radius": 8.5, "chase_limit": 12.0, "scale": 1.08},
		{"idle": "Alert", "walk": "Walking", "alert": "Alert", "run": "Running", "stunned": "Weapon_Combo_1"}
	)


func _spawn_paladin(monster_name: String, spawn_position: Vector3, patrol_offset: Vector3) -> void:
	_spawn_monster(
		monster_name,
		PALADIN_MODEL,
		spawn_position,
		patrol_offset,
		{"monster_type": &"paladin", "patrol_speed": 0.9, "chase_speed": 1.85, "detection_radius": 8.0, "chase_limit": 10.0, "scale": 1.18},
		{"idle": "Listening_Gesture", "walk": "Walking", "alert": "Listening_Gesture", "run": "Running", "stunned": "Punch_Combo_3"}
	)


func _spawn_conqueror(monster_name: String, spawn_position: Vector3, patrol_offset: Vector3) -> void:
	_spawn_monster(
		monster_name,
		CONQUEROR_MODEL,
		spawn_position,
		patrol_offset,
		{"monster_type": &"conqueror", "patrol_speed": 1.35, "chase_speed": 2.65, "detection_radius": 9.0, "chase_limit": 12.0, "scale": 1.06},
		{"idle": "Combat_Stance", "walk": "Walking", "alert": "Combat_Stance", "run": "Running", "stunned": "Weapon_Combo_2"}
	)


func _spawn_monster(
	monster_name: String,
	model_path: String,
	spawn_position: Vector3,
	patrol_offset: Vector3,
	settings: Dictionary,
	animations: Dictionary
) -> void:
	var monster := MonsterScript.new() as FactionFightMonster
	add_child(monster)
	monster.configure(monster_name, model_path, _player, spawn_position, patrol_offset, settings, animations)
	monster.player_bumped.connect(_on_player_bumped)
	_monsters.append(monster)


func _spawn_rewards() -> void:
	_spawn_item("BÂTON BONBON", Vector3(-6.0, 0.45, -10.0), &"candy_cane", 3)
	_spawn_support(Vector3(-6.0, 0.02, -10.0), Color(1.0, 0.24, 0.18))
	_spawn_candy(Vector3(-6.0, 0.55, -18.0), 2)
	_spawn_candy(Vector3(11.0, 0.55, -38.0), 3)
	_spawn_chest("RÉSERVE DU JARDIN", Vector3(7.0, 0.05, -38.0), 6, &"garden_reserve")

	_spawn_item("SPRAY SUCRÉ", Vector3(20.0, 0.45, -78.0), &"sugar_spray", 3)
	_spawn_support(Vector3(20.0, 0.02, -78.0), Color(0.25, 0.92, 1.0))
	_spawn_candy(Vector3(-11.0, 0.55, -65.0), 2)
	_spawn_candy(Vector3(22.0, 0.55, -90.0), 3)
	_spawn_candy(Vector3(24.0, 0.55, -102.0), 4)

	_spawn_item("BOUCLIER CARAMEL", Vector3(-12.0, 0.45, -126.0), &"caramel_shield", 1)
	_spawn_support(Vector3(-12.0, 0.02, -126.0), Color(1.0, 0.54, 0.12))
	_spawn_candy(Vector3(-14.0, 0.55, -130.0), 3)
	_spawn_candy(Vector3(4.0, 0.55, -176.0), 4)
	_spawn_chest("CACHE DE SIROP", Vector3(4.0, 0.05, -176.0), 8, &"syrup_cache")

	_spawn_candy(Vector3(-8.0, 0.55, -208.0), 4)
	_spawn_candy(Vector3(22.0, 0.55, -226.0), 5)
	_spawn_chest("COFFRE DU SANCTUAIRE", Vector3(-8.0, 0.05, -233.0), 12, &"sanctuary_treasure")


func _spawn_unlock_chains() -> void:
	_spawn_key_item("CLÉ CARAMEL", Vector3(-4.0, 0.45, -66.0), &"caramel_key")
	_spawn_support(Vector3(-4.0, 0.02, -66.0), Color(1.0, 0.48, 0.08))
	_spawn_device("CASIER HANTÉ", Vector3(-11.0, 0.05, -92.0), &"caramel_key", &"ghost_lamp", &"forest_locker")
	_spawn_key_item("CRISTAL D’ÉNERGIE SUCRÉE", Vector3(20.0, 0.45, -95.0), &"sugar_crystal")
	_spawn_device("MÉCANISME MAGIQUE", Vector3(-10.0, 0.05, -120.0), &"sugar_crystal", &"crystal_chest")
	_spawn_key_item("CAPSULE DE SIROP", Vector3(-5.0, 0.45, -148.0), &"syrup_capsule")
	_spawn_device("DISTRIBUTEUR DE SIROP", Vector3(-8.0, 0.05, -134.0), &"syrup_capsule", &"spray_refill")
	_spawn_key_item("INSIGNE SPECTRAL", Vector3(14.0, 0.45, -207.0), &"spectral_badge")
	_spawn_device("AUTEL SPECTRAL", Vector3(20.0, 0.05, -236.0), &"spectral_badge", &"spectral_secret")


func _spawn_candy(position_3d: Vector3, amount: int) -> void:
	_spawn_pickup(
		FactionFightPickup.Kind.CANDY,
		"CANDY +%d" % amount,
		position_3d,
		amount,
		&"",
		0,
		_next_candy_variant
	)
	_next_candy_variant = (_next_candy_variant + 1) % 2


func _spawn_item(item_name: String, position_3d: Vector3, item_id: StringName, charges: int) -> void:
	_spawn_pickup(FactionFightPickup.Kind.ITEM, item_name, position_3d, 0, item_id, charges)


func _spawn_chest(chest_name: String, position_3d: Vector3, amount: int, mission_id: StringName = &"") -> void:
	var placed_position := Vector3(position_3d.x, 0.19, position_3d.z)
	_spawn_pickup(FactionFightPickup.Kind.CHEST, "%s • +%d" % [chest_name, amount], placed_position, amount, &"", 0, 0, &"", &"", mission_id)
	_spawn_support(position_3d, Color(1.0, 0.68, 0.16))


func _spawn_key_item(item_name: String, position_3d: Vector3, item_id: StringName) -> void:
	_spawn_pickup(FactionFightPickup.Kind.KEY_ITEM, item_name, position_3d, 0, item_id)


func _spawn_device(device_name: String, position_3d: Vector3, required_id: StringName, reward_id: StringName, mission_id: StringName = &"") -> void:
	var placed_position := Vector3(position_3d.x, 0.05, position_3d.z)
	_spawn_pickup(FactionFightPickup.Kind.DEVICE, device_name, placed_position, 0, &"", 0, 0, required_id, reward_id, mission_id)


func _spawn_pickup(
	kind: int,
	pickup_name: String,
	position_3d: Vector3,
	value: int = 0,
	item_id: StringName = &"",
	charges: int = 0,
	candy_variant: int = 0,
	required_item_id: StringName = &"",
	reward_id: StringName = &"",
	mission_id: StringName = &""
) -> void:
	var pickup := PickupScript.new() as FactionFightPickup
	add_child(pickup)
	pickup.configure(kind, pickup_name, position_3d, value, item_id, charges, candy_variant, required_item_id, reward_id, mission_id)
	if kind == FactionFightPickup.Kind.CANDY:
		pickup.candy_collected.connect(_on_shared_candy_collected)
	_pickups.append(pickup)


func _spawn_support(position_3d: Vector3, color: Color) -> void:
	var support_root := Node3D.new()
	support_root.name = "GameplaySupport"
	support_root.add_to_group(&"faction_fight_support")
	add_child(support_root)
	support_root.global_position = Vector3(position_3d.x, 0.0, position_3d.z)
	var support := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.9
	mesh.bottom_radius = 1.08
	mesh.height = 0.22
	mesh.radial_segments = 12
	mesh.material = _particle_material(color.darkened(0.35))
	support.mesh = mesh
	support.position.y = 0.11
	support_root.add_child(support)
	var body := StaticBody3D.new()
	body.name = "SupportCollision"
	body.collision_layer = 4
	body.collision_mask = 0
	support_root.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.0
	shape.height = 0.22
	collision.shape = shape
	collision.position.y = 0.11
	body.add_child(collision)


func _on_shared_candy_collected(pickup: FactionFightPickup) -> void:
	if _completed:
		return
	_add_candy(pickup.candy_value, true)
	_update_hud()
	_hud.show_gameplay_message("+%d CANDY" % pickup.candy_value, FactionFightHUD.MessageCategory.SUCCESS)


func _update_zone_progress() -> void:
	while _zones_completed < ZONE_THRESHOLDS.size():
		if _player.global_position.z > ZONE_THRESHOLDS[_zones_completed]:
			break
		_zones_completed += 1
		_add_candy(5, true)
		_hud.show_gameplay_message("ZONE %d / 4 • RÉCOMPENSE GARANTIE +5 CANDY" % _zones_completed, FactionFightHUD.MessageCategory.SUCCESS)
		_spawn_burst(_player.global_position + Vector3.UP, Color(1.0, 0.62, 0.18))


func _create_objective_marker() -> void:
	_objective_marker = MissionMarkerScript.new() as Node3D
	_objective_marker.name = "UniqueMissionMarker"
	add_child(_objective_marker)


func _update_mission(delta: float) -> void:
	_mission_elapsed += delta
	if not _mission_hint_shown and _mission_elapsed >= RESCUE_HINT_DELAY and _mission_index < MISSIONS.size():
		_mission_hint_shown = true
		_ensure_mission_tool()
		_hud.show_gameplay_message("INDICE • %s" % String(MISSIONS[_mission_index]["hint"]), FactionFightHUD.MessageCategory.INFORMATION)
	_refresh_mission_hud()


func _refresh_mission() -> void:
	_mission_elapsed = 0.0
	_mission_hint_shown = false
	if _objective_marker == null:
		return
	_objective_marker.global_position = _mission_target()
	_refresh_mission_hud()


func _refresh_mission_hud() -> void:
	if _hud == null:
		return
	var target := _mission_target()
	var distance := _player.global_position.distance_to(target)
	if _mission_index < MISSIONS.size():
		var mission: Dictionary = MISSIONS[_mission_index]
		var rescue_text := String(mission["hint"]) if _mission_hint_shown else ""
		if distance > 75.0:
			rescue_text = "RETOUR VERS LA MISSION"
		_hud.set_objective(String(mission["title"]), _mission_objective_text(), distance, _mission_direction_symbol(target), rescue_text)
	else:
		_hud.set_objective("MISSIONS ACCOMPLIES", "Rejoins le portail et termine CHASEWEEN.", distance, _mission_direction_symbol(target))


func _mission_target() -> Vector3:
	if _mission_index < MISSIONS.size():
		if _mission_index == 0:
			if not _tool_has_charges(&"candy_cane") and not _mission_tactical_done.get(&"garden_reserve", false):
				return Vector3(-6.0, 0.45, -10.0)
			if not _mission_tactical_done.get(&"garden_reserve", false):
				return Vector3(7.0, 0.1, -42.0)
		if _mission_index == 1 and not _inventory.get(&"caramel_key", false):
			return Vector3(-4.0, 0.45, -66.0)
		if _mission_index == 2 and not _mission_tactical_done.get(&"syrup_cache", false):
			return Vector3(4.0, 0.1, -169.0)
		var target: Vector3 = MISSIONS[_mission_index]["target"]
		return target
	return _portal_objective_position()


func _mission_objective_text() -> String:
	if _mission_index == 0:
		if not _tool_has_charges(&"candy_cane") and not _mission_tactical_done.get(&"garden_reserve", false):
			return "Ramasse le bâton bonbon sur son socle."
		if not _mission_tactical_done.get(&"garden_reserve", false):
			return "Oriente-toi vers le Gobelin puis utilise le bâton au clic gauche."
		return "Le Gobelin est repoussé : ouvre la réserve."
	if _mission_index == 1:
		return "Ouvre le casier gardé par le Paladin avec la clé." if _inventory.get(&"caramel_key", false) else "Trouve la clé caramel au bord du chemin."
	if _mission_index == 2:
		return "L’affinité est testée : ouvre la cache de sirop." if _mission_tactical_done.get(&"syrup_cache", false) else "Oriente-toi vers le Conquérant puis utilise un outil au clic gauche."
	return String(MISSIONS[_mission_index]["objective"]) if _mission_index < MISSIONS.size() else "Rejoins le portail."


func _is_active_mission(mission_id: StringName) -> bool:
	return _mission_index < MISSIONS.size() and StringName(MISSIONS[_mission_index]["id"]) == mission_id


func _mission_direction_symbol(target: Vector3) -> String:
	var forward := -_player.global_basis.z
	forward.y = 0.0
	var direction := target - _player.global_position
	direction.y = 0.0
	if forward.is_zero_approx() or direction.is_zero_approx():
		return "◆"
	var angle := atan2(forward.normalized().cross(direction.normalized()).y, forward.normalized().dot(direction.normalized()))
	if absf(angle) < deg_to_rad(25.0):
		return "↑"
	if absf(angle) > deg_to_rad(150.0):
		return "↩"
	return "←" if angle > 0.0 else "→"


func _ensure_mission_tool() -> void:
	if _mission_index == 0 and not _mission_tactical_done.get(&"garden_reserve", false):
		if not _tool_has_charges(&"candy_cane"):
			_equip_tool(&"candy_cane", 1)
			_objective_marker.global_position = _mission_target()
			_hud.show_gameplay_message("AIDE • 1 charge de bâton restaurée", FactionFightHUD.MessageCategory.INFORMATION)
	elif _mission_index == 2 and not _mission_tactical_done.get(&"syrup_cache", false):
		if _tool_slots.is_empty():
			_equip_tool(&"candy_cane", 1)
			_objective_marker.global_position = _mission_target()
			_hud.show_gameplay_message("AIDE • 1 outil restauré pour tester l’affinité", FactionFightHUD.MessageCategory.INFORMATION)


func _tool_has_charges(tool_id: StringName) -> bool:
	for slot: Dictionary in _tool_slots:
		if StringName(slot.get("id", &"")) == tool_id and int(slot.get("charges", 0)) > 0:
			return true
	return false


func _complete_mission(mission_id: StringName, reward_amount: int = 0) -> void:
	if not _is_active_mission(mission_id):
		return
	_mission_index += 1
	_zones_completed = maxi(_zones_completed, _mission_index)
	_spawn_burst(_player.global_position + Vector3.UP, Color(1.0, 0.72, 0.16))
	var reward_text := " • +%d CANDY" % reward_amount if reward_amount > 0 else ""
	_hud.show_gameplay_message("MISSION ACCOMPLIE • %d / 4%s" % [_mission_index, reward_text], FactionFightHUD.MessageCategory.SUCCESS)
	_refresh_mission()


func _celebrate_chest(pickup: FactionFightPickup, amount: int) -> void:
	_hud.show_gameplay_message("COFFRE OUVERT • RÉCOMPENSE +%d CANDY" % amount, FactionFightHUD.MessageCategory.SUCCESS)
	for index: int in 3:
		var candy_scene := CRYSTALBERRY_SCENE if index % 2 == 0 else PUMPKIN_SCENE
		var candy_visual := candy_scene.instantiate() as Node3D
		if candy_visual == null:
			continue
		add_child(candy_visual)
		candy_visual.global_position = pickup.get_interaction_position() + Vector3(0.0, 0.8, 0.0)
		if candy_visual is Area3D:
			(candy_visual as Area3D).monitoring = false
			(candy_visual as Area3D).monitorable = false
		var offset := Vector3(float(index - 1) * 0.9, 1.2 + float(index % 2) * 0.4, -0.35)
		var tween := candy_visual.create_tween()
		tween.set_parallel(true)
		tween.tween_property(candy_visual, "global_position", candy_visual.global_position + offset, 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(candy_visual, "rotation:y", TAU, 0.8)
		tween.chain().tween_interval(0.55)
		tween.chain().tween_property(candy_visual, "scale", Vector3.ZERO, 0.2)
		tween.finished.connect(candy_visual.queue_free)


func _update_interaction_prompt() -> void:
	_nearest_interactive = null
	var nearest_distance := 3.2
	for pickup: FactionFightPickup in _pickups:
		if not is_instance_valid(pickup) or pickup.collected or pickup.auto_collect:
			continue
		if pickup.mission_id != &"" and not _is_active_mission(pickup.mission_id):
			continue
		var distance := _player.global_position.distance_to(pickup.get_interaction_position())
		if distance < nearest_distance:
			nearest_distance = distance
			_nearest_interactive = pickup
	if _nearest_interactive != null:
		_hud.set_prompt("E  •  %s" % _nearest_interactive.display_name)
		return
	if _is_player_near_portal():
		if _mission_index >= MISSIONS.size():
			_hud.set_prompt("E  •  QUITTER CHASEWEEN")
		else:
			_hud.set_prompt("Termine d’abord la mission active")
		return
	_hud.set_prompt("")


func _interact() -> void:
	if _nearest_interactive != null and is_instance_valid(_nearest_interactive):
		_collect_pickup(_nearest_interactive)
		return
	if _is_player_near_portal():
		if _mission_index >= MISSIONS.size():
			_complete_world()
		else:
			_hud.show_gameplay_message("Le portail attend les quatre missions", FactionFightHUD.MessageCategory.INFORMATION)


func _is_player_near_portal() -> bool:
	if not is_instance_valid(_portal):
		return false
	var local_player_position := _portal.to_local(_player.global_position)
	if local_player_position.z < PORTAL_MIN_FRONT_DISTANCE:
		return false
	if absf(local_player_position.x) > PORTAL_MAX_SIDE_DISTANCE:
		return false
	return _player.global_position.distance_to(_portal_interaction_position()) <= PORTAL_INTERACTION_RADIUS


func _portal_interaction_position() -> Vector3:
	if not is_instance_valid(_portal):
		return Vector3(8.0, 1.5, -235.6)
	var interaction_point := _portal.get_node_or_null("InteractionPoint") as Node3D
	return interaction_point.global_position if interaction_point != null else _portal.global_position


func _portal_objective_position() -> Vector3:
	if not is_instance_valid(_portal):
		return Vector3(8.0, 1.0, -238.0)
	var objective_point := _portal.get_node_or_null("ObjectivePoint") as Node3D
	return objective_point.global_position if objective_point != null else _portal.global_position


func _collect_pickup(pickup: FactionFightPickup) -> void:
	if pickup.mission_id != &"" and not _is_active_mission(pickup.mission_id):
		_hud.show_gameplay_message("Cet objectif appartient à une mission suivante", FactionFightHUD.MessageCategory.INFORMATION)
		return
	if pickup.mission_id == &"garden_reserve" and not _mission_tactical_done.get(&"garden_reserve", false):
		_hud.show_gameplay_message("Repousse d’abord le Gobelin avec ton bâton", FactionFightHUD.MessageCategory.OBJECTIVE)
		return
	if pickup.mission_id == &"syrup_cache" and not _mission_tactical_done.get(&"syrup_cache", false):
		_hud.show_gameplay_message("Teste d’abord une affinité sur le Conquérant", FactionFightHUD.MessageCategory.OBJECTIVE)
		return
	if pickup.kind == FactionFightPickup.Kind.DEVICE and not _inventory.get(pickup.required_item_id, false):
		_hud.show_gameplay_message("NÉCESSITE : %s" % KEY_ITEM_NAMES.get(pickup.required_item_id, "OBJET MANQUANT"), FactionFightHUD.MessageCategory.OBJECTIVE)
		return
	if not pickup.collect_once():
		return
	_spawn_burst(pickup.global_position + Vector3.UP * 0.4, Color(0.4, 1.0, 0.72))
	match pickup.kind:
		FactionFightPickup.Kind.CANDY:
			_add_candy(pickup.candy_value, true)
			_hud.show_gameplay_message("+%d CANDY" % pickup.candy_value, FactionFightHUD.MessageCategory.SUCCESS)
		FactionFightPickup.Kind.CHEST:
			_add_candy(pickup.candy_value, true)
			_celebrate_chest(pickup, pickup.candy_value)
		FactionFightPickup.Kind.ITEM:
			_equip_tool(pickup.item_id, pickup.item_charges)
			_hud.show_gameplay_message("OBJET ACTIF : %s ×%d • CLIC GAUCHE POUR UTILISER" % [ITEM_NAMES.get(_active_item, "OBJET"), _item_charges], FactionFightHUD.MessageCategory.INFORMATION)
			if _mission_index == 0:
				_refresh_mission()
		FactionFightPickup.Kind.KEY_ITEM:
			_inventory[pickup.item_id] = true
			_hud.show_gameplay_message("TROUVÉ : %s" % KEY_ITEM_NAMES.get(pickup.item_id, "OBJET"), FactionFightHUD.MessageCategory.SUCCESS)
			if pickup.item_id == &"caramel_key" and _mission_index == 1:
				_refresh_mission()
		FactionFightPickup.Kind.DEVICE:
			_inventory.erase(pickup.required_item_id)
			_apply_unlock_reward(pickup.reward_id)
	if pickup.mission_id != &"":
		_complete_mission(pickup.mission_id, pickup.candy_value)
	_update_hud()


func _apply_unlock_reward(reward_id: StringName) -> void:
	match reward_id:
		&"ghost_lamp":
			_equip_tool(&"ghost_lamp", 4)
			_hud.show_gameplay_message("LAMPE FANTÔME DÉBLOQUÉE !", FactionFightHUD.MessageCategory.SUCCESS)
		&"crystal_chest":
			_add_candy(7, true)
			_hud.show_gameplay_message("MÉCANISME ACTIVÉ • +7 CANDY", FactionFightHUD.MessageCategory.SUCCESS)
		&"spray_refill":
			_equip_tool(&"sugar_spray", 5)
			_add_candy(3, true)
			_hud.show_gameplay_message("SPRAY RECHARGÉ • SECRET +3 CANDY", FactionFightHUD.MessageCategory.SUCCESS)
		&"spectral_secret":
			_add_candy(10, true)
			_hud.show_gameplay_message("PASSAGE SECRET DÉCOUVERT • +10 CANDY", FactionFightHUD.MessageCategory.SUCCESS)
		_:
			push_warning("FactionFight: récompense inconnue %s" % reward_id)


func _use_active_item() -> void:
	if _active_item == &"" or _item_charges <= 0:
		_hud.show_gameplay_message("Aucun objet actif", FactionFightHUD.MessageCategory.DANGER)
		return
	match _active_item:
		&"candy_cane":
			_use_candy_cane()
		&"sugar_spray":
			_use_sugar_spray()
		&"caramel_shield":
			_use_caramel_shield()
		&"ghost_lamp":
			_use_ghost_lamp()


func _equip_tool(tool_id: StringName, charges: int) -> void:
	for index: int in _tool_slots.size():
		if StringName(_tool_slots[index].get("id", &"")) == tool_id:
			_tool_slots[index]["charges"] = int(_tool_slots[index].get("charges", 0)) + charges
			_active_tool_index = index
			_sync_active_tool()
			return
	var slot := {"id": tool_id, "charges": charges}
	if _tool_slots.size() < 2:
		_tool_slots.append(slot)
		_active_tool_index = _tool_slots.size() - 1
	else:
		_tool_slots[_active_tool_index] = slot
	_sync_active_tool()


func _switch_tool() -> void:
	if _tool_slots.size() < 2:
		_hud.show_gameplay_message("Un seul outil équipé", FactionFightHUD.MessageCategory.INFORMATION)
		return
	_active_tool_index = (_active_tool_index + 1) % _tool_slots.size()
	_sync_active_tool()
	_hud.show_gameplay_message("OUTIL : %s" % ITEM_NAMES.get(_active_item, "OBJET"), FactionFightHUD.MessageCategory.INFORMATION)


func _sync_active_tool() -> void:
	if _tool_slots.is_empty():
		_active_item = &""
		_item_charges = 0
		_refresh_held_tool_visual()
		_set_aiming(false)
		return
	_active_tool_index = clampi(_active_tool_index, 0, _tool_slots.size() - 1)
	_active_item = StringName(_tool_slots[_active_tool_index].get("id", &""))
	_item_charges = int(_tool_slots[_active_tool_index].get("charges", 0))
	_refresh_held_tool_visual()
	_set_aiming(_item_charges > 0)


func _refresh_held_tool_visual() -> void:
	if is_instance_valid(_held_tool_visual) and _held_tool_visual.presentation_id == _active_item:
		return
	if is_instance_valid(_held_tool_visual):
		_held_tool_visual.queue_free()
	_held_tool_visual = null
	if _active_item == &"" or not is_instance_valid(_player):
		return
	var knight := _player.get_node_or_null("Player") as Node3D
	if knight == null:
		return
	_held_tool_visual = PresentationScript.new() as PresentationScript
	_held_tool_visual.name = "FactionFightHeldTool"
	knight.add_child(_held_tool_visual)
	_held_tool_visual.configure(_active_item, true)
	_held_tool_visual.position = Vector3(0.48, 1.02, 0.18)
	_held_tool_visual.rotation = _held_tool_rotation(_active_item)


func _held_tool_rotation(tool_id: StringName) -> Vector3:
	match tool_id:
		&"candy_cane":
			return Vector3(0.0, 0.0, deg_to_rad(-24.0))
		&"caramel_shield":
			return Vector3(0.0, deg_to_rad(90.0), deg_to_rad(8.0))
		&"ghost_lamp":
			return Vector3(0.0, deg_to_rad(180.0), 0.0)
		_:
			return Vector3.ZERO


func _set_aiming(enabled: bool) -> void:
	var should_aim := enabled and _active_item != &"" and _item_charges > 0
	if should_aim and _aiming and is_instance_valid(_aim_preview) and _aim_preview_tool_id == _active_item:
		return
	_aiming = should_aim
	if _aiming:
		_rebuild_aim_preview()
	else:
		_clear_aim_preview()


func _rebuild_aim_preview() -> void:
	_clear_aim_preview()
	if not _aiming:
		return
	_aim_preview = VFX.create_preview(_active_item, self)
	_aim_preview_tool_id = _active_item
	_update_aim_preview()


func _update_aim_preview() -> void:
	if not _aiming or _aim_preview == null or not is_instance_valid(_aim_preview):
		return
	_aim_preview.global_transform = _player.global_transform
	for monster: FactionFightMonster in _monsters:
		if is_instance_valid(monster):
			monster.clear_aim_feedback()
	for target: FactionFightMonster in _targets_for_tool(_active_item):
		var discovery_key := "%s:%s" % [_active_item, target.monster_type]
		if _discoveries.has(discovery_key):
			var reaction := int(_discoveries[discovery_key])
			target.show_aim_feedback(FactionFightAffinityRules.label(reaction), FactionFightAffinityRules.color(reaction))
		else:
			target.show_aim_feedback("?", Color(0.72, 0.82, 0.95))


func _clear_aim_preview() -> void:
	if _aim_preview != null and is_instance_valid(_aim_preview):
		_aim_preview.queue_free()
	_aim_preview = null
	_aim_preview_tool_id = &""
	for monster: FactionFightMonster in _monsters:
		if is_instance_valid(monster):
			monster.clear_aim_feedback()


func _targets_for_tool(tool_id: StringName) -> Array[FactionFightMonster]:
	match tool_id:
		&"sugar_spray":
			return _monsters_in_cone(7.0, deg_to_rad(30.0))
		&"ghost_lamp":
			return _monsters_in_cone(VFX.GHOST_BEAM_DISTANCE, VFX.GHOST_BEAM_HALF_ANGLE)
		&"caramel_shield":
			return _monsters_in_cone(1.65, PI)
		_:
			return _monsters_in_cone(6.0, deg_to_rad(75.0))


func _use_candy_cane() -> void:
	var targets := _monsters_in_cone(6.0, deg_to_rad(75.0))
	var affected := targets.size()
	if affected == 0:
		_hud.show_gameplay_message("Aucun monstre assez proche", FactionFightHUD.MessageCategory.DANGER)
		return
	for monster: FactionFightMonster in targets:
		var reaction := _apply_affinity(&"candy_cane", monster)
		monster.apply_repel(_player.global_position, 1.5 if reaction == FactionFightAffinityRules.Reaction.EFFECTIVE else 0.6, 8.0 if reaction == FactionFightAffinityRules.Reaction.EFFECTIVE else 2.6)
		if monster.monster_type == &"conqueror":
			monster.apply_stun(0.8)
	_consume_charge("BÂTON BONBON • ARC TACTIQUE !")
	VFX.spawn_arc(self, _player.global_transform, 2.6, Color(1.0, 0.22, 0.08))


func _use_sugar_spray() -> void:
	var targets := _monsters_in_cone(7.0, deg_to_rad(30.0))
	if targets.is_empty():
		_hud.show_gameplay_message("Aucun monstre à portée du spray", FactionFightHUD.MessageCategory.DANGER)
		return
	for target: FactionFightMonster in targets:
		var reaction := _apply_affinity(&"sugar_spray", target)
		match reaction:
			FactionFightAffinityRules.Reaction.EFFECTIVE:
				target.apply_stun(2.6)
			FactionFightAffinityRules.Reaction.WEAK:
				target.apply_slow(2.0, 0.72)
			FactionFightAffinityRules.Reaction.INVERSE:
				target.apply_enrage(5.0)
	_consume_charge("SPRAY SUCRÉ • PROJECTION TACTIQUE !")
	VFX.spawn_cone(self, _player.global_transform, 7.0, deg_to_rad(30.0), Color(1.0, 0.12, 0.62, 0.32))


func _use_caramel_shield() -> void:
	_shield_time = 8.0
	_consume_charge("BOUCLIER CARAMEL • PROTECTION 8 S")
	VFX.spawn_dome(self, _player.global_position, 1.65, Color(1.0, 0.55, 0.08, 0.24), 8.0)


func _use_ghost_lamp() -> void:
	VFX.pulse_spectral_beam(_aim_preview)
	var targets := _monsters_in_cone(VFX.GHOST_BEAM_DISTANCE, VFX.GHOST_BEAM_HALF_ANGLE)
	if targets.is_empty():
		_hud.show_gameplay_message("Aucun monstre dans le faisceau", FactionFightHUD.MessageCategory.DANGER)
		return
	for target: FactionFightMonster in targets:
		var reaction := _apply_affinity(&"ghost_lamp", target)
		VFX.spawn_spectral_impact(self, target.global_position + Vector3.UP * 1.1)
		if target.monster_type == &"goblin":
			target.apply_repel(_player.global_position, 1.45, 7.0)
		elif reaction == FactionFightAffinityRules.Reaction.EFFECTIVE:
			target.apply_slow(4.0, 0.45)
		else:
			target.apply_slow(1.0, 0.8)
	_consume_charge("LAMPE FANTÔME • FAISCEAU SPECTRAL !")


func _monsters_in_cone(max_distance: float, half_angle: float) -> Array[FactionFightMonster]:
	var targets: Array[FactionFightMonster] = []
	var forward := -_player.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	for monster: FactionFightMonster in _monsters:
		if not is_instance_valid(monster):
			continue
		var offset := monster.global_position - _player.global_position
		offset.y = 0.0
		if offset.length() <= max_distance and forward.angle_to(offset.normalized()) <= half_angle:
			targets.append(monster)
	return targets


func _apply_affinity(item_id: StringName, monster: FactionFightMonster) -> int:
	var reaction := FactionFightAffinityRules.reaction(item_id, monster.monster_type)
	var label := FactionFightAffinityRules.label(reaction)
	var color := FactionFightAffinityRules.color(reaction)
	monster.show_reaction(label, color)
	_spawn_burst(monster.global_position + Vector3.UP, color)
	_discoveries["%s:%s" % [item_id, monster.monster_type]] = reaction
	if _mission_index == 0 and monster.monster_type == &"goblin":
		if not _mission_tactical_done.get(&"garden_reserve", false):
			_mission_tactical_done[&"garden_reserve"] = true
			_refresh_mission()
	elif _mission_index == 2 and monster.monster_type == &"conqueror":
		if not _mission_tactical_done.get(&"syrup_cache", false):
			_mission_tactical_done[&"syrup_cache"] = true
			_refresh_mission()
	_refresh_journal()
	return reaction


func _nearest_monster(max_distance: float) -> FactionFightMonster:
	var nearest: FactionFightMonster
	var nearest_distance := max_distance
	for monster: FactionFightMonster in _monsters:
		if not is_instance_valid(monster):
			continue
		var distance := monster.global_position.distance_to(_player.global_position)
		if distance < nearest_distance:
			nearest = monster
			nearest_distance = distance
	return nearest


func _consume_charge(message: String) -> void:
	_item_charges -= 1
	_hud.show_gameplay_message(message, FactionFightHUD.MessageCategory.INFORMATION)
	if _tool_slots.is_empty():
		if _item_charges <= 0:
			_active_item = &""
		return
	if _item_charges <= 0:
		if not _tool_slots.is_empty():
			_tool_slots.remove_at(_active_tool_index)
			_active_tool_index = mini(_active_tool_index, _tool_slots.size() - 1)
	else:
		_tool_slots[_active_tool_index]["charges"] = _item_charges
	_sync_active_tool()


func _on_player_bumped(monster: FactionFightMonster, direction: Vector3, strength: float) -> void:
	if not monster.can_steal_candy():
		return
	if _shield_time > 0.0:
		var reaction := _apply_affinity(&"caramel_shield", monster)
		if reaction == FactionFightAffinityRules.Reaction.INVERSE:
			_shield_time = maxf(_shield_time - 2.0, 0.5)
		monster.apply_repel(_player.global_position, 1.35, 6.5)
		_hud.show_gameplay_message("BOUCLIER ACTIF • AUCUN CANDY VOLÉ", FactionFightHUD.MessageCategory.SUCCESS)
		_spawn_burst(_player.global_position + Vector3.UP, FactionFightAffinityRules.color(reaction))
		return
	_player.move_and_collide(direction * strength)
	monster.apply_repel(_player.global_position, 0.65, 3.2)
	if _theft_immunity_time > 0.0:
		return
	_steal_candy(monster)


func _steal_candy(monster: FactionFightMonster) -> int:
	var requested_amount := _roll_theft_amount()
	var stolen_amount := mini(requested_amount, _candy)
	if stolen_amount <= 0:
		_hud.show_gameplay_message("%s n’a trouvé aucun CANDY" % monster.display_name, FactionFightHUD.MessageCategory.INFORMATION)
		return 0
	_candy -= stolen_amount
	result_data.candy_amount = _candy
	_theft_immunity_time = THEFT_IMMUNITY_DURATION
	_update_hud()
	_hud.pulse_candy(Color(1.0, 0.25, 0.14))
	_hud.show_gameplay_message("-%d CANDY • VOLÉ PAR %s • IMMUNITÉ 3 S" % [stolen_amount, monster.display_name], FactionFightHUD.MessageCategory.DANGER)
	_spawn_burst(_player.global_position + Vector3.UP, Color(1.0, 0.24, 0.08))
	VFX.spawn_dome(self, _player.global_position, 1.0, Color(0.3, 0.85, 1.0, 0.14), THEFT_IMMUNITY_DURATION)
	return stolen_amount


func _roll_theft_amount() -> int:
	return _random.randi_range(1, 5)


func _complete_world(exit_mode: String = "PORTAIL") -> void:
	if _completed:
		return
	_completed = true
	_finishing = false
	var guarantee_added := _ensure_exit_minimum()
	result_data.candy_amount = _candy
	result_data.completed = true
	_stop_world_interactions()
	_hud.show_summary(_candy, guarantee_added, mini(_mission_index, 4), _discoveries.size(), exit_mode)
	_spawn_burst(_portal.global_position + Vector3.UP * 3.0, Color(0.85, 0.25, 1.0))


func _on_summary_closed() -> void:
	if _return_transition_started or not bool(result_data.get("completed", false)):
		return
	var progression_service: Node = get_node_or_null("/root/ProgressionService")
	var scene_transition: Node = get_node_or_null("/root/SceneTransition")
	if progression_service == null or scene_transition == null:
		push_error("CHASEWEEN: services de progression ou de transition indisponibles.")
		return
	progression_service.call(&"complete_world", WORLD_ID, int(result_data.get("candy_amount", 0)))
	var transition_started := bool(scene_transition.call(&"change_scene", LOBBY_SCENE_PATH, _mark_lobby_return))
	if not transition_started:
		return
	_return_transition_started = true


func _mark_lobby_return() -> void:
	get_tree().set_meta(LOBBY_RETURN_META, true)


func _ensure_exit_minimum() -> int:
	var guarantee_added := maxi(MINIMUM_EXIT_CANDY - _candy, 0)
	if guarantee_added > 0:
		_add_candy(guarantee_added)
	return guarantee_added


func _add_candy(amount: int, play_collect_sound: bool = false) -> void:
	_candy += amount
	result_data.candy_amount = _candy
	if play_collect_sound:
		_collect_audio_player.pitch_scale = 1.0
		_collect_audio_player.play()
	if _hud != null:
		_hud.pulse_candy()


func _update_hud() -> void:
	var item_name := String(ITEM_NAMES.get(_active_item, ""))
	_hud.update_status(_candy, mini(_mission_index, 4), item_name, _item_charges, _shield_time)
	var secondary_name := ""
	var secondary_charges := 0
	if _tool_slots.size() == 2:
		var secondary_index := (_active_tool_index + 1) % 2
		secondary_name = String(ITEM_NAMES.get(StringName(_tool_slots[secondary_index].get("id", &"")), ""))
		secondary_charges = int(_tool_slots[secondary_index].get("charges", 0))
	_hud.update_tools(item_name, _item_charges, secondary_name, secondary_charges)
	var found_names: Array[String] = []
	for item_id: StringName in _inventory:
		if _inventory[item_id]:
			found_names.append(String(KEY_ITEM_NAMES.get(item_id, item_id)))
	_hud.update_inventory(" • ".join(found_names))


func _refresh_journal() -> void:
	if _hud == null:
		return
	var entries: Array[String] = []
	var monster_names: Dictionary = {&"goblin": "PEPPERMINT GOBLIN", &"paladin": "PUMPKIN PALADIN", &"conqueror": "CANDY CORN CONQUEROR"}
	for monster_type: StringName in monster_names:
		entries.append(String(monster_names[monster_type]))
		for item_id: StringName in ITEM_NAMES:
			var key := "%s:%s" % [item_id, monster_type]
			var result := "?"
			if _discoveries.has(key):
				result = FactionFightAffinityRules.label(_discoveries[key])
			entries.append("  %s : %s" % [ITEM_NAMES[item_id], result])
		entries.append("")
	_hud.set_journal(entries)


func _setup_corruption() -> void:
	_environment_controller = get_parent() as FactionFightEnvironment
	_world_environment = get_node_or_null("../Atmosphere/WorldEnvironment") as WorldEnvironment
	_moon_light = get_node_or_null("../Atmosphere/MoonLight") as DirectionalLight3D
	_portal_light = get_node_or_null("../Zone4_LeSanctuaireCorrompu/ExitPortal/PortalLight") as OmniLight3D
	if _world_environment != null and _world_environment.environment != null:
		_world_environment.environment = _world_environment.environment.duplicate(true) as Environment
		_base_fog_density = _world_environment.environment.fog_density
		_base_fog_color = _world_environment.environment.fog_light_color
	if _moon_light != null:
		_base_moon_color = _moon_light.light_color
		_base_moon_energy = _moon_light.light_energy
	if _portal_light != null:
		_base_portal_energy = _portal_light.light_energy
	_create_corruption_particles()


func _update_corruption(delta: float) -> void:
	_session_time = minf(_session_time + delta, SESSION_DURATION)
	var progress := _session_time / SESSION_DURATION
	var phase_name := _corruption_phase_name(_session_time)
	var phase_index := mini(int(_session_time / 60.0), 3)
	_hud.update_corruption(progress * 100.0, phase_name)
	if phase_index != _last_corruption_phase:
		_last_corruption_phase = phase_index
		if _environment_controller != null:
			_environment_controller.set_storm_phase(phase_index)
		for monster: FactionFightMonster in _monsters:
			if is_instance_valid(monster):
				monster.set_corruption_level(progress)
	if _world_environment != null and _world_environment.environment != null:
		_world_environment.environment.fog_density = lerpf(_base_fog_density, minf(_base_fog_density * 1.7, 0.19), progress)
		_world_environment.environment.fog_light_color = _base_fog_color.lerp(Color(0.38, 0.16, 0.52), progress * 0.75)
	if _moon_light != null:
		_moon_light.light_color = _base_moon_color.lerp(Color(0.48, 0.38, 0.92), progress)
		_moon_light.light_energy = lerpf(_base_moon_energy, _base_moon_energy * 0.78, progress)
	if _portal_light != null:
		_portal_light.light_energy = lerpf(_base_portal_energy, _base_portal_energy * 1.65, progress)
	if _corruption_particles != null:
		_corruption_particles.emitting = _session_time >= 120.0
		_corruption_particles.global_position = _player.global_position + Vector3.UP * 6.0
	if _session_time >= SESSION_DURATION:
		_begin_final_spell()


func _corruption_phase_name(seconds: float) -> String:
	if seconds < 60.0:
		return "LES DERNIÈRES DOUCEURS"
	if seconds < 120.0:
		return "L’ÉVEIL DE LA CORRUPTION"
	if seconds < 180.0:
		return "LA TEMPÊTE DES CONFISERIES"
	return "LE DERNIER SORT"


func _begin_final_spell() -> void:
	if _finishing or _completed:
		return
	_finishing = true
	_stop_world_interactions()
	VFX.spawn_wave(self, _player.global_position)
	_hud.show_final_spell()
	get_tree().create_timer(1.2).timeout.connect(_finish_final_spell)


func _finish_final_spell() -> void:
	if not _completed:
		_complete_world("DERNIER SORT")


func _stop_world_interactions() -> void:
	_nearest_interactive = null
	_set_aiming(false)
	_hud.set_prompt("")
	if _environment_controller != null:
		_environment_controller.stop_storm()
	for monster: FactionFightMonster in _monsters:
		if is_instance_valid(monster):
			monster.stop_gameplay()
	for pickup: FactionFightPickup in _pickups:
		if is_instance_valid(pickup):
			pickup.stop_gameplay()
	if is_instance_valid(_fall_protection):
		_fall_protection.set_active(false)


func _create_fall_protection() -> void:
	_fall_protection = FallProtectionScript.new() as FallProtectionScript
	_fall_protection.name = "FallProtection"
	add_child(_fall_protection)
	_fall_protection.configure(_player)


func _create_chewingland_heart() -> void:
	_heart = PickupScript.new() as FactionFightPickup
	_heart.name = "ChewinglandHeart"
	add_child(_heart)
	_heart.configure(FactionFightPickup.Kind.KEY_ITEM, "CŒUR DE CHEWINGLAND", HEART_POSITION, 0, &"chewingland_heart")
	_pickups.append(_heart)


func _create_corruption_particles() -> void:
	_corruption_particles = GPUParticles3D.new()
	_corruption_particles.amount = 48
	_corruption_particles.lifetime = 5.0
	_corruption_particles.visibility_aabb = AABB(Vector3(-24.0, -8.0, -24.0), Vector3(48.0, 16.0, 48.0))
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(18.0, 5.0, 18.0)
	process_material.gravity = Vector3(0.0, -0.15, 0.0)
	process_material.initial_velocity_min = 0.1
	process_material.initial_velocity_max = 0.35
	process_material.color = Color(0.75, 0.22, 1.0, 0.5)
	_corruption_particles.process_material = process_material
	var mesh := SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.07
	mesh.material = _particle_material(Color(0.75, 0.22, 1.0))
	_corruption_particles.draw_pass_1 = mesh
	_corruption_particles.emitting = false
	add_child(_corruption_particles)


func _update_heart() -> void:
	if not is_instance_valid(_heart) or _heart.collected or not is_instance_valid(_heart._presentation):
		return
	var progress := clampf(_session_time / SESSION_DURATION, 0.0, 1.0)
	var color := Color(1.0, 0.20, 0.74).lerp(Color(0.72, 0.12, 1.0), progress)
	_heart._presentation.set_glow_color(color)


func _spawn_burst(position_3d: Vector3, color: Color) -> void:
	var particles := GPUParticles3D.new()
	particles.one_shot = true
	particles.amount = 18
	particles.lifetime = 0.65
	particles.explosiveness = 0.92
	particles.visibility_aabb = AABB(Vector3(-4.0, -4.0, -4.0), Vector3(8.0, 8.0, 8.0))
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 0.35
	process_material.direction = Vector3.UP
	process_material.spread = 180.0
	process_material.initial_velocity_min = 1.8
	process_material.initial_velocity_max = 3.6
	process_material.gravity = Vector3(0.0, -2.0, 0.0)
	process_material.color = color
	particles.process_material = process_material
	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.07
	particle_mesh.height = 0.14
	particle_mesh.material = _particle_material(color)
	particles.draw_pass_1 = particle_mesh
	add_child(particles)
	particles.global_position = position_3d
	particles.emitting = true
	get_tree().create_timer(1.2).timeout.connect(particles.queue_free)


func _particle_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.5
	return material
