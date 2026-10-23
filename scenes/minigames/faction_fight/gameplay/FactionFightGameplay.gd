class_name FactionFightGameplay
extends Node3D

const MonsterScript := preload("res://scenes/minigames/faction_fight/gameplay/MonsterAgent.gd")
const PickupScript := preload("res://scenes/minigames/faction_fight/gameplay/GameplayPickup.gd")
const HUDScript := preload("res://scenes/minigames/faction_fight/gameplay/FactionFightHUD.gd")

const GOBLIN_MODEL := "res://assets/chaseween/Meshy_AI_Peppermint_Goblin_All_Animations.glb"
const PALADIN_MODEL := "res://assets/chaseween/Meshy_AI_Pumpkin_Paladin_All_Animations.glb"
const CONQUEROR_MODEL := "res://assets/chaseween/Meshy_AI_Candy_Corn_Conqueror_All_Animations.glb"
const ZONE_THRESHOLDS: Array[float] = [-45.0, -112.0, -195.0, -230.0]
const THEFT_IMMUNITY_DURATION: float = 3.0
const MINIMUM_EXIT_CANDY: int = 20
const ITEM_NAMES: Dictionary = {
	&"candy_cane": "BÂTON BONBON",
	&"sugar_spray": "SPRAY SUCRÉ",
	&"caramel_shield": "BOUCLIER CARAMEL",
}

var result_data: Dictionary = {
	"world_id": "faction_fight",
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


func _ready() -> void:
	_player = get_node_or_null("../Player") as CharacterBody3D
	_portal = get_node_or_null("../Zone4_LeSanctuaireCorrompu/ExitPortal") as Node3D
	if _player == null:
		push_error("FactionFight: Player introuvable, gameplay local désactivé.")
		set_process(false)
		set_physics_process(false)
		return
	_random.randomize()
	_create_hud()
	_spawn_monsters()
	_spawn_rewards()
	_update_hud()
	_hud.show_toast("Explore les 4 zones • E interagit • F utilise l’objet")


func _process(delta: float) -> void:
	if _hud == null or _completed:
		return
	_shield_time = maxf(_shield_time - delta, 0.0)
	_theft_immunity_time = maxf(_theft_immunity_time - delta, 0.0)
	_collect_contact_candy()
	_update_zone_progress()
	_update_interaction_prompt()
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if _hud == null or _completed or _hud.summary_visible:
		return
	if event.is_action_pressed(&"action_activate"):
		_interact()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_F:
			_use_active_item()
			get_viewport().set_input_as_handled()


func _create_hud() -> void:
	_hud = HUDScript.new() as FactionFightHUD
	add_child(_hud)


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
		{"patrol_speed": 1.75, "chase_speed": 3.25, "detection_radius": 8.5, "chase_limit": 12.0, "scale": 1.08},
		{"idle": "Alert", "walk": "Walking", "alert": "Alert", "run": "Running", "stunned": "Weapon_Combo_1"}
	)


func _spawn_paladin(monster_name: String, spawn_position: Vector3, patrol_offset: Vector3) -> void:
	_spawn_monster(
		monster_name,
		PALADIN_MODEL,
		spawn_position,
		patrol_offset,
		{"patrol_speed": 0.9, "chase_speed": 1.85, "detection_radius": 8.0, "chase_limit": 10.0, "scale": 1.18},
		{"idle": "Listening_Gesture", "walk": "Walking", "alert": "Listening_Gesture", "run": "Running", "stunned": "Punch_Combo_3"}
	)


func _spawn_conqueror(monster_name: String, spawn_position: Vector3, patrol_offset: Vector3) -> void:
	_spawn_monster(
		monster_name,
		CONQUEROR_MODEL,
		spawn_position,
		patrol_offset,
		{"patrol_speed": 1.35, "chase_speed": 2.65, "detection_radius": 9.0, "chase_limit": 12.0, "scale": 1.06},
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
	_spawn_candy(Vector3(-6.0, 0.55, -18.0), 2)
	_spawn_candy(Vector3(11.0, 0.55, -38.0), 3)

	_spawn_item("SPRAY SUCRÉ", Vector3(20.0, 0.45, -78.0), &"sugar_spray", 3)
	_spawn_candy(Vector3(-11.0, 0.55, -65.0), 2)
	_spawn_candy(Vector3(22.0, 0.55, -90.0), 3)
	_spawn_candy(Vector3(24.0, 0.55, -102.0), 4)
	_spawn_chest("COFFRE DES RACINES", Vector3(-12.0, 0.05, -92.0), 5)

	_spawn_item("BOUCLIER CARAMEL", Vector3(-12.0, 0.45, -126.0), &"caramel_shield", 1)
	_spawn_candy(Vector3(-14.0, 0.55, -130.0), 3)
	_spawn_candy(Vector3(4.0, 0.55, -176.0), 4)
	_spawn_chest("COFFRE DE SIROP", Vector3(-13.0, 0.05, -184.0), 6)

	_spawn_candy(Vector3(-8.0, 0.55, -208.0), 4)
	_spawn_candy(Vector3(22.0, 0.55, -226.0), 5)
	_spawn_chest("COFFRE DU SANCTUAIRE", Vector3(-8.0, 0.05, -233.0), 8)


func _spawn_candy(position_3d: Vector3, amount: int) -> void:
	_spawn_pickup(FactionFightPickup.Kind.CANDY, "CANDY +%d" % amount, position_3d, amount)


func _spawn_item(item_name: String, position_3d: Vector3, item_id: StringName, charges: int) -> void:
	_spawn_pickup(FactionFightPickup.Kind.ITEM, item_name, position_3d, 0, item_id, charges)


func _spawn_chest(chest_name: String, position_3d: Vector3, amount: int) -> void:
	_spawn_pickup(FactionFightPickup.Kind.CHEST, "%s • +%d" % [chest_name, amount], position_3d, amount)


func _spawn_pickup(
	kind: int,
	pickup_name: String,
	position_3d: Vector3,
	value: int = 0,
	item_id: StringName = &"",
	charges: int = 0
) -> void:
	var pickup := PickupScript.new() as FactionFightPickup
	add_child(pickup)
	pickup.configure(kind, pickup_name, position_3d, value, item_id, charges)
	_pickups.append(pickup)


func _collect_contact_candy() -> void:
	for pickup: FactionFightPickup in _pickups:
		if is_instance_valid(pickup) and not pickup.collected and pickup.auto_collect:
			if _player.global_position.distance_to(pickup.global_position) <= 1.45:
				_collect_pickup(pickup)


func _update_zone_progress() -> void:
	while _zones_completed < ZONE_THRESHOLDS.size():
		if _player.global_position.z > ZONE_THRESHOLDS[_zones_completed]:
			break
		_zones_completed += 1
		_add_candy(5)
		_hud.show_toast("ZONE %d / 4 • RÉCOMPENSE GARANTIE +5 CANDY" % _zones_completed)
		_spawn_burst(_player.global_position + Vector3.UP, Color(1.0, 0.62, 0.18))


func _update_interaction_prompt() -> void:
	_nearest_interactive = null
	var nearest_distance := 3.2
	for pickup: FactionFightPickup in _pickups:
		if not is_instance_valid(pickup) or pickup.collected or pickup.auto_collect:
			continue
		var distance := _player.global_position.distance_to(pickup.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			_nearest_interactive = pickup
	if _nearest_interactive != null:
		_hud.set_prompt("E  •  %s" % _nearest_interactive.display_name)
		return
	if _portal != null and _player.global_position.distance_to(_portal.global_position) <= 5.0:
		if _zones_completed == 4:
			_hud.set_prompt("E  •  TERMINER FACTION FIGHT")
		else:
			_hud.set_prompt("Explore encore les quatre zones")
		return
	_hud.set_prompt("")


func _interact() -> void:
	if _nearest_interactive != null and is_instance_valid(_nearest_interactive):
		_collect_pickup(_nearest_interactive)
		return
	if _portal != null and _player.global_position.distance_to(_portal.global_position) <= 5.0:
		if _zones_completed == 4:
			_complete_world()
		else:
			_hud.show_toast("Le portail s’ouvrira après les 4 zones", Color(0.75, 0.75, 1.0))


func _collect_pickup(pickup: FactionFightPickup) -> void:
	if not pickup.collect_once():
		return
	_spawn_burst(pickup.global_position + Vector3.UP * 0.4, Color(0.4, 1.0, 0.72))
	match pickup.kind:
		FactionFightPickup.Kind.CANDY:
			_add_candy(pickup.candy_value)
			_hud.show_toast("+%d CANDY" % pickup.candy_value)
		FactionFightPickup.Kind.CHEST:
			_add_candy(pickup.candy_value)
			_hud.show_toast("COFFRE OUVERT • +%d CANDY" % pickup.candy_value)
		FactionFightPickup.Kind.ITEM:
			_active_item = pickup.item_id
			_item_charges = pickup.item_charges
			_hud.show_toast("OBJET ACTIF : %s ×%d" % [ITEM_NAMES.get(_active_item, "OBJET"), _item_charges])


func _use_active_item() -> void:
	if _active_item == &"" or _item_charges <= 0:
		_hud.show_toast("Aucun objet actif", Color(0.8, 0.76, 0.88))
		return
	match _active_item:
		&"candy_cane":
			_use_candy_cane()
		&"sugar_spray":
			_use_sugar_spray()
		&"caramel_shield":
			_use_caramel_shield()


func _use_candy_cane() -> void:
	var affected := 0
	for monster: FactionFightMonster in _monsters:
		if is_instance_valid(monster) and monster.global_position.distance_to(_player.global_position) <= 6.0:
			monster.apply_repel(_player.global_position)
			affected += 1
	if affected == 0:
		_hud.show_toast("Aucun monstre assez proche", Color(0.8, 0.76, 0.88))
		return
	_consume_charge("BÂTON BONBON • MONSTRE REPOUSSÉ !")
	_spawn_burst(_player.global_position + Vector3.UP, Color(1.0, 0.2, 0.36))


func _use_sugar_spray() -> void:
	var target := _nearest_monster(7.0)
	if target == null:
		_hud.show_toast("Aucun monstre à portée du spray", Color(0.8, 0.76, 0.88))
		return
	target.apply_stun(2.6)
	_consume_charge("SPRAY SUCRÉ • MONSTRE DISTRAIT !")
	_spawn_burst(target.global_position + Vector3.UP, Color(0.3, 0.95, 1.0))


func _use_caramel_shield() -> void:
	_shield_time = 8.0
	_consume_charge("BOUCLIER CARAMEL • PROTECTION 8 S")
	_spawn_burst(_player.global_position + Vector3.UP, Color(1.0, 0.48, 0.08))


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
	_hud.show_toast(message)
	if _item_charges <= 0:
		_active_item = &""


func _on_player_bumped(monster: FactionFightMonster, direction: Vector3, strength: float) -> void:
	if not monster.can_steal_candy():
		return
	if _shield_time > 0.0:
		monster.apply_repel(_player.global_position, 1.2, 4.0)
		_hud.show_toast("BOUCLIER ACTIF • AUCUN CANDY VOLÉ")
		return
	_player.move_and_collide(direction * strength)
	monster.apply_repel(_player.global_position, 0.65, 2.5)
	if _theft_immunity_time > 0.0:
		return
	_steal_candy(monster)


func _steal_candy(monster: FactionFightMonster) -> int:
	var requested_amount := _roll_theft_amount()
	var stolen_amount := mini(requested_amount, _candy)
	if stolen_amount <= 0:
		_hud.show_toast("%s n’a trouvé aucun CANDY" % monster.display_name, Color(1.0, 0.58, 0.25))
		return 0
	_candy -= stolen_amount
	result_data.candy_amount = _candy
	_theft_immunity_time = THEFT_IMMUNITY_DURATION
	_update_hud()
	_hud.show_toast("-%d CANDY • VOLÉ PAR %s" % [stolen_amount, monster.display_name], Color(1.0, 0.28, 0.14))
	_spawn_burst(_player.global_position + Vector3.UP, Color(1.0, 0.24, 0.08))
	return stolen_amount


func _roll_theft_amount() -> int:
	return _random.randi_range(1, 5)


func _complete_world() -> void:
	if _completed:
		return
	_completed = true
	var guarantee_added := _ensure_exit_minimum()
	result_data.candy_amount = _candy
	result_data.completed = true
	_nearest_interactive = null
	_hud.set_prompt("")
	for monster: FactionFightMonster in _monsters:
		if is_instance_valid(monster):
			monster.stop_gameplay()
	_hud.show_summary(_candy, guarantee_added)
	_spawn_burst(_portal.global_position + Vector3.UP * 3.0, Color(0.85, 0.25, 1.0))


func _ensure_exit_minimum() -> int:
	var guarantee_added := maxi(MINIMUM_EXIT_CANDY - _candy, 0)
	if guarantee_added > 0:
		_add_candy(guarantee_added)
	return guarantee_added


func _add_candy(amount: int) -> void:
	_candy += amount
	result_data.candy_amount = _candy


func _update_hud() -> void:
	var item_name := String(ITEM_NAMES.get(_active_item, ""))
	_hud.update_status(_candy, _zones_completed, item_name, _item_charges, _shield_time)


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
