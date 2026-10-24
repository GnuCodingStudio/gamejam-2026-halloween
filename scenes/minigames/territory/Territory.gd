class_name Territory
extends Node3D

const LOBBY_SCENE_PATH := "res://scenes/levels/main.tscn"
const ROGUE_STATS: UnitStats = preload("res://scenes/minigames/territory/units/rogue.tres")
const ALL_STATS: Array[UnitStats] = [
	ROGUE_STATS,
	preload("res://scenes/minigames/territory/units/ranger.tres"),
	preload("res://scenes/minigames/territory/units/mage.tres"),
]
const CANDIES_PER_SITE := 1

var _candies := 0

@onready var _player_spawner: UnitSpawner = %PlayerSpawner
@onready var _enemy_ai: EnemyAI = %EnemyAI
@onready var _payout_timer: Timer = %PayoutTimer
@onready var _round_timer: Timer = %RoundTimer
@onready var _hud: TerritoryHud = %Hud
@onready var _result_overlay: TerritoryResultOverlay = %ResultOverlay


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hud.setup(ALL_STATS, _player_spawner)
	_hud.unit_requested.connect(_on_unit_requested)
	_payout_timer.timeout.connect(_on_payout_timer_timeout)
	_round_timer.timeout.connect(_on_round_timer_timeout)
	_result_overlay.continue_pressed.connect(_on_continue_pressed)
	for site: Site in get_tree().get_nodes_in_group(Site.GROUP):
		site.owner_changed.connect(_on_site_owner_changed)
	_refresh_hud()
	_enemy_ai.start(ALL_STATS)
	_player_spawner.spawn(ROGUE_STATS)
	_player_spawner.start_cooldowns(ALL_STATS)


func _process(_delta: float) -> void:
	_hud.set_time(_round_timer.time_left)


func _on_unit_requested(stats: UnitStats) -> void:
	_player_spawner.spawn(stats)


func _on_site_owner_changed(_site: Site, _side: Faction.Side) -> void:
	_refresh_hud()


func _on_payout_timer_timeout() -> void:
	var gained := _count_player_sites() * CANDIES_PER_SITE
	_candies += gained
	_hud.set_candies(_candies)
	_hud.show_gain(gained)


func _on_round_timer_timeout() -> void:
	get_tree().paused = true
	_result_overlay.show_result(_candies)


func _on_continue_pressed() -> void:
	get_tree().paused = false
	SceneTransition.change_scene(LOBBY_SCENE_PATH)


func _refresh_hud() -> void:
	_hud.set_candies(_candies)
	_hud.set_sites(_count_player_sites(), get_tree().get_node_count_in_group(Site.GROUP))


func _count_player_sites() -> int:
	var count := 0
	for site: Site in get_tree().get_nodes_in_group(Site.GROUP):
		if site.faction == Faction.Side.PLAYER:
			count += 1
	return count
