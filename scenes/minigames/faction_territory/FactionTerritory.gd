class_name FactionTerritory
extends Node3D

const LOBBY_SCENE_PATH := "res://scenes/levels/main.tscn"
const WORLD_ID: StringName = &"faction_territory"
const LOBBY_RETURN_META: StringName = &"faction_territory_return_to_door"
const ROGUE_STATS: UnitStats = preload("res://scenes/minigames/faction_territory/units/rogue.tres")
const RANGER_STATS: UnitStats = preload("res://scenes/minigames/faction_territory/units/ranger.tres")
const ALL_STATS: Array[UnitStats] = [
	ROGUE_STATS,
	RANGER_STATS,
	preload("res://scenes/minigames/faction_territory/units/mage.tres"),
]
const UNITS_AVAILABLE_AT_START := 1
const CANDIES_PER_SITE := 1
const ENEMY_NERF_MAX_PLAYER_SITES := 1
const ENEMY_NERF_DAMAGE_MULTIPLIER := 0.2
const ENEMY_BOOST_MAX_ENEMY_SITES := 1
const ENEMY_BOOST_DAMAGE_MULTIPLIER := 5.0
const MUSIC_VOLUME_DB: float = -8.0

var _candies := 0

@onready var _player_spawner: UnitSpawner = %PlayerSpawner
@onready var _enemy_spawner: UnitSpawner = %EnemySpawner
@onready var _enemy_ai: EnemyAI = %EnemyAI
@onready var _payout_timer: Timer = %PayoutTimer
@onready var _round_timer: Timer = %RoundTimer
@onready var _hud: FactionTerritoryHud = %Hud
@onready var _result_overlay: FactionTerritoryResultOverlay = %ResultOverlay
@onready var _music: AudioStreamPlayer = %FactionMusic


func _ready() -> void:
	seed(13121988)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_start_music()
	_hud.setup(ALL_STATS, _player_spawner)
	_hud.unit_requested.connect(_on_unit_requested)
	_payout_timer.timeout.connect(_on_payout_timer_timeout)
	_round_timer.timeout.connect(_on_round_timer_timeout)
	_result_overlay.continue_pressed.connect(_on_continue_pressed)
	for site: Site in get_tree().get_nodes_in_group(Site.GROUP):
		site.owner_changed.connect(_on_site_owner_changed)
	_refresh_hud()
	_player_spawner.unit_spawned.connect(_on_player_unit_spawned)
	_enemy_ai.start(ALL_STATS)
	_player_spawner.spawn_free(RANGER_STATS)
	_player_spawner.start_cooldowns(_stats_unlocked_at(0).slice(UNITS_AVAILABLE_AT_START))


func _exit_tree() -> void:
	if is_instance_valid(_music):
		_music.stop()


func _start_music() -> void:
	var local_stream: AudioStreamMP3 = _music.stream.duplicate() as AudioStreamMP3
	local_stream.loop = true
	_music.stream = local_stream
	_music.volume_db = MUSIC_VOLUME_DB
	_music.play()


func _process(_delta: float) -> void:
	_hud.set_time(_round_timer.time_left)


func _on_unit_requested(stats: UnitStats) -> void:
	_player_spawner.spawn(stats)


func _on_player_unit_spawned(_unit: Unit) -> void:
	_player_spawner.start_cooldowns(_stats_unlocked_at(_player_spawner.spawned_count))


func _stats_unlocked_at(spawn_count: int) -> Array[UnitStats]:
	var result: Array[UnitStats] = []
	for stats in ALL_STATS:
		if stats.unlock_after_spawns == spawn_count:
			result.append(stats)
	return result


func _on_site_owner_changed(_site: Site, _side: Faction.Side) -> void:
	_refresh_hud()


func _on_payout_timer_timeout() -> void:
	var gained := _count_player_sites() * CANDIES_PER_SITE
	_candies += gained
	_hud.set_candies(_candies)
	_hud.show_gain(gained)


func _on_round_timer_timeout() -> void:
	ProgressionService.complete_world(WORLD_ID, _candies)
	get_tree().paused = true
	_result_overlay.show_result(_candies)


func _on_continue_pressed() -> void:
	get_tree().paused = false
	SceneTransition.change_scene(LOBBY_SCENE_PATH, _mark_lobby_return)


func _mark_lobby_return() -> void:
	get_tree().set_meta(LOBBY_RETURN_META, true)


func _refresh_hud() -> void:
	_hud.set_candies(_candies)
	_hud.set_sites(_count_player_sites(), get_tree().get_node_count_in_group(Site.GROUP))
	_refresh_enemy_damage()


func _refresh_enemy_damage() -> void:
	var multiplier := 1.0
	if _count_player_sites() <= ENEMY_NERF_MAX_PLAYER_SITES:
		multiplier *= ENEMY_NERF_DAMAGE_MULTIPLIER
	if _count_sites(Faction.Side.ENEMY) <= ENEMY_BOOST_MAX_ENEMY_SITES:
		multiplier *= ENEMY_BOOST_DAMAGE_MULTIPLIER
	_enemy_spawner.damage_multiplier = multiplier


func _count_player_sites() -> int:
	return _count_sites(Faction.Side.PLAYER)


func _count_sites(side: Faction.Side) -> int:
	var count := 0
	for site: Site in get_tree().get_nodes_in_group(Site.GROUP):
		if site.faction == side:
			count += 1
	return count
